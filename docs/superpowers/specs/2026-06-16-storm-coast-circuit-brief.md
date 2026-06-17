# Storm Coast Circuit Brief

Date: 2026-06-16
Project: Demo
Status: Track 1 concept locked

## 1. Track Identity

Storm Coast Circuit is the first premium-realism track prototype.

It is a rainy mountain/coastal road with wet asphalt, cliffs, guardrails, power lines, mist, tunnel or bridge moments, distant ocean/mountain views, premium car reflections, tire spray, and strong headlight/brake-light readability.

The road should feel believable first. It is not a stunt park. The signature arcade moment is one engineered cliffside jump that feels like a temporary race-event structure built into a dangerous coastal route.

## 2. Core Direction

- Environment: rainy mountain/coastal.
- Weather: light rain or recently-rained wet road.
- Time: overcast late afternoon or moody storm light.
- Road style: realistic asphalt with vertical variation, banking, variable width, and realistic shoulders/guardrails.
- Arcade set piece: cliffside jump.
- Road realism: believable road with one impossible/event structure.
- Camera: multiple selectable camera views from the start.

## 3. Cliffside Jump

The cliffside jump should be authored as a set-piece module with entry and exit sockets.

Required parts:

- Approach straight or fast sweeping bend.
- Clear player-readable jump warning.
- Takeoff ramp integrated into race-event construction.
- Airborne section with ocean/cliff/mist reveal.
- Landing catch zone wide enough for arcade recovery.
- Recovery straight after landing.
- Reset/fail-safe volume below or beyond landing area.

The first implementation should be stable and non-destructive.

Later expansion can add:

- Multiple cliffside jumps.
- Scripted collapse animations.
- Track crumbling behind or near the player.
- Timed acceleration requirement.
- Dynamic debris and audio cues.

Blunt rule: do not build the first version as real physics destruction. Use a scripted set-piece timeline, animated meshes, collision swaps, VFX, and audio. Real rigidbody collapse will be expensive, hard to tune, and likely unreliable for racing.

## 4. Camera Views

The default primary camera is chase view.

The player can toggle the primary camera between chase and cockpit. The player can also hold a look-back key to see behind the car only while the key is pressed.

Recommended PC defaults:

- `C`: toggle primary camera between chase and cockpit.
- `V`: hold look-back while driving.
- `Tab`: race menu/overlay.

Keybinding note:

`Tab` should stay in UI/race menu territory. The camera input map should not consume it. Controller support should be planned later with right-stick look-back or a hold button.

Architecture:

- Use a `CameraRig` that owns multiple `CameraViewProfile`s.
- Each primary view defines offset, FOV, damping, roll behavior, collision behavior, and road-preview bias.
- Look-back is a temporary override on top of the current primary camera.
- Camera state should persist across races through session/settings.
- The first implemented views are chase, cockpit placeholder, and hold look-back. Far chase and hood/bumper can be added later if needed.

Loop/jump warning:

For cliff jumps and future vertical set pieces, the camera must understand track-relative up/forward. A camera that only assumes world-up will become unstable on airborne, banked, or inverted sections.

## 5. Countdown And Input Gate

The race start should use a countdown from 3.

During countdown, player input should be filtered by action instead of fully disabled.

Recommended first gate:

| Input | Countdown |
|---|---|
| Accelerate | Blocked |
| Brake | Allowed |
| Steer | Blocked |
| Drift/handbrake | Blocked |
| Camera cycle | Allowed |
| Pause | Allowed |

Reason:

Allowing brake lets brake lights respond before the start, which supports realism and player feedback. Accelerate stays blocked until the race starts.

Architecture:

- `RaceInputGate` filters raw player commands into allowed `VehicleCommand` values.
- The car controller should not know about countdown rules.
- Race phase owns the input permission profile.
- Future rules can allow revving, clutch, steering wiggle, boost charging, or handbrake independently.

## 6. Start Grid

Cars should start from preset positions in the first section of the track.

Use a `StartGridProfile`:

- `grid_origin_distance_m`
- `slot_count`
- `rows`
- `columns`
- `lane_spacing_m`
- `row_spacing_m`
- `stagger_offset_m`
- `start_section_only`

The track should expose:

```gdscript
get_start_grid_transform(slot_index: int) -> Transform3D
```

Cars spawn from those transforms instead of arbitrary scene positions.

The start grid should support:

- Staggered racing placement.
- Road-relative alignment.
- Variable road width.
- Slight vertical offsets if road surface has slope or banking.
- Editor-visible start slot markers.

## 7. Editor Track Authoring

Storm Coast should be editable in the Godot/Summer editor without running the game.

Required authoring workflow:

1. Move road points, width markers, banking markers, elevation markers, start-grid marker, and set-piece markers in editor.
2. Press `Preview Regenerate`.
3. Generated road, collision, lane lines, curbs, guardrails, and dressing appear in editor.
4. Move generated props manually if needed.
5. Prop manual edits are stored as stable generated IDs plus anchor modes.
6. Press `Bake Track` to save generated content as reusable scene assets.

Road mesh itself should not be manually vertex-edited in Godot. The road should be edited through authoring points and markers, then regenerated.

Generated props should become editable scene nodes:

- Billboards.
- Streetlights.
- Signs.
- Crowd barriers.
- Cones.
- Small road furniture.

Generated road components should remain generator-owned:

- Road mesh.
- Lane lines.
- Curbs.
- Collision.
- Guardrails, unless explicitly overridden.

## 8. Stable Generated Props

Every generated prop needs stable identity and an anchor mode.

```text
GeneratedPropState
- stable_id
- generator_rule_id
- anchor_distance_m
- road_side
- lateral_offset_from_road_edge_m
- longitudinal_offset_m
- vertical_offset_m
- yaw_offset_degrees
- manual_override_mode
```

Manual override modes:

- `none`: generator fully controls the prop.
- `road_relative`: prop keeps its edited offset relative to road edge.
- `world_locked`: prop keeps exact world transform.
- `socket_locked`: prop follows a set-piece or module socket.

Bulk tools:

- Reset selected override.
- Reset all overrides.
- Reset all props from a rule.
- Convert selected to road-relative.
- Convert selected to world-locked.
- Validate generated props.
- Snap invalid props back outside road edge.

Validator rules:

- Flag props inside road bounds.
- Flag props intersecting barriers.
- Flag props floating too high/low.
- Flag props too close to start grid or landing zones.
- Offer bulk repair.

## 9. Track Width And Vertical Variation

Storm Coast requires vertical road variation and variable width.

Use marker/profile data:

- `WidthMarker`: changes road width over distance.
- `BankingMarker`: changes road roll/banking.
- `ElevationPoint`: defines vertical road shape.
- `SurfaceMarker`: marks asphalt, wet asphalt, bridge, tunnel, ramp, jump.
- `SafetyMarker`: defines reset/fail zones.

The road generator samples:

- position,
- tangent,
- normal/up,
- banking,
- width,
- surface type,
- zone id.

This is required for realistic coastal slopes, banked corners, jump approach, and future vertical set pieces.

## 10. First Implementation Slice

Do not build the entire premium track at once.

First slice should prove:

- Editor-visible authored road points.
- Variable width road section.
- Vertical elevation changes.
- Start grid markers.
- Countdown input gate.
- Camera cycling.
- One simple cliffside jump prototype.
- Generated billboards or signs with stable IDs and road-relative overrides.

Once those are stable, increase art fidelity and environment density.
