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
