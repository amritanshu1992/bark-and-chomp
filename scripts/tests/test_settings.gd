extends SceneTree

## Headless test for Phase 3.4a settings: the SFX/Music audio buses exist,
## Save's Sound/Music settings mute them, gameplay audio players route to
## SFX, and the reusable settings overlay reads/writes Save. Uses a temp
## save file -- never the real user://save.json.
## Run with: godot --headless --path . -s res://scripts/tests/test_settings.gd

const TEMP_SAVE := "user://test_save_settings.json"
const SETTINGS_SCENE := "res://scenes/settings.tscn"

var ok := true
var save: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	save = root.get_node("Save")
	save.save_path = TEMP_SAVE
	_delete_temp()
	save.reload()

	var sfx := AudioServer.get_bus_index("SFX")
	var music := AudioServer.get_bus_index("Music")
	_check(sfx != -1 and music != -1, "default_bus_layout.tres should define SFX and Music buses")
	if sfx != -1 and music != -1:
		_check(not AudioServer.is_bus_mute(sfx) and not AudioServer.is_bus_mute(music), "a fresh save should leave both buses unmuted")
		save.set_sound_on(false)
		_check(AudioServer.is_bus_mute(sfx), "Sound off should mute SFX")
		_check(not AudioServer.is_bus_mute(music), "Sound off must not mute Music")
		save.set_music_on(false)
		_check(AudioServer.is_bus_mute(music), "Music off should mute Music")
		save.set_sound_on(true)
		save.set_music_on(true)
		_check(not AudioServer.is_bus_mute(sfx) and not AudioServer.is_bus_mute(music), "turning both back on should unmute both")

	for path in ["res://scenes/player.tscn", "res://scenes/rival.tscn"]:
		var inst: Node = load(path).instantiate()
		for player_name in ["SfxPlayer", "LoopPlayer"]:
			var p: AudioStreamPlayer = inst.get_node(player_name)
			_check(p.bus == &"SFX", "%s/%s should play on the SFX bus (got %s)" % [path, player_name, p.bus])
		inst.free()

	if not ResourceLoader.exists(SETTINGS_SCENE):
		_check(false, "%s missing" % SETTINGS_SCENE)
	else:
		await _test_overlay()

	_delete_temp()
	if ok:
		print("PASS: settings")
	else:
		print("FAIL: settings")
	quit(0 if ok else 1)

func _test_overlay() -> void:
	save.set_sound_on(false)
	save.set_music_on(true)
	var panel: Control = load(SETTINGS_SCENE).instantiate()
	root.add_child(panel)
	await process_frame
	_check(not panel.is_open(), "the settings overlay should start hidden")
	panel.open()
	_check(panel.is_open(), "open() should show the overlay")
	var sound_toggle: CheckButton = panel.get_node("SoundToggle")
	var music_toggle: CheckButton = panel.get_node("MusicToggle")
	_check(not sound_toggle.button_pressed, "the Sound toggle should reflect the saved (off) value")
	_check(music_toggle.button_pressed, "the Music toggle should reflect the saved (on) value")
	music_toggle.button_pressed = false
	_check(not save.is_music_on(), "switching Music off should save it")
	sound_toggle.button_pressed = true
	_check(save.is_sound_on(), "switching Sound on should save it")
	var version_label: Label = panel.get_node("VersionLabel")
	_check(version_label.text.begins_with("v"), "the version line should be filled in (got '%s')" % version_label.text)
	var close_button: Button = panel.get_node("CloseButton")
	close_button.pressed.emit()
	_check(not panel.is_open(), "Back should close the overlay")
	panel.queue_free()
	await process_frame

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		ok = false

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
