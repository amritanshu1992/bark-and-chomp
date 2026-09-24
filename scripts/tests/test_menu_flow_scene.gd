extends SceneTree

## Headless integration test for Phase 3.4a scene flow through the real
## scenes: title -> run, pause menu, run-over Retry/Home. The Save autoload
## is redirected to a temp file for every scenario -- never the real save.
## Run with: godot --headless --path . -s res://scripts/tests/test_menu_flow_scene.gd

const TEMP_SAVE := "user://test_save_menu_flow_scene.json"
const TITLE := "res://scenes/title.tscn"
const MAIN := "res://scenes/main.tscn"

var ok := true
var save: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("Save")
	if not ResourceLoader.exists(TITLE):
		_check(false, "%s missing" % TITLE)
	else:
		await _test_title()
		await _test_run_over_retry()
		await _test_run_over_home()
		await _test_pause_resume()
		await _test_focus_out_and_back()
		await _test_pause_settings_while_paused()
		await _test_no_pause_over_modals()
		await _test_pause_restart_banks()
		await _test_pause_home_banks()
		await _test_pause_freezes_telegraph()
		await _test_pause_freezes_deflect_window()
		await _test_resume_drops_stale_hold()
	_delete_temp()
	if ok:
		print("PASS: menu flow scene")
	else:
		print("FAIL: menu flow scene")
	quit(0 if ok else 1)

## The app boots to the title; it shows the wallet; Settings opens and Back
## closes it; Play starts a run.
func _test_title() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == TITLE, "the title should be the main scene")
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back") == false, "Android Back must be handled, not auto-quit")
	_use_temp_save(15)
	var title: Node = await _open(TITLE)
	var wallet_label: Label = title.get_node("WalletLabel")
	_check(wallet_label.text == "Treats: 15", "the title should show the wallet (got '%s')" % wallet_label.text)
	var settings: Node = title.get_node("Settings")
	title.get_node("SettingsButton").pressed.emit()
	_check(settings.is_open(), "the Settings button should open the overlay")
	title.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not settings.is_open(), "Back should close the settings overlay first")
	title.get_node("PlayButton").pressed.emit()
	await _settle()
	_check(current_scene != null and current_scene.scene_file_path == MAIN, "Play should start a run")
	await _free_current()

## Declining the revive banks (2 + 5); Retry starts a fresh run without
## banking again.
func _test_run_over_retry() -> void:
	var main: Node = await _start_run(2, 5)
	_die(main)
	main._on_no_button_pressed()
	_check(save.get_wallet() == 7, "declining should bank the run (got %d)" % save.get_wallet())
	main.get_node("UI/RunOverBg/RetryButton").pressed.emit()
	_check(save.get_wallet() == 7, "Retry must not bank the same run again (got %d)" % save.get_wallet())
	await _settle()
	_check(current_scene != null and not is_instance_valid(main) and current_scene.scene_file_path == MAIN, "Retry should reload the run")
	_check(not paused, "Retry should leave the game unpaused")
	await _free_current()

## Home after declining: no second bank, lands on the title, and the title
## shows the wallet including this run's treats.
func _test_run_over_home() -> void:
	var main: Node = await _start_run(0, 7)
	_die(main)
	main._on_no_button_pressed()
	main.get_node("UI/RunOverBg/HomeButton").pressed.emit()
	_check(save.get_wallet() == 7, "a run's treats must bank exactly once (got %d)" % save.get_wallet())
	await _settle()
	_check(current_scene != null and current_scene.scene_file_path == TITLE, "Home should go to the title")
	_check(not paused, "Home should leave the game unpaused")
	if current_scene != null and current_scene.has_node("WalletLabel"):
		var label: Label = current_scene.get_node("WalletLabel")
		_check(label.text == "Treats: 7", "the title should show the banked wallet (got '%s')" % label.text)
	await _free_current()

func _pause_menu(main: Node) -> Node:
	return main.get_node("UI/PauseMenu")

func _test_pause_resume() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	_check(not menu.is_open(), "the pause menu should start hidden")
	main.get_node("UI/PauseButton").pressed.emit()
	_check(paused and menu.is_open(), "the pause button should pause and show the menu")
	menu.get_node("ResumeButton").pressed.emit()
	_check(not paused and not menu.is_open(), "Resume should unpause and hide the menu")
	await _free_current()

## Focus loss pauses; a second focus loss doesn't stack; Back resumes.
## Back while running opens the menu.
func _test_focus_out_and_back() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(paused and menu.is_open(), "losing focus should open the pause menu")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(paused and menu.is_open(), "a second focus loss should leave one open menu")
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not paused and not menu.is_open(), "Back with the menu open should resume")
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(paused and menu.is_open(), "Back while running should open the pause menu")
	menu.resume()
	await _free_current()

## Settings opened from the pause menu works while paused; Back closes the
## overlay first, then resumes.
func _test_pause_settings_while_paused() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	menu.open()
	menu.get_node("SettingsButton").pressed.emit()
	var settings: Node = menu.get_node("Settings")
	_check(settings.is_open(), "the Settings button should open the overlay")
	_check(settings.can_process(), "the settings overlay must keep processing while paused")
	var sound_toggle: CheckButton = settings.get_node("SoundToggle")
	sound_toggle.button_pressed = false
	_check(not save.is_sound_on(), "toggling Sound while paused should save it")
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not settings.is_open() and menu.is_open() and paused, "Back should close only the settings overlay")
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not paused and not menu.is_open(), "a second Back should resume")
	await _free_current()

## With the revive prompt (then the run-over panel) up, the pause button,
## focus loss, and Back must all do nothing.
func _test_no_pause_over_modals() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	var revive_bg: CanvasItem = main.get_node("UI/ReviveBg")
	_die(main)
	_check(revive_bg.visible, "setup: the revive prompt should be up")
	_poke_pause(main, menu)
	_check(not menu.is_open(), "nothing should open the pause menu over the revive prompt")
	_check(paused and revive_bg.visible, "the revive prompt should stay up and paused")
	main._on_no_button_pressed()
	_poke_pause(main, menu)
	_check(not menu.is_open(), "nothing should open the pause menu over the run-over panel")
	_check(paused, "the run-over panel should stay paused")
	await _free_current()

func _poke_pause(main: Node, menu: Node) -> void:
	main.get_node("UI/PauseButton").pressed.emit()
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	menu.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)

func _test_pause_restart_banks() -> void:
	var main: Node = await _start_run(4, 6)
	var menu: Node = _pause_menu(main)
	menu.open()
	menu.get_node("RestartButton").pressed.emit()
	_check(save.get_wallet() == 10, "pause-Restart should bank this run (got %d)" % save.get_wallet())
	await _settle()
	_check(current_scene != null and not is_instance_valid(main) and current_scene.scene_file_path == MAIN, "pause-Restart should reload the run")
	_check(not paused, "pause-Restart should leave the game unpaused")
	await _free_current()

func _test_pause_home_banks() -> void:
	var main: Node = await _start_run(1, 2)
	var menu: Node = _pause_menu(main)
	menu.open()
	menu.get_node("HomeButton").pressed.emit()
	_check(save.get_wallet() == 3, "pause-Home should bank this run (got %d)" % save.get_wallet())
	await _settle()
	_check(current_scene != null and current_scene.scene_file_path == TITLE, "pause-Home should go to the title")
	_check(not paused, "pause-Home should leave the game unpaused")
	await _free_current()

## Pausing mid wind-up must not use up the throw telegraph: nothing launches
## while paused, and the throw still happens after Resume.
func _test_pause_freezes_telegraph() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	var rival: Node = main.get_node("Rival")
	rival._first_throw_done = true
	rival._start_throw()
	menu.open()
	await create_timer(rival.tuning.throw_telegraph_s + 0.3).timeout
	_check(_in_flight(rival) == 0, "no projectile should launch while paused")
	_check(rival._state == rival.State.THROWING, "the rival should still be winding up while paused")
	menu.resume()
	await create_timer(rival.tuning.throw_telegraph_s + 0.2).timeout
	_check(_in_flight(rival) == 1 or rival._state != rival.State.THROWING, "the throw should complete after Resume")
	await _free_current()

## Pausing while the deflect hitbox is live must not use up its window.
func _test_pause_freezes_deflect_window() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	var player: Node = main.get_node("Player")
	player._on_bark_ready()
	menu.open()
	await create_timer(player.tuning.bark_hitbox_duration_s + 0.3).timeout
	_check(player.bark_hitbox.monitorable, "the deflect window should not run out while paused")
	menu.resume()
	await create_timer(player.tuning.bark_hitbox_duration_s + 0.2).timeout
	_check(not player.bark_hitbox.monitorable, "the deflect window should close after Resume")
	await _free_current()

## A hold that was in progress when the game paused must not turn into a
## charge (or stay a charge) after Resume -- the release was never seen.
func _test_resume_drops_stale_hold() -> void:
	var main: Node = await _start_run(0, 0)
	var menu: Node = _pause_menu(main)
	var player: Node = main.get_node("Player")
	var ic: Node = player.input_controller
	ic._on_touch(true)
	menu.open()
	await create_timer(ic.tuning.bark_threshold_ms / 1000.0 + 0.2).timeout
	menu.resume()
	await _settle()
	_check(ic.get_state_name() == "IDLE", "a hold interrupted by pause should reset to IDLE, got " + ic.get_state_name())
	_check(not player._is_charging, "the dog should not start charging after Resume")
	ic._on_touch(true)
	await create_timer(ic.tuning.bark_threshold_ms / 1000.0 + 0.2).timeout
	_check(ic.get_state_name() == "CHARGING", "setup: a real hold should charge")
	menu.open()
	menu.resume()
	await _settle()
	_check(ic.get_state_name() != "CHARGING", "a charge interrupted by pause should end")
	_check(not player._is_charging, "the dog should stop charging after Resume")
	await _free_current()

func _in_flight(rival: Node) -> int:
	var n := 0
	for child in rival.get_children():
		if child.has_method("cancel") and child.visible:
			n += 1
	return n

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		ok = false

func _use_temp_save(wallet: int) -> void:
	paused = false
	save.save_path = TEMP_SAVE
	_delete_temp()
	save.reload()
	save.add_treats(wallet)

func _open(scene_path: String) -> Node:
	var n: Node = load(scene_path).instantiate()
	root.add_child(n)
	current_scene = n
	for i in 5:
		await process_frame
	return n

## Fresh temp save holding `wallet`, fresh main.tscn, and `run_treats`
## already collected this run.
func _start_run(wallet: int, run_treats: int) -> Node:
	_use_temp_save(wallet)
	var main: Node = await _open(MAIN)
	main.get_node("Player").treats_collected = run_treats
	return main

func _die(main: Node) -> void:
	var player: Node = main.get_node("Player")
	for i in player.tuning.hits_to_die:
		player._register_hit_and_maybe_die()

## Scene changes are deferred: give them time to land.
func _settle() -> void:
	await process_frame
	await process_frame

func _free_current() -> void:
	paused = false
	if current_scene != null:
		current_scene.queue_free()
	await process_frame

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
