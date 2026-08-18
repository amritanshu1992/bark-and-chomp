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

The key change is splitting "how far into the run" from "the player's own position" — in the horizontal game these were the same number (`player.global_position.x`). They can't stay the same number here, because Y is about to carry two different jobs: forward progress, and hop height above a fixed row. Keeping them separate is the core of this design.

- **World-scroll progress** — a new accumulator (owned by `player.gd` or a small level/game-state script; exact home is an implementation-plan decision) that increases at `run_speed`, exactly like `velocity.x` did before, just not stored as a position. This drives the camera moving up through the level, and is what rival chase / obstacle spawn / treat spawn logic use as "distance covered" — a direct rename of the role `player.global_position.x` used to play.
- **Player hop height** — `gravity`, `hop_impulse`, and `is_on_floor()` stay almost exactly as they work today, just reinterpreted as a **local vertical offset from a fixed baseline row** instead of an absolute position on a scrolling floor. Tapping launches the player upward with the same impulse; gravity pulls back down to the baseline. This is genuine spatial avoidance, not a cosmetic cue: while airborne, the player is rendered and collides above the baseline row, so an obstacle scrolling down to that row (driven by world-scroll progress) passes underneath. Same timing skill as today.
- **Player X position**: fixed for the whole run. No physics, no input, no camera-follow on this axis at all.
- **Bark charge/release/deflect**: unchanged. The bark hitbox is repositioned to face "up the screen" (the incoming direction, i.e. toward negative world-scroll-progress-remaining) instead of +X.
- **Camera**: no longer a simple child-of-player offset (since the player's own `global_position.y` is now hop-height, not distance). It needs to follow world-scroll progress directly rather than the player node's transform. This is the trickiest single piece of the implementation — flagged under Risks below.
- **Rival chase** (`rival_base.gd::_chase`): target becomes `world_scroll_progress + rival_target_distance` (+ existing sine noise), same rubber-band math, now against the shared progress value instead of `player.global_position.x`.
- **Projectile**: travels toward the player along the scroll axis (closing speed = `projectile_speed + run_speed`, unchanged math from the round-5 fix). Hit detection must also account for the player's current hop height — a projectile arriving while the player is airborne above baseline should miss, mirroring how the horizontal game's projectile already only threatens a grounded player.
- **No literal ground/floor node** — "ground" is now the fixed baseline row the player's hop offset measures from, not a scrolling collidable. Obstacles are placed along the world-scroll track at that baseline row.
- **UI** (`DebugLabel`, `MeterBarBg`/`MeterBarFill`, `HintLabel`): repositioned for a portrait play area — a fresh placement pass, not a port of the landscape coordinates hand-tuned this session.
- **Android export**: switched to portrait orientation (confirmed with the user).

## Files touched

- `scripts/player.gd` — remove `velocity.x` forward-run logic; add the world-scroll-progress accumulator; keep gravity/hop-impulse code but reinterpret against a fixed baseline instead of a floor; camera-follow logic reworked to track scroll progress, not the player node; bark hitbox reoriented to face the incoming direction
- `scripts/rival_base.gd` — `_chase()` retargeted from `player.global_position.x` to the shared world-scroll-progress value; same for any other `global_position.x` reads (respawn positioning, knockback)
- `scripts/projectile.gd` — travel direction switched to the scroll axis; hit-check gains a hop-height condition
- `scenes/main.tscn` — Ground node removed/replaced by a baseline-row concept; obstacle placement re-laid-out along the scroll track
- `scenes/player.tscn` — UI nodes repositioned for portrait; `BarkHitbox` reoriented
- Android export preset — orientation switched to portrait
- `scripts/tuning.gd` — **no numeric changes expected**; magnitudes carry over, only what they're applied to changes

## Testing

- Headless smoke test after each meaningful change (established pattern this session).
- Full manual on-device playtest (portrait) once assembled.
- **The Milestone 1.6 silent-observation playtest protocol needs to be re-run from scratch.** The horizontal game's validated findings (deflect timing fairness, discoverability hint) don't transfer automatically to a vertical single-lane game — even though the underlying mechanics are unchanged, the moment-to-moment feel and readability are different enough to warrant a fresh gate. This is a divergence from `bark_and_chomp_project_plan.md`'s original Phase 1 sequencing (written assuming the horizontal prototype); noted here and will be reflected in `handoff.md` once implementation starts.

## Risks / open questions carried into implementation

- **Camera decoupling is the trickiest part.** Today `Camera2D` is a child of `Player` and implicitly follows the player's own transform. Once the player's `global_position.y` means "hop height" rather than "distance traveled," the camera can no longer simply follow the player node — it needs to track the new world-scroll-progress value while the player's own node stays visually anchored near a fixed screen row. The implementation plan should settle this explicitly (e.g., camera as a sibling driven by the accumulator, or the whole level moving instead of the camera) rather than discovering it mid-implementation.
- **Obstacle spawning logic hasn't been located yet** — no `obstacle_spawner.gd`-equivalent has been inspected in this session. The implementation plan needs to find and account for however obstacles currently get placed before assuming the port is complete.
- Projectile-vs-hop-height hit detection is new logic (the horizontal game never needed to check "is the player currently elevated" because hop height and forward position were on different, unrelated axes there; here they still are, but the projectile's target axis is now the same axis the rival/obstacles travel on, so the interaction needs to be explicit).
