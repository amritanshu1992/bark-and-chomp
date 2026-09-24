# Phase 3.1a — Treat Wallet + Treat Revive: Design

**Date:** 2026-09-24
**Status:** Approved in conversation; awaiting written-spec review.
**Plan reference:** `bark_and_chomp_project_plan.md` §3.1, GDD §10.1 / §6.4, TDD §10.

## Scope decision

Project plan §3.1 bundles a treat wallet and a costume shop. It is split:

- **3.1a (this spec):** persistent treat wallet, treats bank at run end, wallet shown on run-over, `[50 treats]` revive option.
- **3.1b (later):** costume shop (catalog, buy/equip, preview, price ladder, earn-rate tuning). Deferred because there are no menus yet (Phase 3.4) and no costume art/bark SFX sourced — the GDD §9.5 costume rule can't be met with placeholders.

This split is a divergence from the plan and gets recorded in `handoff.md`.

## Goals / success criteria

- Treats collected in a run survive into the next run and the next app launch.
- A player can revive with treats when wallet + this run's treats ≥ `tuning.revive_cost_treats` (50).
- Spending never touches the in-run Zoomie meter (GDD §10.1).
- A corrupt or missing save never crashes the game.
- Running the headless tests never touches the real save file.

## 1. `Save` autoload

New `scripts/save.gd` (`extends Node`), registered in `project.godot` under `[autoload]` as `Save="*res://scripts/save.gd"`. An autoload rather than the static no-autoload pattern of `juice.gd`/`ad_service.gd`, because this one holds state that must survive `reload_current_scene()` (the Restart button) and be loaded once at boot.

**Save file:** `user://save.json`

```json
{"version": 1, "wallet": 0}
```

Only the wallet for now. Later phases (best distance 3.3, owned/equipped costume 3.1b, streak 3.3, settings) add fields and handle `version`.

**API**

| Member | Behavior |
|---|---|
| `var save_path := "user://save.json"` | Overridable by tests. |
| `func reload() -> void` | Reads `save_path`. Missing file → defaults. Unparseable JSON, non-dictionary root, missing/non-numeric `wallet`, negative `wallet`, or `version != 1` → defaults + `push_warning`. Never errors out. `_ready()` calls this. |
| `func get_wallet() -> int` | Current balance. |
| `func add_treats(n: int) -> void` | `n <= 0` is a no-op. Otherwise adds and writes. |
| `func try_spend(n: int) -> bool` | `n < 0` or `n > wallet` → `false`, no change, no write. Otherwise subtracts, writes, returns `true`. `n == 0` → `true`, no write. |

**Write policy:** every mutation writes the whole file immediately (tiny file; survives Android killing the app). A failed write → `push_warning`, in-memory value kept.

## 2. Banking

Banking happens exactly once per run, when the run truly ends — not at the first death, since a revive may follow.

- `main.gd::_show_run_over()` calls `Save.add_treats(player.treats_collected)` before building the label.
- Run-over label becomes: `Run over!\nDistance: %.0fm\nTreats: +%d\nWallet: %d`.
- Quitting the app mid-run forfeits that run's treats (accepted; normal for the genre).

## 3. Treat revive

**UI** (`scenes/main.tscn`, under `UI/ReviveBg`):

- New `TreatButton` (Button) placed between `WatchAdButton` (y 680–780) and `NoButton`; `NoButton` moves down to make room. Exact offsets decided in the plan; all stay within the 720×1280 base viewport.
- Connected to `main.gd::_on_treat_button_pressed`.

**Prompt setup** — when `_on_player_died` shows the revive prompt, it calls `_refresh_treat_button()`:

- `available = Save.get_wallet() + player.treats_collected`
- `cost = player.tuning.revive_cost_treats`
- Affordable: `disabled = false`, text `"%d treats" % cost`.
- Not affordable: `disabled = true`, text `"%d treats\n(you have %d)" % [cost, available]`.

**Spend** — `_on_treat_button_pressed()`:

1. Recompute `available`; if `< cost`, return (defensive — button should be disabled).
2. `from_run = min(cost, player.treats_collected)`; `player.treats_collected -= from_run`.
3. `Save.try_spend(cost - from_run)` (guaranteed to succeed after step 1).
4. `_do_revive()`.

**Refactor:** `_on_revive_ad_success()` body becomes `_do_revive()` (hide prompt, `rival.clear_hazards()`, clear on-screen obstacle, `player.revive()`); the ad callback calls it. One revive per run still enforced by `player.can_offer_revive()`. Meter untouched on both paths.

## 4. Tests

All headless `extends SceneTree` scripts, run as documented in `handoff.md`.

**Verified during design:** Godot 4.7.1 instantiates autoloads (and runs their `_ready()`) under `-s` test scripts. Therefore every test that runs `main.tscn` must first set `Save.save_path` to a temp path under `user://` (e.g. `user://test_save_<name>.json`), delete it if present, and call `Save.reload()` — before instantiating the scene. Tests delete their temp file on exit.

**New `scripts/tests/test_save.gd`** (unit, fresh `save.gd` instance on a temp path, not the autoload):
- Missing file → wallet 0.
- `add_treats(30)` → 30; persisted: a second instance on the same path reads 30.
- `try_spend(40)` with 30 → `false`, still 30. `try_spend(20)` → `true`, 10.
- `add_treats(-5)` and `try_spend(-5)` → no change.
- Corrupt file (`"not json"`) → 0, no crash.
- `{"version": 99, "wallet": 500}` → 0.
- `{"version": 1, "wallet": -4}` → 0.

**New `scripts/tests/test_treat_revive_scene.gd`** (integration, real `main.tscn`):
- Wallet 40 (via temp save), set `player.treats_collected = 30`, die → prompt shown, `TreatButton` enabled. Press → tree unpaused, `treats_collected == 0`, wallet 20, player invincible. Wait out grace, die again → run-over shown, wallet still 20 (nothing left to bank).
- Fresh scene: wallet 10, `treats_collected = 5`, die → `TreatButton` disabled, text contains `"you have 15"`.
- Banking: wallet 0, `treats_collected = 7`, die, press No → wallet 7, label contains `"+7"`.

**Updated `scripts/tests/test_revive_scene.gd`:** redirect `Save` to a temp path before loading the scene.

**Unchanged:** the other existing tests don't touch `Save`; all must still pass, plus the smoke run.

## Out of scope (3.1a)

- Costume shop and everything in §3.1b.
- Chomp paying out treats (TDD §7) — belongs with 3.1b earn-rate tuning.
- HUD wallet display during a run.
- Best distance / high score (3.3).
- `GameManager` autoload / run-lifecycle state machine — `main.gd` keeps owning the death → revive → run-over flow.
- Save migration (only version 1 exists).
