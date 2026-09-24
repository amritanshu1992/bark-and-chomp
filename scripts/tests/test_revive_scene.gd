extends SceneTree

## Headless integration test for Phase 3.2's revive flow through the real
## main.tscn: die -> revive prompt -> Watch Ad -> resume with hazards cleared
## and grace invincibility -> second death skips the prompt -> run-over.
## Run with: godot --headless -s res://scripts/tests/test_revive_scene.gd

func _init() -> void:
	_run.call_deferred()

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
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame

	var player: Node = main.get_node("Player")
	var rival: Node = main.get_node("Rival")
	var revive_bg: CanvasItem = main.get_node("UI/ReviveBg")
	var run_over_bg: CanvasItem = main.get_node("UI/RunOverBg")

	# Put a projectile in flight so there's a hazard to clear.
	rival._throw_projectile()

	for i in player.tuning.hits_to_die:
		player._register_hit_and_maybe_die()
	if not paused:
		push_error("FAIL: death should pause the tree")
		ok = false
	if not revive_bg.visible or run_over_bg.visible:
		push_error("FAIL: first death should show the revive prompt, not run-over")
		ok = false

	main._on_watch_ad_button_pressed()
	if paused:
		push_error("FAIL: a successful revive should unpause the tree")
		ok = false
	if revive_bg.visible:
		push_error("FAIL: revive prompt should hide after Watch Ad")
		ok = false
	if not player.is_invincible():
		push_error("FAIL: player should have grace invincibility right after revive")
		ok = false
	for child in rival.get_children():
		if child.has_method("cancel") and child.visible:
			push_error("FAIL: in-flight projectiles should be cleared on revive")
			ok = false

	# Let the grace window run out, then die again: no second revive offered.
	await create_timer(player.tuning.revive_grace_s + 0.2).timeout
	if player.is_invincible():
		push_error("FAIL: grace invincibility should have expired")
		ok = false
	for i in player.tuning.hits_to_die:
		player._register_hit_and_maybe_die()
	if revive_bg.visible or not run_over_bg.visible:
		push_error("FAIL: second death should go straight to run-over")
		ok = false

	paused = false
	_delete_temp()
	if ok:
		print("PASS: revive flow scene")
	else:
		print("FAIL: revive flow scene")
	quit(0 if ok else 1)

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
