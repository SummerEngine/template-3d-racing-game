# AI Repaint Proxy

Local Express proxy for the Summer Engine live AI repaint prototype. Godot calls this service at `http://127.0.0.1:8787`, and the proxy calls fal.ai's Meshy retexture model with the secret `FAL_KEY` kept on the local machine.

## Endpoints

- `GET /health`
- `POST /api/repaint`
- `GET /api/repaint/:job_id`
- `POST /api/repaint-texture`
- `GET /api/repaint-texture/:job_id`
- `GET /api/local-texture?path=<repo-relative-texture>`

`POST /api/repaint` accepts:

```json
{
  "prompt": "red metallic race livery with black carbon fiber details",
  "model_url": "https://example.com/model.glb",
  "mode": "retexture"
}
```

Successful job responses use the Godot-facing shape:

```json
{
  "job_id": "fal-request-id",
  "status": "queued",
  "progress": 0.05,
  "message": "Queued for retexture generation."
}
```

Completed responses include:

```json
{
  "job_id": "fal-request-id",
  "status": "succeeded",
  "progress": 1,
  "message": "Retexture generation succeeded.",
  "result": {
    "model_url": "https://...",
    "preview_url": "https://...",
    "base_color_url": "https://...",
    "roughness_url": "https://...",
    "metallic_url": "https://...",
    "normal_url": "https://..."
  }
}
```

## Install and Run

From the repo root:

```sh
cp .env.example .env
```

Edit `.env` locally:

```sh
FAL_KEY=your-local-fal-key
PORT=8787
UV_REPAINT_DRY_RUN=true
FAL_TEXTURE_REPAINT_MODEL_ID=fal-ai/nano-banana-2/edit
```

Do not commit `.env` or any real API key. The repo ignores `.env` files.

Then install and start the proxy:

```sh
cd tools/ai-repaint-proxy
npm install
npm start
```

Health check:

```sh
curl http://127.0.0.1:8787/health
```

Submit a repaint job:

```sh
curl -X POST http://127.0.0.1:8787/api/repaint \
  -H "Content-Type: application/json" \
  -d '{"prompt":"red metallic race livery","model_url":"https://example.com/model.glb","mode":"retexture"}'
```

Poll the returned job:

```sh
curl http://127.0.0.1:8787/api/repaint/<job_id>
```

Submit a dry-run UV texture image-to-image repaint job:

```sh
curl -X POST http://127.0.0.1:8787/api/repaint-texture \
  -H "Content-Type: application/json" \
  -d '{"prompt":"white racing livery with red diagonal stripes","texture_path":"assets/cars/player_hypercar_Image_0.jpg","strength":0.65,"dry_run":true,"mode":"uv_texture_img2img"}'
```

Dry-run returns immediately with `result.base_color_url` pointing back at the local proxy's copy of the source texture. It does not call fal or spend credits.

To opt into a live fal image-edit call later, set `UV_REPAINT_DRY_RUN=false` in local `.env`, keep `FAL_KEY` local, and omit `dry_run` or pass `false`. Local `texture_path` inputs are uploaded to fal storage only in that live mode. Public `texture_url` inputs are sent directly as `image_urls`.

## Notes

- Jobs are stored in memory for the prototype. Restarting the proxy clears the local job map.
- The proxy uses a single AI layer: Godot prompt to Meshy retexture generation to preview/apply URLs.
- The fal model is `fal-ai/meshy/v5/retexture` with original UVs, PBR maps, and safety checker enabled.
- The UV texture experiment uses `fal-ai/nano-banana-2/edit` by default and maps the first returned image URL to `result.base_color_url`.
- `POST /api/repaint` remains the Meshy full-model retexture path. `POST /api/repaint-texture` is the flat UV texture image-to-image path.
