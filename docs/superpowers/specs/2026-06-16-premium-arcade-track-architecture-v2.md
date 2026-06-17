# Premium Arcade Track Architecture v2

Date: 2026-06-16
Project: Demo
Status: Planning direction

## 1. Purpose

This document updates the track plan after the art-style pivot from toy-low-poly to premium arcade realism.

The new target is realistic or slightly futuristic racing environments with high-end cars, detailed lighting, road materials, glares, sound, and arcade-impossible moments such as loops, wall rides, and dramatic ramps.

The project must also remain a template that future AI agents can edit safely from prompts. That means style, materials, environment kits, shaders, lighting, and track dressing must be profile-driven instead of hardcoded into single scripts or scenes.

## 2. Blunt Recommendation

Do not build premium realistic tracks as fully procedural worlds.

Fully procedural generation is good for rough terrain, endless roads, and toy-like filler. It is bad at premium race composition: readable turn setup, skyline framing, hero landmarks, loop placement, tunnel reveals, road surface quality, believable city dressing, and performance budgeting.

Use a hybrid system:

1. Authored spline layout.
2. Procedural road mesh and collision from the spline.
3. Premade modular environment kits.
4. Procedural dressing along authored zones.
5. Premade hero set pieces for loops, jumps, tunnels, bridges, landmarks, and garages.

This gives the project authored quality where it matters and AI-editability where it is useful.

## 3. Track Types

### Authored Circuit

Use for the first premium vertical slice.

- Designer/AI defines a spline path.
- Track has intentional pacing: start straight, braking zone, drift corner, fast section, hero set piece, recovery straight, final turn.
- Environment zones are marked along the spline.
- Best option for quality.

### Generated Variant Circuit

Use later, once the authored system works.

- AI can create a new spline from design constraints.
- System validates length, curvature, banking, loop count, road width, and spawn safety.
- Human or AI review still required.

### Open-World Route

Do not build yet.

- Requires streaming, traffic, navigation, minimap, broader environment logic, and route management.
- Too expensive for the first premium slice.

## 4. Core Architecture

### TrackScene

Root scene for a playable track.

Responsibilities:

- Owns the track spline.
- Owns the selected profiles.
- Spawns/generates road mesh.
- Places modular environment zones.
- Registers spawn grid.
- Exposes `TrackQuery` to cars, NPCs, camera, HUD, VFX, and race systems.

Suggested root:

```text
TrackScene
├── TrackAuthoring
│   ├── SplinePath
│   ├── ZoneMarkers
│   ├── SetPieceMarkers
│   └── SpawnMarkers
├── Generated
│   ├── RoadMesh
│   ├── RoadCollision
│   ├── LaneMarkings
│   ├── Guardrails
│   ├── Curbs
│   ├── SkidDecalReceivers
│   └── RacingLineHelpers
├── Environment
│   ├── Zone_00_City
│   ├── Zone_01_Tunnel
│   ├── Zone_02_Mountain
│   └── Zone_03_SetPiece
├── SetPieces
│   ├── Loop_01
│   └── Jump_01
├── Lighting
│   ├── WorldEnvironment
│   ├── DirectionalLight3D
│   └── ReflectionProbes
└── Runtime
    ├── TrackQuery
    ├── SurfaceState
    └── PerformanceVolumes
```

### TrackProfile

Designer/AI-facing resource.

Fields:

- `display_name`
- `track_scene_path`
- `target_length_m`
- `lap_count`
- `road_width_m`
- `lane_count`
- `default_environment_kit`
- `lighting_profile`
- `road_surface_profile`
- `set_piece_budget`
- `music_profile`
- `weather_profile`
- `time_of_day_profile`
- `difficulty_defaults`

### TrackSpline

The spline is the spine of the track.

It must provide:

- Position at distance.
- Tangent at distance.
- Normal/up vector at distance.
- Banking at distance.
- Width at distance.
- Curvature at distance.
- Zone id at distance.
- Surface type at distance.

For loops and wall rides, the normal/up vector becomes critical. The current flat-world assumption is not enough.

### TrackQuery

Public API used by all systems.

Required methods:

- `sample_at_distance(distance_m: float) -> Dictionary`
- `closest_distance_for_position(position: Vector3) -> float`
- `lane_transform(distance_m: float, lane_index: int) -> Transform3D`
- `surface_transform(distance_m: float, lateral_offset_m: float) -> Transform3D`
- `get_track_length_m() -> float`
- `get_road_width_m(distance_m: float = -1.0) -> float`
- `get_zone_at_distance(distance_m: float) -> StringName`
- `get_surface_type_at_distance(distance_m: float) -> StringName`
- `get_spawn_transform(grid_index: int) -> Transform3D`

No car, camera, NPC, VFX, or HUD system should read private spline arrays directly.

## 5. Vehicle Architecture Consequence

Vertical loops change the vehicle architecture.

The current car can be kept for flat-road mechanics testing, but the premium arcade controller should move toward track-relative driving:

- Surface normal defines local up.
- Track tangent defines ideal forward.
- Gravity can be blended between world gravity and track adhesion.
- Tires need a surface contact model.
- Camera must understand roll, pitch, and road preview through loops.
- NPCs need lookahead along spline, not flat X/Z steering only.
- Reset/recovery must place cars back onto the nearest valid surface transform.

Do not fake loops by only rotating visuals while the controller remains flat. It will break camera, collisions, NPCs, and player trust.

## 6. Road Generation

The road should be procedurally generated from the authored spline.

Generated pieces:

- Road mesh.
- Shoulder mesh.
- Curbs.
- Lane markings.
- Barriers/guardrails.
- Collision.
- Checkpoint volumes.
- Road-edge sockets for props.
- Decal receiver surfaces.

Road mesh requirements:

- Supports banking.
- Supports width changes.
- Supports vertical loops.
- Generates UVs based on distance for stable asphalt texture scale.
- Separates road, curbs, shoulder, barriers, and collision into distinct nodes.
- Can regenerate without deleting authored environment objects.

## 7. Road Surface State

Roads must visually react to driving.

Initial implementation:

- Tire skid decals or mesh strips spawned by drift state.
- Burnout marks from acceleration.
- Spark marks near barrier contact.
- Wet-road reflection variants through material profile.

Later implementation:

- Render-target road mask for accumulated rubber/dirt.
- Surface grip changes by rubber/wetness.
- Damage or debris on repeated impacts.

Keep this system separate from the car controller. The car emits contact/drift events; the surface system decides how to draw and persist marks.

## 8. Environment Strategy

Use modular environment kits, not one-off giant scenes.

EnvironmentKitProfile fields:

- `kit_id`
- `display_name`
- `style_tags`
- `module_scenes`
- `roadside_props`
- `background_props`
- `landmark_scenes`
- `lighting_overrides`
- `audio_ambience`
- `performance_budget`

Initial kits:

- `CityGoldenHourKit`
- `MountainCoastalWetKit`
- `GarageWarehouseMenuKit`
- `FuturisticTunnelKit`

Kit modules should be reusable:

- City block facade.
- Bridge side.
- Tunnel segment.
- Cliff wall.
- Guardrail cluster.
- Power-line run.
- Spectator barrier.
- Light pole.
- Billboard.
- Garage wall.
- Neon sign.

## 9. Set Pieces

Set pieces should be authored modules with standardized sockets.

SetPieceProfile fields:

- `set_piece_id`
- `scene_path`
- `entry_socket`
- `exit_socket`
- `min_speed_mps`
- `recommended_camera_mode`
- `surface_gravity_mode`
- `ai_strategy`
- `risk_rating`

Initial set pieces:

- Vertical loop.
- Banked wall ride.
- Tunnel boost corridor.
- Mountain jump.
- Spiral ramp.

Rules:

- One major set piece per short vertical-slice track is enough.
- Set pieces must include clear approach and recovery space.
- Set pieces must have visible structural support.
- Set pieces must be justified in-world.
- Set pieces should not use toy-orange plastic unless the mode intentionally references toy tracks.

## 10. Menu/Garage Architecture

The menu should become a real 3D scene, not only Control UI.

Main menu target:

```text
GarageMenuScene
├── HeroCarAnchor
├── GarageEnvironment
├── CameraRig
├── LightingRig
├── UI
│   ├── LeftNav
│   ├── NewRacePanel
│   ├── CarSelectPanel
│   ├── TrackSelectPanel
│   └── SettingsPanel
└── PreviewController
```

The UI remains simple on the left. The rest of the screen is the hero car in a premium warehouse/garage.

The preview car should eventually use the same `CarVisualProfile` as the race car so menu and race visuals stay consistent.

## 11. AI-Editable Profile System

Future AI agents should modify resources, not core gameplay scripts.

Create these resources:

- `ArtStyleProfile`
- `LightingProfile`
- `CarVisualProfile`
- `RoadSurfaceProfile`
- `EnvironmentKitProfile`
- `TrackProfile`
- `SetPieceProfile`
- `VFXStyleProfile`
- `AudioMixProfile`

Prompt examples this architecture should support:

- "Make this track a rainy mountain pass at dusk."
- "Change the race to a futuristic neon city style."
- "Use warmer golden-hour lighting."
- "Make the road wider and add a loop after the first straight."
- "Swap to a black hypercar with blue emissive accents."
- "Make UI more premium and minimal."

The AI should translate prompts into profile edits and modular scene selections.

## 12. Premade vs Procedural Decision Table

| Element | Recommendation | Reason |
|---|---|---|
| Track route | Authored spline | Racing feel requires intention. |
| Road mesh | Procedural from spline | Needs regeneration and width/banking changes. |
| Lane markings | Procedural | Must follow route exactly. |
| Guardrails/barriers | Procedural with authored overrides | Must follow road edge but allow special cases. |
| Loops/jumps | Premade set pieces | Quality and physics require strict control. |
| City blocks | Premade modular kits | Full procedural cities look generic. |
| Mountain/cliff terrain | Hybrid | Base authored chunks plus procedural dressing. |
| Billboards/streetlights | Procedural dressing | Good fit for placement rules. |
| Hero landmarks | Premade | Composition matters. |
| Skid marks | Runtime procedural decals | Driven by gameplay events. |
| Menu garage | Premade scene | It is a first impression and must look premium. |

## 13. Performance Plan

Premium realism requires hard budgets.

Budgets for first premium slice:

- 4 race cars on track.
- 1 hero car model class with color/material variants.
- 1 detailed track environment kit.
- 1 major set piece.
- 1 time-of-day lighting profile.
- 1 road material family with dry/wet/rubber variants.

Optimization requirements:

- LODs on cars and large props.
- Occlusion or visibility volumes in city/tunnel zones.
- Reflection probes only where they matter.
- Limited real-time lights.
- Baked or static lighting for garage/background elements.
- Instanced props for repeated objects.
- Decal pooling for skid marks.
- Performance testing before adding more scenery density.

## 14. Migration From Current Prototype

Keep:

- Race manager.
- Menu flow concept.
- Difficulty selection concept.
- NPC personality idea.
- Track query API idea.
- Drift/event signal idea.
- Camera-road-preview goal.

Replace or rewrite:

- Low-poly visual style.
- Current procedural scenery.
- Flat-only road assumptions.
- Placeholder car mesh.
- Toy VFX and playful audio direction.
- Current simple menu background.

Add:

- Track-relative vehicle controller.
- Spline normal/up support.
- Premium road material system.
- 3D garage menu scene.
- Car visual profile.
- Environment kit profiles.
- Set piece profiles.

## 15. First Premium Prototype Recommendation

Build one premium test track before rebuilding everything:

Name: `Storm Coast Circuit`

Scope:

- 900-1200 m closed circuit.
- Rainy mountain/coastal road.
- Wet asphalt, cliffs, guardrails, power lines, mist, and distant ocean/mountain views.
- Believable road layout with one engineered arcade event structure.
- One signature cliffside jump.
- A safe approach, airborne section, landing section, and recovery straight.
- One premium hero car.
- Minimal but premium menu garage.
- Multiple camera views selectable by the player with a key.

Goal:

Prove that premium visuals, arcade physics, track-relative driving, camera switching, cliffside jump handling, and AI-editable profiles can work together before expanding content.

## 16. Open Design Questions

Resolved decisions:

- First premium environment: rainy mountain/coastal.
- First premium set piece: cliffside jump.
- Road realism level: believable road with one impossible/event structure.
- Car class: fictional hypercar/prototype hybrid.
- Damage scope: scrape decals only for now, with a clean path to expand later.
- Camera requirement: chase is the default primary view. Player can toggle primary view between chase and cockpit, and can hold a look-back key for rear view while pressed.

Remaining decisions before implementation:

1. Exact camera keybinds.
   Recommended PC defaults:
   - `C`: toggle primary camera between chase and cockpit.
   - `V`: hold look-back while driving.
   - `Tab`: race menu/overlay.
   - Controller later: right stick or face-button hold for look-back, D-pad or shoulder chord for camera toggle.

2. First car visual package.
   The class is locked as fictional hypercar/prototype hybrid, but the exact silhouette, drivetrain fantasy, cockpit detail level, and paint/material variants still need art selection.

## 17. Non-Negotiables

- Premium style cannot coexist with low-poly placeholder assets in final scenes.
- Set pieces must be rare and cinematic.
- The road must remain readable.
- Track generation must preserve authored composition.
- Future AI editability must happen through profiles and modular kits, not random script rewrites.
- Track-relative driving is required for loops and vertical segments.
