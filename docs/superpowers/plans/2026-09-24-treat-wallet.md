# Phase 3.1a Treat Wallet + Treat Revive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Treats collected in a run bank into a persistent wallet at run end, and the revive prompt gains a `[50 treats]` option paid from this run's treats first, then the wallet.

**Architecture:** A new `Save` autoload (`scripts/save.gd`) owns the wallet and a tiny JSON save file, writing on every change. `main.gd` (which already owns death → revive → run-over) banks treats in `_show_run_over()` and drives a new `TreatButton` on the existing `UI/ReviveBg` prompt; the ad and treat revive paths share one `_do_revive()`.

**Tech Stack:** Godot 4.7.1, GDScript 2.0, headless `extends SceneTree` test scripts.

**Spec:** `docs/superpowers/specs/2026-09-24-treat-wallet-design.md`

## Global Constraints

- Godot console exe: `/c/Godot_v4.7.1-stable_win64/Godot_v4.7.1-stable_win64_console.exe` (Git Bash path). Below, `$GODOT` means this path; set it with `GODOT=/c/Godot_v4.7.1-stable_win64/Godot_v4.7.1-stable_win64_console.exe`.
- Run a test: `"$GODOT" --headless --path . -s res://scripts/tests/<name>.gd` — prints a `PASS:`/`FAIL:` line, exits 0/1.
- Save file: `user://save.json`, contents exactly `{"version": 1, "wallet": N}`.
- Revive cost comes from `player.tuning.revive_cost_treats` (default 50) — never hardcode 50 in game code.
- Spending never touches the Zoomie meter (`player.meter`); only `player.treats_collected` and the wallet.
- One revive per run, still enforced by `player.can_offer_revive()`.
- Tests must never read/write the real `user://save.json`. Autoloads **are** instantiated under `-s` (verified), so every scene test sets `Save.save_path` to a temp `user://test_save_*.json`, deletes it, and calls `Save.reload()` **before** instantiating `main.tscn`, and deletes the temp file on exit. Test scripts reach the autoload via `root.get_node("Save")`, not the bare `Save` identifier.
- Line endings: `project.godot` and `scenes/main.tscn` are **CRLF**; `scripts/main.gd` and the test scripts are LF. Preserve each file's existing endings (check with `file <path>` after editing).
- GDScript gotcha (seen repeatedly in this repo): `var x := <expression on an untyped/duck-typed node>` fails type inference. Use an explicit type (`var x: int = player.treats_collected`).

## Review Focus

- Double-tapping the treat button: the second press (after the revive already happened) must not spend again → Task 3, scenario A.
- Exactly affordable (wallet + run == cost): button enabled, both piles end at 0 → Task 3, scenario B.
- Run treats alone cover the cost: wallet must be untouched → Task 3, scenario C.
- A valid save file read back from disk: JSON numbers parse as floats in Godot, so `"wallet": 12` must load as 12, not be rejected as "non-integer" → Task 1 test.
- Treats picked up after a treat revive bank at the final run-over, but spent treats aren't banked again → Task 3, scenario A.

---

### Task 1: `Save` autoload

**Files:**
- Create: `scripts/save.gd`
- Create: `scripts/tests/test_save.gd`
- Modify: `project.godot` (add an `[autoload]` section between `[application]` and `[display]`)

**Interfaces:**
- Produces (autoload singleton named `Save`, a `Node`):
  - `var save_path: String` (default `"user://save.json"`)
  - `func reload() -> void`
  - `func get_wallet() -> int`
  - `func add_treats(n: int) -> void`
  - `func try_spend(n: int) -> bool`

- [ ] **Step 1: Write the failing test** — create `scripts/tests/test_save.gd`:

```gdscript
extends SceneTree

## Standalone headless unit test for Phase 3.1a's Save autoload script
## (scripts/save.gd), exercised on fresh instances pointed at a temp file --
## never the real user://save.json. Corrupt-file cases print push_warning
## lines; that's expected.
## Run with: godot --headless --path . -s res://scripts/tests/test_save.gd

const TEMP_SAVE := "user://test_save_unit.json"
const SAVE_SCRIPT := "res://scripts/save.gd"

var ok := true

func _init() -> void:
	if not ResourceLoader.exists(SAVE_SCRIPT):
		print("FAIL: save wallet (%s missing)" % SAVE_SCRIPT)
		quit(1)
		return
	var save_script: GDScript = load(SAVE_SCRIPT)

	_delete_temp()
	var s: Node = _fresh(save_script)
	_check(s.get_wallet() == 0, "a missing save file should mean a wallet of 0")

	s.add_treats(30)
	_check(s.get_wallet() == 30, "add_treats(30) should give 30")
	var s2: Node = _fresh(save_script)
	_check(s2.get_wallet() == 30, "the wallet should persist to disk and reload as 30")
	s2.free()

	_check(not s.try_spend(40), "try_spend beyond the balance should fail")
	_check(s.get_wallet() == 30, "a failed try_spend must not change the wallet")
	_check(s.try_spend(20), "try_spend within the balance should succeed")
	_check(s.get_wallet() == 10, "try_spend(20) from 30 should leave 10")

	s.add_treats(-5)
	_check(s.get_wallet() == 10, "add_treats with a negative amount must be a no-op")
	_check(not s.try_spend(-5), "try_spend with a negative amount should fail")
	_check(s.get_wallet() == 10, "a negative try_spend must not change the wallet")
	_check(s.try_spend(0), "spending 0 should succeed")
	_check(s.get_wallet() == 10, "spending 0 must not change the wallet")
	s.free()

	# JSON numbers come back from the parser as floats -- a whole-number
	# wallet must still load.
	_check(_wallet_from_raw(save_script, '{"version": 1, "wallet": 12}') == 12, "a valid save file should load its wallet")
	_check(_wallet_from_raw(save_script, "not json") == 0, "a corrupt file should reset to 0")
	_check(_wallet_from_raw(save_script, "[1, 2, 3]") == 0, "a non-object root should reset to 0")
	_check(_wallet_from_raw(save_script, '{"version": 99, "wallet": 500}') == 0, "an unknown version should reset to 0")
	_check(_wallet_from_raw(save_script, '{"version": 1, "wallet": -4}') == 0, "a negative wallet should reset to 0")
	_check(_wallet_from_raw(save_script, '{"version": 1, "wallet": 2.5}') == 0, "a fractional wallet should reset to 0")
	_check(_wallet_from_raw(save_script, '{"version": 1, "wallet": "lots"}') == 0, "a non-numeric wallet should reset to 0")
	_check(_wallet_from_raw(save_script, '{"version": 1}') == 0, "a missing wallet should reset to 0")

	_delete_temp()
	if ok:
		print("PASS: save wallet")
	else:
		print("FAIL: save wallet")
	quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		ok = false

func _fresh(save_script: GDScript) -> Node:
	var s: Node = save_script.new()
	s.save_path = TEMP_SAVE
	s.reload()
	return s

func _wallet_from_raw(save_script: GDScript, raw: String) -> int:
	var f := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	f.store_string(raw)
	f.close()
	var s: Node = _fresh(save_script)
	var wallet: int = s.get_wallet()
	s.free()
	return wallet

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `"$GODOT" --headless --path . -s res://scripts/tests/test_save.gd; echo "exit $?"`
Expected: `FAIL: save wallet (res://scripts/save.gd missing)`, `exit 1`.

- [ ] **Step 3: Implement** — create `scripts/save.gd` (LF endings):

```gdscript
extends Node

## Phase 3.1a: persistent save data (TDD Sec10), registered as the `Save`
## autoload. Unlike the static juice.gd/ad_service.gd this holds state -- the
## treat wallet -- which must survive reload_current_scene() (the Restart
## button) and load once at boot. Only the wallet for now; later phases add
## fields (best distance, costumes, streak) under a bumped VERSION.
## Every change writes the whole (tiny) file immediately, so Android killing
## the app never loses banked treats.

const VERSION := 1

var save_path := "user://save.json"
var _wallet: int = 0

func _ready() -> void:
	reload()

## Missing file -> fresh wallet. Anything unreadable, malformed, or from an
## unknown version -> fresh wallet + a warning, never a crash.
func reload() -> void:
	_wallet = 0
	if not FileAccess.file_exists(save_path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK:
		push_warning("Save: %s is not valid JSON; starting fresh" % save_path)
		return
	if not _is_valid(json.data):
		push_warning("Save: %s has an unexpected shape or version; starting fresh" % save_path)
		return
	_wallet = int(json.data["wallet"])

func get_wallet() -> int:
	return _wallet

func add_treats(n: int) -> void:
	if n <= 0:
		return
	_wallet += n
	_write()

func try_spend(n: int) -> bool:
	if n < 0 or n > _wallet:
		return false
	if n == 0:
		return true
	_wallet -= n
	_write()
	return true

## JSON numbers always parse as floats, so "whole number" is checked by value
## rather than by TYPE_INT.
static func _is_valid(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var version: Variant = data.get("version")
	var wallet: Variant = data.get("wallet")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version != VERSION:
		return false
	if typeof(wallet) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return wallet >= 0 and wallet == floorf(wallet)

func _write() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not write %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify({"version": VERSION, "wallet": _wallet}))
```

- [ ] **Step 4: Register the autoload** — in `project.godot` (CRLF), insert between the `[application]` block and `[display]`:

```ini
[autoload]

Save="*res://scripts/save.gd"

```

Then regenerate the editor caches / `.uid` files: `"$GODOT" --headless --path . --editor --quit`. Confirm `scripts/save.gd.uid` and `scripts/tests/test_save.gd.uid` now exist, and `file project.godot` still reports CRLF.

- [ ] **Step 5: Run the test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://scripts/tests/test_save.gd; echo "exit $?"`
Expected: `PASS: save wallet`, `exit 0` (push_warning lines for the corrupt cases are expected).

- [ ] **Step 6: Commit**

```bash
git add scripts/save.gd scripts/save.gd.uid scripts/tests/test_save.gd scripts/tests/test_save.gd.uid project.godot
git commit -m "Add Save autoload with persistent treat wallet (Phase 3.1a)"
```

---

### Task 2: Bank treats at run end

**Files:**
- Modify: `scripts/main.gd` (`_show_run_over()`)
- Modify: `scripts/tests/test_revive_scene.gd` (redirect `Save` to a temp file)
- Create: `scripts/tests/test_treat_revive_scene.gd`

**Interfaces:**
- Consumes: `Save.add_treats(n: int)`, `Save.get_wallet() -> int`, `Save.save_path`, `Save.reload()` from Task 1.
- Produces: run-over label format `"Run over!\nDistance: %.0fm\nTreats: +%d\nWallet: %d"`; the `test_treat_revive_scene.gd` harness (`_start`, `_die`, `_finish`, `_check`) that Task 3 extends.

- [ ] **Step 1: Keep the existing scene test off the real save** — in `scripts/tests/test_revive_scene.gd`, replace the start of `_run()`:

```gdscript
func _run() -> void:
	var ok := true
	var main: Node = load("res://scenes/main.tscn").instantiate()
```

with:

```gdscript
const TEMP_SAVE := "user://test_save_revive_scene.json"

func _run() -> void:
	var ok := true
	# The Save autoload is live under -s; point it at a temp file so this
	# test's run-over banking never touches the real user://save.json.
	var save: Node = root.get_node("Save")
	save.save_path = TEMP_SAVE
	_delete_temp()
	save.reload()
	var main: Node = load("res://scenes/main.tscn").instantiate()
```

and replace its ending:

```gdscript
	paused = false
	if ok:
		print("PASS: revive flow scene")
```

with:

```gdscript
	paused = false
	_delete_temp()
	if ok:
		print("PASS: revive flow scene")
```

and append at the end of the file:

```gdscript

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
```

- [ ] **Step 2: Write the failing banking test** — create `scripts/tests/test_treat_revive_scene.gd`:

```gdscript
extends SceneTree

## Headless integration test for Phase 3.1a through the real main.tscn:
## treats bank to the Save wallet at run end, and the [50 treats] revive
## option spends this run's treats first, then the wallet. The Save autoload
## is redirected to a temp file for every scenario -- never the real save.
## Run with: godot --headless --path . -s res://scripts/tests/test_treat_revive_scene.gd

const TEMP_SAVE := "user://test_save_treat_revive_scene.json"

var ok := true
var save: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("Save")
	await _test_bank_on_decline()
	_delete_temp()
	if ok:
		print("PASS: treat wallet + treat revive scene")
	else:
		print("FAIL: treat wallet + treat revive scene")
	quit(0 if ok else 1)

## Declining the revive ends the run: this run's treats bank to the wallet,
## the run-over screen shows them, and they're on disk.
func _test_bank_on_decline() -> void:
	var main: Node = await _start(0, 7)
	_die(main)
	main._on_no_button_pressed()
	var run_over_bg: CanvasItem = main.get_node("UI/RunOverBg")
	var label: Label = main.get_node("UI/RunOverBg/RunOverLabel")
	_check(run_over_bg.visible, "declining the revive should show run-over")
	_check(save.get_wallet() == 7, "run treats should bank to the wallet at run end (got %d)" % save.get_wallet())
	_check(label.text.contains("Treats: +7"), "run-over should show the banked treats, got: " + label.text)
	_check(label.text.contains("Wallet: 7"), "run-over should show the wallet total, got: " + label.text)
	save.reload()
	_check(save.get_wallet() == 7, "the banked wallet should be on disk")
	await _finish(main)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		ok = false

## Fresh temp save holding `wallet`, fresh main.tscn, and `run_treats`
## already collected this run.
func _start(wallet: int, run_treats: int) -> Node:
	paused = false
	save.save_path = TEMP_SAVE
	_delete_temp()
	save.reload()
	save.add_treats(wallet)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	main.get_node("Player").treats_collected = run_treats
	return main

func _die(main: Node) -> void:
	var player: Node = main.get_node("Player")
	for i in player.tuning.hits_to_die:
		player._register_hit_and_maybe_die()

func _finish(main: Node) -> void:
	paused = false
	main.queue_free()
	await process_frame

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
```

- [ ] **Step 3: Run it to verify it fails**

Run: `"$GODOT" --headless --path . -s res://scripts/tests/test_treat_revive_scene.gd; echo "exit $?"`
Expected: `FAIL: run treats should bank to the wallet at run end (got 0)` (plus the label failures), final `FAIL: treat wallet + treat revive scene`, `exit 1`.

- [ ] **Step 4: Implement banking** — in `scripts/main.gd`, replace `_show_run_over()`:

```gdscript
func _show_run_over() -> void:
	var distance_m: float = player.distance_traveled / player.PX_PER_UNIT
	run_over_label.text = "Run over!\nDistance: %.0fm\nTreats: %d" % [distance_m, player.treats_collected]
	run_over_bg.visible = true
```

with:

```gdscript
## The run is truly over here (no revive left or it was declined), so this
## is the one place this run's treats bank to the wallet (GDD 10.1).
func _show_run_over() -> void:
	var distance_m: float = player.distance_traveled / player.PX_PER_UNIT
	var banked: int = player.treats_collected
	Save.add_treats(banked)
	run_over_label.text = "Run over!\nDistance: %.0fm\nTreats: +%d\nWallet: %d" % [distance_m, banked, Save.get_wallet()]
	run_over_bg.visible = true
```

- [ ] **Step 5: Run both scene tests to verify they pass**

Run: `for t in test_treat_revive_scene test_revive_scene; do "$GODOT" --headless --path . -s res://scripts/tests/$t.gd 2>&1 | grep -E "^(PASS|FAIL)"; done`
Expected: `PASS: treat wallet + treat revive scene` and `PASS: revive flow scene`.

- [ ] **Step 6: Commit** (run `"$GODOT" --headless --path . --editor --quit` first so the new test's `.uid` exists)

```bash
git add scripts/main.gd scripts/tests/test_revive_scene.gd scripts/tests/test_treat_revive_scene.gd scripts/tests/test_treat_revive_scene.gd.uid
git commit -m "Bank run treats to the wallet at run end (Phase 3.1a)"
```

---

### Task 3: `[50 treats]` revive button

**Files:**
- Modify: `scenes/main.tscn` (CRLF — add `TreatButton`, move `NoButton`, add a connection)
- Modify: `scripts/main.gd` (full replacement below)
- Modify: `scripts/tests/test_treat_revive_scene.gd` (full replacement below)

**Interfaces:**
- Consumes: `Save.get_wallet()`, `Save.try_spend(n) -> bool` (Task 1); the test harness from Task 2; existing `player.treats_collected: int`, `player.tuning.revive_cost_treats: int`, `player.can_offer_revive()`, `player.revive()`, `rival.clear_hazards()`, `Obstacle.clear_if_on_screen()`.
- Produces: node `UI/ReviveBg/TreatButton` (Button); `main.gd` methods `_on_treat_button_pressed()`, `_refresh_treat_button()`, `_do_revive()`.

- [ ] **Step 1: Write the failing tests** — replace `scripts/tests/test_treat_revive_scene.gd` entirely with:

```gdscript
extends SceneTree

## Headless integration test for Phase 3.1a through the real main.tscn:
## treats bank to the Save wallet at run end, and the [50 treats] revive
## option spends this run's treats first, then the wallet. The Save autoload
## is redirected to a temp file for every scenario -- never the real save.
## Run with: godot --headless --path . -s res://scripts/tests/test_treat_revive_scene.gd

const TEMP_SAVE := "user://test_save_treat_revive_scene.json"

var ok := true
var save: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("Save")
	await _test_mixed_spend_then_bank()
	await _test_exact_cost()
	await _test_run_treats_only()
	await _test_unaffordable()
	await _test_bank_on_decline()
	_delete_temp()
	if ok:
		print("PASS: treat wallet + treat revive scene")
	else:
		print("FAIL: treat wallet + treat revive scene")
	quit(0 if ok else 1)

## Wallet 40 + run 30 affords 50: run treats go first (30), then the wallet
## (20). A second press must not spend again, and only treats picked up
## after the revive bank at the final run-over.
func _test_mixed_spend_then_bank() -> void:
	var main: Node = await _start(40, 30)
	var player: Node = main.get_node("Player")
	var button: Button = main.get_node_or_null("UI/ReviveBg/TreatButton")
	_check(button != null, "UI/ReviveBg/TreatButton should exist")
	if button == null:
		await _finish(main)
		return
	_check(player.tuning.revive_cost_treats == 50, "these scenarios assume the default 50-treat revive cost")
	_die(main)
	_check(main.get_node("UI/ReviveBg").visible, "first death should show the revive prompt")
	_check(not button.disabled, "40 wallet + 30 run treats should afford a 50-treat revive")
	_check(button.text == "50 treats", "affordable button text should be '50 treats', got: " + button.text)

	main._on_treat_button_pressed()
	_check(not paused, "a treat revive should unpause the tree")
	_check(not main.get_node("UI/ReviveBg").visible, "the revive prompt should hide after a treat revive")
	_check(player.treats_collected == 0, "this run's treats should be spent first (got %d)" % player.treats_collected)
	_check(save.get_wallet() == 20, "the wallet should cover the remaining 20 (got %d)" % save.get_wallet())
	_check(player.is_invincible(), "a treat revive should grant grace invincibility")

	main._on_treat_button_pressed()
	_check(save.get_wallet() == 20 and player.treats_collected == 0, "a second press after reviving must not spend again")

	await create_timer(player.tuning.revive_grace_s + 0.2).timeout
	player.treats_collected = 4
	_die(main)
	_check(main.get_node("UI/RunOverBg").visible, "second death should go straight to run-over")
	_check(save.get_wallet() == 24, "only the 4 treats collected after the revive should bank (got %d)" % save.get_wallet())
	await _finish(main)

## Wallet 20 + run 30 == 50 exactly: affordable, both piles end at 0.
func _test_exact_cost() -> void:
	var main: Node = await _start(20, 30)
	var player: Node = main.get_node("Player")
	var button: Button = main.get_node("UI/ReviveBg/TreatButton")
	_die(main)
	_check(not button.disabled, "exactly 50 available should be affordable")
	main._on_treat_button_pressed()
	_check(not paused, "exact-cost treat revive should resume the run")
	_check(player.treats_collected == 0 and save.get_wallet() == 0, "exact cost should empty both piles (run %d, wallet %d)" % [player.treats_collected, save.get_wallet()])
	await _finish(main)

## Run treats alone cover the cost: the wallet is untouched.
func _test_run_treats_only() -> void:
	var main: Node = await _start(5, 60)
	var player: Node = main.get_node("Player")
	_die(main)
	main._on_treat_button_pressed()
	_check(not paused, "run-treats-only revive should resume the run")
	_check(player.treats_collected == 10, "60 run treats minus 50 should leave 10 (got %d)" % player.treats_collected)
	_check(save.get_wallet() == 5, "the wallet must be untouched when run treats cover the cost (got %d)" % save.get_wallet())
	await _finish(main)

## Wallet 10 + run 5 can't afford 50: button disabled with the balance, and
## even a direct call does nothing.
func _test_unaffordable() -> void:
	var main: Node = await _start(10, 5)
	var player: Node = main.get_node("Player")
	var button: Button = main.get_node("UI/ReviveBg/TreatButton")
	_die(main)
	_check(button.disabled, "15 available should not afford a 50-treat revive")
	_check(button.text.contains("you have 15"), "unaffordable button should show the balance, got: " + button.text)
	main._on_treat_button_pressed()
	_check(paused, "an unaffordable treat revive must not resume the run")
	_check(main.get_node("UI/ReviveBg").visible, "an unaffordable press must leave the prompt up")
	_check(save.get_wallet() == 10 and player.treats_collected == 5, "an unaffordable press must not spend anything")
	await _finish(main)

## Declining the revive ends the run: this run's treats bank to the wallet,
## the run-over screen shows them, and they're on disk.
func _test_bank_on_decline() -> void:
	var main: Node = await _start(0, 7)
	_die(main)
	main._on_no_button_pressed()
	var run_over_bg: CanvasItem = main.get_node("UI/RunOverBg")
	var label: Label = main.get_node("UI/RunOverBg/RunOverLabel")
	_check(run_over_bg.visible, "declining the revive should show run-over")
	_check(save.get_wallet() == 7, "run treats should bank to the wallet at run end (got %d)" % save.get_wallet())
	_check(label.text.contains("Treats: +7"), "run-over should show the banked treats, got: " + label.text)
	_check(label.text.contains("Wallet: 7"), "run-over should show the wallet total, got: " + label.text)
	save.reload()
	_check(save.get_wallet() == 7, "the banked wallet should be on disk")
	await _finish(main)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		ok = false

## Fresh temp save holding `wallet`, fresh main.tscn, and `run_treats`
## already collected this run.
func _start(wallet: int, run_treats: int) -> Node:
	paused = false
	save.save_path = TEMP_SAVE
	_delete_temp()
	save.reload()
	save.add_treats(wallet)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	main.get_node("Player").treats_collected = run_treats
	return main

func _die(main: Node) -> void:
	var player: Node = main.get_node("Player")
	for i in player.tuning.hits_to_die:
		player._register_hit_and_maybe_die()

func _finish(main: Node) -> void:
	paused = false
	main.queue_free()
	await process_frame

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `"$GODOT" --headless --path . -s res://scripts/tests/test_treat_revive_scene.gd; echo "exit $?"`
Expected: `FAIL: UI/ReviveBg/TreatButton should exist`, then errors from the later scenarios (missing node / method), and no `PASS:` line. If Godot stops on a script error instead of printing the final `FAIL:` line, that's still red — confirm there's no `PASS:` line and move on.

- [ ] **Step 3: Add the button to the scene** — in `scenes/main.tscn` (CRLF; keep CRLF), insert this node block immediately **before** the `[node name="NoButton" ...]` block:

```ini
[node name="TreatButton" type="Button" parent="UI/ReviveBg"]
offset_left = 160.0
offset_top = 800.0
offset_right = 560.0
offset_bottom = 900.0
theme_override_font_sizes/font_size = 32
text = "50 treats"

```

In the `NoButton` block, change `offset_top = 820.0` → `offset_top = 930.0` and `offset_bottom = 890.0` → `offset_bottom = 1000.0`.

Append after the existing `NoButton` connection line:

```ini
[connection signal="pressed" from="UI/ReviveBg/TreatButton" to="." method="_on_treat_button_pressed"]
```

Verify: `file scenes/main.tscn` still says CRLF.

- [ ] **Step 4: Implement** — replace `scripts/main.gd` entirely with (LF endings):

```gdscript
extends Node2D

@onready var player: Node2D = $Player
@onready var rival: Node2D = $Rival
@onready var run_over_bg: ColorRect = $UI/RunOverBg
@onready var run_over_label: Label = $UI/RunOverBg/RunOverLabel
@onready var revive_bg: ColorRect = $UI/ReviveBg
@onready var treat_button: Button = $UI/ReviveBg/TreatButton

func _ready() -> void:
	player.died.connect(_on_player_died)

## Phase 3.2: first death each run offers a revive (GDD 6.4); declining it,
## or a second death, falls through to the run-over screen. The tree is
## already paused by player.gd; UI keeps working since the UI CanvasLayer is
## process_mode ALWAYS.
func _on_player_died() -> void:
	if player.can_offer_revive():
		_refresh_treat_button()
		revive_bg.visible = true
	else:
		_show_run_over()

## The run is truly over here (no revive left or it was declined), so this
## is the one place this run's treats bank to the wallet (GDD 10.1).
func _show_run_over() -> void:
	var distance_m: float = player.distance_traveled / player.PX_PER_UNIT
	var banked: int = player.treats_collected
	Save.add_treats(banked)
	run_over_label.text = "Run over!\nDistance: %.0fm\nTreats: +%d\nWallet: %d" % [distance_m, banked, Save.get_wallet()]
	run_over_bg.visible = true

## Phase 3.1a: the treat revive can draw on this run's (unbanked) treats as
## well as the wallet. Shown disabled with the balance when unaffordable, so
## the player learns the option exists.
func _revive_cost() -> int:
	return player.tuning.revive_cost_treats

func _treats_available() -> int:
	return Save.get_wallet() + player.treats_collected

func _refresh_treat_button() -> void:
	var cost := _revive_cost()
	var available := _treats_available()
	if available >= cost:
		treat_button.disabled = false
		treat_button.text = "%d treats" % cost
	else:
		treat_button.disabled = true
		treat_button.text = "%d treats\n(you have %d)" % [cost, available]

func _on_watch_ad_button_pressed() -> void:
	AdService.show_rewarded("revive", _do_revive)

## Spends this run's treats first, then the wallet. Never touches the Zoomie
## meter. Guarded so a stray second press (prompt already gone) or an
## unaffordable press does nothing.
func _on_treat_button_pressed() -> void:
	var cost := _revive_cost()
	if not revive_bg.visible or _treats_available() < cost:
		return
	var from_run: int = mini(cost, player.treats_collected)
	player.treats_collected -= from_run
	Save.try_spend(cost - from_run)
	_do_revive()

func _do_revive() -> void:
	revive_bg.visible = false
	rival.clear_hazards()
	# The single placed Obstacle may already be gone (Zoomies free it).
	var obstacle := get_node_or_null("Obstacle")
	if obstacle != null:
		obstacle.clear_if_on_screen()
	player.revive()

func _on_no_button_pressed() -> void:
	revive_bg.visible = false
	_show_run_over()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
```

- [ ] **Step 5: Run the scene tests to verify they pass**

Run: `for t in test_treat_revive_scene test_revive_scene; do "$GODOT" --headless --path . -s res://scripts/tests/$t.gd 2>&1 | grep -E "^(PASS|FAIL)"; done`
Expected: `PASS: treat wallet + treat revive scene` and `PASS: revive flow scene` (the latter proves the ad path still works through `_do_revive()`).

- [ ] **Step 6: Commit**

```bash
git add scenes/main.tscn scripts/main.gd scripts/tests/test_treat_revive_scene.gd
git commit -m "Add 50-treat revive option to the revive prompt (Phase 3.1a)"
```

---

### Task 4: Full verification, APK, handoff

**Files:**
- Modify: `handoff.md`

- [ ] **Step 1: Run every headless test**

Run:
```bash
for t in scripts/tests/test_*.gd; do "$GODOT" --headless --path . -s "res://$t" 2>&1 | grep -E "^(PASS|FAIL)"; done
```
Expected: exactly these 8 lines (order may differ), and zero `FAIL:` lines:
```
PASS: audio scaffolding no-ops safely on null streams
PASS: get_track_y
PASS: register_hit rolling window
PASS: juice helpers
PASS: revive flow
PASS: revive flow scene
PASS: save wallet
PASS: treat wallet + treat revive scene
```

- [ ] **Step 2: Smoke run**

Run: `"$GODOT" --headless --path . --quit-after 60; echo "exit $?"`
Expected: `exit 0`, no `SCRIPT ERROR` lines.

- [ ] **Step 3: Confirm tests left no files behind and didn't write the real save**

Run: `ls "$APPDATA/Godot/app_userdata/Bark and Chomp/"`
Expected: no `test_save_*.json` files. `save.json` should not exist unless the game has been played manually on this machine; if it does exist, its modification time must predate this task's test runs.

- [ ] **Step 4: Mutation check** — temporarily change `var from_run: int = mini(cost, player.treats_collected)` in `scripts/main.gd` to `var from_run: int = 0`, re-run `test_treat_revive_scene.gd`, confirm it prints `FAIL:` (wallet-first spending breaks scenarios A–C), then restore the line with `git checkout scripts/main.gd` and confirm it passes again.

- [ ] **Step 5: Rebuild the APK**

Run: `"$GODOT" --headless --path . --export-debug "Android" builds/android/bark_and_chomp.apk; echo "exit $?"`
Expected: `exit 0` (the pre-existing "no project icon" warning is harmless).

- [ ] **Step 6: Update `handoff.md`** — keep the file's existing line endings.
  - Bump "Last updated" to the session date with a one-line summary (3.1a built, headless-verified, not yet on-device).
  - In §2i, add a "What was built" list: `Save` autoload (first autoload in the project), banking in `_show_run_over()`, `TreatButton` + `_do_revive()` refactor, tests `test_save.gd` and `test_treat_revive_scene.gd`, `test_revive_scene.gd` redirected to a temp save, verification results (all tests, smoke, mutation check, APK).
  - In §3: item 1 becomes "confirm the revive flow **and** treat wallet on-device" — die with ≥50 treats available → `[50 treats]` enabled → revive; die with <50 → disabled with balance; run-over shows `+N` and wallet; restart the app → wallet persisted. Mark `3.1a` `[x]` (built, headless-verified, not yet on-device).

- [ ] **Step 7: Commit**

```bash
git add handoff.md
git commit -m "handoff: Phase 3.1a treat wallet built and headless-verified"
```
