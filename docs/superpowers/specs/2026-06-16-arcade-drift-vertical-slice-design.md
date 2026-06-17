# Arcade Drift Racer Vertical Slice Design

Date: 2026-06-16
Project: Demo
Engine: Summer Engine / Godot
Status: Mechanics prototype record. Superseded for art direction and future track architecture by `.summer/art-bible.md` and `docs/superpowers/specs/2026-06-16-premium-arcade-track-architecture-v2.md`.

## 1. Product Target

Build a polished vertical slice of a toy-like arcade drift racing game.

The first polished milestone is a complete 3-lap race, not a loose tech demo. It should launch from a demo menu, let the player choose a cosmetic car color, select the curated Showcase Circuit preset, choose difficulty, race against three personality-driven NPC cars, finish the race, and see results.

Core target:

- Genre: toy-like arcade drift racer.
- Race format: 3-lap race.
- Cars: 4 cars total, player plus 3 NPCs.
- Track: one short closed-loop track, target length around 1.8 km.
- Road width: 14 m.
- Environment flow: Highway/Crops to Industrial to Highway.
- UI scope: full demo UI.
- Audio: playful kart-like.
- VFX: clean and readable.
- Customization: cosmetic-only car color select.
- Asset strategy: hybrid, with generated hero assets and procedural/simple filler props.
- Implementation strategy: parallel waves with integration gates.

## 2. Design Pillars

1. Race flow over realism.
   The car should recover from wall scrapes, bumps, and drift mistakes quickly enough that the race keeps moving.

2. Road readability first.
   Camera, VFX, props, and UI must preserve the player's ability to read the road ahead.

3. Toy-like polish.
   Assets can be low-poly and stylized, but should feel intentional, colorful, chunky, and coherent.

4. Data-driven generation.
   Tracks, environments, transitions, music choices, and prop rules must be configurable through profiles rather than hardcoded into one large script.

5. Parallel-safe architecture.
   Systems must have clear file ownership so multiple agents can work without overwriting each other.

## 3. First Slice Scope

### Included

- Main menu.
- New race flow.
- Cosmetic car color select.
- Curated track preset select.
- Difficulty select.
- Settings menu with volume and brightness.
- Race countdown.
- Race HUD with speed, lap, position, race timer, and countdown.
- Pause menu.
- Results screen.
- 3-lap Showcase Circuit race.
- Player car with tuned arcade drift controller.
- 3 NPC racers with personality profiles.
- Soft car-to-car collision and bump assist.
- Soft guardrail scrape response.
- Professional chase camera tuned for road preview.
- Tire smoke, drift sparks, bump sparks, wall scrape sparks, subtle speed streaks, countdown pop, finish FX.
- Playful engine loop, drift SFX, bump SFX, scrape SFX, UI sounds, countdown/start stingers, race music.
- One polished toy-like race car model with 4 color variants.
- 5 billboard ad sprites generated through Summer Studio.
- Highway/Crops and Industrial environment generation.
- Environment transitions on a closed loop.

### Not Included In This Slice

- Stat upgrades.
- Multiple car handling models.
- Multiple generated car models.
- Full social deduction systems.
- Online multiplayer.
- Full combat mechanics.
- Full track customization exposed to players.
- Realistic vehicle physics.
- Full spinout system.

## 4. Track Generation System

The current monolithic `test_track_5km.gd` should be replaced over time by a modular track generation system.

### Core Resources

#### TrackProfile

Designer-facing data for a playable track preset.

Fields:

- `display_name`
- `target_length_m`
- `road_width_m`
- `road_material`
- `road_color`
- `guardrail_settings`
- `music_profile`
- `environment_sequence`
- `lap_count`
- `spawn_grid_settings`
- `difficulty_defaults`

Vertical slice preset:

- Name: Showcase Circuit.
- Length: about 1800 m.
- Road width: 14 m.
- Lap count: 3.
- Environment sequence:
  - 0-45 percent: Highway/Crops.
  - 45-57 percent: Highway to Industrial transition.
  - 57-88 percent: Industrial.
  - 88-100 percent: Industrial to Highway transition.

#### EnvironmentProfile

Reusable biome/environment rule set.

Fields:

- `display_name`
- `environment_id`
- `terrain_palette`
- `prop_rules`
- `ambient_audio`
- `coverage_targets`
- `roadside_offset_rules`
- `transition_prop_rules`

Initial environments:

- `HighwayCropsEnvironment`
- `IndustrialEnvironment`

#### TransitionProfile

Defines how two environments blend over a distance band.

Fields:

- `from_environment`
- `to_environment`
- `start_distance_ratio`
- `end_distance_ratio`
- `blend_curve`
- `prop_crossfade_rules`
- `audio_crossfade_rules`
- `terrain_crossfade_rules`

### Track Query API

The generator must expose a public API used by AI, lap counting, spawn logic, HUD, VFX, and camera systems.

Required API:

- `sample_at_distance(distance: float) -> Dictionary`
- `lane_transform(distance: float, lane_index: int) -> Transform3D`
- `closest_distance_for_position(position: Vector3) -> float`
- `environment_weights_at_distance(distance: float) -> Dictionary`
- `get_track_length_m() -> float`
- `get_road_width_m() -> float`
- `get_spawn_transform(grid_index: int) -> Transform3D`

No system should read private centerline arrays directly.

## 5. Environment Rules

### Highway/Crops Environment

Purpose:

Open, readable, playful countryside racing zone with crops, farmhouses, fenced areas, animals, and billboards.

Rules:

- Billboards appear on both sides of the road.
- Billboards are randomly distributed through Highway/Crops segments.
- Billboards must be placed relative to the road edge, not fixed world coordinates.
- Billboard placement formula:

```text
road_center + road_normal * (road_width / 2 + billboard_offset)
```

- Billboard sprites: generate 5 different ad-like sprites through Summer Studio.
- Crop clusters cover 30-50 percent of the Highway/Crops section length, not the whole track.
- Farmhouse/fenced animal areas cover 5-15 percent of the Highway/Crops section length, not the whole track.
- Farmhouses should be 2-3 times larger than cars.
- Farmhouses use playful toy-like colors.
- Farm animals are simple, readable, toy-like low-poly or sprite/mesh stand-ins.
- Fences must not intersect guardrails or road collision.
- Crop clusters should appear in groups, not evenly sprinkled.

### Industrial Environment

Purpose:

Chunky toy-like industrial zone that contrasts with the open countryside while staying readable.

Rules:

- Factories are 2-3 times larger than farmhouses.
- Factories use sadder gray tones.
- Props include factories, containers, utility poles, small warehouses, service-road hints, concrete/gravel patches, and industrial signage.
- Props must use road-edge-relative placement where they appear roadside.
- Industrial density should rise after the Highway to Industrial transition and taper before returning to Highway.

### Transition Rules

The road should remain mechanically stable through transitions unless a TrackProfile explicitly changes it. The environment changes around the road.

Highway to Industrial transition:

- Crops become less frequent.
- Farmhouses and fenced animal areas taper out.
- Billboards shift toward industrial signage.
- Utility props appear.
- Terrain shifts from green/crop colors toward gravel, asphalt, concrete, and muted industrial tones.
- Small industrial buildings appear far from the road first, then larger buildings appear closer.
- Ambience crossfades from countryside/open-road tone into industrial hum.

Industrial to Highway transition:

- Industrial buildings and containers taper out.
- Gravel/concrete patches soften into grass/crop terrain.
- Highway-style billboards return.
- Open sightlines increase before the lap boundary.

## 6. Vehicle And Driver Architecture

Vehicle input and vehicle physics must be split.

### VehicleCommand

Shared command data produced by either the player or an NPC.

Fields:

- `throttle: float` from 0 to 1.
- `brake: float` from 0 to 1.
- `steer: float` from -1 to 1.
- `drift: bool`.

### VehicleController

Owns arcade movement and feel.

Responsibilities:

- Reads `VehicleCommand`.
- Applies acceleration, braking, reverse, steering, drift, lateral grip, and drag.
- Applies visual wheel spin and front-wheel steering.
- Applies body roll and pitch.
- Applies soft guardrail scrape recovery.
- Applies soft car-to-car contact response.
- Does not read keyboard input directly.
- Does not know whether command came from player or AI.

### PlayerDriver

Responsibilities:

- Reads keyboard/controller input.
- Outputs `VehicleCommand`.
- Supports current controls:
  - `W` / Up: accelerate.
  - `S` / Down: brake/reverse.
  - `A` / `D`: steer.
  - Shift: drift.

### NpcDriver

Responsibilities:

- Reads TrackQuery.
- Reads NpcPersonalityProfile.
- Chooses target lane and target distance.
- Outputs `VehicleCommand`.
- Handles overtakes, braking, drift choice, avoidance, and recovery.

## 7. NPC Personality AI

NPCs should not be experimental freeform agents in the first slice. They should be reliable racing-line AI with personality modifiers.

Initial NPCs:

### The Technician

- Smooth line.
- Brakes early.
- Low contact aggression.
- Consistent lap times.
- Weak in chaotic traffic.

### The Bully

- Prefers inside lanes.
- Blocks and overtakes aggressively.
- Higher bump tolerance.
- More contact risk.
- Can overcommit in corners.

### The Showoff

- Drifts more often.
- More expressive.
- Slightly less optimal racing line.
- Strong on wide turns.
- Useful for drift VFX readability.

## 8. Collision And Assist Design

### Soft Car-To-Car Collision

Goal:

Cars should physically acknowledge each other without destroying race flow.

Rules:

- Light side bumps nudge.
- Rear hits push slightly.
- Hard impacts reduce speed and trigger sparks/SFX.
- NPCs receive temporary avoidance steering after contact.
- Anti-pileup assist activates if cars are blocked at low speed.
- No full spinouts in v1.

### Soft Guardrail Response

Goal:

Guardrails remain hard boundaries, but hitting them should scrape and recover rather than dead-stop.

Rules:

- Guardrail collision is tagged for detection.
- VehicleController inspects slide contacts after movement.
- Contact with guardrail reduces speed based on impact angle.
- Car gets scrape friction and a small recovery push along the rail.
- VFX/SFX trigger for wall scrape.

## 9. Camera Design

The camera should prioritize seeing more road ahead.

Rules:

- Professional third-person chase camera.
- Reads `CameraTarget` marker but never writes to it.
- Car mass sits around the lower third of the screen.
- High speed increases look-ahead and FOV, not distance.
- Camera should not get too far from the car.
- Drift camera blends slightly toward velocity direction.
- Camera roll is modest.
- Camera settings should be exportable and eventually profile-driven.

## 10. VFX Direction

VFX style: clean and readable.

Required effects:

- Tire smoke during drift.
- Drift sparks at stronger speed/angle.
- Wall scrape sparks.
- Car-to-car bump sparks.
- Subtle high-speed streaks.
- Countdown/start pop.
- Finish celebration burst.

Rules:

- Effects clarify state.
- Effects should not obscure road readability.
- VFX should match toy-like arcade style.
- VFX intensity can scale with speed, drift angle, or impact strength.

## 11. Audio Direction

Audio style: playful kart-like.

Required audio:

- Bright engine loop.
- Tire squeal.
- Drift sparkle/whoosh.
- Toy-like bump impact.
- Wall scrape sound.
- Countdown/start stinger.
- UI clicks/selects.
- Upbeat loopable race music.
- Light environment ambience.

Rules:

- Audio should feel responsive and charming.
- Avoid harsh realism.
- Environment ambience and music layers can crossfade using environment weights.
- Music choice is part of TrackProfile, but player-facing track menu only exposes curated presets in v1.

## 12. UI And Game Flow

Player-facing flow:

```text
Boot
-> Main Menu
-> New Race
-> Car Color Select
-> Track Preset Select
-> Difficulty Select
-> Race Loading/Countdown
-> 3-Lap Race
-> Results
-> Restart / Main Menu
```

### Main Menu

- New Race.
- Settings.
- Quit.

### Car Select

- One car model.
- 4 cosmetic color variants.
- No stat differences.

### Track Select

- Curated presets only.
- v1 preset: Showcase Circuit.
- The designer-facing generation system remains flexible internally.

### Difficulty Select

- Easy.
- Medium.
- Hard.

Difficulty affects NPC skill and player assists, not track generation.

Easy:

- Slower NPCs.
- Wider NPC turns.
- More player wall-scrape recovery.
- Stronger anti-pileup assist.
- Softer car-to-car bumps.

Medium:

- Baseline intended experience.
- Balanced NPC speed and mistakes.
- Normal recovery assists.

Hard:

- Better NPC racing lines.
- Less player recovery assist.
- More assertive overtakes.
- Smaller NPC mistakes.
- No unfair full cheating unless a tuned rubberbanding profile explicitly allows it.

### Settings

- Master volume.
- Music volume.
- SFX volume.
- Brightness.

### Race HUD

- Speed.
- Lap.
- Position.
- Race timer.
- Countdown.
- Optional mini placement list.

### Pause Menu

- Resume.
- Restart.
- Settings.
- Main Menu.

### Results Screen

- Final placement.
- Total time.
- NPC rankings.
- Restart.
- Main Menu.

## 13. Asset Strategy

Strategy: hybrid.

### Generate Or Source High-Impact Assets

- One polished toy-like race car model.
- 4 car color/material variants.
- 5 billboard ad sprites.
- Main race music loop.
- Key SFX:
  - engine loop
  - drift
  - bump
  - wall scrape
  - countdown/start
  - UI sounds

### Procedural Or Simple Assets

- Crop clusters.
- Fences.
- Farmhouses.
- Simple farm animals.
- Industrial factories.
- Containers.
- Guardrails.
- Road mesh.
- Road markings.
- Terrain patches.
- Trackside filler props.

## 14. Parallel Agent Work Plan

Implementation should use parallel waves with integration gates. Do not run every agent at once.

### Wave 1: Foundation

#### Agent A: Track Architecture

Ownership:

- `scripts/track/*`
- `resources/tracks/*`

Responsibilities:

- Create TrackProfile.
- Create EnvironmentProfile.
- Create TransitionProfile.
- Create TrackQuery API.
- Migrate path/distance logic out of `test_track_5km.gd`.
- Implement Showcase Circuit profile.

Do not touch:

- Vehicle controller.
- UI.
- VFX/SFX.
- NPC driver logic.

#### Agent B: Vehicle Architecture

Ownership:

- `scripts/vehicles/*`
- `scenes/player_car.tscn` only if needed for vehicle nodes/anchors.

Responsibilities:

- Create VehicleCommand.
- Refactor controller to read VehicleCommand.
- Create PlayerDriver.
- Preserve current controls.
- Preserve wheel steering and visual rotation.

Do not touch:

- Track generator.
- UI menus.
- NPC behavior.

#### Agent C: Race State

Ownership:

- `scripts/race/*`

Responsibilities:

- RaceManager.
- Countdown.
- Lap tracking.
- Position tracking.
- Finish detection.
- Results data model.

Dependencies:

- TrackQuery interface from Agent A.

Do not touch:

- Vehicle physics.
- Track generation internals.
- UI visuals beyond test hooks.

#### Agent D: Scene Composition

Ownership:

- Race scene setup.
- Scene folder conventions.
- Node hierarchy integration.

Responsibilities:

- Create or organize main race scene.
- Wire generated track, cars, camera, race manager, and HUD anchors.
- Keep reusable scenes clean.

Do not touch:

- Gameplay algorithm internals.

Wave 1 gate:

- Showcase Circuit generates.
- One player car spawns from track spawn grid.
- Player can drive.
- RaceManager can detect lap progress.
- No script errors.

### Wave 2: Playable Race

#### Agent E: NPC Drivers

Ownership:

- `scripts/ai/*`
- `resources/ai/*`

Responsibilities:

- NpcDriver.
- NpcPersonalityProfile.
- Technician, Bully, Showoff profiles.
- Lane following.
- Overtake logic.
- Drift choice.
- Recovery logic.

Do not touch:

- Track mesh generation.
- UI menu flow.

#### Agent F: Soft Collision And Assists

Ownership:

- `scripts/vehicles/*` collision/assist modules.

Responsibilities:

- Soft car-to-car contact.
- Guardrail scrape recovery.
- Anti-pileup assist.
- Impact strength data for VFX/SFX.

Do not touch:

- Track environment placement.
- UI menus.

#### Agent G: Camera Feel

Ownership:

- `scripts/camera/*` or existing chase camera script.

Responsibilities:

- Road-preview chase camera.
- CameraTarget read-only behavior.
- Drift camera response.
- Tunable camera profile.

Do not touch:

- Vehicle physics except through public getters.

#### Agent H: Race HUD

Ownership:

- `scripts/ui/race_hud/*`
- HUD scene.

Responsibilities:

- Speed.
- Lap.
- Position.
- Countdown.
- Race timer.
- Optional placement list.

Dependencies:

- RaceManager state.
- Vehicle speed API.

Wave 2 gate:

- 3-lap race against 3 NPCs is playable from start to finish.
- Player and NPCs use the same vehicle command path.
- No script errors.

### Wave 3: Assets And Polish

#### Agent I: Track Environment Assets

Ownership:

- `scripts/track/environment/*`
- procedural prop rules.
- simple generated/procedural environment scenes.

Responsibilities:

- Highway/Crops props.
- Industrial props.
- Farmhouse/fenced animal areas.
- Crop clusters.
- Roadside placement rules.

Do not touch:

- Race state.
- Vehicle controller.

#### Agent J: Generated Assets

Ownership:

- `assets/generated/*`
- imported generated assets.

Responsibilities:

- Generate/import polished race car.
- Create 4 car color variants.
- Generate/import 5 billboard ad sprites.
- Document asset IDs and source metadata.

Do not touch:

- Gameplay code.

#### Agent K: VFX

Ownership:

- `scripts/vfx/*`
- VFX scenes/resources.

Responsibilities:

- Tire smoke.
- Drift sparks.
- Wall scrape sparks.
- Bump sparks.
- Speed streaks.
- Countdown/start pop.
- Finish FX.

Dependencies:

- Vehicle event signals or impact data from Agent F.

#### Agent L: SFX And Music

Ownership:

- `assets/audio/*`
- `scripts/audio/*`

Responsibilities:

- Engine loop.
- Drift SFX.
- Bump SFX.
- Wall scrape SFX.
- UI sounds.
- Countdown/start stingers.
- Race music.
- Environment ambience crossfade hooks.

Wave 3 gate:

- Race looks and sounds like a polished toy-like arcade slice.
- No missing imported resources.
- No script errors or runtime warnings.

### Wave 4: UI And Final Polish

#### Agent M: Menus

Ownership:

- `scenes/ui/main_menu.tscn`
- `scenes/ui/car_select.tscn`
- `scenes/ui/track_select.tscn`
- `scenes/ui/difficulty_select.tscn`
- `scenes/ui/settings.tscn`
- related `scripts/ui/menu/*`

Responsibilities:

- Main menu.
- New Race flow.
- Car color select.
- Track preset select.
- Difficulty select.
- Settings.

#### Agent N: Results And Pause Flow

Ownership:

- `scenes/ui/pause_menu.tscn`
- `scenes/ui/results_screen.tscn`
- related scripts.

Responsibilities:

- Pause menu.
- Results screen.
- Restart.
- Main menu return.

#### Agent O: Difficulty Tuning

Ownership:

- `resources/difficulty/*`
- tuning resources only.

Responsibilities:

- Easy/Medium/Hard NPC settings.
- Player assist tuning.
- Rubberbanding profile if used.
- Document final values.

#### Agent P: QA And Performance

Ownership:

- QA notes.
- Performance notes.
- Bug reports.
- Verification scripts if added.

Responsibilities:

- Fresh launch from main menu.
- Play complete 3-lap race.
- Test restart.
- Test all difficulty options.
- Test car color select.
- Check diagnostics.
- Check console/debugger.
- Performance sanity check.

Final gate:

- User can launch from main menu.
- User can select car color.
- User can select Showcase Circuit.
- User can select difficulty.
- User can complete a 3-lap race.
- Results screen appears.
- Restart works.
- Main menu return works.
- No script errors.
- No console errors.
- No debugger errors.
- No significant warnings.
- Camera, controller, VFX, and SFX meet the approved slice direction.
- Finalization reminder: decide whether to swap the staged generated car model into `scenes/player_car.tscn`. If swapped, preserve `CameraTarget`, `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR`, collision shape, and all controller/audio/VFX child paths.

## 15. Risks And Mitigations

Risk: Scope creep from full demo UI plus NPCs plus generated assets.

Mitigation:

- Use curated track preset only.
- Use one car model only.
- Use cosmetic variants only.
- Keep VFX clean and readable.
- Gate implementation by waves.

Risk: NPC personality AI becomes unreliable.

Mitigation:

- Implement reliable track-following first.
- Make personality a modifier layer, not separate AI logic.

Risk: Track generation becomes another large monolith.

Mitigation:

- Extract TrackPath, TrackProfile, EnvironmentProfile, and TrackQuery first.
- Keep environment placement separate from path generation.

Risk: Generated assets are inconsistent.

Mitigation:

- Generate only high-impact assets.
- Keep procedural/simple fallback assets.
- Record asset IDs and import paths.

Risk: Soft collision feels fake.

Mitigation:

- Tune with player testing.
- Prioritize race flow over realism.
- Use VFX/SFX to sell contact.

## 16. Acceptance Criteria

The vertical slice is accepted when:

1. The game launches to the main menu.
2. New Race flow works.
3. Player can choose one of 4 cosmetic color variants.
4. Player can choose Showcase Circuit.
5. Player can choose Easy, Medium, or Hard.
6. Countdown starts the race.
7. Player races 3 laps against 3 NPCs.
8. NPCs display distinct driving personalities.
9. Lap and position tracking work.
10. Results screen appears after finish.
11. Restart and Main Menu return work.
12. Track is about 1.8 km, 14 m wide, closed-loop.
13. Track includes Highway/Crops, Industrial, and both transitions.
14. Highway billboards appear on both sides of the road.
15. Billboards remain correctly beside road when road width changes.
16. Crop clusters cover 30-50 percent of Highway/Crops section length.
17. Farmhouse/fenced animal areas cover 5-15 percent of Highway/Crops section length.
18. Factories are 2-3 times larger than farmhouses.
19. Farmhouses are 2-3 times larger than cars.
20. Playful farmhouse colors and gray factory tones are visible.
21. Camera prioritizes road preview and keeps car mass near lower third.
22. Drift, wall scrape, and car bump VFX/SFX are present and readable.
23. Audio direction feels playful kart-like.
24. Staged generated car model has either been integrated into the playable prefab or explicitly deferred after visual review.
25. Fresh playthrough has no script errors, console errors, or debugger errors.
