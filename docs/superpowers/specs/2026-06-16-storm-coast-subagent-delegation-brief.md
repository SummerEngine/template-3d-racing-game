# Storm Coast Subagent Delegation Brief

Date: 2026-06-16
Project: Demo
Status: Ready for delegation planning

## 1. Objective

Build the first premium-realism foundation for `Storm Coast Circuit`.

The goal is not to finish a full premium track in one pass. The goal is to create the editor-authorable, AI-editable foundation that can support:

- rainy mountain/coastal track,
- fictional hypercar/prototype hybrid,
- believable road with vertical variation and variable width,
- one cliffside jump set piece,
- preset start grid,
- countdown with per-action input gating,
- chase/cockpit camera toggle,
- hold-to-look-back,
- scrape decals as the first damage/feedback layer,
- editor-visible generated content with stable IDs and reset/validation tools.

## 2. Locked Design Choices

- Track: `Storm Coast Circuit`.
- Environment: rainy mountain/coastal.
- Road realism: believable road with one engineered arcade event structure.
- Signature set piece: cliffside jump.
- Car class: fictional hypercar/prototype hybrid.
- Damage scope: scrape decals only for now, expandable later.
- Camera:
  - default primary view: chase,
  - `C`: toggle chase/cockpit primary view,
  - `V`: hold look-back while driving only,
  - `Tab`: race menu/overlay, not camera control,
  - far chase and hood/bumper are later additions.
- Countdown:
  - starts from 3,
  - acceleration blocked until race start,
  - brake allowed during countdown,
  - camera toggle/look-back allowed during countdown,
  - race menu/overlay allowed during countdown,
  - pause allowed during countdown.
- Track generation:
  - editor-time / bake-time by default,
  - not hidden runtime generation,
  - runtime only handles dynamic effects such as skid marks, decals, race state, VFX, audio, and weather animation.
- Generated props:
  - stable IDs,
  - road-relative override mode by default for roadside props,
  - bulk reset, validate, and snap-back tools.

## 3. Shared Architecture Rules

1. Do not rewrite the whole current prototype.
   The current project is a mechanics prototype. Agents should build new premium foundations alongside existing systems where possible.

2. Do not make fully procedural premium tracks.
   The track is authored through editor-visible points, markers, profiles, and set-piece sockets, then generated/baked into reusable scene assets.

3. Do not hardcode style into gameplay scripts.
   Use resources/profiles for style, lighting, road surface, set pieces, environment kits, and camera views.

4. Do not let cars/camera/NPCs read private road arrays.
   They must use `TrackQuery` APIs.

5. Do not make real physics destruction for the cliffside jump in the first pass.
   Future crumbling should be scripted animation, collision swaps, VFX, and audio.

6. Do not place generated props only in world space.
   Store stable ID plus anchor mode and road-relative data.

## 4. Agent Ownership

### Agent A: Track Authoring Tool

Primary ownership:

- `scripts/track_authoring/*`
- `addons/storm_coast_track_authoring/*` if an editor plugin is needed
- authoring scene/resource definitions

Responsibilities:

- Editor-visible `RoadPoint`, `WidthMarker`, `BankingMarker`, `ElevationMarker`, `ZoneMarker`, `StartGridMarker`, and `SetPieceMarker` nodes/resources.
- `Preview Regenerate` workflow.
- `Bake Editable` workflow.
- `Freeze Final` placeholder workflow, if time permits.
- Inspector-friendly properties that both human users and AI agents can edit.
- Clear separation between `Authoring`, `Generated`, `ManualOverrides`, and `SetPieces` scene branches.

Do not touch:

- Vehicle controller.
- Camera controller.
- Race manager logic.
- Visual art assets except simple placeholders needed for editor testing.

Dependencies:

- Depends on Agent B for the road generator/query contract.
- Must coordinate with Agent F on generated prop IDs and override metadata.

Acceptance checks:

- A designer can move at least 5 road/marker nodes in editor and regenerate visible output.
- Generated output appears in editor without pressing Play.
- Regeneration does not delete `ManualOverrides`.
- Authoring data is saved in scene/resources, not only in runtime memory.

### Agent B: Track Query And Road Mesh Generator

Primary ownership:

- `scripts/track/*`
- `resources/tracks/*`
- generated road mesh/collision code

Responsibilities:

- Spline sampling with position, tangent, up/normal, banking, width, surface type, and zone id.
- `TrackQuery` v2 API:
  - `sample_at_distance`
  - `closest_distance_for_position`
  - `lane_transform`
  - `surface_transform`
  - `get_track_length_m`
  - `get_road_width_m`
  - `get_zone_at_distance`
  - `get_surface_type_at_distance`
  - `get_spawn_transform`
  - `get_start_grid_transform`
- Road mesh generation from authoring data.
- Collision generation.
- Lane markings.
- Curbs/shoulders.
- Guardrail placeholder generation.
- UVs that maintain stable asphalt texture scale.

Do not touch:

- Generated roadside props ownership.
- Race input gating.
- Camera switching.

Dependencies:

- Receives authoring data from Agent A.
- Provides transforms to Agent C, D, and E.

Acceptance checks:

- Road supports visible elevation change.
- Road supports at least one width change.
- Road supports at least one banked section.
- `get_start_grid_transform(0..3)` returns sensible transforms on first section.
- Collision exists and roughly matches generated road.

### Agent C: Start Grid And Race Input Gate

Primary ownership:

- `scripts/race/*`
- `scripts/vehicles/player_driver.gd`
- input map additions in `project.godot`
- small changes to car command filtering only

Responsibilities:

- `StartGridProfile`.
- Preset car start positions in first track section.
- Race countdown starts from 3.
- `RaceInputGate` filters player commands by race phase and permission profile.
- Countdown permissions:
  - accelerate blocked,
  - brake allowed,
  - steer blocked,
  - drift/handbrake blocked,
  - camera controls allowed,
  - pause allowed.
- Brake input during countdown should affect command state enough for brake lights later.

Do not touch:

- Road mesh generation.
- Camera view implementation, except consuming camera input action names if needed.
- Vehicle physics rewrite beyond command filtering.

Dependencies:

- Depends on Agent B for `get_start_grid_transform`.
- Coordinates with Agent D for camera inputs during countdown.

Acceptance checks:

- Cars spawn in staggered preset grid positions.
- Player cannot accelerate before countdown ends.
- Player can brake during countdown.
- Race starts after countdown.
- Filtering is action-specific, not a hard global input lock.

### Agent D: Multi-View Camera System

Primary ownership:

- `scripts/camera/*`
- existing `scripts/elastic_chase_camera.gd` only if refactoring is unavoidable
- camera profile resources
- camera input bindings

Responsibilities:

- `CameraRig` with `CameraViewProfile`s.
- Default chase camera.
- Cockpit camera placeholder.
- `C` toggles primary camera between chase and cockpit.
- `V` holds look-back while pressed in race gameplay.
- `Tab` is reserved for race menu/overlay behavior, not camera control.
- Look-back is a temporary override and returns to prior primary camera when released.
- Camera handles road preview and jump stability.
- Camera state can be stored in session/settings later.

Do not touch:

- Vehicle controller.
- Track mesh generator.
- Race manager except reading race phase if needed.

Dependencies:

- Needs track-relative orientation from Agent B eventually.
- Needs input action names coordinated with Agent C.

Acceptance checks:

- Pressing `C` toggles chase/cockpit.
- Holding `V` shows rear/look-back view.
- Releasing `V` restores the prior primary camera.
- Camera does not break during the cliffside jump prototype.

### Agent E: Storm Coast Cliffside Jump Set Piece

Primary ownership:

- `scenes/setpieces/storm_coast/*`
- `scripts/setpieces/*`
- set-piece marker/profile resources

Responsibilities:

- Cliffside jump module with entry and exit sockets.
- Approach, ramp, airborne section, landing catch zone, recovery straight.
- Reset/fail-safe zone below or beyond landing.
- Basic visual placeholders for cliff, ocean/mist, ramp supports, and warning signage.
- Future-proof hooks for scripted crumbling/collapse, but no real destruction in first pass.

Do not touch:

- Core road generator internals except through sockets/markers.
- Vehicle physics except reporting needs.
- Camera code except providing set-piece metadata.

Dependencies:

- Depends on Agent A/B socket and spline contracts.
- Coordinates with Agent D for camera behavior through jump.

Acceptance checks:

- Jump can be placed as a module in editor.
- Entry/exit sockets align with road surfaces.
- Landing has a recovery zone.
- Fail/reset volume exists.
- Set piece is not random toy-track geometry; it reads as engineered into Storm Coast.

### Agent F: Generated Prop Stable IDs And Overrides

Primary ownership:

- `scripts/track_authoring/generated_props/*`
- generated prop state resources
- validation/reset tooling

Responsibilities:

- `GeneratedPropState`.
- Stable IDs such as `Billboard_014`.
- Anchor modes:
  - `none`,
  - `road_relative`,
  - `world_locked`,
  - `socket_locked`.
- Road-relative offsets from road edge.
- Manual override detection/recording.
- Bulk tools:
  - reset selected,
  - reset all overrides,
  - reset all props from rule,
  - convert selected to road-relative,
  - convert selected to world-locked,
  - validate generated props,
  - snap invalid props back outside road edge.

Do not touch:

- Road mesh generation except consuming road-edge transforms.
- Race systems.
- Camera systems.

Dependencies:

- Depends on Agent B for road-edge transforms.
- Depends on Agent A for editor UI/tool entry points.

Acceptance checks:

- Moving a generated billboard manually stores a road-relative override.
- Changing road width keeps the billboard outside the road.
- Reset all overrides works.
- Validator flags props inside road bounds.
- Snap-back repairs invalid roadside props.

### Agent G: Premium Profiles And Materials Foundation

Primary ownership:

- `scripts/profiles/*`
- `resources/profiles/*`
- placeholder materials under `resources/materials/*`
- profile documentation

Responsibilities:

- Define resources:
  - `ArtStyleProfile`
  - `LightingProfile`
  - `RoadSurfaceProfile`
  - `CarVisualProfile`
  - `EnvironmentKitProfile`
  - `SetPieceProfile`
  - `VFXStyleProfile`
  - `AudioMixProfile`
- Storm Coast profile placeholders.
- Wet asphalt material placeholder.
- Scrape decal material placeholder.
- Light-rain/wet-road weather profile.
- Fictional hypercar/prototype `CarVisualProfile`.

Do not touch:

- Gameplay controller.
- Road mesh generation logic.
- Race manager.

Dependencies:

- Agent B consumes `RoadSurfaceProfile`.
- Agent E consumes `SetPieceProfile`.
- Agent D may consume camera profile style hints later.

Acceptance checks:

- Profiles are loadable resources.
- Storm Coast has assigned profile resources.
- Road generator can reference road material profile.
- Decal material exists and is clearly expandable.

## 5. Integration Order

Recommended order:

1. Agent G defines profile resource classes and placeholder resources.
2. Agent A defines authoring node/resource structure.
3. Agent B implements v2 road query and generated road from authoring data.
4. Agent F plugs stable generated prop state into the authoring/regeneration workflow.
5. Agent C adds start grid and input gate using `TrackQuery`.
6. Agent D adds camera views and input.
7. Agent E adds cliffside jump set piece once sockets/query are stable.

Parallelization:

- Agent G can start immediately.
- Agent D can start with existing camera, but must avoid deep refactor until B exposes track-relative data.
- Agent C can design `RaceInputGate` immediately, but start grid transform integration waits for B.
- Agent E can block out a standalone jump module immediately, but final placement waits for A/B.

## 6. Shared Input Actions

Add or reserve:

- `camera_toggle_primary`: recommended key `C`.
- `camera_look_back`: recommended key `V`.
- `race_menu_overlay`: recommended key `Tab`.

Input note:

`Tab` is reserved for UI/race menu behavior. Camera systems should not consume it.

## 7. Shared Acceptance Gate

The combined foundation is accepted when:

1. Storm Coast authoring scene can be opened in editor.
2. Road authoring markers are visible and editable.
3. Preview regeneration creates visible road output in editor.
4. Road has width variation and vertical variation.
5. Four cars can spawn from the start grid.
6. Countdown blocks acceleration but allows brake.
7. `C` toggles chase/cockpit.
8. Holding `V` look-backs and releasing returns to prior view.
9. Cliffside jump placeholder exists with entry/exit/landing/reset.
10. At least one generated roadside prop has stable ID and road-relative override.
11. Reset/validate tool can repair invalid generated props.
12. Scrape decal placeholder exists and is expandable.
13. No script parser errors.
14. Live play launch has no debugger errors.

## 8. Agent Conflict Rules

- One agent owns a file at a time. If another agent needs the file, they propose an interface change instead of editing directly.
- Agents should add new scripts/resources rather than expanding large scripts where possible.
- Shared scene mutation should happen through a single integration pass after individual branches land.
- Race scene integration should be minimal until the authoring and query contracts are stable.
- Any destructive cleanup waits until the integration agent confirms replacements are working.

## 9. Files Likely To Be Shared

High-conflict files:

- `project.godot`
- `scenes/race/showcase_circuit_race.tscn`
- `scripts/car_controller.gd`
- `scripts/race/showcase_race_scene.gd`
- `scripts/elastic_chase_camera.gd`
- `scripts/track/track_generator.gd`

Avoid direct edits unless the agent owns the integration task for that file.

Preferred new-file areas:

- `scripts/track_authoring/`
- `scripts/camera/`
- `scripts/profiles/`
- `scripts/setpieces/`
- `scripts/race/input_gate/`
- `resources/profiles/`
- `resources/tracks/storm_coast/`
- `scenes/tracks/storm_coast/`
- `scenes/setpieces/storm_coast/`

## 10. What Not To Build Yet

- Full premium car art integration.
- Real rigidbody crumbling/destruction.
- Dense city environment.
- Weather transitions during race.
- Full cockpit interior beyond placeholder.
- Online multiplayer.
- Full damage deformation.
- Traffic/open-world routing.
- Fully procedural city generation.

These are future waves after the editor-authoring foundation works.
