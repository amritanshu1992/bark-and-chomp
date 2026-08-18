# Technical Design Document — "Bark & Chomp"

Version 1.0 · Godot 4.x / GDScript 2.0 · Companion docs: GDD, Project Plan

Purpose: the build spec. Written to be dropped into the repo (alongside the GDD) as context for Claude Code or any coding agent. Work milestone-by-milestone per the Project Plan — never generate the whole game in one pass; every milestone ends with a human playtest on a physical Android device.

---

## 1. Engine & Project Settings

- **Godot 4.x, GDScript 2.0.** (Agents: do not emit Godot 3 syntax — `onready` → `@onready`, `export` → `@export`, `yield` → `await`, signals use `signal_name.emit()` / `.connect(callable)`.)
- Renderer: Mobile. Target 60 FPS.
- Orientation: portrait. Base resolution 720×1280, stretch mode `canvas_items`, aspect `expand`. Confirmed working end-to-end on-device as of the vertical-orientation migration (see §5).
- Physics tick: 60. All gameplay-critical motion in `_physics_process`.
- Input: touch only in production; mouse-emulates-touch ON for editor testing. **All timing thresholds must be tuned against a physical device**, not the editor.
- Android export configured in Phase 0; keystore + export template verified before any gameplay code.
- **Gotcha:** `project.godot`'s `window/handheld/orientation` must be the bare enum index (e.g. `1` for portrait), never a quoted string like `"portrait"`. Godot's Android export code does `int(get_project_setting(...))` on that value, and casting a non-numeric string silently yields `0` (Landscape) — this shipped a landscape APK from a portrait project for a while before being caught on-device.

---

## 2. Project Structure

**As actually built through Phase 1 / Milestone 1.6** (not all of the originally-planned structure exists yet — items marked "not yet built" below are still correct future scope, just not present today):

```
res://
  scenes/
    main.tscn            # Game scene: world, player, rival, treat spawner
    player.tscn          # CharacterBody2D (fixed-position container, not a physics
                          # slider) + Visual/Shadow ColorRects + BarkHitbox (Area2D)
                          # + UI CanvasLayer
    rival.tscn            # Area2D running rival_base.gd directly (no separate skin yet)
    projectile.tscn       # Area2D (pooled)
    treat.tscn            # Area2D (pooled)
    obstacle.tscn         # Area2D (pooled progress-crossing check, not StaticBody2D — see §5)
  scripts/
    player.gd
    input_controller.gd  # The tap/hold state machine — isolated & unit-testable
    rival_base.gd        # Template AI (chase/throw/stun/react/caught)
    projectile.gd
    treat.gd
    treat_spawner.gd     # Interval spawner for treats only
    obstacle.gd           # Single fixed-progress instance in main.tscn — no spawner yet
    lane_scroll.gd        # Recycling scroll-cue stripes (placeholder ground-texture stand-in)
    main.gd                # Restart button -> reload_current_scene()
    tuning.gd
  resources/
    tuning.tres           # Overrides live on top of tuning.gd's defaults -- check both
  assets/                # sprites, audio (placeholders in Phase 1)
```

**Not yet built** (still correct future scope per the phases below, not an oversight): `rival_vacuum.tscn`/`.gd` skin split, `hud.tscn`/`ui/` scenes, `spawner.gd` for obstacles, `game_manager.gd`, `economy.gd`, `save.gd`, `difficulty.gd`, `audio_manager.gd`, and any autoload singleton at all. Meter, zoomies, hit-flash, and debug-label state currently all live directly on `player.gd`, and `rival_base.gd` reaches `player.gd` via duck-typed `has_method(...)` checks rather than through a shared manager — a deliberate Phase-1 simplification (§13's "build milestone-by-milestone" instruction). `GameManager` is real Phase 3 scope (§8, §10).

---

## 3. Tuning Resource (single source of truth)

Every gameplay number lives in one `@export`-ed custom Resource so it can be tweaked live and A/B'd without touching code. **As actually built** (`scripts/tuning.gd`) — script defaults below; `resources/tuning.tres` overrides a handful on top (noted inline), so always check both when reasoning about live feel:

```gdscript
class_name Tuning extends Resource
# Movement
@export var run_speed := 6.0            # start speed, u/s
@export var run_speed_max := 10.0       # ramp target, u/s
@export var run_speed_ramp_s := 45.0    # real seconds to reach run_speed_max
@export var gravity := 28.0             # OVERRIDDEN to 80.0 in tuning.tres — snappier feel
@export var hop_impulse := 9.0          # OVERRIDDEN to 20.0 in tuning.tres
# Input
@export var bark_threshold_ms := 150    # tap vs hold boundary — LOAD-BEARING
@export var bark_full_charge_ms := 400
@export var bark_cooldown_s := 0.85
@export var bark_range_units := 2.5     # 2–3 dog lengths
@export var bark_hitbox_duration_s := 1.0  # widened from an original 0.3 across several
                                            # 1.6-playtest rounds — see handoff.md §2b
@export var projectile_speed := 8.0
# Zoomies
@export var zoomie_duration_s := 4.0
@export var zoomie_speed_mult := 2.25
@export var zoomie_nudge_impulse := 4.0 # tap steering during zoomies
@export var chomp_window_s := 1.5
# Meter
@export var meter_max := 100.0
@export var treat_meter_value := 8.0
@export var deflect_hit_meter_value := 20.0  # deflects feed meter (stun/meter sync fix)
# Rival
@export var rival_target_distance := 11.0   # raised from an original 6.0 — playtest wanted
                                             # more room/reaction time
@export var rival_distance_variation := 0.75
@export var rival_rubber_band_k := 2.0
@export var rival_max_adjust := 3.0
@export var throw_interval_min_s := 3.0
@export var throw_interval_max_s := 4.0
@export var throw_telegraph_s := 0.65
@export var stun_duration_s := 2.5
# Economy (Phase 3 — not yet consumed by any built system)
@export var revive_cost_treats := 50
```

Unit convention: 1 unit = 64 px (`PX_PER_UNIT` in `player.gd`) at base resolution.

---

## 4. Input State Machine (the heart of the game)

Isolated in `input_controller.gd`, emitting signals consumed by the player. No gameplay logic inside — pure input interpretation, so it can be tested headlessly.

### 4.1 States & transitions

```
IDLE
 └─ touch_down → TIMING (record t0)
TIMING
 ├─ touch_up  &&  (now - t0) < bark_threshold_ms  → emit hop_requested → IDLE
 └─ (now - t0) >= bark_threshold_ms               → emit charge_started → CHARGING
CHARGING
 └─ touch_up:
      charge = now - t0
      if charge >= bark_full_charge_ms → emit bark_released(full=true)   # BLAST
      else                             → emit bark_released(full=false)  # whimper
      → COOLDOWN
COOLDOWN
 └─ after bark_cooldown_s → IDLE      # touches during cooldown: hop still allowed,
                                      # charging not (tune in playtest)
ZOOMIES MODE (flag set by GameManager)
 ├─ touch_up (any duration) → emit zoomie_nudge_requested
 └─ charging disabled entirely (dog too excited to bark)
```

### 4.2 Rules
- Timing uses `Time.get_ticks_msec()` deltas, never frame counts.
- While CHARGING: player keeps full horizontal momentum and vertical arc (mid-air charge is mandatory); sprite squashes as the charge cue.
- Signals: `hop_requested`, `charge_started`, `bark_released(full: bool)`, `zoomie_nudge_requested`.
- **Debug overlay (Phase 1 requirement):** HUD label mirrors the live state (HOP / CHARGING / BLAST / WHIMPER) so input misreads are visible during phone testing. Tuning target: zero intended-hops read as whimpers.

---

## 5. Player (`player.gd`, CharacterBody2D)

**As actually built, this is a vertical-orientation architecture, not the horizontal auto-runner originally specced above §1–4.** Partway through Milestone 1.6 playtesting the game was converted to a portrait, single-lane, auto-climbing runner at the user's direction (full narrative: `handoff.md` §2c). The player node does not physically traverse the world at all:

- The player is pinned at a fixed screen position, `(FIXED_X=360.0, BASELINE_Y=1000.0)` minus a local `hop_offset` — no `move_and_slide()`, no `is_on_floor()`, no literal floor body. `distance_traveled` is the single "how far into the run" clock, advanced every `_physics_process` by the current scroll speed.
- Every other entity (rival, projectile, treat, obstacle) is stationary in its own fixed `progress`/`target_progress` coordinate and renders each frame via `player.get_track_y(progress) -> float: return BASELINE_Y - (progress - distance_traveled)` — so visually, the world scrolls top-to-bottom toward the dog rather than the dog running through the world.
- Hop physics: `hop_requested` sets `hop_velocity = tuning.hop_impulse * PX_PER_UNIT` if grounded (`hop_offset <= 0 and hop_velocity == 0`); each tick applies gravity to `hop_velocity` then integrates into `hop_offset`, clamped at 0 on landing. Gravity is asymmetric — `HOP_RISE_GRAVITY_MULT=0.8` while rising, `HOP_FALL_GRAVITY_MULT=1.6` while falling — a deliberate feel fix (floats a beat longer near the apex, drops fast at the bottom) over an earlier symmetric-parabola version that read as an abrupt "snap."
- Hop-vs-obstacle/treat clearance is **not** real Area2D shape-overlap physics. `is_hop_clearing() -> bool: return hop_offset > HOP_CLEARANCE_MIN_PX` (20px) is checked once, by the obstacle/treat itself, at the exact physics frame `distance_traveled` crosses its fixed progress value — see §6/§9 and `handoff.md` §2c for why real overlap testing was abandoned (essentially unlandable against a fast-scrolling target).
- Camera2D and the Shadow ColorRect are both children of the player and cancel the parent's `hop_offset`-driven Y movement in local space (`local_position.y = hop_offset - CAMERA_Y_OFFSET_PX` / `= hop_offset`), so the camera stays pinned at a fixed world Y and the shadow stays pinned at ground level while only the Visual sprite appears to rise — plus a lift-scale (`HOP_VISUAL_LIFT_SCALE`) and shadow fade as a pseudo-3D cue.
- `bark_released(full=true)` → enable forward bark hitbox (Area2D, `bark_range_units` long) for `bark_hitbox_duration_s`; play blast VFX/SFX; start cooldown. `full=false` → whimper puff VFX/SFX only.
- Zoomies: invincible flag (`is_invincible()`), speed multiplier, obstacle-destroy on contact (`queue_free()` on an obstacle it crosses while invincible), `zoomie_nudge_requested` → small hop-style impulse (steering).
- Contact with projectile/obstacle when not invincible → placeholder feedback only (`on_projectile_hit()` / `on_obstacle_hit()`, a red flash + debug label). **No death/consequence mechanic exists yet** — that's real `GameManager` scope (§8), deliberately deferred past Milestone 1.6.

---

## 6. Projectile (`projectile.gd`, pooled)

Uses the same fixed-`_progress` + `get_track_y()` render pattern as every other entity (§5) rather than literal X/Y velocity — the rival throws it at a `_progress` ahead of the dog, and it moves by advancing `_progress` (via `_progress_velocity`) each tick, same as `distance_traveled` does for the player.

- Spawned by rival: `_progress` starts at the rival's position, `_progress_velocity` set toward the dog at `tuning.projectile_speed`.
- On overlap with active bark hitbox → **deflect**: reverses `_progress_velocity` and retargets it to `max(original_return_speed, player.get_speed_px_s() + DEFLECT_RETURN_MARGIN_PX_S)` where `DEFLECT_RETURN_MARGIN_PX_S := 320.0`. This margin fix was load-bearing: a flat return speed let the rival's chase speed (which ramps with the run) outrun and permanently evade an already-deflected projectile for most of a run — see `handoff.md` §2c for the full bug writeup.
- Deflected projectile crossing the rival's progress → `rival.on_deflect_hit()` + `player.add_meter(tuning.deflect_hit_meter_value)`.
- Hitting the player (progress crosses the player's line, not deflected, player not invincible) → `player.on_projectile_hit()` (placeholder flash, no consequence yet).
- Past the player and off the bottom of the screen → return to pool. Pool everything: projectiles, treats (obstacles are a single non-pooled instance, §9).

---

## 7. Rival AI (`rival_base.gd` — the monster template)

Built as a base class so guest monsters are pure skins later: override sprites, SFX, projectile art, and reaction animations only.

### 7.1 States
```
CHASING   # default: hold ~target_distance ahead with soft rubber-banding + noise
THROWING  # telegraph (turn/wind-up anim) → spawn projectile → back to CHASING
STUNNED   # entered via on_deflect_hit(); sparks, holds/slows; timer = stun_duration_s
CAUGHT    # chomped during zoomies: defeat anim (dust-bag burst), big treat payout,
          # despawn → respawn ahead at target_distance + margin
REACT     # brief interrupt layer for non-stun hits: flatten/spin/knockback
```

### 7.2 Chase math (per physics tick)

**As actually built**, this is progress-space, not X-space (§5's vertical-orientation architecture) — the rival holds a lead in `distance_traveled` units, not a literal screen-X gap:
```
desired_progress = player.distance_traveled + rival_target_distance * PX_PER_UNIT + noise(t)
error             = desired_progress - self._progress
progress_velocity = player.get_speed_px_s() + clamp(error * rival_rubber_band_k, -rival_max_adjust * PX_PER_UNIT, +rival_max_adjust * PX_PER_UNIT)
```
`rival_target_distance` is currently tuned to 11.0 units (raised from an original 6.0 — playtest wanted more room/reaction time). Never hard-locked — `rival_rubber_band_k` and `rival_max_adjust` are tuned so the vacuum feels alive, drifting within `rival_distance_variation` (±0.75 units) of the target.

All five states below (CHASING/THROWING/STUNNED/CAUGHT/REACT) are implemented in `rival_base.gd` and confirmed working on-device as of Milestone 1.5.

### 7.3 Throwing
- Timer: uniform random in `[throw_interval_min_s, throw_interval_max_s]`, re-rolled each throw (anti-memorization).
- Mandatory telegraph animation before spawn (readability — attacks must never be cheap).

### 7.4 Stun/chomp interaction
- `on_deflect_hit()` → REACT (ragdoll/knockback + screen shake via GameManager) → STUNNED.
- If player is in zoomies and overlaps rival while STUNNED → `CAUGHT` → emit `chomped` → GameManager pays out treats, respawns rival.
- If STUNNED expires or zoomies ends → recover to CHASING (escape animation).
- Known tuning risk (from GDD §7.3): if chomps are too rare, first lengthen `stun_duration_s`; deflect-hits already feed the meter by design.

---

## 8. GameManager (autoload)

**Not yet built — real Phase 3 scope, consistent with §2's file-tree note.** There is no autoload of any kind in the project today. Everything this section describes (meter, zoomies, hit-flash, run lifecycle) currently lives directly on `player.gd` as plain methods (`add_meter()`, `on_treat_collected()`, `on_projectile_hit()`, etc.), and `rival_base.gd` reaches the player through duck-typed `has_method(...)` checks rather than a shared manager — a deliberate Phase-1 simplification per §13. The design below is the intended future shape once run lifecycle (death, revive, results) becomes real.

Owns run state, never scene-specific logic.

- Run lifecycle: `READY → RUNNING → (HIT → REVIVE_OFFER → RUNNING | GAME_OVER) → RESULTS`.
- Distance score = player X traveled; treat count (in-run); Zoomie meter (add/spend/full → trigger zoomies with duration timer).
- **Revive flow is a first-class state:** on hit → freeze (pause tree except UI) → revive screen (sad dog, "Give a Treat to Revive": [Watch Ad placeholder] / [50 treats] / [No]) → on accept: clear nearby hazards, brief invincibility, resume seamlessly. Once per run. In Phases 1–3 the ad button simply succeeds; the real SDK replaces the stub in Phase 4 behind the same interface (`AdService.show_rewarded(slot, on_success)`).
- On run end: bank in-run treats to `Save` wallet; show results (distance, treats, [Double Treats — ad stub]).
- Screen shake + hit-stop service (single implementation, called by everyone).
- Difficulty: queries `difficulty.gd` for current speed multiplier / throw-interval scaling as a function of distance; curves tuned so average death lands at 60–120 s.

---

## 9. Spawning & World

**As actually built** (not the originally-planned endless-world spawner below, which is still correct future scope — see the gaps noted per item):

- **Obstacle:** a single fixed-`target_progress` instance placed in `main.tscn` (`obstacle.gd`, `target_progress = 1500.0`) — Phase-1 scope matches the pre-migration game, which also only ever had one placed instance. No `spawner.gd`, no pooling, no fairness/spacing logic yet.
- **Treats:** `treat_spawner.gd`, a plain interval spawner (`POOL_SIZE=6`, `SPAWN_INTERVAL_S=1.5`, spawns 500px ahead of the player each interval) — enough to exercise meter-fill → Zoomies → Chomp, not the difficulty-ramp-aware placement/hop-teaching arcs described in the original plan.
- **Visual scroll cue:** `lane_scroll.gd` — a small fixed ring of recycling stripe bars rendered via the same `get_track_y()`/`distance_traveled` clock every other entity uses, standing in for a real ground texture/parallax layer (placeholder art, Phase 1).
- **Camera:** a child of the player (§5), pinned to a fixed world-Y anchor (`CAMERA_Y_OFFSET_PX`) that cancels the player's own hop bob — not a follow-camera, since the player never moves in world space; the world scrolls to it instead.
- **Not yet built:** real endless-world recycling for obstacles, fairness guarantees (min gap ≥ hop reach, no obstacle inside an unavoidable throw path), parallax layers, and any obstacle spawner at all.

---

## 10. Economy & Save (Phase 3)

- `save.gd`: JSON at `user://save.json` — wallet, owned/equipped costume, best distance, daily-streak data, settings, `interstitials_removed`, session count. Write on run end + purchase; load on boot; corrupt file → reset to defaults (never crash).
- `economy.gd`: costume catalog as Resources (`id, name, price, sprite_frames, bark_sfx, victory_anim`); buy/equip; earn-rate anchor: first cheap costume ≈ 10–15 average runs (validate against real telemetry from playtests, adjust prices not earn rate).
- Meter and wallet are separate values fed by the same pickups (GDD §10.1) — never let spending touch in-run resources.
- Shop preview: instantiate the player scene in-UI wearing the selected costume, playing idle + bark.

## 11. Ads & IAP (Phase 4 — interfaces only until then)

- `AdService` interface from day one; stub implementation auto-succeeds. Real implementation: one mediation SDK (AdMob first), rewarded slots per GDD §10.4; interstitial policy (≥ every 3rd–4th death, suppressed first 5–10 sessions, never after a personal best) enforced in `GameManager`, not in the ad layer.
- IAP via Google Play Billing: treat packs ×3, boosters (2× treats, magnet), Remove Ads (interstitials only — rewarded slots remain for everyone).
- Consent (UMP/GDPR) on first boot before any ad init; Play data-safety + content rating handled in Phase 4 checklist.

## 12. Performance Budget (mobile)

- 60 FPS on a low-end test device (not your flagship).
- Object pools for projectiles/treats/particles; no per-frame allocations in hot paths; no `get_node()` in `_physics_process` (cache with `@onready`).
- Texture atlases for sprites; compressed audio (OGG); single `AudioStreamPlayer` pool.
- Profile with Godot's monitor on-device at the end of every phase.

## 13. Testing & Agent Workflow

- `input_controller.gd` gets headless unit tests (GUT or plain script tests): threshold boundaries (149/150/151 ms; 399/400 ms), zoomies-mode remapping, cooldown behavior.
- Every milestone (per Project Plan) ends with: build → deploy to physical Android device → human plays → feel-notes fed back as the next prompt. The agent implements; the human is the tuning instrument.
- Definition of done for any gameplay task: runs at 60 FPS on device, debug state overlay shows no input misreads, and the relevant Project Plan milestone test question is answered by a human, not asserted by the agent.
- Commit per milestone minimum; tuning.tres changes committed separately from code so feel-tuning history is readable.
