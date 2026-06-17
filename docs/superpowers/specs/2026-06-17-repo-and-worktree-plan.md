# Repo and Worktree Plan

## Repository

Canonical remote:

`https://github.com/SummerEngine/template-3d-racing-game.git`

The current Summer project should be imported on a feature branch first, then merged to `main` after a clean playtest and visual review. Do not force-push over `main`.

## Branches

- `main`: stable playable baseline.
- `feature/playability-core`: controller, camera, countdown, HUD, reset-to-road.
- `feature/storm-coast-art`: road material, lighting, weather, coastal/mountain dressing.
- `feature/vehicle-art`: car model swaps, materials, wheel pivots, cockpit model.
- `feature/race-ai`: NPC path following, difficulty tuning, start grid race behavior.
- `feature/editor-tools`: track authoring handles, bake/regenerate tools, generated prop overrides.

## Worktree Layout

Keep the primary checkout as the baseline and create sibling worktrees for parallel work:

```bash
git worktree add ../racing-playability feature/playability-core
git worktree add ../racing-storm-coast-art feature/storm-coast-art
git worktree add ../racing-vehicle-art feature/vehicle-art
git worktree add ../racing-race-ai feature/race-ai
git worktree add ../racing-editor-tools feature/editor-tools
```

Each worktree should own different files whenever possible. If two agents need the same scene, split the scene first or serialize the work.

## Conflict Rules

- One agent owns `scenes/player_car.tscn` at a time.
- One agent owns `scripts/car_controller.gd` at a time.
- Track art agents should work under `assets/`, `resources/materials/`, and environment scenes, not controller scripts.
- Race logic agents should work under `scripts/race/` and UI scenes.
- Track generator agents should work under `scripts/track/` and `scripts/track_authoring/`.

## First Stable Baseline

The first baseline should include:

- imported playable car model,
- corrected car model orientation,
- red metallic texture candidate imported from Summer Studio,
- Storm Coast preview scene booting,
- road collision floor probe clean,
- no debugger errors or warnings except known Summer TCP noise.
