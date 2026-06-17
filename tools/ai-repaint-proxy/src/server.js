import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import { fal } from "@fal-ai/client";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const packageRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(packageRoot, "..", "..");

dotenv.config({ path: path.join(repoRoot, ".env"), quiet: true });
dotenv.config({ path: path.join(packageRoot, ".env"), override: false, quiet: true });

const MODEL_ID = "fal-ai/meshy/v5/retexture";
const PORT = Number.parseInt(process.env.PORT || "8787", 10);
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
    model: MODEL_ID,
    fal_configured: Boolean(process.env.FAL_KEY),
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
    const { prompt, model_url } = req.body;
    const submitted = await fal.queue.submit(MODEL_ID, {
      input: {
        model_url,
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

app.get("/api/repaint/:job_id", async (req, res) => {
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
});

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

  if (typeof body.model_url !== "string" || body.model_url.trim().length === 0) {
    return "model_url is required and must be a non-empty string.";
  }

  if (body.mode !== undefined && body.mode !== "retexture") {
    return 'mode must be "retexture" when provided.';
  }

  return null;
}

async function refreshJob(job) {
  const status = await fal.queue.status(MODEL_ID, {
    requestId: job.fal_request_id,
    logs: true,
  });

  const falStatus = status.status;
  job.updated_at = new Date().toISOString();

  if (falStatus === "IN_QUEUE") {
    job.status = "queued";
    job.progress = 0.05;
    job.message = formatQueueMessage(status);
    return;
  }

  if (falStatus === "IN_PROGRESS") {
    job.status = "running";
    job.progress = 0.5;
    job.message = getLastLogMessage(status) || "Retexture generation is running.";
    return;
  }

  if (falStatus === "COMPLETED") {
    const result = await fal.queue.result(MODEL_ID, {
      requestId: job.fal_request_id,
    });

    job.status = "succeeded";
    job.progress = 1;
    job.message = "Retexture generation succeeded.";
    job.result = normalizeFalResult(result.data);
    return;
  }

  job.status = "failed";
  job.progress = 1;
  job.message = getLastLogMessage(status) || `Retexture generation failed with fal status ${falStatus}.`;
}

function normalizeFalResult(data = {}) {
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

function getUrl(file) {
  return typeof file?.url === "string" && file.url.length > 0 ? file.url : null;
}

function formatQueueMessage(status) {
  if (typeof status.queue_position === "number") {
    return `Queued for retexture generation. Position ${status.queue_position}.`;
  }

  return "Queued for retexture generation.";
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
