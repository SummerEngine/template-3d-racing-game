import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import { fal } from "@fal-ai/client";
import { File } from "node:buffer";
import fs from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const packageRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(packageRoot, "..", "..");

dotenv.config({ path: path.join(repoRoot, ".env"), quiet: true });
dotenv.config({ path: path.join(packageRoot, ".env"), override: true, quiet: true });

const MESHY_RETEXTURE_MODEL_ID = "fal-ai/meshy/v5/retexture";
const TEXTURE_REPAINT_MODEL_ID = process.env.FAL_TEXTURE_REPAINT_MODEL_ID || "fal-ai/nano-banana-2/edit";
const PORT = Number.parseInt(process.env.PORT || "8787", 10);
const TEXTURE_REPAINT_DEFAULT_DRY_RUN = parseBooleanEnv(process.env.UV_REPAINT_DRY_RUN, true);
const LOCAL_TEXTURE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga"]);
const LOCAL_MODEL_EXTENSIONS = new Set([".glb", ".gltf", ".obj"]);
const jobs = new Map();

if (process.env.FAL_KEY) {
  fal.config({ credentials: process.env.FAL_KEY });
}

const app = express();
app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "ai-repaint-proxy",
    model: MESHY_RETEXTURE_MODEL_ID,
    models: {
      retexture: MESHY_RETEXTURE_MODEL_ID,
      texture_img2img: TEXTURE_REPAINT_MODEL_ID,
    },
    fal_configured: Boolean(process.env.FAL_KEY),
    model_path_upload: true,
    texture_repaint_dry_run: TEXTURE_REPAINT_DEFAULT_DRY_RUN,
  });
});

app.post("/api/repaint", async (req, res) => {
  const validationError = validateRepaintRequest(req.body);
  if (validationError) {
    return sendFailed(res, 400, null, validationError);
  }

  if (!process.env.FAL_KEY) {
    return sendFailed(res, 503, null, "FAL_KEY is not configured. Add it to the local .env file.");
  }

  try {
    const { prompt } = req.body;
    const source = resolveModelSource(req.body);
    const modelUrl = source.model_url || await uploadLocalModel(source.model_path);
    const submitted = await fal.queue.submit(MESHY_RETEXTURE_MODEL_ID, {
      input: {
        model_url: modelUrl,
        text_style_prompt: prompt,
        enable_original_uv: true,
        enable_pbr: true,
        enable_safety_checker: true,
      },
    });

    const jobId = submitted.request_id || submitted.requestId;
    if (!jobId) {
      throw new Error("fal queue did not return a request id.");
    }

    const job = {
      job_id: jobId,
      fal_request_id: jobId,
      model_id: MESHY_RETEXTURE_MODEL_ID,
      kind: "retexture",
      status: "queued",
      progress: 0.05,
      message: "Queued for retexture generation.",
      result: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    jobs.set(jobId, job);
    return res.status(202).json(toPublicJob(job));
  } catch (error) {
    return sendFailed(res, 502, null, getErrorMessage(error));
  }
});

app.post("/api/repaint-texture", async (req, res) => {
  const validationError = validateTextureRepaintRequest(req.body);
  if (validationError) {
    return sendFailed(res, 400, null, validationError);
  }

  try {
    const source = resolveTextureSource(req.body, req);
    if (shouldDryRunTextureRepaint(req.body)) {
      const job = createDryRunTextureJob(req.body, source);
      jobs.set(job.job_id, job);
      return res.json(toPublicJob(job));
    }

    if (!process.env.FAL_KEY) {
      return sendFailed(
        res,
        503,
        null,
        "FAL_KEY is not configured. Keep UV_REPAINT_DRY_RUN=true for mock responses or add a local .env key."
      );
    }

    const textureUrl = source.texture_url || await uploadLocalTexture(source.texture_path);
    const submitted = await fal.queue.submit(TEXTURE_REPAINT_MODEL_ID, {
      input: buildTextureRepaintInput(req.body, textureUrl),
    });

    const jobId = submitted.request_id || submitted.requestId;
    if (!jobId) {
      throw new Error("fal queue did not return a request id.");
    }

    const job = {
      job_id: jobId,
      fal_request_id: jobId,
      model_id: TEXTURE_REPAINT_MODEL_ID,
      kind: "texture_img2img",
      status: "queued",
      progress: 0.05,
      message: "Queued for UV texture image-to-image repaint.",
      result: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    jobs.set(jobId, job);
    return res.status(202).json(toPublicJob(job));
  } catch (error) {
    return sendFailed(res, 502, null, getErrorMessage(error));
  }
});

app.get("/api/local-texture", async (req, res) => {
  const texturePath = typeof req.query.path === "string" ? req.query.path : "";
  const resolved = resolveLocalTexturePath(texturePath);
  if (typeof resolved === "string") {
    return sendFailed(res, 400, null, resolved);
  }

  try {
    await fs.access(resolved.absolute_path);
    return res.sendFile(resolved.absolute_path);
  } catch {
    return sendFailed(res, 404, null, "Local texture file was not found.");
  }
});

app.get("/api/repaint-texture/:job_id", async (req, res) => {
  return sendJobStatus(req, res);
});

app.get("/api/repaint/:job_id", async (req, res) => {
  return sendJobStatus(req, res);
});

async function sendJobStatus(req, res) {
  const job = jobs.get(req.params.job_id);
  if (!job) {
    return sendFailed(res, 404, req.params.job_id, "Unknown repaint job. The proxy keeps jobs in memory only.");
  }

  if (job.status === "succeeded" || job.status === "failed") {
    return res.json(toPublicJob(job));
  }

  try {
    await refreshJob(job);
    return res.json(toPublicJob(job));
  } catch (error) {
    job.status = "failed";
    job.progress = 1;
    job.message = getErrorMessage(error);
    job.updated_at = new Date().toISOString();
    return res.status(502).json(toPublicJob(job));
  }
}

app.use((_req, res) => {
  sendFailed(res, 404, null, "Not found.");
});

app.use((error, _req, res, _next) => {
  sendFailed(res, 500, null, getErrorMessage(error));
});

app.listen(PORT, "127.0.0.1", () => {
  console.log(`ai-repaint-proxy listening on http://127.0.0.1:${PORT}`);
});

function validateRepaintRequest(body) {
  if (!body || typeof body !== "object") {
    return "Request body must be a JSON object.";
  }

  if (typeof body.prompt !== "string" || body.prompt.trim().length === 0) {
    return "prompt is required and must be a non-empty string.";
  }

  if (body.prompt.length > 600) {
    return "prompt must be 600 characters or fewer for Meshy retexture.";
  }

  const hasModelUrl = typeof body.model_url === "string" && body.model_url.trim().length > 0;
  const hasModelPath = typeof body.model_path === "string" && body.model_path.trim().length > 0;
  if (hasModelUrl === hasModelPath) {
    return "Provide exactly one of model_url or model_path.";
  }

  if (hasModelUrl && !isHttpUrl(body.model_url)) {
    return "model_url must be an http or https URL.";
  }

  if (hasModelPath) {
    const resolved = resolveLocalModelPath(body.model_path);
    if (typeof resolved === "string") {
      return resolved;
    }
  }

  if (body.mode !== undefined && body.mode !== "retexture") {
    return 'mode must be "retexture" when provided.';
  }

  return null;
}

function validateTextureRepaintRequest(body) {
  if (!body || typeof body !== "object") {
    return "Request body must be a JSON object.";
  }

  if (typeof body.prompt !== "string" || body.prompt.trim().length === 0) {
    return "prompt is required and must be a non-empty string.";
  }

  if (body.prompt.length > 800) {
    return "prompt must be 800 characters or fewer for UV texture repaint.";
  }

  const hasTextureUrl = typeof body.texture_url === "string" && body.texture_url.trim().length > 0;
  const hasTexturePath = typeof body.texture_path === "string" && body.texture_path.trim().length > 0;
  if (hasTextureUrl === hasTexturePath) {
    return "Provide exactly one of texture_url or texture_path.";
  }

  if (hasTextureUrl && !isHttpUrl(body.texture_url)) {
    return "texture_url must be an http or https URL.";
  }

  if (hasTexturePath) {
    const resolved = resolveLocalTexturePath(body.texture_path);
    if (typeof resolved === "string") {
      return resolved;
    }
  }

  if (body.strength !== undefined && !isUnitNumber(body.strength)) {
    return "strength must be a number between 0 and 1 when provided.";
  }

  if (body.dry_run !== undefined && typeof body.dry_run !== "boolean") {
    return "dry_run must be a boolean when provided.";
  }

  if (body.mode !== undefined && body.mode !== "texture_img2img" && body.mode !== "uv_texture_img2img") {
    return 'mode must be "texture_img2img" or "uv_texture_img2img" when provided.';
  }

  return null;
}

async function refreshJob(job) {
  const modelId = job.model_id || MESHY_RETEXTURE_MODEL_ID;
  const status = await fal.queue.status(modelId, {
    requestId: job.fal_request_id,
    logs: true,
  });

  const falStatus = status.status;
  job.updated_at = new Date().toISOString();

  if (falStatus === "IN_QUEUE") {
    job.status = "queued";
    job.progress = 0.05;
    job.message = formatQueueMessage(job, status);
    return;
  }

  if (falStatus === "IN_PROGRESS") {
    job.status = "running";
    job.progress = 0.5;
    job.message = getLastLogMessage(status) || runningMessage(job);
    return;
  }

  if (falStatus === "COMPLETED") {
    const result = await fal.queue.result(modelId, {
      requestId: job.fal_request_id,
    });

    job.status = "succeeded";
    job.progress = 1;
    job.message = successMessage(job);
    job.result = normalizeFalResult(job, result.data);
    return;
  }

  job.status = "failed";
  job.progress = 1;
  job.message = getLastLogMessage(status) || failedMessage(job, falStatus);
}

function normalizeFalResult(job, data = {}) {
  if (job.kind === "texture_img2img") {
    return normalizeTextureRepaintFalResult(data);
  }

  return normalizeMeshyFalResult(data);
}

function normalizeMeshyFalResult(data = {}) {
  const texture = Array.isArray(data.texture_urls) ? data.texture_urls[0] || {} : data.texture_urls || {};

  return {
    model_url: getUrl(data.model_glb) || getUrl(data.model_urls?.glb),
    preview_url: getUrl(data.thumbnail),
    base_color_url: getUrl(texture.base_color),
    roughness_url: getUrl(texture.roughness),
    metallic_url: getUrl(texture.metallic),
    normal_url: getUrl(texture.normal),
  };
}

function normalizeTextureRepaintFalResult(data = {}) {
  const image = Array.isArray(data.images) ? data.images[0] || {} : data.image || {};
  const imageUrl = getUrl(image);
  if (!imageUrl) {
    throw new Error("fal texture repaint result did not include an image URL.");
  }

  return {
    model_url: null,
    preview_url: imageUrl,
    base_color_url: imageUrl,
    roughness_url: null,
    metallic_url: null,
    normal_url: null,
  };
}

function getUrl(file) {
  if (typeof file === "string" && file.length > 0) {
    return file;
  }
  return typeof file?.url === "string" && file.url.length > 0 ? file.url : null;
}

function formatQueueMessage(job, status) {
  const prefix = job.kind === "texture_img2img"
    ? "Queued for UV texture image-to-image repaint."
    : "Queued for retexture generation.";

  if (typeof status.queue_position === "number") {
    return `${prefix} Position ${status.queue_position}.`;
  }

  return prefix;
}

function runningMessage(job) {
  return job.kind === "texture_img2img"
    ? "UV texture image-to-image repaint is running."
    : "Retexture generation is running.";
}

function successMessage(job) {
  return job.kind === "texture_img2img"
    ? "UV texture image-to-image repaint succeeded."
    : "Retexture generation succeeded.";
}

function failedMessage(job, falStatus) {
  return job.kind === "texture_img2img"
    ? `UV texture image-to-image repaint failed with fal status ${falStatus}.`
    : `Retexture generation failed with fal status ${falStatus}.`;
}

function resolveTextureSource(body, req) {
  if (typeof body.texture_url === "string" && body.texture_url.trim().length > 0) {
    return {
      source: "url",
      texture_url: body.texture_url.trim(),
      texture_path: null,
      texture_public_url: null,
    };
  }

  const resolved = resolveLocalTexturePath(body.texture_path);
  if (typeof resolved === "string") {
    throw new Error(resolved);
  }

  return {
    source: "path",
    texture_url: null,
    texture_path: resolved.absolute_path,
    texture_public_url: localTextureUrl(req, resolved.relative_path),
  };
}

function resolveModelSource(body) {
  if (typeof body.model_url === "string" && body.model_url.trim().length > 0) {
    return {
      source: "url",
      model_url: body.model_url.trim(),
      model_path: null,
    };
  }

  const resolved = resolveLocalModelPath(body.model_path);
  if (typeof resolved === "string") {
    throw new Error(resolved);
  }

  return {
    source: "path",
    model_url: null,
    model_path: resolved.absolute_path,
  };
}

function createDryRunTextureJob(body, source) {
  const now = new Date().toISOString();
  const sourceUrl = source.texture_url || source.texture_public_url;
  const jobId = `texture-dry-run-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

  return {
    job_id: jobId,
    fal_request_id: null,
    model_id: TEXTURE_REPAINT_MODEL_ID,
    kind: "texture_img2img",
    status: "succeeded",
    progress: 1,
    message: "Dry-run UV texture repaint returned the source texture without calling fal.",
    result: {
      model_url: null,
      preview_url: sourceUrl,
      base_color_url: sourceUrl,
      roughness_url: null,
      metallic_url: null,
      normal_url: null,
      dry_run: true,
      prompt: body.prompt.trim(),
      strength: textureRepaintStrength(body),
    },
    created_at: now,
    updated_at: now,
  };
}

async function uploadLocalTexture(absolutePath) {
  return uploadLocalFile(absolutePath);
}

async function uploadLocalModel(absolutePath) {
  return uploadLocalFile(absolutePath);
}

async function uploadLocalFile(absolutePath) {
  const bytes = await fs.readFile(absolutePath);
  const file = new File([bytes], path.basename(absolutePath), {
    type: mimeTypeForPath(absolutePath),
  });
  return fal.storage.upload(file);
}

function buildTextureRepaintInput(body, textureUrl) {
  return {
    prompt: buildTextureRepaintPrompt(body.prompt, textureRepaintStrength(body)),
    image_urls: [textureUrl],
    num_images: 1,
    aspect_ratio: "auto",
    output_format: "png",
    safety_tolerance: "4",
    resolution: textureRepaintResolution(body),
    limit_generations: true,
    system_prompt: "Edit the provided flat UV texture map. Preserve the UV layout, island silhouettes, padding, and canvas framing.",
  };
}

function buildTextureRepaintPrompt(prompt, strength) {
  const strengthPercent = Math.round(strength * 100);
  return [
    "This is a flat UV texture map for a 3D vehicle, not a camera photo.",
    "Keep the same UV island positions, island boundaries, blank padding, and canvas aspect ratio.",
    "Do not crop, rotate, add new islands, merge islands, or repaint outside the existing mapped texture areas.",
    `Apply the user's livery/material design at about ${strengthPercent}% edit strength while preserving baked shading cues where useful.`,
    `User design prompt: ${prompt.trim()}`,
  ].join(" ");
}

function resolveLocalTexturePath(texturePath) {
  if (typeof texturePath !== "string" || texturePath.trim().length === 0) {
    return "texture_path is required and must be a non-empty string.";
  }

  const cleanPath = texturePath.trim().replace(/^res:\/\//, "");
  const absolutePath = path.isAbsolute(cleanPath)
    ? path.resolve(cleanPath)
    : path.resolve(repoRoot, cleanPath);

  if (!isPathInside(absolutePath, repoRoot)) {
    return "texture_path must resolve inside this repo worktree.";
  }

  if (!LOCAL_TEXTURE_EXTENSIONS.has(path.extname(absolutePath).toLowerCase())) {
    return "texture_path must point to a supported texture image file.";
  }

  return {
    absolute_path: absolutePath,
    relative_path: path.relative(repoRoot, absolutePath).split(path.sep).join("/"),
  };
}

function resolveLocalModelPath(modelPath) {
  if (typeof modelPath !== "string" || modelPath.trim().length === 0) {
    return "model_path is required and must be a non-empty string.";
  }

  const cleanPath = modelPath.trim().replace(/^res:\/\//, "");
  const absolutePath = path.isAbsolute(cleanPath)
    ? path.resolve(cleanPath)
    : path.resolve(repoRoot, cleanPath);

  if (!isPathInside(absolutePath, repoRoot)) {
    return "model_path must resolve inside this repo worktree.";
  }

  if (!LOCAL_MODEL_EXTENSIONS.has(path.extname(absolutePath).toLowerCase())) {
    return "model_path must point to a supported model file.";
  }

  return {
    absolute_path: absolutePath,
    relative_path: path.relative(repoRoot, absolutePath).split(path.sep).join("/"),
  };
}

function localTextureUrl(req, relativePath) {
  const host = req.get("host") || `127.0.0.1:${PORT}`;
  const query = new URLSearchParams({ path: relativePath });
  return `http://${host}/api/local-texture?${query.toString()}`;
}

function shouldDryRunTextureRepaint(body) {
  return body.dry_run === true || TEXTURE_REPAINT_DEFAULT_DRY_RUN;
}

function textureRepaintStrength(body) {
  return isUnitNumber(body.strength) ? Number(body.strength) : 0.65;
}

function textureRepaintResolution(body) {
  const allowed = new Set(["0.5K", "1K", "2K", "4K"]);
  if (typeof body.resolution === "string" && allowed.has(body.resolution)) {
    return body.resolution;
  }
  return "1K";
}

function isHttpUrl(value) {
  try {
    const parsed = new URL(String(value));
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

function isPathInside(childPath, parentPath) {
  const relative = path.relative(parentPath, childPath);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function isUnitNumber(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1;
}

function mimeTypeForPath(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case ".glb":
      return "model/gltf-binary";
    case ".gltf":
      return "model/gltf+json";
    case ".obj":
      return "model/obj";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".webp":
      return "image/webp";
    case ".bmp":
      return "image/bmp";
    case ".tga":
      return "image/x-tga";
    case ".png":
    default:
      return "image/png";
  }
}

function getLastLogMessage(status) {
  const logs = Array.isArray(status.logs) ? status.logs : [];
  const lastLog = logs.findLast((log) => typeof log?.message === "string" && log.message.trim().length > 0);
  return lastLog?.message || null;
}

function toPublicJob(job) {
  const payload = {
    job_id: job.job_id,
    status: job.status,
    progress: job.progress,
    message: job.message,
  };

  if (job.result) {
    payload.result = job.result;
  }

  return payload;
}

function sendFailed(res, httpStatus, jobId, message) {
  return res.status(httpStatus).json({
    job_id: jobId,
    status: "failed",
    progress: 1,
    message,
  });
}

function getErrorMessage(error) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return "Unexpected repaint proxy error.";
}

function parseBooleanEnv(value, fallback) {
  if (typeof value !== "string" || value.trim().length === 0) {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  return fallback;
}
