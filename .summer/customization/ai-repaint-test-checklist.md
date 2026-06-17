# AI Repaint Test Checklist

Use this checklist to validate the live AI car repaint prototype before calling the branch ready. The prototype proves the local proxy, Godot UI, and body-material application path; it does not validate a production prompt interpreter.

## Security Checks

- Confirm no `FAL_KEY` or fal.ai secret appears in committed files.
- Confirm `.env` exists only locally and is ignored by git.
- Confirm Godot calls only the local proxy at `http://127.0.0.1:8787` or `http://localhost:8787`.
- Confirm Godot does not store, log, or send the fal.ai key.
- Confirm generated API responses, downloaded paid outputs, and temporary files are not committed unless explicitly approved.

Suggested commands:

```sh
git status --short
git check-ignore -v .env
rg "FAL_KEY|fal_key|fal\\.ai|api[_-]?key|secret" .
```

## Proxy Tests

- `GET /health` returns a successful response when the proxy is running.
- Missing `FAL_KEY` produces a clear local error and does not crash the proxy.
- Missing or empty `prompt` returns a validation error.
- Missing or invalid `model_url` returns a validation error.
- Bad `model_url` values are rejected or fail with a useful message.
- Unsupported repaint mode or provider/model settings fail cleanly.
- `POST /api/repaint` returns a `job_id` and one of the expected states: `queued`, `running`, `succeeded`, or `failed`.
- `GET /api/repaint/:job_id` returns progress, message text, and result URLs when available.
- Failed jobs return a readable error message without leaking secrets.

## Godot Tests

- Repaint UI launches without script errors.
- Prompt field accepts a repaint prompt.
- Submit starts a request against the local proxy.
- UI status changes from idle to queued/running and then succeeded or failed.
- On success, the generated texture applies to the body paint material.
- If the proxy returns a placeholder texture, the placeholder still applies to the body paint material.
- Reset restores the original body material or texture.
- Wheels/rims remain unchanged after repaint.
- Tires remain unchanged after repaint.
- Glass remains unchanged after repaint.
- Lights, interior, decals, and carbon trim remain unchanged where present.
- Failed requests show a readable status and leave the current vehicle materials intact.
- Repeated submissions do not stack duplicate materials indefinitely.

## Prototype Success Criteria

- A user can enter a prompt, submit it, and see the body paint update in Godot.
- The fal.ai key stays outside the repo and outside Godot.
- The local proxy is the only network service Godot needs to know about.
- The applier changes the intended body material only.
- Reset provides a quick way back to the original look.
- Errors are visible enough for a developer to diagnose without opening provider dashboards first.

## Known Limitations

- The prototype may apply only `base_color_url`; roughness, metallic, normal, and full model replacement can come later.
- Texture generation quality depends on the source model UVs and material naming.
- Mirrored or overlapping body UVs will limit asymmetric decals, numbers, and readable text.
- The prototype does not yet provide structured prompt controls, moderation rules, repaint zones, or player-facing guardrails.
- Generated textures may need manual cleanup before being used in public screenshots or builds.
- This branch is not a shipping implementation.

## Before Ship

Revisit the deferred prompt interpreter layer before shipping. It should translate player language into safe material zones, blocked terms, color settings, decal controls, and predictable repaint options instead of sending raw prompts straight through the prototype path.
