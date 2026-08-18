# Technical Design Document — "Bark & Chomp"

Version 1.0 · Godot 4.x / GDScript 2.0 · Companion docs: GDD, Project Plan

Purpose: the build spec. Written to be dropped into the repo (alongside the GDD) as context for Claude Code or any coding agent. Work milestone-by-milestone per the Project Plan — never generate the whole game in one pass; every milestone ends with a human playtest on a physical Android device.

---

## 1. Engine & Project Settings

- **Godot 4.x, GDScript 2.0.** (Agents: do not emit Godot 3 syntax — `onready` → `@onready`, `export` → `@export`, `yield` → `await`, signals use `signal_name.emit()` / `.connect(callable)`.)
- Renderer: Mobile. Target 60 FPS.
- Orientation: portrait. Base resolution 720×1280, stretch mode `canvas_items`, aspect `expand`.
- Physics tick: 60. All gameplay-critical motion in `_physics_process`.
- Input: touch only in production; mouse-emulates-touch ON for editor testing. **All timing thresholds must be tuned against a physical device**, not the editor.
- Android export configured in Phase 0; keystore + export template verified before any gameplay code.

---

## 2. Project Structure

```
res://
  scenes/
    main.tscn            # Game scene: world, player, rival, spawners, HUD
    player.tscn          # CharacterBody2D + sprite + collision + bark hitbox (Area2D)
    rival_vacuum.tscn    # CharacterBody2D (inherits rival_base behavior)
    projectile.tscn      # Area2D or RigidBody2D (pooled)
    treat.tscn           # Area2D (pooled)
    obstacle.tscn        # StaticBody2D
    hud.tscn             # Meter, distance, treat count, debug state label
    ui/                  # title, death/revive, shop (Phase 3), pause, settings
  scripts/
    player.gd
    input_controller.gd  # The tap/hold state machine — isolated & unit-testable
    rival_base.gd        # Template AI (chase/throw/stun/react) — skins extend this
    rival_vacuum.gd
    projectile.gd
    treat.gd
    spawner.gd           # Obstacles + treats, difficulty-ramp-aware
    game_manager.gd      # Autoload: run state, score, meter, zoomies, revive
    economy.gd           # Autoload (Phase 3): wallet, costumes, prices
    save.gd              # Autoload: local save (user://save.json)
    difficulty.gd        # Ramp curves (speed, throw frequency vs. distance)
    audio_manager.gd     # Autoload: pooled SFX players
  resources/
    tuning.tres          # ALL gameplay numbers as a custom Resource (see §3)
    costumes/            # Phase 3: costume resource defs
  assets/               # sprites, audio (placeholders in Phase 1)
```

Autoload singletons: `GameManager`, `Save`, `AudioManager` (+ `Economy` from Phase 3).

---

## 3. Tuning Resource (single source of truth)

Every gameplay number lives in one `@export`-ed custom Resource so it can be tweaked live and A/B'd without touching code. Initial values (from GDD; feel > numbers):

```gdscript
class_name Tuning extends Resource
# Movement
@export var run_speed := 6.0            # 5–7 u/s
@export var gravity := 28.0             # 25–30 u/s^2
@export var hop_impulse := 9.0          # 8–10 u/s
# Input
@export var bark_threshold_ms := 150    # tap vs hold boundary — LOAD-BEARING
@export var bark_full_charge_ms := 400
@export var bark_cooldown_s := 0.85     # 0.7–1.0
@export var bark_range_units := 2.5     # 2–3 dog lengths
# Zoomies
@export var zoomie_duration_s := 4.0
@export var zoomie_speed_mult := 2.25   # 2–2.5x
@export var zoomie_nudge_impulse := 4.0 # tap steering during zoomies
@export var chomp_window_s := 1.5
# Meter
@export var meter_max := 100.0
@export var treat_meter_value := 8.0
@export var deflect_hit_meter_value := 20.0  # deflects feed meter (stun/meter sync fix)
# Rival
@export var rival_target_distance := 6.0
@export var rival_distance_variation := 0.75  # ±0.5–1.0
@export var throw_interval_min_s := 3.0
@export var throw_interval_max_s := 4.0
@export var stun_duration_s := 2.5      # tune upward if chomps too rare
# Economy (Phase 3)
@export var revive_cost_treats := 50
```

Unit convention: 1 unit = 64 px at base resolution (adjust in prototype if it feels wrong; keep ONE conversion constant).

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

Movement states: `RUNNING → HOPPING → FALLING` (+ `ZOOMIES` as a modifier flag, not a separate movement system; + `DEAD`).

- `_physics_process`: constant `run_speed` (× zoomie multiplier when active) on X; gravity on Y; `move_and_slide()`.
- `hop_requested` → if on floor: `velocity.y = -hop_impulse` (units→px). No double jump in MVP.
- `bark_released(full=true)` → enable forward bark hitbox (Area2D, `bark_range_units` long) for a few frames; play blast VFX/SFX; start cooldown. `full=false` → whimper puff VFX/SFX only.
- Zoomies: invincible flag, speed multiplier, obstacle-destroy on contact, `zoomie_nudge_requested` → small upward impulse (steering).
- Contact with projectile/obstacle when not invincible → `GameManager.on_player_hit()`.

---

## 6. Projectile (`projectile.gd`, pooled)

- Spawned by rival: velocity toward the dog (negative X), slight arc allowed for readability.
- On overlap with active bark hitbox → **deflect**: `velocity.x *= -1` (plus small speed bonus for crispness), retag `deflected = true`, flip sprite.
- Deflected projectile overlapping rival → `rival.on_deflect_hit()` + `GameManager.add_meter(deflect_hit_meter_value)`.
- Hitting the player (not deflected, player not invincible) → player hit.
- Off-screen → return to pool. Pool everything: projectiles, treats, particles (mobile GC hygiene).

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
```
desired_x = player.x + target_distance + noise(t)     # noise: ±distance_variation, slow sine/perlin
error     = desired_x - self.x
velocity.x = player_run_speed + clamp(error * k, -max_adjust, +max_adjust)
```
Never hard-lock position — the rubber-band constant `k` and `max_adjust` are tuned so the vacuum feels alive, drifting within ±0.5–1.0 units.

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

Owns run state, never scene-specific logic.

- Run lifecycle: `READY → RUNNING → (HIT → REVIVE_OFFER → RUNNING | GAME_OVER) → RESULTS`.
- Distance score = player X traveled; treat count (in-run); Zoomie meter (add/spend/full → trigger zoomies with duration timer).
- **Revive flow is a first-class state:** on hit → freeze (pause tree except UI) → revive screen (sad dog, "Give a Treat to Revive": [Watch Ad placeholder] / [50 treats] / [No]) → on accept: clear nearby hazards, brief invincibility, resume seamlessly. Once per run. In Phases 1–3 the ad button simply succeeds; the real SDK replaces the stub in Phase 4 behind the same interface (`AdService.show_rewarded(slot, on_success)`).
- On run end: bank in-run treats to `Save` wallet; show results (distance, treats, [Double Treats — ad stub]).
- Screen shake + hit-stop service (single implementation, called by everyone).
- Difficulty: queries `difficulty.gd` for current speed multiplier / throw-interval scaling as a function of distance; curves tuned so average death lands at 60–120 s.

---

## 9. Spawning & World

- Endless world via ground segments recycled ahead of the camera; parallax layers (2–3) in vertical slice.
- `spawner.gd`: obstacle + treat placement ahead of player; guarantees fairness (min gap after obstacles ≥ hop reach; no obstacle inside a throw's unavoidable path). Treat lines/arcs placed to teach hop trajectories.
- Camera: follows player X with slight lead; Y fixed or gently smoothed.

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
