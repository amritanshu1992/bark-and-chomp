# Handoff — "Bark & Chomp"

Last updated: 2026-08-18

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

**Phase: 0 — Setup** (per `bark_and_chomp_project_plan.md`). Nothing beyond repo/doc setup has been done yet — **no Godot project exists yet, no code has been written.**

Done so far:
- [x] Three design docs written and finalized (project plan, GDD, TDD).
- [x] Local git repo initialized at `D:\AI\Business\claud\Bark and Chomp`.
- [x] `.gitignore` added (Godot 4 defaults: `.godot/`, `.import/`, export configs, editor/OS cruft).
- [x] Initial commit made (`80ccfde`, "Initial commit: project plan, GDD, and technical design docs").
- [x] Remote added and pushed: **https://github.com/amritanshu1992/bark-and-chomp** (branch `main`, tracking `origin/main`).

Not done yet (still Phase 0, per the project plan's own exit criteria — "a blank Godot scene runs on your physical phone"):
- [ ] Install Godot 4.x + Android SDK, configure Android export templates.
- [ ] Create the actual Godot project (landscape, 1280×720 base resolution, `canvas_items` stretch, `expand` aspect, Mobile renderer, 60 FPS target — see TDD §1–2 for exact settings and folder layout under `res://`).
- [ ] Deploy an empty scene to a real Android phone and confirm it runs. **This is explicitly flagged in the plan as "do not skip" — deployment problems must be solved before they can block a playtest.**
- [ ] Commit the Godot project into this repo once created.

---

## 3. What's next (in order)

1. Finish Phase 0 setup (Godot install, Android export config, blank-scene-on-phone deploy).
2. Start Phase 1 ("The Ugly Capsule" prototype) milestone by milestone, exactly as sequenced in `bark_and_chomp_project_plan.md` §PHASE 1:
   - 1.1 Movement (auto-run, gravity, tap-to-hop) → deploy to phone, tune the 150ms tap threshold against real touch latency.
   - 1.2 Bark input state machine (hop / charging / blast / whimper).
   - 1.3 Projectile + deflect.
   - 1.4 Placeholder vacuum AI (chase distance, throw timer, stun state).
   - 1.5 Treats, Zoomie meter, Chomp.
   - 1.6 The Critical Test — full sequence playtest with 3–5 people, silent observation.
3. **GO/NO-GO gate at end of Phase 1.6**: only proceed to Phase 2 (art/sound vertical slice) if the ugly prototype is instinctively fun. Do not skip this gate.

Per the TDD's own instruction to coding agents: **build milestone-by-milestone, never generate the whole game in one pass — every milestone ends with a human playtest on a physical Android device.**

---

## 4. Key context / decisions worth remembering

- User's GitHub account: `amritanshu1992`; repo: `bark-and-chomp` (public, no README/license added by GitHub — this repo's own docs serve that purpose).
- `gh` CLI is **not installed** on this machine (checked both Git Bash and PowerShell) — remote repo creation had to be done manually by the user via the GitHub web UI, then the URL was handed back for `git remote add`.
- Git identity is already configured globally (Amritanshu Kumar Gaurav / amritanshu1990@gmail.com) — no setup needed there.
- No CI, no build pipeline, no tests yet — nothing to configure until the Godot project itself exists.

---

## 5. How to resume a session

1. Read this file.
2. `git -C "D:\AI\Business\claud\Bark and Chomp" status` and `git log --oneline -5` to confirm nothing has drifted from what's recorded above.
3. Re-check "What's next" §3 and continue from the first unchecked item.
4. At the end of the session, update the checkboxes in §2, the "What's next" list in §3, and the "Last updated" date at the top before ending.
