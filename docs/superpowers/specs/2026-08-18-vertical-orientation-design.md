# Vertical Orientation (Subway Surfers-style forward motion, single lane)

## Goal

Change Bark & Chomp's world direction from a horizontal side-scroller (auto-run right, hop over ground obstacles, vacuum chases from ahead) to a vertical runner where the player auto-climbs upward. Visual/directional inspiration is Subway Surfers' forward-scrolling feel — **without** its 3-lane system. There is no lateral movement of any kind: single fixed lane, single-thumb tap/hold input, exactly as today.

## Non-goals

- No lane system, no lateral/steering input of any kind (explicitly rejected by the user — this stayed a single-lane game throughout the brainstorm, including after an earlier draft of this spec incorrectly introduced a continuous dodge axis, which was corrected).
- No pseudo-3D/angled perspective.
- No support for toggling between horizontal and vertical modes — straight replacement, not a configurable option.
- No new input scheme. Tap = hop, hold = bark charge/release, exactly the same thresholds and state machine as today (`input_controller.gd` is untouched).
- No new gameplay mechanics — hop, bark, deflect, Zoomies, Chomp, treats, meter all behave the same; only the spatial model they sit on top of changes.

## Current architecture (horizontal)

- **Forward/auto-run**: `velocity.x = tuning.run_speed * ...` in `player.gd::_physics_process`. The player's own `global_position.x` **is** "how far into the run we are" — everything else (rival chase target, obstacle/treat spawn distance) is computed relative to it.
- **Gravity/hop**: `velocity.y` — gravity accumulates downward, `hop_impulse` is a negative-Y impulse, `is_on_floor()` gates whether a new hop can start. This is genuine spatial avoidance: the player's Y position rises above a ground-level obstacle's collision box.
- **Camera**: child of `Player`, offset `(200, 0)`, so it moves through the world exactly as the player's X advances.
- **Rival chase** (`rival_base.gd::_chase`): desired X = `player.global_position.x + rival_target_distance` (+ sine noise), rubber-banded toward.
- **Projectile**: launched toward the player along X.
- **Ground**: a literal floor the player rests on and obstacles sit on.

## New architecture (vertical, single lane)

The key change is splitting "how far into the run" from "the player's own screen position" — in the horizontal game these were the same number (`player.global_position.x`), and everything (rival chase, treat spawn) read that one value directly. They can't stay the same number here, because the player's own position now needs to stay near a fixed screen row (for the hop wobble to read as real clearance) while something else has to represent progress.

- **`distance_traveled`** — a plain float on `player.gd`, incremented by `run_speed * PX_PER_UNIT * speed_mult * delta` every physics frame — a direct, like-for-like replacement for the role `player.global_position.x` used to play as "how far into the run we are." Nothing renders directly from this value; it's the shared clock everything else reads.
- **The player and camera stay visually fixed on screen.** `Player.global_position` is fixed on X, and on Y sits at a constant `BASELINE_Y` minus a **hop offset** — `gravity`/`hop_impulse`/`is_on_floor()` stay almost exactly as they work today, just measured as a local ballistic excursion from `BASELINE_Y` instead of an absolute position on a scrolling floor. The camera doesn't move at all — no camera code changes needed. This resolves what the first draft of this spec called out as the trickiest risk (camera decoupling); it turns out to not be a problem, because the camera simply has nothing to follow anymore.
- **Every other moving entity (obstacle, rival, projectile, treat) tracks its own `_progress` value and renders itself relative to the player's clock.** `player.gd` exposes `func get_track_y(progress: float) -> float: return BASELINE_Y - (progress - distance_traveled)`. Each entity sets `global_position.y = player.get_track_y(_progress)` every frame; `global_position.x` stays at that entity's fixed lane offset (matching the player's X). This is the generalized version of what `rival_base.gd::_chase()` already does today (compare a tracked value against the player's position) — the pattern extends to obstacle and treat, which previously didn't need any per-frame logic because the player moved past their static position instead.
  - **Obstacle** — currently a bare `StaticBody2D` with no script (`scenes/obstacle.tscn`, one static instance in `main.tscn`). Needs a new small script holding a fixed `_progress` (its target distance) and applying the render formula each frame. This is new code, not a port.
  - **Rival** (`rival_base.gd::_chase`) — internal state changes from "my own `global_position.x` is my progress" to an explicit `_progress` float, rubber-banded toward `distance_traveled + rival_target_distance` (+ existing sine noise) exactly as today's math, then rendered via `get_track_y(_progress)`.
  - **Projectile** — launched with `_progress` starting at the rival's `_progress`, decreasing toward the player's `distance_traveled` at `projectile_speed` (closing speed with the player's own advance is still `projectile_speed + run_speed`, unchanged math from the round-5 timing fix). Rendered via the same formula.
  - **Treats** (`treat_spawner.gd`) — spawn with a fixed `_progress = distance_traveled + SPAWN_AHEAD_PX` at spawn time (direct replacement for today's `player.global_position.x + SPAWN_AHEAD_PX`), static thereafter, same as Obstacle's pattern.
  - Collision at the "did the hop clear it" moment stays genuine Godot shape-overlap physics — it happens naturally when an entity's rendered Y (via `get_track_y`) coincides with the player's `BASELINE_Y - hop_offset`, exactly mirroring how collision worked in the horizontal game, just recomputed each frame instead of the player physically moving through a static world.
- **Bark charge/release/deflect**: unchanged. The bark hitbox is repositioned to face "up the screen" (toward the incoming direction, i.e. −Y) instead of +X.
- **No literal ground/floor node** — `BASELINE_Y` is a plain constant the hop offset and every entity's render formula reference, not a scrolling collidable. The `Ground` `StaticBody2D` in `main.tscn` is removed.
- **UI** (`DebugLabel`, `MeterBarBg`/`MeterBarFill`, `HintLabel`): repositioned for a portrait play area — a fresh placement pass, not a port of the landscape coordinates hand-tuned this session.
- **Android export**: switched to portrait orientation (confirmed with the user).

## Files touched

- `scripts/player.gd` — remove `velocity.x` forward-run logic; add `distance_traveled` accumulator and `get_track_y(progress)` helper; keep gravity/hop-impulse code but reinterpret as a local ballistic offset from `BASELINE_Y`; remove the old `(200, 0)` camera offset (camera no longer needs to move); bark hitbox reoriented to face the incoming (−Y) direction
- `scripts/rival_base.gd` — replace `global_position.x`-as-state with an explicit `_progress` float; `_chase()` rubber-bands `_progress` toward `distance_traveled + rival_target_distance` (+ existing sine noise) instead of targeting `player.global_position.x` directly; render via `player.get_track_y(_progress)`; same treatment for the respawn/knockback lines that currently write `global_position.x`
- `scripts/projectile.gd` — add `_progress` (starts at the launching rival's `_progress`, decreases at `projectile_speed`), rendered via `get_track_y`; hit-check gains a hop-height condition (a projectile arriving while the player is airborne above `BASELINE_Y` should miss, mirroring how it already only threatens a grounded player today)
- `scripts/obstacle.gd` — **new file**. Currently `scenes/obstacle.tscn` has no script at all (a bare `StaticBody2D`). Needs one: holds a fixed `_progress` (its target distance) and sets `global_position.y = player.get_track_y(_progress)` every frame, same pattern as the rival/projectile.
- `scripts/treat_spawner.gd` — `_spawn()` currently activates a treat at `player.global_position.x + SPAWN_AHEAD_PX`; changes to set the treat's own `_progress = player.distance_traveled + SPAWN_AHEAD_PX` instead. `scripts/treat.gd` needs the same small `_progress` + per-frame render as obstacle/projectile (it's currently a static Area2D that never moves once activated — now it must, since the player itself no longer moves toward it).
- `scenes/main.tscn` — `Ground` `StaticBody2D` node removed entirely; `Obstacle` instance keeps a placed position but now needs its script attached (see `obstacle.gd` above) and its position reinterpreted as a target progress, not a literal world coordinate; `Rival` node's initial world position no longer matters much beyond a starting `_progress`
- `scenes/player.tscn` — UI nodes repositioned for portrait; `BarkHitbox` reoriented; `Camera2D` offset changed from `(200, 0)` to `(0, 0)` (or removed — no longer needs an ahead-of-player offset since the world scrolls past a fixed player instead)
- Android export preset — orientation switched to portrait
- `scripts/tuning.gd` — **no numeric changes expected**; magnitudes carry over, only what they're applied to changes

## Testing

- Headless smoke test after each meaningful change (established pattern this session).
- Full manual on-device playtest (portrait) once assembled.
- **The Milestone 1.6 silent-observation playtest protocol needs to be re-run from scratch.** The horizontal game's validated findings (deflect timing fairness, discoverability hint) don't transfer automatically to a vertical single-lane game — even though the underlying mechanics are unchanged, the moment-to-moment feel and readability are different enough to warrant a fresh gate. This is a divergence from `bark_and_chomp_project_plan.md`'s original Phase 1 sequencing (written assuming the horizontal prototype); noted here and will be reflected in `handoff.md` once implementation starts.

## Risks / open questions carried into implementation

- Projectile-vs-hop-height hit detection is new logic (the horizontal game never needed to check "is the player currently elevated" because hop height and forward position were on different, unrelated axes there; here they still are in spirit — the player's hop offset and every other entity's progress-based render are logically separate — but it's worth an explicit test that a well-timed hop actually avoids a projectile arriving at that instant, not just a static obstacle).
- `treat.gd` and `obstacle.tscn` currently have no per-frame movement logic at all (treat is static once activated; obstacle has no script). Both need one added — this is genuinely new code, not a mechanical port, so give it its own task with its own test rather than folding it into a larger "port the scripts" step.
- `rival_base.gd`'s `STUNNED`/`CAUGHT` states currently write `global_position.x` directly (e.g. `_recover_to_chasing`, `_on_chomped`'s respawn) — these all need the same `global_position.x` → `_progress` treatment as `_chase()`, easy to miss since they're not in the main chase path.
