# Phase 2 asset list

Source: `game_design_document.md` §9 (Art, Animation & Audio Direction) and
`bark_and_chomp_project_plan.md` §2.1-2.2. Compiled 2026-08-23, checklist
form added same day so this can be worked through independently of the
code-only Phase 2 work (that's tracked separately in `handoff.md`'s Phase 2
groundwork list — animation/audio scaffolding is being built against
placeholder art so these assets drop in later without rework).

Nothing here has been sourced yet. Check items off as you go; the "source"
column is a starting suggestion, not a decision already made.

## Player — shih tzu (the most important asset in the project)

Per the GDD: "The shih tzu animation rig is the single most important asset
in the project... commission a professional 2D animator for this rig if it
exceeds in-house skill — this is the one budget line that determines whether
the personality bet pays off." **Do this one first / budget for it
separately from everything else below.**

- [ ] Sprite + full animation rig (commission a 2D animator, e.g. via
      Fiverr/Upwork/ArtStation, if in-house skill doesn't reach it):
  - [ ] idle
  - [ ] run
  - [ ] hop
  - [ ] bark-charge (squash)
  - [ ] blast
  - [ ] whimper
  - [ ] zoomies (ears flapping)
  - [ ] chomp
  - [ ] hit
  - [ ] death
  - [ ] victory
- [ ] Bark SFX: charge rumble → blast — worth a custom recording per GDD
- [ ] Whimper puff SFX — worth a custom recording per GDD
- [ ] Chomp crunch SFX (library SFX is fine for v1)
- [ ] Zoomies wind/scramble loop SFX (library SFX is fine for v1)

## Rival — vacuum

- [ ] Sprite + animation set:
  - [ ] run
  - [ ] throw wind-up
  - [ ] hit/ragdoll
  - [ ] stunned (sparking, confused)
  - [ ] defeat (dust-bag burst — treats/socks/junk flying)
- [ ] Vacuum whir loop SFX (library, e.g. Freesound/Zapsplat)
- [ ] Panic beeps SFX (library)
- [ ] Deflating "defeat" SFX (library)

## World

- [ ] One environment (living room), 2-3 parallax scroll layers
- [ ] 1-2 obstacle sprites
- [ ] Treat sprite
- [ ] Treat pickup pop SFX (library)
- [ ] 3-4 household projectile sprites (sock, mailbox flag, plunger, etc.)

## Juice (non-optional per GDD — "it IS the product")

Code-driven, not asset files, but tuned against real animation timing once
it exists — no sourcing needed, just noting it depends on the above:

- [ ] Hit-stop on deflect + chomp
- [ ] Screen shake scaled to impact
- [ ] Particle bursts for treat pickups / dust-bag defeat

## Not needed yet (later phases) — don't source these now

- Costume sprites — 5 launch costumes (GDD §9.5 / §10.3), each changing at
  minimum appearance + bark sound + victory animation. Phase 3+ economy work.
- Custom-recorded barks beyond the core set — GDD says library SFX is fine
  for v1 except a few custom barks worth paying for.

## Sourcing note

GDD/plan don't mandate a specific pipeline: "free/cheap libraries are fine
for v1" for SFX, with a few custom barks worth paying for; the shih tzu rig
is flagged as the one line worth commissioning if in-house skill doesn't
reach it. Everything else can start from free/cheap asset libraries
(OpenGameArt, itch.io asset packs, Freesound, Zapsplat) as placeholder-grade
starting points and get replaced later if needed.
