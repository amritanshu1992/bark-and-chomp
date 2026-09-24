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
