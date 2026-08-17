# Handoff — "Bark & Chomp"

Last updated: 2026-08-18 (session 4)

Purpose: read this first at the start of a new session to pick up exactly where things left off. It is a living doc — update it at the end of each session.

---

## 1. What this project is

A casual, ad-funded Android endless runner built in **Godot 4.x / GDScript 2.0**: a chaotic shih tzu chases a sentient vacuum cleaner to get its stolen treats back, hopping over obstacles and deflecting flying household objects with timed bark blasts, then CHOMPing the vacuum during a "Zoomies" burst.

Full specs live in three companion docs in this repo — read them in this order:
1. `bark_and_chomp_project_plan.md` — phased build plan, milestones, gates, timeline, risks.
2. `game_design_document.md` — mechanics, characters, economy, monetization, feel.
3. `technical_design_document.md` — Godot project structure, scripts, node layout, build spec for coding agents.

**Locked guiding principles** (do not relitigate these without the user):
- One dog, forever. Depth via costumes, not new characters/breeds.
- The vacuum wants to *clean* the treats, not hurt the dog — all its behavior flows from that.
- Two inputs only: tap = hop, hold = bark. All skill expression is timing.
- Runs are short (60–120s); nothing from the backlog gets built until the core loop is proven fun on a real phone.
- Every design question answerable by playtesting gets playtested, not debated.

---

## 2. Where things stand right now

**Phase: 0 — Setup, transitioning into Phase 1 Milestone 1.1** (per `bark_and_chomp_project_plan.md`).

Done so far:
- [x] Three design docs written and finalized (project plan, GDD, TDD).
- [x] Local git repo initialized at `D:\AI\Business\claud\Bark and Chomp`.
- [x] `.gitignore` added (Godot 4 defaults: `.godot/`, `.import/`, export configs, editor/OS cruft).
- [x] Remote added and pushed: **https://github.com/amritanshu1992/bark-and-chomp** (branch `main`, tracking `origin/main`).
- [x] `handoff.md` + `CLAUDE.md` added for session continuity.
- [x] Godot 4.7.1 confirmed already installed at `C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64.exe` (found by scanning C:\ and D:\, not on PATH).
- [x] Godot project created (`project.godot`): landscape, 1280×720 base resolution, `canvas_items` stretch/`expand` aspect, Mobile renderer, 60 physics ticks, touch-emulate-from-mouse on. Matches TDD §1 exactly.
- [x] **Milestone 1.1 (Movement) implemented**: auto-run, gravity, tap-to-hop, floor, one static obstacle.
  - `scripts/tuning.gd` + `resources/tuning.tres` — the single-source-of-truth `Tuning` resource (TDD §3), all values as specified.
  - `scripts/input_controller.gd` — full tap/hold state machine (TDD §4: IDLE/TIMING/CHARGING/COOLDOWN, 150ms threshold, signals `hop_requested`/`charge_started`/`bark_released`/`zoomie_nudge_requested`). Built in full now since the 150ms threshold is already part of 1.1's test criteria, but only `hop_requested` is wired up yet — bark/charge handling is deferred to Milestone 1.2.
  - `scripts/player.gd` + `scenes/player.tscn` — CharacterBody2D, CapsuleShape2D collider (literal "ugly capsule"), white ColorRect placeholder visual, child Camera2D, child InputController.
  - `scenes/obstacle.tscn` — StaticBody2D placeholder block.
  - `scenes/main.tscn` — long static ground, player, one obstacle placed ~1.8s of run-time ahead.
  - Verified with Godot headless (`--headless --editor --quit` to build the script-class cache, then `--headless --quit-after 30`): loads and runs with **zero script/scene errors**.
- [x] Committed to git and pushed.

**Android SDK / device / export pipeline: fully working end-to-end as of this session.**
- Android SDK + Android Studio turned out to already be installed at `C:\Users\amrit\AppData\Local\Android\Sdk` (Platform-Tools, platforms 34/35, build-tools 34.0.0/35.0.0).
- JDK: OpenJDK 25 (Temurin) at `C:\Program Files\Eclipse Adoptium\jdk-25.0.4.7-hotspot`, well above the 17+ requirement. `java_sdk_path` set explicitly in Godot's editor settings (`%APPDATA%\Godot\editor_settings-4.7.tres`) since `JAVA_HOME` env var isn't set globally.
- Test device: **Samsung Galaxy S24 Ultra (SM-S928B)**, USB debugging enabled and authorized, confirmed via `adb devices` (adb id `RZCX115BPWY`). Per TDD §1 this is the required real-device test target — do not substitute an emulator/AVD for timing-sensitive testing.
- Godot 4.7.1 export templates (~1.19GB) downloaded manually by the user from GitHub releases (`Godot_v4.7.1-stable_export_templates.tpz`) and extracted into `%APPDATA%\Godot\export_templates\4.7.1.stable\`. (Note: an automated `Invoke-WebRequest`/`curl` download was also attempted and abandoned as slower/redundant — the manual download is what's actually in place.)
- Debug keystore generated via `keytool` at `%APPDATA%\Godot\keystores\debug.keystore` (standard `androiddebugkey`/`android` debug credentials, referenced automatically by Godot's global Android export settings — the project's `export_presets.cfg` leaves `keystore/debug` blank on purpose so it always falls back to this machine-level default).
- `export_presets.cfg` added to the repo (Android preset, `use_gradle_build=false` — i.e. the simpler precompiled-template export path, not a custom Gradle build; `arm64-v8a` only, since that's what the test phone needs; package id `com.barkandchomp.game`). **This file is now tracked in git**, not ignored — it's just config, no secrets (the actual keystore lives outside the repo on each dev machine).
- Had to add `textures/vram_compression/import_etc2_astc=true` to `project.godot` — Android export refuses to build without ETC2/ASTC compression enabled.
- **Full pipeline verified working:** `Godot_..._console.exe --headless --export-debug "Android" builds/android/bark_and_chomp.apk` builds and signs cleanly → `adb install -r` → `adb shell monkey -p com.barkandchomp.game -c android.intent.category.LAUNCHER 1` launches it. (Direct `adb shell am start` with a guessed activity class name failed twice — Godot's actual launcher activity class wasn't obvious from outside; `monkey` sidesteps needing to know it.)
- `builds/` (the APK output dir) is gitignored — regenerate with the command above, don't commit binaries.

**Milestone 1.1 on-device debugging journey (this is the real story — earlier drafts of this doc claimed first-try success, which was wrong):**
1. First playtest: hop did not respond to tap at all. Root cause: `player.gd`'s `_physics_process` unconditionally zeroed `velocity.y` whenever `is_on_floor()` was true — but `is_on_floor()` is a cached value only refreshed by `move_and_slide()`, so the physics frame right after a hop request would still see stale "grounded" state and wipe out the just-applied jump velocity before it took effect. **Fix**: only zero `velocity.y` when on floor AND `velocity.y >= 0.0` (don't clobber an active jump). This is the current code in `player.gd`.
2. Second playtest: hop worked once, then the capsule got permanently stuck against the red obstacle and stopped responding to taps entirely. Root cause: `hop_impulse=9.0` (TDD §3 default) only gives ~93px of rise, but the placeholder obstacle is 96px tall — the capsule hit the obstacle's *side* wall mid-air instead of clearing it, got pinned there, and since wall contact ≠ floor contact, `is_on_floor()` never became true again, permanently blocking all future hops via the `_on_hop_requested()` guard. **Fix**: added `hop_impulse = 12.0` override in `resources/tuning.tres` (apex ≈164px, ~1.7x the obstacle height for margin). Correct fix location per TDD's tuning-as-data principle — the script default in `tuning.gd` was left untouched; only the `.tres` instance got the override.
3. Third playtest (after fix #2): capsule cleared the obstacle correctly, but tapping over the green floor area did nothing while tapping elsewhere hopped fine. Root cause: `ColorRect` extends `Control`, not just a 2D visual — the `Ground/Visual`, `Player/Visual`, and `Obstacle/Visual` placeholder ColorRects all had the default `mouse_filter = STOP`, so any touch landing within their (large) rectangles was consumed as a GUI input event before it ever reached `InputController._unhandled_input()`. The Ground ColorRect alone covered most of the lower half of the screen. **Fix**: added `mouse_filter = 2` (MOUSE_FILTER_IGNORE) to all three placeholder ColorRects in `main.tscn`, `player.tscn`, `obstacle.tscn`.
4. Fourth playtest (after fix #3): **user confirmed "yes its working"** — taps register everywhere including over the floor, hop responds reliably on repeated taps, capsule clears the obstacle. This is the first genuinely verified pass of Milestone 1.1's core mechanic.
5. Added a **Restart button** (top-right corner, screen-space `CanvasLayer`/`Button`, wired to `scripts/main.gd` → `get_tree().reload_current_scene()`) purely as a testing convenience, so retries don't require a reinstall. Confirmed working on-device.

**Milestone 1.1 status: core mechanic (auto-run, gravity, tap-to-hop, obstacle clearance, input responsiveness) is confirmed working on the physical device.**

Still open, but not blocking progression to 1.2:
- [ ] Fine feel-tuning pass (project plan's exact test question: "does hopping over a block feel floaty, predictable, responsive?" — current values work correctly but haven't been deliberately tuned for *feel*, and the 150ms tap/hold threshold hasn't been stress-tested against real touchscreen latency). Can be revisited any time; not a hard gate.
- [ ] No custom app icon set yet (cosmetic `ERROR: No project icon specified` warning during export, harmless, default Android icon used) — irrelevant until Phase 2 art pass, not worth fixing now.

**Lesson for future sessions**: don't mark a milestone "confirmed working" from a single playtest report or an `AskUserQuestion` answer given before the actual test happened — three real bugs surfaced across four playtest iterations here. Wait for an explicit, specific confirmation after the fix is deployed.

**Milestone 1.2 — Bark input state machine: done, confirmed on-device.**
- `input_controller.gd`'s tap/hold state machine was already fully built in Milestone 1.1 (IDLE/TIMING/CHARGING/COOLDOWN, 150ms/400ms thresholds); this milestone wired its `charge_started`/`bark_released(full)` signals into `player.gd` for the first time, plus `hop_requested` now also drives the debug label.
- `player.gd`: on `charge_started` the capsule visual squashes (`scale = Vector2(1.3, 0.65)`, pivot centered via `pivot_offset` on the `Visual` ColorRect so it doesn't drift); on `bark_released` it flashes orange "BLAST" (full charge ≥400ms) or grey "WHIMPER" (released 150–400ms) for 0.4s via `modulate`, then reverts to white. `hop_requested` flashes "HOP" the same way.
- Added a `UI`/`DebugLabel` (`CanvasLayer` + `Label`, yellow text w/ black outline, top-left) inside `player.tscn` itself — self-contained per-player debug overlay, per TDD §4.2/§13's "debug state overlay shows no input misreads" requirement.
- No bark hitbox / projectile deflect logic yet — that's explicitly Milestone 1.3 scope (TDD §6), not touched here. This milestone is pure input-feedback plumbing.
- **User confirmed on real device**: quick taps hop cleanly with zero accidental whimpers, and CHARGING/BLAST/WHIMPER all displayed distinctly and correctly. This satisfies the project plan's exact 1.2 test question ("zero accidental whimpers when the player intended a hop").

**Milestone 1.3 — Projectile + deflect: done, confirmed on-device.**
- `scripts/projectile.gd` + `scenes/projectile.tscn`: pooled `Area2D` projectile (black `ColorRect` square), constant horizontal velocity toward the player, 5s max-lifetime auto-despawn (decoupled from world coordinates — simpler and more robust than an x-position bounds check for a prototype-phase test rig).
- `scripts/projectile_spawner.gd`: **test-only** timer spawner (every 2.5s, pool of 4, spawns 700px ahead of the player) since there's no rival yet — explicitly commented as a stand-in to be replaced by `rival_base.gd`'s THROWING state in Milestone 1.4. Don't build this out further.
- `player.gd`/`player.tscn`: added a `BarkHitbox` `Area2D` child, sized from `tuning.bark_range_units` at runtime (keeps tuning-as-data intact), positioned forward of the player. Activated only during the brief window after a full BLAST release (`tuning.bark_hitbox_duration_s = 0.15`, "a few frames" per TDD §4.2).
- Collision layers introduced (previously everything was default layer/mask 1): `world=1` (Ground/Obstacle, untouched), `player=2`, `projectile=4`, `bark_hitbox=8`. Player's `collision_mask` was left untouched (still `1`) so its physical collision with Ground/Obstacle via `move_and_slide()` was never at risk — only `collision_layer` was added.
- **Real bug hit and fixed**: first deploy had projectiles auto-deflecting on every pass regardless of whether the player had barked at all ("two squares... automatically reversing and not hitting"). Root cause: toggled `bark_hitbox.monitoring` on/off to gate the hitbox window, but **`monitoring` controls whether an Area2D scans others — whether an Area2D *can be detected by* others is the separate `monitorable` property**, which defaulted to `true` and was never touched, so the hitbox was always detectable regardless of the charge state. Fix: toggle `bark_hitbox.monitorable` instead (`player.gd::_activate_bark_hitbox`), and set `monitorable = false` as its default state in `player.tscn`. **Remember this distinction for any future Area2D-based mechanic** (rival stun detection in 1.4, Zoomies obstacle-destroy in 1.5) — it's an easy trap since both properties sound like the same thing.
- `on_projectile_hit()` on `player.gd` is a deliberately thin placeholder (red "HIT" flash only) — real hit consequences (revive flow, `GameManager.on_player_hit()`) don't exist yet and shouldn't be built prematurely; this just makes misses visible during playtesting per TDD §13's "definition of done" (debug state overlay shows no input misreads).
- **User confirmed on real device**: deflect works correctly (bark hitbox only active during the intended window, projectile turns orange and reverses only on genuine overlap, red "HIT" flash shows correctly on a miss) and **feels crisp and instantaneous** — satisfies the project plan's exact 1.3 test question.

**Milestone 1.4 — Vacuum AI: done, confirmed on-device.**
- `scripts/rival_base.gd` (new, `class_name RivalBase extends Area2D`) + `scenes/rival.tscn`: placeholder vacuum, built as a base class per TDD §7 so guest monsters can later be pure reskins. States implemented: `CHASING` (rubber-band chase math per TDD §7.2, `desired_x = player.x + rival_target_distance + noise`, correction clamped by `rival_max_adjust`), `THROWING` (telegraph → spawn via its own pooled projectile → back to `CHASING`), `REACT`/`STUNNED` (entered via `on_deflect_hit()`), `CAUGHT` reserved in the enum but not wired — that's Milestone 1.5 (Zoomies/Chomp).
- Replaced Milestone 1.3's test-only `projectile_spawner.gd` (deleted) with the rival owning its own pooled throw timer, as planned. `main.tscn`'s `ProjectileSpawner` node swapped for a `Rival` instance.
- `projectile.gd`'s `_on_area_entered` now branches on `is_in_group("bark_hitbox")` (existing deflect behavior) vs `is_in_group("rival")` (calls `rival.on_deflect_hit()` then returns to pool). `BarkHitbox` in `player.tscn` and `Rival` in `rival.tscn` both tagged with their respective groups. New collision layer `rival=16`; `projectile.tscn`'s `collision_mask` updated `10 → 26` to add it. Rival's `Area2D` set `monitoring=false, monitorable=true` permanently (always deflect-hittable, no toggling needed — unlike the player's bark hitbox which does need to toggle `monitorable`, per the 1.3 gotcha).
- **Three real bugs surfaced across on-device playtests, all fixed:**
  1. Throw wind-up was too short and too subtle (`throw_telegraph_s=0.35`, plain color tint on a small ColorRect) — shorter than the 400ms full-charge threshold itself, so there was no way to react in time. **Fix**: bumped `throw_telegraph_s` to 0.65 in `tuning.gd`, and made the cue much louder (`rival_base.gd::_start_throw` now flashes bright red *and* scales the visual up to 1.4x, not just a subtle tint). Needed `pivot_offset = Vector2(40, 40)` on `rival.tscn`'s `Visual` ColorRect so the scale-up is centered instead of drifting.
  2. Projectiles spawn from the rival's actual position, which per the project plan's `rival_target_distance=6.0` units is much closer than Milestone 1.3's test-spawner (`SPAWN_AHEAD_PX=700px` vs 6 units×64=384px) — noticeably less flight time/reaction room than what 1.3 was tuned and confirmed against. **Fix**: bumped `rival_target_distance` to 8.5 in `tuning.gd` (deliberate playtest-driven deviation from the plan's "~6 units" — noted here per `CLAUDE.md`'s divergence-tracking instruction). Also updated the `Rival` node's initial spawn offset in `main.tscn` to match.
  3. After a deflect-hit, the vacuum froze completely in world-space for the whole REACT+STUNNED window (~2.8s) while the player kept auto-running — so the player would catch up to and run past the stationary vacuum (read as "it comes at me"), then it would be left behind off the left edge of the camera for several seconds before a slow rubber-band catch-up brought it back. **Fix** (`rival_base.gd::_physics_process`): `STUNNED` now moves the rival forward at the player's base `run_speed` with no active herding/throwing (keeps pace instead of literally freezing — still visually reads as stunned via the grey tint, but doesn't fall behind or get run through). `on_deflect_hit()` also still snaps to the ideal chase distance the instant `STUNNED` ends, as a cheap stand-in for the "escape animation" TDD §7.4 calls for.
- **User confirmed on real device** ("it feels much better" after fix #3, then explicit answer via `AskUserQuestion`): **yes, active nuisance, not a goalpost** — satisfies the project plan's exact 1.4 test question.

---

## 3. What's next (in order)

1. **Immediate next action:** start **Milestone 1.5 — Treats, Zoomie meter, Chomp** (TDD, project plan):
   - Treat pickups (pooled, per TDD §6-style pattern) feeding the Zoomie meter (`meter_max`, `treat_meter_value`); deflect-hits already feed the meter too (`deflect_hit_meter_value`, wired since 1.3/1.4).
   - Zoomies burst: `zoomie_duration_s`, `zoomie_speed_mult`, tap-steering via `zoomie_nudge_impulse` (input controller already emits `zoomie_nudge_requested`, unused until now).
   - CHOMP: preconditions are zoomies active AND rival `STUNNED`; wires up the `CAUGHT` state left reserved-but-unimplemented in `rival_base.gd` since 1.4 — `chomp_window_s` is the steer-and-line-up window (project plan: "~1.5s window to line up → CHOMP").
   - Hit: dust-bag-burst placeholder reaction, treat payout, rival respawns further ahead (reuse the same "snap to ideal chase distance" pattern already used for the post-stun recovery in `rival_base.gd`). Miss: rival just recovers to CHASING, no punishment beyond the lost opportunity (GDD §6).
   - Test question (project plan, §1.5): does landing a CHOMP feel like a payoff worth chasing?
2. Continue Phase 1 ("The Ugly Capsule" prototype) milestone by milestone, exactly as sequenced in `bark_and_chomp_project_plan.md` §PHASE 1:
   - [x] 1.1 Movement — confirmed working on-device (see §2 debugging journey above).
   - [x] 1.2 Bark input state machine — confirmed working on-device (see §2 above): squash cue on charge, BLAST/WHIMPER debug label, zero accidental whimpers on intended hops.
   - [x] 1.3 Projectile + deflect — confirmed working on-device (see §2 above): deflect feels crisp and instantaneous.
   - [x] 1.4 Placeholder vacuum AI — confirmed working on-device (see §2 above): feels like an active nuisance, not a goalpost.
   - [ ] 1.5 Treats, Zoomie meter, Chomp — next up, see above.
   - [ ] 1.6 The Critical Test — full sequence playtest with 3–5 people, silent observation.
3. **GO/NO-GO gate at end of Phase 1.6**: only proceed to Phase 2 (art/sound vertical slice) if the ugly prototype is instinctively fun. Do not skip this gate.

**Reusable dev tooling now in place** (built during 1.1, applies to all future milestones):
- Full build→deploy→test loop: `Godot_..._console.exe --headless --path "." --export-debug "Android" "builds/android/bark_and_chomp.apk"` → `adb install -r <apk>` → `adb shell am force-stop com.barkandchomp.game` → `adb shell monkey -p com.barkandchomp.game -c android.intent.category.LAUNCHER 1`.
- In-game **Restart button** (top-right corner) reloads the current run instantly on-device — use this between playtest attempts instead of a full reinstall.
- **Gotcha to remember for every new scene/UI node**: any `ColorRect`/`Label`/other `Control`-derived placeholder visual placed over gameplay area will silently eat touch input (`mouse_filter` defaults to STOP) unless `mouse_filter = 2` (IGNORE) is set explicitly. Set this on every new placeholder visual from now on, don't wait to rediscover it.

Per the TDD's own instruction to coding agents: **build milestone-by-milestone, never generate the whole game in one pass — every milestone ends with a human playtest on a physical Android device.** Code-writing can and should continue ahead of the Android-SDK setup (it doesn't block editing GDScript/scenes), but no milestone is actually *done* until it's been played on a real phone.

---

## 4. Key context / decisions worth remembering

- User's GitHub account: `amritanshu1992`; repo: `bark-and-chomp` (public, no README/license added by GitHub — this repo's own docs serve that purpose).
- `gh` CLI is **not installed** on this machine (checked both Git Bash and PowerShell) — remote repo creation had to be done manually by the user via the GitHub web UI, then the URL was handed back for `git remote add`.
- Git identity is already configured globally (Amritanshu Kumar Gaurav / amritanshu1990@gmail.com) — no setup needed there.
- No CI, no build pipeline, no automated tests yet.
- Godot binary: `C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64.exe` (GUI) / `..._console.exe` (console/headless — use this one for headless validation, e.g. `--headless --editor --path . --quit` once after any new `class_name` script is added, to rebuild `.godot/global_script_class_cache.cfg`, then `--headless --path . --quit-after N` to smoke-test for script/scene errors).
- 1 game unit = 64 px at base resolution (`PX_PER_UNIT` constant in `player.gd`) — keep this the single conversion constant per TDD §3.

---

## 5. How to resume a session

1. Read this file.
2. `git -C "D:\AI\Business\claud\Bark and Chomp" status` and `git log --oneline -5` to confirm nothing has drifted from what's recorded above.
3. Re-check "What's next" §3 and continue from the first unchecked item.
4. At the end of the session, update the checkboxes in §2, the "What's next" list in §3, and the "Last updated" date at the top before ending.
