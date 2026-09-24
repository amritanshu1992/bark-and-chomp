extends Node

## Persistent save data (TDD Sec10), registered as the `Save` autoload.
## Holds state that must survive reload_current_scene() and load once at
## boot: the treat wallet (Phase 3.1a) and the Sound/Music settings (Phase
## 3.4a). Every change writes the whole (tiny) file immediately, so Android
## killing the app never loses banked treats.
##
## Format v2: {"version": 2, "wallet": N, "settings": {"sound": b, "music": b}}.
## v1 files ({"version": 1, "wallet": N}) migrate: wallet kept, default
## settings, stored as v2 on the next write. Bad settings never cost the
## wallet.

const VERSION := 2

var save_path := "user://save.json"
var _wallet: int = 0
var _sound_on := true
var _music_on := true

func _ready() -> void:
	reload()

func reload() -> void:
	_wallet = 0
	_sound_on = true
	_music_on = true
	_load()
	_apply_audio()

## Missing file -> defaults. Anything unreadable, malformed, or from an
## unknown version -> defaults + a warning, never a crash.
func _load() -> void:
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
	if json.data["version"] == 1:
		return  # v1 had no settings; defaults stand.
	_load_settings(json.data.get("settings"))

func _load_settings(settings: Variant) -> void:
	if typeof(settings) != TYPE_DICTIONARY:
		push_warning("Save: settings missing or malformed in %s; using defaults" % save_path)
		return
	var sound: Variant = settings.get("sound")
	var music: Variant = settings.get("music")
	if typeof(sound) == TYPE_BOOL:
		_sound_on = sound
	if typeof(music) == TYPE_BOOL:
		_music_on = music
	if typeof(sound) != TYPE_BOOL or typeof(music) != TYPE_BOOL:
		push_warning("Save: a setting in %s is missing or not a bool; using its default" % save_path)

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

func is_sound_on() -> bool:
	return _sound_on

func is_music_on() -> bool:
	return _music_on

func set_sound_on(on: bool) -> void:
	_sound_on = on
	_apply_audio()
	_write()

func set_music_on(on: bool) -> void:
	_music_on = on
	_apply_audio()
	_write()

func _apply_audio() -> void:
	_set_bus_mute("SFX", not _sound_on)
	_set_bus_mute("Music", not _music_on)

## A missing bus (e.g. no bus layout loaded) is skipped, never an error.
static func _set_bus_mute(bus_name: String, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, mute)

## Accepts v1 and v2. JSON numbers always parse as floats, so "whole number"
## is checked by value rather than by TYPE_INT.
static func _is_valid(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var version: Variant = data.get("version")
	var wallet: Variant = data.get("wallet")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or (version != 1 and version != VERSION):
		return false
	if typeof(wallet) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return wallet >= 0 and wallet == floorf(wallet)

func _write() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Save: could not write %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify({
		"version": VERSION,
		"wallet": _wallet,
		"settings": {"sound": _sound_on, "music": _music_on},
	}))
