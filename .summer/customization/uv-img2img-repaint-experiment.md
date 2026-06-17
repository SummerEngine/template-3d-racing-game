# UV Texture Image-to-Image Repaint Experiment

## Goal

Prototype an alternate live repaint path that edits the car's existing flat UV texture instead of asking a 3D retexture model to generate a new GLB/material package.

Current starter texture:

```text
assets/cars/player_hypercar_Image_0.jpg
```

The proxy can use this already extracted file through `texture_path`, so this experiment does not need to extract embedded GLB images before the first dry-run or live-provider test.

## Proxy Contract

Dry-run-safe endpoint:

```http
POST /api/repaint-texture
```

Request:

```json
{
  "prompt": "white racing livery with red diagonal stripes",
  "texture_path": "assets/cars/player_hypercar_Image_0.jpg",
  "strength": 0.65,
  "dry_run": true,
  "mode": "uv_texture_img2img"
}
```

Use exactly one of:

- `texture_path`: repo-local texture path, including `res://assets/...`
- `texture_url`: public HTTP(S) texture URL

Response shape matches the existing repaint job contract:

```json
{
  "job_id": "texture-dry-run-...",
  "status": "succeeded",
  "progress": 1,
  "message": "Dry-run UV texture repaint returned the source texture without calling fal.",
  "result": {
    "model_url": null,
    "preview_url": "http://127.0.0.1:8787/api/local-texture?path=assets%2Fcars%2Fplayer_hypercar_Image_0.jpg",
    "base_color_url": "http://127.0.0.1:8787/api/local-texture?path=assets%2Fcars%2Fplayer_hypercar_Image_0.jpg",
    "roughness_url": null,
    "metallic_url": null,
    "normal_url": null
  }
}
```

Poll live jobs at:

```http
GET /api/repaint-texture/:job_id
```

`GET /api/repaint/:job_id` also reads from the same in-memory job map, but new clients should use the texture-specific poll route.

## Provider Shape

The live implementation is prepared for `fal-ai/nano-banana-2/edit` by default. The official fal.ai API page at `https://fal.ai/models/fal-ai/nano-banana-2/edit/api` documents `image_urls` as the image-edit input and an `images` array as the output. The proxy maps the first returned image URL to `result.base_color_url` so the current Godot result parser can tolerate a texture-only result.

Live calls are opt-in:

```text
UV_REPAINT_DRY_RUN=false
FAL_KEY=<local key only>
```

Keep `UV_REPAINT_DRY_RUN=true` for development checks. Do not commit `.env`, generated paid outputs, or API responses containing secrets.

## How This Differs From Meshy Retexture

Meshy retexture path:

```text
prompt + model_url -> fal-ai/meshy/v5/retexture -> model_glb + PBR texture URLs
```

UV texture image-to-image path:

```text
prompt + existing flat base-color texture -> image-edit model -> new base_color_url only
```

The UV path keeps the original GLB, mesh, material slots, UV coordinates, normal map, metallic map, and roughness map. Only the base-color/albedo texture is swapped. It should be faster to preview and easier to apply in Godot, but it gives up full PBR regeneration unless later steps synthesize matching roughness/metallic/normal maps.

## Why UV Layout Should Be Preserved

The source image is already the texture atlas used by the car's material. If the image-edit model keeps the same canvas, UV island positions, island boundaries, and blank padding, the original mesh UVs will sample the new design in the same places.

The proxy prompt explicitly tells the model to preserve:

- UV island positions
- island silhouettes and boundaries
- blank padding/unused areas
- canvas aspect ratio and framing

Godot then applies `result.base_color_url` to the same body material path, so no model replacement is needed.

## Known Risks

- The image model may redraw island boundaries, fill padding, or add design details outside mapped areas.
- Canvas size can change, even when the prompt asks it not to; a post-check should reject dimension mismatches.
- Text, numbers, and logos can distort across UV seams or mirrored UVs.
- The model may hallucinate panel lines or lighting baked into the albedo.
- Fine decals can blur because the model sees a texture atlas, not a rendered car.
- A base-color-only output may clash with the existing normal/roughness/metallic maps.
- If the current GLB uses overlapping or mirrored UVs, asymmetric liveries cannot be reliable.

## Embedded GLB Texture Extraction Plan

Current prototype starts from `assets/cars/player_hypercar_Image_0.jpg`.

For a GLB with only embedded images:

1. Inspect the GLB materials and find the body material's `baseColorTexture`.
2. Export the embedded image to a stable repo path such as `assets/cars/<car>_body_base_color.png`.
3. Record which material slot uses that texture so the Godot applier swaps only the repaintable body material.
4. Keep protected materials, such as glass, tires, rims, lights, and interior, on separate material slots or excluded UV regions.
5. Add an automated dimension check before accepting the provider output.

## Godot Helper

`scripts/customization/uv_texture_repaint_client.gd` extends `RepaintClient` and submits to `/api/repaint-texture`.

Default exports:

```text
source_texture_path = res://assets/cars/player_hypercar_Image_0.jpg
strength = 0.65
dry_run = true
```

It emits:

```gdscript
signal repaint_preview_ready(preview_result: Dictionary)
signal preview_ready(preview_result: Dictionary)
```

The emitted dictionary includes `base_color_url`, `preview_url`, `mode = "uv_texture_img2img"`, and `job_id`.

## Next Live Test

1. Start the proxy with `UV_REPAINT_DRY_RUN=true`.
2. Submit the curl example from `tools/ai-repaint-proxy/README.md` and confirm `base_color_url` serves the source texture.
3. Set a local `FAL_KEY` and `UV_REPAINT_DRY_RUN=false`.
4. Submit one low-risk prompt against `assets/cars/player_hypercar_Image_0.jpg`.
5. Verify the output dimensions and that island padding/bounds survived.
6. Apply the returned `base_color_url` to the body material and inspect seams, text orientation, and protected materials.
