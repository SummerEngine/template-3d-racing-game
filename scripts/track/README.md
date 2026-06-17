# Track Foundation API

`TrackProfile` is the designer-facing data resource for track length, road width,
material/color identity, guardrails, music, spawn grid, environment sections, and
transition bands.

`EnvironmentProfile` owns reusable scenery rules. Roadside rules store offsets
from the road edge, so placement should use:

```text
road_center + road_normal * side * (road_width / 2 + road_edge_offset)
```

`TransitionProfile` blends adjacent environments over a ratio band. If a profile
has more than one environment section and no explicit transitions, `TrackProfile`
can auto-generate default centered transitions at section boundaries.

`TrackQuery` is the public runtime contract for other systems:

- `sample_at_distance(distance: float) -> Dictionary`
- `lane_transform(distance: float, lane_index: int) -> Transform3D`
- `closest_distance_for_position(position: Vector3) -> float`
- `environment_weights_at_distance(distance: float) -> Dictionary`
- `get_track_length_m() -> float`
- `get_road_width_m() -> float`
- `get_spawn_transform(grid_index: int) -> Transform3D`

Do not consume `TrackPath.centerline` directly from race, NPC, camera, HUD, or VFX
code. Use `TrackQuery` so the path representation can change later.
