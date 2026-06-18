# Live AI Repaint Prototype Contract

This prototype uses one AI layer only:

```
player prompt -> texture/retexture generation -> preview/apply in Godot
```

The later prompt-interpreter layer is intentionally deferred. Before shipping, revisit a structured interpreter that maps player language into safe material zones, blocked terms, color settings, and editable controls.

## Local Proxy

The fal.ai key must live only in a local `.env` file. Godot never stores or sends the key.

Local base URL:

```
http://127.0.0.1:8787
```

Required endpoints:

```
GET /health
POST /api/repaint
GET /api/repaint/:job_id
```

Prototype request:

```json
{
  "prompt": "red metallic body with black racing stripes",
  "model_url": "https://example.com/player_hypercar.glb",
  "mode": "retexture"
}
```

Prototype response states:

```json
{
  "job_id": "local-or-fal-request-id",
  "status": "queued|running|succeeded|failed",
  "progress": 0.0,
  "message": "human-readable status",
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

The Godot client should tolerate missing optional texture URLs. `base_color_url` is the most important first-pass result.

## Godot Client Signals

Expected signal names:

```gdscript
signal repaint_submitted(job_id: String)
signal repaint_progress(job_id: String, status: String, progress: float, message: String)
signal repaint_succeeded(job_id: String, result: Dictionary)
signal repaint_failed(job_id: String, message: String)
```

## Prototype Safety Rules

- Do not commit `.env`, generated API responses with keys, or downloaded paid outputs unless explicitly approved.
- Store temporary downloads in `user://ai_repaint_cache/` first.
- Keep model replacement optional. The first proof can apply only a generated base-color texture to the body material.
- Keep glass, wheels, tires, lights, and interior untouched for the prototype.
- No prompt-interpreter layer in this branch.
