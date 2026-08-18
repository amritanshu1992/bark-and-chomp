# Vertical Orientation (Subway Surfers-style world movement, no lanes)

## Goal

Change Bark & Chomp's core world movement from a horizontal side-scroller (auto-run right, hop over obstacles, vacuum chases from ahead) to a vertical, continuous (non-lane-locked) runner: the player auto-climbs upward, dodges laterally with continuous free movement (not discrete lanes), and the rival vacuum/obstacles/throws approach from above. Visual/directional inspiration is Subway Surfers' forward-scrolling feel, explicitly *without* its 3-lane system.

## Non-goals

- No discrete lane system (explicitly rejected by the user).
- No pseudo-3D/angled perspective (rejected in favor of a flat, cheaper build that reuses the existing 2D pipeline).
- No support for toggling between horizontal and vertical modes — this is a straight replacement, not a configurable option. Building that flexibility would be speculative (YAGNI) since nobody asked for both.
- No new gameplay mechanics. Hop, hold-to-charge bark, deflect, Zoomies, Chomp, treats, and the meter are all unchanged in behavior — only which screen axis "forward" and "dodge" map to changes.

## Current architecture (horizontal)

- **Forward/auto-run**: `velocity.x = tuning.run_speed * PX_PER_UNIT * speed_mult` in `player.gd::_physics_process`.
- **Gravity/hop**: `velocity.y` — gravity accumulates downward, `hop_impulse` is a negative Y impulse, floor check via `is_on_floor()`.
- **Camera**: `Camera2D` offset `(200, 0)` — shows more world ahead in +X.
- **Rival chase** (`rival_base.gd::_chase`): computes a desired X position ahead of the player (`player.global_position.x + rival_target_distance`), rubber-bands toward it, applies sine-noise on X.
- **Projectile** (`projectile.gd`): launched toward the player along X (leftward, closing speed = `projectile_speed + run_speed`).
- **Ground**: a `ColorRect`/collision floor in `main.tscn` the player rests on and obstacles sit on.
- **UI**: `DebugLabel`, `MeterBarBg`/`MeterBarFill`, `HintLabel` all positioned in landscape screen-space, hand-tuned this session to stay clear of a landscape-oriented play area.
- **Android export**: currently landscape.

## New architecture (vertical, continuous, no lanes)

- **Forward/auto-run**: moves to `velocity.y`, auto-climbing (world Y decreasing = up on screen). Same `run_speed` magnitude.
- **Gravity/dodge**: moves to `velocity.x`. Gravity's role changes from "pull down to a floor" to "pull back toward a center X rest position" (a spring-return, not a floor rest) — this is the direct analog of "hop away from rest, then gravity returns you," just on the horizontal axis instead of vertical. Hop impulse becomes a lateral dodge impulse (still tap-triggered, same `hop_impulse` magnitude). Continuous, not lane-snapped — the player can be at any X within bounds, not just left/center/right.
- **Camera**: offset moves to `(0, -200)` (or equivalent), showing more world above the player (the approach direction) instead of ahead in X.
- **Rival chase** (`rival_base.gd::_chase`): desired position becomes Y above the player (`player.global_position.y - rival_target_distance`, since up is -Y), rubber-band and sine-noise logic unchanged, just applied to Y instead of X.
- **Projectile**: launches downward (+Y) toward the player instead of leftward. Same `projectile_speed`, same closing-speed math (`projectile_speed + run_speed`) — the round-5 `bark_hitbox_duration_s` timing fix stays numerically valid since it only depends on that sum, not which axis it's applied to.
- **Ground → side boundaries**: the horizontal "floor" concept is replaced by left/right bounds that constrain the dodge range on X (the vertical equivalent of "don't run off the world" — prevents infinite lateral drift). No obstacles literally "sit on the ground" anymore; obstacles are placed somewhere along the vertical track and the player dodges them on X.
- **UI**: `DebugLabel`, `MeterBarBg`/`MeterBarFill`, `HintLabel` all need new positions suited to a portrait play area — the current landscape-tuned coordinates (from this session's hint-placement iteration) don't apply. This is a fresh placement pass, not a port.
- **Android export**: switched to portrait orientation to match the vertical world (matches Subway Surfers' own orientation, and gives more usable vertical screen height than landscape-with-vertical-world would).

## Files touched

- `scripts/player.gd` — physics_process axis swap, hop/gravity axis swap, camera offset direction, bark hitbox orientation (currently sized/positioned assuming forward = +X; needs to face +Y/up instead)
- `scripts/rival_base.gd` — `_chase()` axis swap (X→Y), all `global_position.x` references affected by chase/respawn/knockback logic
- `scripts/projectile.gd` — launch direction axis swap
- `scenes/main.tscn` — Ground node becomes side boundary colliders; obstacle/rival/player starting positions re-laid-out for a vertical track
- `scenes/player.tscn` — `UI/DebugLabel`, `UI/MeterBarBg`, `UI/MeterBarFill`, `UI/HintLabel` repositioned for portrait
- `project.godot` (or Android export preset) — orientation flag switched to portrait
- `scripts/tuning.gd` — **no numeric changes expected**; only which axis each value drives changes, not the magnitudes

## Testing

- Headless smoke test after each meaningful change, as established this session.
- Full manual playtest on-device (portrait) once assembled — this is a big enough change to the feel of the game that it needs its own pass, not just a "does it still boot" check.
- **The Milestone 1.6 silent-observation playtest protocol needs to be re-run from scratch** once this ships. The current 1.6 progress (deflect timing fairness, discoverability hint) was validated against the horizontal game; none of those UX findings can be assumed to transfer to a vertical, portrait, continuous-dodge game. This is a divergence from `bark_and_chomp_project_plan.md`'s original Phase 1 sequencing (which assumed the horizontal prototype throughout) — noting it here per the project's own instruction to record divergences rather than silently drift, and it will also be flagged in `handoff.md`.

## Risks / open questions carried into implementation

- The bark hitbox's shape/orientation (`BarkHitbox` in `player.tscn`, sized in `player.gd::_ready`) is currently a rectangle facing +X; it needs to face +Y (up, toward the incoming rival/projectile) — straightforward but easy to miss since it's built at runtime from `tuning.bark_range_units`, not authored in the scene file.
- Obstacle layout/spawning logic isn't explicitly covered by the scripts read so far in this session (no `obstacle_spawner.gd`-equivalent was inspected) — the implementation plan should locate and account for however obstacles currently get placed along the track before assuming the axis swap is complete.
