# Phase 3.4a — Menus (Title, Pause, Settings): Design

**Date:** 2026-09-24
**Status:** Approved in conversation; awaiting written-spec review.
**Plan reference:** `bark_and_chomp_project_plan.md` §3.4, TDD §10 (save), §11 (ads interface unchanged).

## Scope decision

Project plan §3.4 bundles title, shop, settings, pause, and a first-run tutorial. It is split:

- **3.4a (this spec):** title screen, pause menu (with auto-pause), settings (Sound + Music), run-over Retry/Home.
- **3.4b (next):** first-run tutorial (FTUE) — teach hop, bark, deflect in safe moments; replaces the Round-4 one-time bark hint.
- **Shop screen** moves to **3.1b** — there is nothing to sell until costumes exist.

This split is a divergence from the plan and gets recorded in `handoff.md`.

## Goals / success criteria

- The app opens on a title screen; one tap on Play starts a run.
- A run can be paused at any time by the pause button, Android Back, or the app losing focus, and resumed exactly where it left off.
- After a run ends, one tap starts the next run (Retry) or returns to the title (Home).
- Sound and Music toggles take effect immediately and survive app restarts.
- Existing players keep their treat wallet when the save format changes.
- A run's treats bank exactly once however the run is left (Retry, pause-Restart, pause-Home, run-over Home).

## 1. Scene flow

```
title.tscn ──Play──▶ main.tscn ──Home (pause menu or run-over)──▶ title.tscn
                       │  ▲
                       └──┘ Retry (run-over) / Restart (pause menu): reload main.tscn
```

- `project.godot`: `run/main_scene="res://scenes/title.tscn"`.
- `project.godot`: `application/config/quit_on_go_back=false`, so Android Back is delivered as `NOTIFICATION_WM_GO_BACK_REQUEST` instead of quitting.
- Scene changes use `get_tree().change_scene_to_file()` / `reload_current_scene()`, both after `get_tree().paused = false`.

## 2. Title screen — `scenes/title.tscn` + `scripts/title.gd`

Layout (720×1280 base viewport, placeholder art like the rest of the game):

| Node | Type | Content |
|---|---|---|
| `TitleLabel` | Label | "Bark & Chomp", large, centered upper third |
| `PlayButton` | Button | "Play", large, centered (roughly y 700–840) |
| `WalletLabel` | Label | `"Treats: %d" % Save.get_wallet()`, below Play |
| `SettingsButton` | Button | "Settings", top-right corner (same slot the old Restart used) |
| `Settings` | instance of `settings.tscn` | hidden by default, full-screen overlay |

Behavior:

- `PlayButton` → `change_scene_to_file("res://scenes/main.tscn")`.
- `SettingsButton` → show the `Settings` overlay.
- Android Back: if the settings overlay is open, close it; otherwise `get_tree().quit()`.
- Every non-interactive `Control` sets `mouse_filter = 2` (project gotcha).

## 3. In-run changes — `scenes/main.tscn` + `scripts/main.gd`

- The top-right dev **`RestartButton` becomes `PauseButton`** (text "II" — Godot's default font may lack the ⏸ glyph; same offsets). The dev shortcut is gone; pause-menu Restart replaces it.
- **Run-over panel** (`UI/RunOverBg`) gets two buttons below the label: **`RetryButton`** ("Retry") and **`HomeButton`** ("Home"). Exact offsets decided in the plan; they must not overlap the label text and must stay inside 720×1280.
- `main.gd` public entry points, used by the run-over buttons and the pause menu:
  - `restart_run()` — `_bank_run_treats()`, unpause, `reload_current_scene()`. (Replaces `_on_restart_button_pressed`.)
  - `go_home()` — `_bank_run_treats()`, unpause, `change_scene_to_file("res://scenes/title.tscn")`.
- `_bank_run_treats()` keeps its exactly-once guard; nothing about the revive flow or banking amounts changes.

## 4. Pause menu — `scenes/pause_menu.tscn` + `scripts/pause_menu.gd`

Instanced in `main.tscn` under `UI` (so it inherits `process_mode = ALWAYS`). Hidden by default. Full-screen dim `ColorRect` (`mouse_filter` STOP, so gameplay taps don't leak through while paused) with a column of buttons: **Resume / Restart / Settings / Home**, plus its own `Settings` overlay instance.

Signals out (main.gd connects them): `restart_requested`, `home_requested`. Resume is handled inside the pause menu.

**The single opening rule:** `open()` does nothing if `get_tree().paused` is already true. The tree is already paused whenever the revive prompt, run-over panel, or Round-4 bark hint is up, so none of those can be interrupted or double-paused, and the pause menu never has to know about them by name.

- `open()` → `get_tree().paused = true`, show menu.
- **Resume** → hide menu (and its settings overlay), `get_tree().paused = false`.
- **Restart** → emit `restart_requested` → `main.restart_run()`.
- **Home** → emit `home_requested` → `main.go_home()`.
- **Settings** → show the settings overlay on top of the menu.

Triggers:

| Trigger | Effect |
|---|---|
| `PauseButton` pressed | `open()` |
| `NOTIFICATION_APPLICATION_FOCUS_OUT` | `open()` |
| `NOTIFICATION_WM_GO_BACK_REQUEST`, menu closed | `open()` |
| `NOTIFICATION_WM_GO_BACK_REQUEST`, settings overlay open | close the settings overlay |
| `NOTIFICATION_WM_GO_BACK_REQUEST`, menu open (no overlay) | Resume |

Notifications are handled in `pause_menu.gd` (a node that processes while paused). Back pressed while the revive prompt or run-over panel is showing does nothing (the opening rule covers it; menu is not open).

`Engine.time_scale` (hit-stop, `juice.gd`) is untouched by pause; hit-stop restores itself on a real-time timer, so pausing mid-hit-stop is safe.

## 5. Settings — `scenes/settings.tscn` + `scripts/settings.gd`

Reusable full-screen overlay (`Control`, dim background with `mouse_filter` STOP) instanced in both the title screen and the pause menu:

- **`SoundToggle`** (CheckButton, "Sound") — `button_pressed = Save.is_sound_on()` on show; toggled → `Save.set_sound_on(pressed)`.
- **`MusicToggle`** (CheckButton, "Music") — same with `is_music_on` / `set_music_on`.
- **`VersionLabel`** — `"v" + ProjectSettings.get_setting("application/config/version", "dev")`.
- **`CloseButton`** ("Back") — hides the overlay.
- `settings.gd` exposes `open()` / `close()` / `is_open()` so owners can route Android Back.

## 6. Audio buses

- New `default_bus_layout.tres` with buses `Master`, `SFX`, `Music` (SFX and Music send to Master).
- `SfxPlayer` and `LoopPlayer` in `scenes/player.tscn` and `scenes/rival.tscn` get `bus = &"SFX"`.
- No music player exists yet; the `Music` bus is empty until music assets arrive.
- `Save` applies bus mutes itself: `AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sound_on)`, likewise `Music`, on every `reload()` and every setter. A missing bus (index −1) is skipped silently, so headless tests and future bus renames can't crash.

## 7. Save format v2 — `scripts/save.gd`

```json
{"version": 2, "wallet": 0, "settings": {"sound": true, "music": true}}
```

Resolves the 3.1a deferred minor "version mismatch resets the wallet".

| File contents | Result |
|---|---|
| Missing file | wallet 0, sound on, music on |
| Unparseable JSON / non-dictionary / missing or invalid wallet | wallet 0, defaults, `push_warning` (unchanged from v1) |
| `version == 1`, valid wallet | **migrated:** wallet kept, settings defaults; next write stores v2 |
| `version == 2`, valid wallet, valid `settings` | loaded as-is |
| `version == 2`, valid wallet, `settings` missing / not a dictionary / non-bool fields | wallet kept; each invalid or missing setting falls back to `true`; `push_warning` |
| Any other version | wallet 0, defaults, `push_warning` (unchanged) |

API additions:

| Member | Behavior |
|---|---|
| `func is_sound_on() -> bool` | Current Sound setting. |
| `func is_music_on() -> bool` | Current Music setting. |
| `func set_sound_on(on: bool) -> void` | Sets, applies the bus mute, writes. |
| `func set_music_on(on: bool) -> void` | Same for Music. |

`_write()` always writes the full v2 shape. Existing wallet API and behavior are unchanged.

## 8. Tests

All headless `extends SceneTree` scripts; every scene test redirects `Save.save_path` to its own `user://test_save_<name>.json`, deletes it before and after (as the 3.1a tests do).

**`test_save.gd` (extended):**
- Missing file → sound and music on.
- `set_sound_on(false)` persists: a second instance on the same path reads false; music still true.
- v1 file `{"version": 1, "wallet": 42}` → wallet 42, settings on; after `add_treats(1)` the file on disk has `"version": 2`.
- v2 file with `"settings": "junk"` → wallet kept, settings on.
- v2 file with `"settings": {"sound": false, "music": 7}` → sound false, music true, wallet kept.
- `{"version": 99, ...}` → wallet 0 (unchanged behavior).

**New `test_settings.gd`:** with the real bus layout loaded, `Save.set_sound_on(false)` mutes `SFX` and leaves `Music` unmuted; `set_music_on(false)` mutes `Music`; turning back on unmutes. Opening `settings.tscn` reflects the saved values in the toggles; toggling a CheckButton calls through to `Save`.

**New `test_menu_flow_scene.gd`:**
- Title: `WalletLabel` shows the temp-save wallet; Play → current scene becomes `main.tscn`.
- In-run: `PauseButton` → tree paused, menu visible; Resume → unpaused, menu hidden.
- `NOTIFICATION_APPLICATION_FOCUS_OUT` → menu opens; Back while open → resumes.
- Revive prompt showing → PauseButton and focus-out do not open the menu.
- Pause-Restart with `treats_collected = 6`, wallet 4 → wallet 10, scene reloaded, unpaused.
- Pause-Home → wallet banked once, current scene is `title.tscn`, unpaused.
- Run-over reached via No on the revive prompt (which banks), then Home → no second bank, current scene `title.tscn`.
- Run-over Retry → scene reloaded, wallet unchanged by the second bank.

**Updated:** `test_treat_revive_scene.gd` restart cases call `restart_run()` instead of `_on_restart_button_pressed()`. All other existing tests and the smoke run must still pass.

## Out of scope (3.4a)

- First-run tutorial (3.4b); the Round-4 bark hint stays as-is until then.
- Shop screen (3.1b).
- Best distance on title / run-over (3.3).
- Actual music or SFX assets; any music player.
- Haptics.
- `GameManager` autoload — `main.gd` keeps owning run flow.
