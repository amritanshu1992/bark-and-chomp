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
