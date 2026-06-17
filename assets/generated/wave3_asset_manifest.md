# Wave 3 Generated Asset Manifest

Generated on 2026-06-16 for the Arcade Drift Racer vertical slice.

## 3D

| Role | Summer Asset ID | Project Path | Status |
|---|---|---|---|
| Polished low-poly arcade race car | `35de701b-7cab-43bd-8b22-aacb6ae27928` | `res://assets/generated/cars/wave3_arcade_race_car.glb` | Imported and staged as art candidate. Not swapped into the playable car yet because the current car prefab has known wheel nodes for steering and wheel rotation. |
| Race car texture | generated with car asset | `res://assets/generated/cars/wave3_arcade_race_car_texture_20250901.png` | Imported with GLB. |

Prompt:

```text
A polished low-poly toy-like arcade drift race car for a Godot racing game, compact stylized open-wheel/fantasy kart silhouette, chunky readable proportions, separate-looking wheels, rear spoiler, bright clean surfaces, simple forms, game-ready low poly, no text, no real brands, centered on origin, facing forward, approximate size 2 meters wide and 4 meters long
```

## Audio

| Role | Summer Asset ID | Project Path | Status |
|---|---|---|---|
| Race music loop | `d40b44ee-a266-4d66-b474-6c4b748bff6d` | `res://assets/audio/music/race_loop_arcade_drift.mp3` | Wired through `RaceAudioController`. |
| Engine loop | `7a2ac12c-0f78-42c0-94de-463a09b44b74` | `res://assets/audio/sfx/engine_loop_arcade.mp3` | Wired through `VehicleAudioController`. |
| Drift tire loop | `727b1ecd-2831-4dd4-b397-529bc33b2bef` | `res://assets/audio/sfx/drift_tire_screech.mp3` | Wired through `VehicleAudioController`. |
| Car bump one-shot | `a98f9513-0a79-4e4e-82af-3a1197ea7a9e` | `res://assets/audio/sfx/car_bump_toy.mp3` | Wired through `VehicleAudioController`. |
| Wall scrape one-shot | `7eb4b4f1-3677-41be-8973-e571bdae0f06` | `res://assets/audio/sfx/wall_scrape_sparks.mp3` | Wired through `VehicleAudioController`. |
| Countdown/start stinger | `8e835f40-1098-488f-ba3b-1e52e8565004` | `res://assets/audio/sfx/countdown_start_stinger.mp3` | Wired through `RaceAudioController`. |
| Finish stinger | `758a9532-3bbe-4593-bb55-80d7a3800cc8` | `res://assets/audio/sfx/race_finish_stinger.mp3` | Wired through `RaceAudioController`. |

## Notes

- Vehicle SFX route to `Master` for now because the project currently has no committed `default_bus_layout.tres`.
- The playable car uses procedural low-poly geometry plus four color variants: blue player, green Technician, red Bully, yellow Showoff.
- Swapping the generated GLB into gameplay should be a separate art-integration pass: split body/wheels, preserve `CameraTarget`, and keep `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR` control paths intact.
