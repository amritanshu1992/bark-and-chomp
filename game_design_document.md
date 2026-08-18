# Game Design Document — "Bark & Chomp"

Version 1.0 · Locked for MVP · Companion docs: Project Plan, Technical Design Doc

---

## 1. High Concept

A chaotic little shih tzu chases a sentient vacuum cleaner that stole its treats, hopping over obstacles and deflecting flying household objects with perfectly timed bark blasts — until it builds up enough zoomie energy to catch the vacuum and CHOMP it.

**One-line pitch:** "A tiny chaotic shih tzu is trying to get its stolen treats back from a sentient vacuum, and you control its hops and perfectly timed bark attacks."

**Genre:** Casual endless runner with timing-based combat
**Platform:** Android (mobile-first, **portrait**, single vertical lane — confirmed during Phase 1; the dog stays fixed near the bottom of the screen while the vacuum, obstacles, treats, and projectiles scroll top-to-bottom toward it, rather than the dog auto-running left-to-right. See Technical Design Doc §1/§5 and `handoff.md` §2c for the full "vertical-orientation migration" story — this was a mid-Phase-1 divergence from the original horizontal-runner assumption baked into this doc's earlier drafts.)
**Session length:** 60–120 second runs
**Audience:** Casual mobile players; short-form-video audiences (TikTok/Reels/Shorts)
**Business model:** Rewarded ads (primary) + treat IAP + remove-ads (see §10)

**Desired player reaction:** "WHAT IS THIS STUPID DOG DOING 😂" — never "it's Flappy Bird with a dog."

---

## 2. Design Pillars (locked — every feature must serve at least one)

1. **The dog IS the product.** One shih tzu, forever. Personality through animation, sound, and physics. Depth via costumes, never via breeds or new characters.
2. **Simple controls, deep timing.** Two verbs (tap, hold) on one thumb. All skill expression comes from timing, not complexity.
3. **The reaction is the reward.** Impacts produce exaggerated, funny consequences (ragdolls, explosions, screen shake) — never abstract numbers.
4. **Funny beats fair-adjacent.** The game may be slightly ridiculous and floaty; it must never feel unresponsive or cheap.
5. **Every run should contain a clip.** If a 90-second run isn't funny to watch, the design has failed regardless of how it plays.

---

## 3. Characters

### 3.1 The Shih Tzu (player)
- Tiny, fluffy, treat-obsessed, slightly stupid, secretly powerful.
- Floppy ears that react to physics (flap during zoomies, droop on whimper).
- Exaggerated facial reactions; squashes when charging a bark.
- Not a customizable avatar — a specific character with a specific grudge.

### 3.2 The Vacuum (evergreen rival)
- A sentient vacuum cleaner. **It does not want to hurt the dog. It wants to CLEAN the dog's treats.** All behavior flows from this motive.
- Personality: fussy, tidy, increasingly exasperated. Treats are "mess." The dog is "mess with legs."
- Throws household objects it previously sucked up: socks, mailboxes, plungers, remote controls (absurd escalation welcome).
- Reactions to being hit: sparks, spins, panics, ragdolls. Defeat: **dust bag bursts — treats, socks, and random junk explode everywhere.**
- The rival is built as a template (see Technical Design Doc) so guest/seasonal monsters can be skinned onto the same AI post-MVP.

### 3.3 Guest monsters (post-MVP only)
- Trend-*inspired* (energies, not IP): gym-bro monster, glitch-static blob, influencer monster, seasonal turkey/snowman/tax-form monster. 67 may appear as a guest if culturally alive at the time.
- Rule: guests are upside, never load-bearing. The vacuum is the Tom to the dog's Jerry.

---

## 4. Core Loop (locked)

```
CHASE the vacuum
  → dodge obstacles / deflect projectiles (hop + bark timing)
  → collect treats → fill Zoomie Meter
  → deflected hits STUN the vacuum
  → full meter = ZOOMIES (4s, invincible, 2–2.5× speed)
  → during zoomies + vacuum stunned: 1.5s steer window
  → CHOMP → dust bag bursts → treat explosion
  → vacuum respawns further ahead → chase continues
  → death when hit outside zoomies → run ends, treats bank
```

The loop is a rhythm of small victories (deflects, chomps), not pure survival. The chomp is IN the MVP — the chase must be catchable or the fantasy is fake.

---

## 5. Controls & Input (locked spec)

One thumb. Two verbs. All thresholds are exported variables tuned on a physical phone.

### 5.1 Normal state
| Input | Result |
|---|---|
| Touch down | Start input timer |
| Release < 150 ms | **HOP** (impulse ~8–10 u/s) |
| Hold ≥ 150 ms | Enter **BARK_CHARGING** (dog squashes; momentum + air arc fully preserved) |
| Release ≥ 400 ms charge | **BARK BLAST** — forward shockwave, 2–3 dog-lengths range, deflects projectiles (velocity reversal toward vacuum) |
| Release < 400 ms charge | **Whimper puff** — harmless, tiny sad sound, zero deflection |
| After blast | Cooldown 0.7–1.0 s |

**Mid-air bark charging is mandatory** — it is the signature mechanic. Jump → charge while floating → release at the perfect moment.

### 5.2 During Zoomies (locked resolution of the input conflict)
| Input | Result |
|---|---|
| Tap | Small **vertical nudge** (steering — reuses the hop verb the player already knows) |
| Hold | **Nothing.** The dog is too excited to bark. No charge state during zoomies. |

### 5.3 Input integrity requirements
- Zero accidental whimpers when a hop was intended is the tuning target. The 150 ms threshold is load-bearing for the entire game; adjust for real touchscreen latency, not editor input.
- Prototype must display live debug state (HOP / CHARGING / BLAST / WHIMPER) to make misreads visible.

---

## 6. Player Systems

### 6.1 Movement (initial tuning values — feel > numbers)
- Auto-scroll speed: starts 5–7 u/s, ramps up to 10 u/s over the first 45s of a run (added during the "Subway Surfers" feel pass — most of a 60–120s run plays at or near max speed). The dog itself is fixed in place; this speed is how fast the world (vacuum, obstacles, treats, projectiles) scrolls toward it, not literal horizontal travel — see §1 platform note.
- Gravity / hop impulse: current on-device tuning (`resources/tuning.tres`) is snappier than the original 25–30 u/s² / 8–10 u/s range — `gravity=80`, `hop_impulse=20`, hang time ~0.5s — chosen deliberately for a punchier feel once the game became a vertical scroller. Treat the original range as the starting point, not the current value; check `tuning.tres` for what's actually live.
- Hop-vs-obstacle/treat resolution is **not** real physics overlap — it's a deterministic check at the exact moment the obstacle/treat reaches the dog's line, gated on whether the dog is airborne past a minimum height at that instant. On-device testing found genuine shape-overlap physics essentially unlandable against a fast-scrolling target. See TDD §5/§6 and `handoff.md` §2c.
- Feel target: slightly ridiculous and floaty, never mushy. 60 FPS.

### 6.2 Zoomie Meter & Zoomies
- Fills from treat collection. **Deflect-hits on the vacuum also add meter** (design intent: naturally synchronizes stun availability with meter availability — see §7.3 risk note).
- Full meter → UNCONTROLLABLE ZOOMIES: 4 s, invincible, 2–2.5× speed, destroys obstacles, ears flap wildly, maximal audio/VFX catharsis.
- Zoomies is a temporary modifier on the movement system, not a separate movement system.

### 6.3 The Chomp
- Preconditions: zoomies active AND vacuum stunned.
- Player gets ~1.5 s to line up vertically (tap-nudge steering) → contact = CHOMP.
- Hit: dust bag bursts, large treat payout, victory animation, vacuum respawns ahead, difficulty continues ramping.
- Miss: vacuum recovers and escapes. No punishment beyond the lost opportunity.
- The chomp is a skill test, never automatic. A payoff you can miss is worth ten you can't.

### 6.4 Death & revive
- Hit by projectile/obstacle outside zoomies = run over.
- Death screen: distance + treats banked → **"Give a Treat to Revive?"** (rewarded ad OR 50 treats; once per run) → seamless resume.
- The dog looks at the camera sadly on the revive prompt. This is the game's best ad slot; it must be built as a first-class game state, not a bolt-on.

---

## 7. Rival Systems (Vacuum AI)

### 7.1 Chase behavior
- Maintains a target lead distance ahead of the dog (currently tuned to 11 units, up from the original ~6 — playtesting wanted more room/reaction time between the dog and the vacuum) with soft rubber-banding: too close → accelerates away; too far → slows. Check `tuning.rival_target_distance` for the live value.
- ±0.5–1.0 unit organic variation (`rival_distance_variation`). **Never hard-locked at the target distance** — the chase must feel alive.

### 7.2 Attack behavior
- Throws a household object backward toward the dog every 3–4 s, with timing jitter so rhythm can't be memorized.
- Telegraph before every throw (turn animation / wind-up) — attacks must be readable, never cheap.

### 7.3 Stun
- A deflected projectile that hits the vacuum → STUNNED state (sparks, confusion, slows/holds position) for a tunable window.
- **Known risk:** stun windows and full meters may fail to align, making chomps too rare. Pre-approved fix (already in design): deflect-hits feed the meter (§6.2). If still too rare in testing, lengthen stun duration before adding any new mechanic.

### 7.4 Reactions (the reward layer)
Never `HP -= 10`. Impacts produce: flattening, spinning, ragdolling, knockback, panic sounds, screen shake, treat spillage, angry retaliation, and a tiny dog victory animation. Reactions are content — budget them like content.

---

## 8. World, Obstacles, Collectibles

### MVP
- **One** endless parallax environment: living room (2–3 layers).
- **One** obstacle type at first (expand to 2 max in vertical slice).
- **One** collectible: the treat (fills meter in-run; banks to wallet at run end — see §10.1).
- **3–4** projectile types (visual variety only; identical physics): sock, mailbox, plunger, remote.

### Difficulty ramp
- Run speed and throw frequency creep upward so an average player dies at 60–120 s. Death frequency is ad inventory (see §10) — a 10-minute survivable game is an economic failure.

### Post-MVP backlog (fenced — DO NOT BUILD until core loop is proven; order of consideration)
1. Projectile catching (perfect timing = catch sock in mouth → tap to spit back; uses the "dog mouth" verb, no new controls)
2. Daily chaos modifiers (low-gravity day, giant-sock day, tiny-dog day)
3. Forbidden treats family: chocolate (dangerous — dog drifts toward it, player fights the dog's instincts), giant bone (heavy, shorter hops, big bank), squeaky toy (distraction), steak (berserk), golden treat (huge meter fill)
4. Sniff distraction (telegraphed involuntary stop; test carefully, cut if unfair)
5. Combo deflects (3 clean deflects in a row → homing return shot)
6. Guest/seasonal monsters on the vacuum AI template
7. Environmental toys (trampoline, slippery rug, couch burrow — one per environment)
8. Zoomie wall-running
9. Impact freeze-frame / photo mode → eventually auto replay clips of the run's funniest moment
10. Additional environments (backyard, etc.)

---

## 9. Art, Animation & Audio Direction

### 9.1 Prototype (Phase 1)
Deliberately ugly: white capsule (dog), vacuum-shaped grey capsule (rival), black squares (projectiles), circles (treats). The prototype tests fun, not looks.

### 9.2 Production art (Phase 2)
- Style: clean, chunky, readable 2D with strong silhouettes; instantly parseable at phone size and in compressed video.
- **The shih tzu animation rig is the single most important asset in the project.** Full set: run, hop, bark-charge squash, blast, whimper, zoomies (ears flapping), chomp, hit/death, idle, victory. Commission a professional 2D animator for this rig if it exceeds in-house skill — this is the one budget line that determines whether the personality bet pays off.
- Vacuum set: run, throw wind-up, hit/ragdoll, stunned (sparking), defeat (dust-bag burst).

### 9.3 Juice (non-optional; it IS the product)
- Hit-stop on deflect and chomp; screen shake scaled to impact; particle bursts for treats.
- Squash & stretch everywhere. If a moment isn't funny in a muted screen recording, add juice until it is.

### 9.4 Audio
- Bark charge rumble → blast; pathetic whimper puff; chomp crunch; treat pickup pops; zoomies wind/scramble loop; vacuum whir, panic beeps, deflating defeat.
- A few custom-recorded barks are worth paying for; everything else can start from libraries.

### 9.5 Costume rule
Every costume changes at minimum: appearance + bark sound + victory animation. Costumes are content and jokes, never recolors. Includes "dog costume" gags (shih tzu in a cardboard corgi suit, badly-fitting greyhound outfit) — never actual playable breeds.

---

## 10. Economy & Monetization

### 10.1 Single currency: Treats
- In-run: treats fill the Zoomie Meter. At run end (or death), collected treats **bank to the wallet**. Meter and wallet are separate numbers sourced from the same pickups — spending never drains in-run power.
- Everything in the game transacts in treats, always framed as **feeding the dog**. No gems/coins/stars.

### 10.2 The revenue chain (each link required)
Treats buy costumes → players want costumes → boosters and "double treats" rewarded ads become worth watching/buying. If costumes aren't desirable, the entire economy collapses — hence §9.5.

### 10.3 Treat sinks (costume shop)
- Launch with ~5 genuinely funny costumes. Price ladder: 1 cheap (achievable in 1–2 sessions; first-purchase dopamine), 3 mid-tier (the grind), 1 absurd prestige item (the long-term dream / streamer flex).
- Preview before purchase: the dog wears it, idles, and barks in the shop. Window shopping is where wanting happens.
- Place one mid-tier costume just out of reach of a new player's first day of earnings — the gap the first "double treats" ad closes.
- Earn-rate anchor: first cheap costume ≈ 10–15 honest runs. All other prices, rewards, and bundles hang off this number.

### 10.4 Ads (primary revenue; rewarded-first)
| Slot | Framing | Notes |
|---|---|---|
| Revive on death | "Give a Treat to Revive" (sad dog face) | Best slot; once per run; also purchasable for 50 treats |
| Run-end double treats | "Extra treats for a good dog" | Core chain activator |
| Head start | Start next run with half Zoomie meter | Session-starter |
| Daily mystery chest | "Mystery treat" | Once daily |

- Interstitials (optional, conservative): at most every 3rd–4th death, never after a great run, fully suppressed for the first 5–10 sessions. D1 retention outranks D1 revenue, always.

### 10.5 IAP
- Treat packs (3 tiers).
- Economy boosters only: 2× treats for N runs, treat magnet, head starts. **Never power** — nothing purchasable may affect bark timing, hop physics, or survival difficulty.
- **Remove Ads:** removes interstitials ONLY. Rewarded ads remain for all players (payers still want their revive treat).
- No purchasable dogs/breeds. Decision is final for v1 (identity + animation cost + tuning fragmentation).

### 10.6 Retention (v1 minimum)
- Daily login treat bonus with growing streak (the dog is "waiting for you"; sad-shih-tzu comeback notification is a post-launch addition).
- Local high score / best distance.
- Post-launch: daily chaos modifiers double as retention content.

---

## 11. Scope Guardrails

**MVP contains exactly:** 1 dog · 1 vacuum · 1 environment · 1 obstacle type · 1 collectible · hop · bark charge/release (incl. mid-air) · deflection · stun · Zoomie meter · zoomies · steer-and-chomp · vacuum chase + throw AI · distance score · treat count · basic physics/VFX/audio · revive flow (placeholder ad button).

**MVP excludes:** everything in the §8 backlog, all monetization SDKs, breeds, multiple environments, bosses, weather, gacha, elaborate progression, large soundtrack.

**The gate:** After the prototype, the sequence *throw → hop → mid-air charge → perfect release → deflect → vacuum ragdolls → treats explode → zoomies → chomp* must make testers instinctively replay. Merely "functional" = stop and tune. Tuning fails for 2+ weeks = reconsider the project. This gate existing is the plan working.

**The rule above all rules:** the next question is never "what should we add?" It is "is the ugliest current version fun on a real phone?"

---

## 12. Success Criteria

| Stage | Metric |
|---|---|
| Prototype | Testers replay unprompted; zero intended-hop-became-whimper misreads |
| Vertical slice | A muted 90 s screen recording is funny to watch / mildly shareable |
| Soft launch | D1 retention ≥ ~30%; if lower, fix fun/FTUE before touching revenue |
| Live | Rewarded-ad engagement on revive + double-treats slots; costume purchase funnel activates within first 2 days of play |
