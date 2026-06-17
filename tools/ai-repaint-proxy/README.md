# AI Repaint Proxy

Local Express proxy for the Summer Engine live AI repaint prototype. Godot calls this service at `http://127.0.0.1:8787`, and the proxy calls fal.ai's Meshy retexture model with the secret `FAL_KEY` kept on the local machine.

## Endpoints

- `GET /health`
- `POST /api/repaint`
- `GET /api/repaint/:job_id`

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

## Notes

- Jobs are stored in memory for the prototype. Restarting the proxy clears the local job map.
- The proxy uses a single AI layer: Godot prompt to Meshy retexture generation to preview/apply URLs.
- The fal model is `fal-ai/meshy/v5/retexture` with original UVs, PBR maps, and safety checker enabled.
