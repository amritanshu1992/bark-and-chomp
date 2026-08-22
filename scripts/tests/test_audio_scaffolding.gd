extends SceneTree

## Standalone headless unit test for the audio scaffolding's null-stream
## no-op safety (player.gd/rival_base.gd _play_sfx/_play_loop/_stop_loop).
## Every stream is null until real SFX from docs/asset_list.md drop in, so
## these calls must never error even though nothing is actually playable
## yet. Instantiates the real scenes (not bare scripts) so the SfxPlayer/
## LoopPlayer @onready nodes resolve as they would in the running game.
## Run with: godot --headless -s res://scripts/tests/test_audio_scaffolding.gd

func _init() -> void:
	var ok := true

	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame  # let _ready() run so @onready nodes resolve
	for sfx_name in ["blast", "whimper", "chomp", "treat", "nonexistent"]:
		player._play_sfx(sfx_name)
	for loop_name in ["charge", "zoomies", "nonexistent"]:
		player._play_loop(loop_name)
	player._stop_loop()
	if player.sfx_player.playing or player.loop_player.playing:
		push_error("FAIL: null streams must never actually start playback")
		ok = false

	var rival = load("res://scenes/rival.tscn").instantiate()
	# rival_base.gd's _ready() looks up "../Player" -- give it a sibling first.
	root.add_child(rival)
	await process_frame  # let _ready() run so @onready nodes resolve
	for sfx_name in ["panic", "defeat", "nonexistent"]:
		rival._play_sfx(sfx_name)
	for loop_name in ["whir", "nonexistent"]:
		rival._play_loop(loop_name)
	rival._stop_loop()
	if rival.sfx_player.playing or rival.loop_player.playing:
		push_error("FAIL: null streams must never actually start playback")
		ok = false

	print("PASS: audio scaffolding no-ops safely on null streams" if ok else "FAIL")
	quit(0 if ok else 1)
