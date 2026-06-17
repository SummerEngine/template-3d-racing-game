# Storm Coast Wave 1 Agent Dispatch

Date: 2026-06-16
Project: Demo
Status: Dispatched

## Goal

Start implementation on the foundation layers that can run in parallel with low conflict.

No commits should be made. The project is currently local-only and has no GitHub repo.

## Launched Agents

| Agent | Nickname | Responsibility | Write Scope |
|---|---|---|---|
| G | Lorentz | Premium profiles and materials foundation | `scripts/profiles/*`, `resources/profiles/*`, `resources/materials/*` |
| A | Singer | Track authoring tool scaffolding | `scripts/track_authoring/*`, excluding `generated_props/*`; `resources/tracks/storm_coast/*`; optional `scenes/tracks/storm_coast/*` |
| B | Bohr | Track query and road mesh generator v2 foundation | New `scripts/track/*` v2 files; optional `resources/tracks/storm_coast/*` |
| F | Pasteur | Generated prop stable IDs and overrides | `scripts/track_authoring/generated_props/*` |
| C | Fermat | Start grid and race input gate foundation | `scripts/race/input_gate/*`, start grid resources/scripts |
| D | Chandrasekhar | Multi-view camera system foundation | `scripts/camera/*`, optional `resources/profiles/camera/*` |

## Held For Wave 2

- Cliffside jump set piece.
- Scene integration.
- Input map edits in `project.godot`.
- Existing race scene mutation.
- Car model swapping.

## Coordination Rules

- Each agent owns its assigned write scope.
- High-conflict files stay untouched unless a later integration pass owns them.
- The main thread will review results before integration.
- `C` remains the camera toggle.
- `V` is hold look-back.
- `Tab` is race menu/overlay.
