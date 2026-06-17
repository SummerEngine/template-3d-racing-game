# AI Repaint Model Requirements

This document describes the preferred vehicle asset setup for the live AI car repaint prototype. The goal is to let Godot identify and repaint the body material while leaving glass, wheels, tires, lights, and interior materials unchanged.

## Ideal GLB Material Slots

Provide a GLB with separate material slots for:

- `BodyPaint`
- `Glass`
- `Wheels` or `Rims`
- `Tires`
- `Lights`
- `Interior`
- `Decals` or `CarbonTrim`

`BodyPaint` is the main repaint target. Decals and trim can be kept separate so prototype repaints do not accidentally overwrite carbon fiber, badges, numbers, sponsor graphics, or fixed design details.

## UV Requirements

For body and livery repainting, the body panels need clean, non-overlapping UVs where possible. The AI-generated base-color texture must map predictably across doors, hood, roof, trunk, fenders, and bumpers.

Avoid mirrored UVs on repaintable body areas. Mirrored UVs are efficient for generic materials, but they break asymmetric liveries: text can appear backwards on one side, numbers may duplicate incorrectly, and one-sided decals or racing stripes cannot be placed reliably.

Recommended UV guidance:

- Keep the main body shell in a dedicated UV region.
- Minimize stretching on broad visible panels.
- Leave enough padding between UV islands to prevent texture bleed.
- Keep glass, tires, rims, lights, interior, and fixed trim on separate material slots or clearly separate UV areas.
- Use consistent UV orientation for left and right body panels if asymmetric decals are expected later.

## Texture Sizes

For the prototype:

- `1024x1024` base color is acceptable for fast iteration.
- `2048x2048` base color is preferred for readable stripes, numbers, and simple decals.
- Roughness, metallic, and normal maps can be omitted or kept at `1024x1024` while proving the workflow.

For later production work:

- `2048x2048` should be the normal minimum for hero cars.
- `4096x4096` may be needed for close-up vehicles, detailed liveries, readable text, or marketing captures.
- Use matching texture dimensions across base color, roughness, metallic, and normal maps when the full material pipeline is implemented.

## Naming Conventions

The Godot applier should be able to find repaint targets by material or mesh names. Artists should use clear names that include one of these searchable tokens:

- Body material: `BodyPaint`, `body_paint`, `paint`, `car_body`, `repaint_target`
- Glass material: `Glass`, `window`, `windshield`
- Wheel or rim material: `Wheels`, `Rims`, `rim`, `wheel`
- Tire material: `Tires`, `rubber`, `tyre`
- Light material: `Lights`, `headlight`, `taillight`
- Interior material: `Interior`, `cabin`, `seat`
- Decal or trim material: `Decals`, `CarbonTrim`, `carbon`, `trim`, `livery_static`

Preferred prototype target name:

```text
BodyPaint
```

## Artist/User Deliverables

Ask the user or artist to provide:

- A GLB vehicle model with separate material slots listed above.
- A body material intended for repainting, ideally named `BodyPaint`.
- UVs for the body shell that support asymmetric designs.
- A reference screenshot or turntable showing the intended default paint.
- Any fixed decals, carbon trim, badges, or interior details that should never be repainted.
- Current texture files if the GLB references external assets.
- A short note describing the expected repaint zones and protected zones.

## Public Repo Safety

Do not include real car logos, manufacturer badges, sponsor marks, or other protected IP in assets committed to the public repo. Use fictional badges, generic silhouettes, or placeholder decals for prototype testing.
