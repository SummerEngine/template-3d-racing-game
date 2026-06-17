# Art Bible v2 - Premium Arcade Realism

Date: 2026-06-16
Project: Demo
Status: Direction pivot approved

## Creative Target

The game is no longer toy-low-poly. The new visual target is premium arcade realism: high-end realistic cars, cinematic roads, detailed environments, glossy lighting, expressive glares, satisfying VFX, and arcade-impossible track moments.

The player fantasy is not a driving simulator. It is a premium racing spectacle where realistic cars perform impossible stunts with confidence: vertical loops, fast acceleration, heavy braking, exaggerated drifts, and dramatic camera moments.

## Reference Interpretation

The supplied references point to these priorities:

- Golden-hour city race with sun glare, crowded barriers, branded-feeling race dressing, and readable road flow.
- Mountain and coastal roads with realistic asphalt, guardrails, road shoulders, power lines, cliffs, mist, and distant terrain.
- First-person and chase-camera HUDs that are information-rich but still clean, with translucent panels and high-contrast typography.
- Hypercar and GT silhouettes with CG-quality body panels, clear headlight/brake-light signatures, aerodynamic surfaces, rims, spoilers, vents, and reflective paint.
- Hot Wheels-like loops as rare emotional punctuation, not the base art style.

## Rendering Technique

Primary technique: stylized high-end PBR realism.

This means:

- Realistic proportions and materials.
- PBR car paint, glass, rubber, asphalt, metal, concrete, wet surfaces, emissive lights.
- Controlled cinematic exaggeration through color grading, bloom, lens flares, reflections, and camera shake.
- No low-poly toy simplification.
- No photogrammetry soup. Assets must be optimized, readable, and art-directed.

The world may be inspired by real cities and real roads, but should avoid exact copies of copyrighted locations, real brands, or manufacturer-specific car replicas unless proper licensed assets are used.

## Mood

- Cinematic
- Glossy
- Fast
- Aspirational
- Dangerous
- Slightly futuristic

## Palette

The palette is broad enough for realism but still constrained for art direction.

| Hex | Role |
|---|---|
| `#0B0F14` | Deep UI black / garage shadow |
| `#171E26` | Dark carbon / asphalt shadow |
| `#2B333D` | Graphite panels / barriers |
| `#5B6875` | Cool concrete / mountain haze |
| `#9BA8B4` | Road mist / cool highlights |
| `#D7DBDE` | Car white / bright UI text |
| `#F2B35E` | Golden-hour sun / premium accent |
| `#FF6A2A` | Brake heat / exhaust flame / warning accent |
| `#E1252F` | Race red / danger / curbs |
| `#1BA7FF` | Futuristic blue guide lights |
| `#0ED4C8` | Electric cyan checkpoint / racing line |
| `#2D7D46` | Natural green / mountain foliage |
| `#7A5B3D` | Dirt shoulder / warm stone |
| `#F6F2E8` | Warm off-white UI text |

Avoid pure white and pure black in authored UI and materials unless used for physically correct emissive values or HDR effects.

## Cars

Cars should feel like they were made by an experienced CG vehicle artist.

Required car qualities:

- Realistic or near-realistic hypercar, GT, tuner, prototype, or futuristic sports-car silhouettes.
- Distinct front, rear, side, top, and wheel details.
- Separate wheels with correct visual rotation and steering.
- Headlights, brake lights, reverse lights, indicators, and optional underglow as separate controllable nodes/materials.
- Reflective layered paint: base coat, clear coat, roughness control, subtle decals or panel lines.
- High-quality rims, tires, brake discs, calipers, vents, spoilers, splitters, mirrors, windows.
- LOD plan: hero race car, mid LOD, far impostor or simplified LOD.
- Damage is not required yet, but scrape marks, sparks, tire smoke, and road marks must sell contact.

Do not use exact real manufacturer logos or exact real car replicas unless explicitly licensed.

## World

World target: realistic roads in cinematic environments.

Initial environment families:

- Urban landmark-inspired city race: bridges, old buildings, modern glass, river roads, sponsor barriers, sunset glare.
- Mountain / coastal road: cliffs, mist, trees, guardrails, wet asphalt, power lines, tunnels.
- Futuristic warehouse / garage menu environment: hero car on reflective floor, soft neon, industrial lighting rigs.
- High-speed highway or city expressway: tunnels, overpasses, reflective signs, glass buildings, dynamic light streaks.

The world can use real-world inspiration but should be fictionalized. The goal is recognizability of mood, not legal or geographic accuracy.

## Road And Track Materials

Roads are a first-class visual feature.

Required road material layers:

- Asphalt base with directional grain.
- Rubber buildup on racing line.
- Dynamic or semi-dynamic drift/skid marks.
- Wetness/roughness variants.
- Painted lane markings and curbs.
- Road-edge dirt/grime.
- Puddle/glare support for selected weather/time-of-day profiles.

Drift should affect the surface visually. The first version can use decal or mesh-strip skid marks. Later versions can add render-target road masks if performance allows.

## Arcade Set Pieces

Impossible track elements are allowed, but should be rare and premium.

Use:

- Vertical loops.
- Banked wall rides.
- High-speed tunnel launches.
- Controlled jumps.
- Spiral ramps.
- Futuristic magnetic track sections.

Rules:

- Set pieces must feel engineered into the world, not randomly attached.
- A city loop might be an experimental race-event structure.
- A mountain jump might be a temporary festival ramp.
- A futuristic tunnel can justify blue guide lights and anti-gravity visual language.
- Do not overuse orange plastic toy-track color unless intentionally referencing a special challenge mode.

## UI Direction

Menu target:

- Minimal left-side navigation.
- Hero car occupies most of the screen.
- Car appears in a realistic garage, warehouse, showroom, or pit-lane environment.
- Menu text is simple, premium, and restrained.
- Large background car can rotate or subtly animate.
- Settings and race setup should use slim panels, not chunky toy buttons.

HUD target:

- Clean racing-game HUD with strong readability.
- Position, lap, race time, speed, gear, minimap, objective/missions.
- Translucent dark panels and white/cyan/yellow accents.
- Avoid large decorative cards.
- Avoid playful low-poly typography.

## Lighting Plan

Garage/menu:

- Dark warehouse base with controlled highlights.
- Area lights above and beside the hero car.
- Cool rim light on car edges.
- Warm practical lights in background.
- Reflective floor, but not mirror-like enough to distract.

Outdoor race:

- Strong time-of-day identity per track.
- Golden-hour city: warm low sun, glare, long shadows, high bloom control.
- Mountain/coastal: cool mist, soft sky, wet road reflections, high-distance haze.
- Night/futuristic: emissive signage, road LEDs, headlight cones, blue/cyan guide lighting.

Godot/Summer Engine defaults:

- Forward+ renderer for richer lighting.
- MSAA or TAA depending on performance.
- Glow enabled, tightly controlled.
- SSAO enabled lightly for grounding.
- SSR only for wet roads/showroom surfaces where performance allows.
- Color grading by `LightingProfile`, not hardcoded scene values.

## VFX Direction

VFX should be realistic enough to match premium cars but exaggerated enough to sell arcade feedback.

Required:

- Tire smoke with density tied to drift angle and speed.
- Sparks from guardrail scrapes and underbody contact.
- Heat/exhaust flare on heavy acceleration.
- Brake glow for hard braking.
- Headlight and taillight bloom.
- Subtle speed streaks only at high speed.
- Road skid decals from drift.
- Checkpoint/racing-line effects that feel like an event overlay, not magic fantasy.

Avoid cartoon particles, chunky starbursts, toy-like puffs, and low-poly smoke cards.

## Audio Direction Notes

Audio should pivot with the visuals:

- Aggressive engine layers.
- Tire squeal and low-frequency road rumble.
- Turbo/EV whine depending on car type.
- Heavy brake and downshift sounds.
- Reflective tunnel reverb.
- Crowd and city ambience.
- Metallic scrape and debris sounds.
- UI sounds should be premium, minimal, and tactile.

## Optimization Constraints

High-end realism must still be shippable.

- Use modular environment kits.
- Use LODs for cars and scenery.
- Use occlusion and sector loading for city/mountain chunks.
- Use baked or semi-baked lighting where possible.
- Use decals/mesh strips for skid marks before render-target road deformation.
- Avoid unique high-resolution textures on every prop.
- Keep AI-editable profiles separate from heavy mesh data.

## Do

- Use PBR materials with clear roughness/metalness intent.
- Treat cars as hero assets.
- Use authored camera composition and lighting.
- Keep roads readable even when environments are detailed.
- Use fictionalized city and car inspiration.
- Build environments from reusable modular kits.
- Use profile-driven style, lighting, material, and environment settings.
- Use impossible set pieces sparingly and narratively.

## Don't

- Do not mix toy-low-poly assets into premium tracks.
- Do not use exact real brands or exact real car replicas without licensing.
- Do not make every track a stunt track.
- Do not fully procedurally generate realistic cities and expect premium quality.
- Do not rely on giant unoptimized hero meshes everywhere.
- Do not use low-resolution UI panels or playful cartoon buttons.
- Do not use bloom, lens flare, chromatic aberration, or motion blur as a substitute for composition.
- Do not let environment detail reduce road readability.

## Immediate Consequence For The Current Prototype

The current vertical slice is still useful for mechanics, race flow, and architecture learning. Visually, it should now be treated as a mechanics prototype, not the final art target.

The next art/tech step is not replacing every asset immediately. The next step is creating the premium-realism template architecture:

- `ArtStyleProfile`
- `LightingProfile`
- `CarVisualProfile`
- `RoadSurfaceProfile`
- `TrackProfile`
- `EnvironmentKitProfile`
- `SetPieceProfile`

Once those profiles exist, future AI agents can alter style, shader choices, lighting, car classes, and track dressing from prompts without rewriting the core systems.
