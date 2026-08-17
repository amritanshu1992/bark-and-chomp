# Project Plan — "Bark & Chomp"

A casual, ad-funded Android runner about a chaotic shih tzu reclaiming its treats from a sentient vacuum cleaner.

**Engine:** Godot 4.x · **Platform:** Android first · **Target:** 60 FPS · **Business model:** Rewarded ads + treat IAP + remove-ads

---

## Guiding principles (locked)

1. The shih tzu is the product. One dog, forever. Depth through costumes, not breeds.
2. The vacuum doesn't want to kill the dog — it wants to CLEAN the treats.
3. Simple controls (tap = hop, hold = bark), funny physics, satisfying timing.
4. Runs are short (~60–120s). Death frequency is ad inventory.
5. One currency: treats. Every transaction is "feeding the dog."
6. Nothing from the backlog gets built until the core loop is proven fun.
7. Every design question that can be answered by playtesting is answered by playtesting, not discussion.

**Core loop (locked):**
Chase → dodge/deflect → collect treats → fill Zoomie meter → Zoomies → steer → CHOMP the vacuum → treat explosion → chase continues.

---

## PHASE 0 — Setup (2–3 days)

- Install Godot 4.x, Android SDK, configure export templates.
- Create project, set landscape resolution, target 60 FPS.
- Deploy an empty scene to a real Android phone. **Do not skip this** — deployment problems must be solved before they can block a playtest.
- Set up a git repository.

**Exit criteria:** a blank Godot scene runs on your physical phone.

---

## PHASE 1 — Prototype: "The Ugly Capsule" (2–3 weeks)

Goal: prove the loop is fun using placeholder shapes. No art, no sound design, no menus, no monetization.

### Milestone 1.1 — Movement (days 1–3)
- Auto-run, gravity (~25–30 u/s²), tap-to-hop (~8–10 u/s impulse), floor, one static obstacle.
- **Deploy to phone immediately.** Tune the 150 ms tap threshold against real touchscreen latency.
- Test: does hopping over a block feel floaty, predictable, responsive?

### Milestone 1.2 — Bark (days 4–6)
- Input state machine: <150 ms release = hop; hold past 150 ms = BARK_CHARGING; release ≥400 ms = full Bark Blast; early release = whimper puff.
- Mid-air charging preserves momentum and arc.
- On-screen debug text (HOP / CHARGING / BLAST / WHIMPER) to catch input misreads.
- Test: zero accidental whimpers when the player intended a hop.

### Milestone 1.3 — Projectile + deflect (days 7–9)
- Black square flies at the dog on a timer; Bark hitbox reverses its velocity.
- Test: does the deflect feel crisp and instantaneous?

### Milestone 1.4 — Vacuum AI (days 10–12)
- Placeholder vacuum keeps ~6 units ahead with soft variation (±0.5–1.0), throws every 3–4 s with slight timing jitter.
- Deflected projectile hitting it = big reaction (fly back, screen shake) + **stun state**.
- Test: does it feel like an active nuisance, not a goalpost?

### Milestone 1.5 — Treats, Zoomies, Chomp (days 13–16)
- Treat spawning + collection + Zoomie meter.
- Full meter = 4 s Zoomies: invincible, 2–2.5× speed, obstacle destruction.
- During Zoomies: tap = vertical nudge, hold = disabled (dog too excited to bark).
- If vacuum is stunned during Zoomies: ~1.5 s window to line up → CHOMP → treat explosion → vacuum respawns further ahead.
- Test variant if catches feel too rare: deflect-hits also add meter, so stun and full meter naturally synchronize.

### Milestone 1.6 — The Critical Test (days 17–21)
Play the full sequence: throw → hop → mid-air charge → perfect release → deflect → vacuum ragdolls → treats explode → Zoomies → chomp.
- Give it to 3–5 people. Watch them play. Say nothing.

**GO / NO-GO GATE:** If players (and you) instinctively replay it, proceed. If it's merely "functional," stop and tune physics/input. **Do not proceed to Phase 2 with an unfun core.** If 2+ weeks of tuning doesn't fix it, seriously reconsider the project — this gate existing is the plan working, not failing.

---

## PHASE 2 — Vertical Slice: "Make the Dog Real" (4–6 weeks)

Goal: the prototype loop with real art, sound, and juice. This is where the personality bet gets tested.

### 2.1 Art
- Shih tzu sprite + full animation set: run, hop, bark charge (squash), blast, whimper, zoomies (ears flapping), chomp, hit/death, idle, victory. This is the single most important asset in the project — budget accordingly, or hire/commission an animator for this one rig.
- Vacuum: run, throw, hit/ragdoll, stunned (sparking, confused), defeat (dust bag bursts — treats, socks, random junk everywhere).
- One environment (living room), 2–3 parallax layers, 1–2 obstacle types, treat sprite, 3–4 household projectiles (sock, mailbox, plunger…).

### 2.2 Sound & juice
- Bark charge/blast/whimper, chomp, treat pickup, zoomies loop, vacuum whir + panic sounds.
- Screen shake, hit-stop on deflect and chomp, particles for treat explosions.
- Juice is not polish here — it IS the product. The "funny dog" bet lives or dies in this phase.

### 2.3 Difficulty ramp
- Speed and throw frequency creep so an average player dies around 60–120 s.
- Death → clean "run over" screen showing distance + treats banked.

**Exit criteria:** a 90-second run that is funny to *watch*. Screen-record a run; if the clip isn't at least mildly shareable, iterate on animation/juice before adding systems.

---

## PHASE 3 — Game Systems (3–4 weeks)

### 3.1 Meta & economy
- Treat wallet (separate from in-run Zoomie meter; run treats bank at death).
- Costume shop: launch with ~5 genuinely funny costumes, each changing bark sound + victory animation (e.g., knight = clank bark, opera singer = operatic bark, hot dog outfit, and 1–2 "dog costume" gags like a cardboard corgi suit).
- Price ladder: 1 cheap (1–2 sessions), 3 mid (the grind), 1 absurd prestige item.
- Preview: player sees the dog wearing + barking in any costume before buying.
- Tune earn rate: first cheap costume ≈ 10–15 honest runs.

### 3.2 Revive flow
- Die → pause → "Give a Treat to Revive?" → resume seamlessly. Ad button is a working placeholder for now. One revive per run.

### 3.3 Retention v1
- Daily login treat bonus with growing streak.
- Local high score + best-distance display.

### 3.4 Menus & FTUE
- Title, shop, settings, pause. First-run tutorial: teach hop, then bark, then deflect, each in a safe moment. No text walls — the vacuum teaches by attacking.

---

## PHASE 4 — Monetization & Compliance (2–3 weeks)

### 4.1 Ads (rewarded-first)
- Integrate one mediation SDK (e.g., AdMob to start).
- Rewarded slots: revive ("give a treat"), double treats at run end, half-Zoomie-meter head start, daily mystery treat chest. All framed as feeding the dog.
- Interstitials (optional, conservative): at most every 3rd–4th death, never after a great run, fully suppressed for the first 5–10 sessions.

### 4.2 IAP
- Treat packs (3 tiers), economy boosters (2× treats for N runs, treat magnet), Remove Ads.
- Remove Ads removes interstitials ONLY — rewarded ads stay for everyone.
- No power. No breeds. Ever (for v1).

### 4.3 Compliance
- Privacy policy, ad consent (GDPR/UMP), Google Play data safety form, content rating questionnaire. Boring, mandatory, ~2–3 days.

---

## PHASE 5 — Polish, Test, Ship (3–4 weeks)

- Performance pass: steady 60 FPS on a low-end test device (borrow/buy a cheap phone — do not trust your flagship).
- Battery/thermal sanity check, object pooling for projectiles/treats/particles.
- Closed testing track on Google Play (Play requires a testing period for new personal dev accounts — start this early, it can take 2+ weeks of testers).
- Fix crashes, tune economy from tester data, cut anything that isn't ready rather than delaying.
- Store listing: icon, screenshots, and a 15–30 s video of the funniest gameplay moment (the chomp + dust-bag burst).
- **Soft launch** to 1–2 smaller markets if possible; watch D1 retention and session counts before wide release.

**Ship.**

---

## PHASE 6 — Post-Launch (ongoing)

Prioritize strictly by data:
- **If D1 retention < ~30%:** fix fun/FTUE before anything else. Nothing else matters.
- **If retention is fine but revenue is weak:** tune ad placement/economy.
- **If both are fine:** start the backlog.

### Backlog (locked order of consideration — DO NOT TOUCH UNTIL CORE IS PROVEN)
1. Projectile catching (catch sock in mouth → tap to spit back)
2. Daily chaos modifiers (low gravity day, giant sock day)
3. Forbidden treats family (chocolate = danger, steak = berserk, golden = mega meter)
4. Sniff distraction (test carefully; cut if it feels unfair)
5. Combo deflects (3 in a row = homing return)
6. Guest/seasonal monsters on the vacuum AI template (67 if still alive, turkey, snowman, tax-form monster)
7. Environmental toys (trampoline, rug, couch)
8. Zoomie wall-running
9. Impact freeze-frame / photo mode → later, auto replay clips
10. Sad-dog comeback notification + streak system v2
11. More costumes (the evergreen revenue content)

---

## Timeline summary

| Phase | Duration | Cumulative |
|---|---|---|
| 0 — Setup | 2–3 days | Week 1 |
| 1 — Ugly prototype | 2–3 weeks | ~Week 4 |
| 2 — Vertical slice | 4–6 weeks | ~Week 10 |
| 3 — Game systems | 3–4 weeks | ~Week 14 |
| 4 — Monetization | 2–3 weeks | ~Week 17 |
| 5 — Polish & ship | 3–4 weeks | ~Week 20–21 |

**Realistic total: ~4.5–5.5 months part-time solo** (assumes commissioned or capable 2D animation in Phase 2 — that's the wildcard that can add a month).

---

## Budget items to expect

- Google Play developer account: $25 one-time
- 2D animator commission for the dog + vacuum rigs (the one expense worth making): varies widely, get quotes early in Phase 1
- Sound effects: free/cheap libraries are fine for v1; a few custom barks are worth it
- A cheap low-end Android test phone

## Risk register (top 5)

1. **Input misreads on touchscreens** (150 ms threshold) → mitigated by Phase 1.1 phone-first testing.
2. **Dog isn't actually funny** → mitigated by the Phase 2 "watchable clip" exit criteria; this is the animation-quality bet.
3. **Feature creep** → mitigated by the locked backlog and the Phase 1.6 gate. The backlog list is a graveyard fence, not a roadmap.
4. **Stun + meter never align (chomp too rare)** → pre-planned fix: deflects also fill the meter.
5. **Launch to silence** → mitigated by soft launch + building the shareable-clip asset from Phase 2 onward; ad-funded games need volume, and volume comes from the dog being clip-worthy.

---

## The one rule above all rules

At every gate, the question is never "what should we add?" It is:

> **"Is the ugliest current version fun on a real phone?"**

If yes, advance. If no, tune. If tuning fails, stop. Everything in this plan exists downstream of a white capsule that is fun to hop.
