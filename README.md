# Bark & Chomp

A casual, ad-funded Android runner about a chaotic shih tzu reclaiming its stolen treats from a sentient vacuum cleaner. Built in **Godot 4.x / GDScript 2.0**, mobile-first.

**One-line pitch:** "A tiny chaotic shih tzu is trying to get its stolen treats back from a sentient vacuum, and you control its hops and perfectly timed bark attacks."

**Core loop:** Chase → dodge/deflect → collect treats → fill Zoomie meter → Zoomies → steer → CHOMP the vacuum → treat explosion → chase continues.

---

## Docs

Read in this order:

1. [`bark_and_chomp_project_plan.md`](bark_and_chomp_project_plan.md) — phased build plan, milestones, playtest gates, timeline, risks.
2. [`game_design_document.md`](game_design_document.md) — mechanics, characters, economy, monetization, feel.
3. [`technical_design_document.md`](technical_design_document.md) — Godot project structure, scripts, node layout, build spec.
4. [`handoff.md`](handoff.md) — **current project status**; read this first when picking work back up.

---

## Status

Phase 1 ("The Ugly Capsule" prototype), Milestone 1.1 (movement) in progress. See [`handoff.md`](handoff.md) for the up-to-date checklist — it's kept current every session.

---

## Requirements

- [Godot 4.7.x](https://godotengine.org/download) (GDScript 2.0)
- Android SDK (Platform-Tools, an SDK Platform, Build-Tools) + JDK 17+ — only needed for on-device export/deploy
- A physical Android phone with USB debugging enabled — the plan requires tuning input timing against real touch latency, not an emulator

## Running the project

Open this folder in the Godot editor and press Play, or from the command line:

```
Godot_v4.7.1-stable_win64.exe --path . 
```

## Project structure

```
res://
  scenes/     # .tscn scene files
  scripts/    # .gd scripts
  resources/  # tuning.tres — single source of truth for gameplay numbers
  assets/     # sprites, audio (placeholders during Phase 1)
```

See the technical design doc for the full intended structure and conventions (autoloads, tuning resource, input state machine, etc.).
