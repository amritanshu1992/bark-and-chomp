# Handoff — "Bark & Chomp"

Last updated: 2026-08-18 (session 2)

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
- [ ] Not yet committed to git — see next action below.

**Android SDK / device status (confirmed with user this session): nothing set up yet.**
- No Android Studio / SDK installed.
- No physical phone prepped with USB debugging.
- **Important:** per TDD §1, test on a **real physical phone, not an emulator/AVD** — touch-latency tuning (the 150ms threshold) is load-bearing and emulators don't reproduce real touchscreen latency. When setting up Android Studio, the SDK components (Platform-Tools, an SDK Platform e.g. API 34, Build-Tools) are what's needed; an AVD is not required for this project.

Not done yet (blocks the Phase 0 exit criterion — "a blank Godot scene runs on your physical phone" — and thus blocks on-device testing of Milestone 1.1):
- [ ] Install JDK 17+ (required by Godot's Android/Gradle export).
- [ ] Install Android SDK (via Android Studio or standalone cmdline-tools): Platform-Tools, an SDK Platform, Build-Tools.
- [ ] Point Godot's Editor Settings → Export → Android at the SDK path; verify/generate debug keystore.
- [ ] Enable USB debugging on a real Android phone, confirm it shows up in `adb devices`.
- [ ] Export/deploy the current project to the phone and confirm the capsule hops over the obstacle, gravity/timing feel right, tune the 150ms threshold against real touch latency (Milestone 1.1's actual test question: "does hopping over a block feel floaty, predictable, responsive?").

---

## 3. What's next (in order)

1. **Immediate next action:** `git add` + commit the new Godot project files (`project.godot`, `scripts/`, `scenes/`, `resources/`) — they exist on disk but aren't committed yet.
2. User sets up JDK + Android SDK + a real phone with USB debugging (nothing installed as of this session).
3. Wire up Godot's Android export preset once the SDK is available, then deploy Milestone 1.1 to the phone and playtest per the plan's own test question.
4. Continue Phase 1 ("The Ugly Capsule" prototype) milestone by milestone, exactly as sequenced in `bark_and_chomp_project_plan.md` §PHASE 1:
   - ~~1.1 Movement~~ — code done, **on-device playtest/tuning still pending** (blocked on Android SDK setup above).
   - 1.2 Bark input state machine — mostly already built in `input_controller.gd`; remaining work is wiring `charge_started`/`bark_released` into `player.gd` (squash on charge, whimper puff) and adding the HOP/CHARGING/BLAST/WHIMPER debug HUD label (Phase 1 requirement, TDD §4.2).
   - 1.3 Projectile + deflect.
   - 1.4 Placeholder vacuum AI (chase distance, throw timer, stun state).
   - 1.5 Treats, Zoomie meter, Chomp.
   - 1.6 The Critical Test — full sequence playtest with 3–5 people, silent observation.
5. **GO/NO-GO gate at end of Phase 1.6**: only proceed to Phase 2 (art/sound vertical slice) if the ugly prototype is instinctively fun. Do not skip this gate.

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
