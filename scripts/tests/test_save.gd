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
	var probe: Node = save_script.new()
	var has_settings: bool = probe.has_method("is_sound_on")
	probe.free()
	if not has_settings:
		print("FAIL: save wallet (settings API missing)")
		quit(1)
		return

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

	# --- Phase 3.4a: settings + save format v2 ---
	_delete_temp()
	var s3: Node = _fresh(save_script)
	_check(s3.is_sound_on() and s3.is_music_on(), "a missing save file should mean sound and music on")
	s3.set_sound_on(false)
	s3.free()
	var s4: Node = _fresh(save_script)
	_check(not s4.is_sound_on(), "set_sound_on(false) should persist to disk")
	_check(s4.is_music_on(), "music should stay on when only sound was turned off")
	s4.set_music_on(false)
	s4.free()
	var s5: Node = _fresh(save_script)
	_check(not s5.is_music_on(), "set_music_on(false) should persist to disk")
	s5.free()

	# v1 saves migrate: wallet kept, default settings, next write is v2.
	_write_raw('{"version": 1, "wallet": 42}')
	var s6: Node = _fresh(save_script)
	_check(s6.get_wallet() == 42, "a v1 save should keep its wallet (got %d)" % s6.get_wallet())
	_check(s6.is_sound_on() and s6.is_music_on(), "a v1 save should get default settings")
	s6.add_treats(1)
	s6.free()
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	_check(typeof(on_disk) == TYPE_DICTIONARY and on_disk.get("version") == 2 and typeof(on_disk.get("settings")) == TYPE_DICTIONARY and on_disk.get("wallet") == 43,
		"writing after a v1 load should store format v2 with settings and wallet 43 (got %s)" % str(on_disk))

	# Broken settings never cost the wallet.
	_write_raw('{"version": 2, "wallet": 9, "settings": "junk"}')
	var s7: Node = _fresh(save_script)
	_check(s7.get_wallet() == 9, "malformed settings must not reset the wallet")
	_check(s7.is_sound_on() and s7.is_music_on(), "malformed settings should fall back to on")
	s7.free()
	_write_raw('{"version": 2, "wallet": 9, "settings": {"sound": false, "music": 7}}')
	var s8: Node = _fresh(save_script)
	_check(s8.get_wallet() == 9, "a bad single setting must not reset the wallet")
	_check(not s8.is_sound_on(), "a valid sound=false should load")
	_check(s8.is_music_on(), "a non-bool music setting should fall back to on")
	s8.free()

	_check(_wallet_from_raw(save_script, '{"version": 2, "wallet": 5, "settings": {"sound": true, "music": true}}') == 5, "a valid v2 save should load its wallet")
	_check(_wallet_from_raw(save_script, '{"version": 3, "wallet": 5}') == 0, "an unknown newer version should reset to 0")

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

func _write_raw(raw: String) -> void:
	var f := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	f.store_string(raw)
	f.close()

func _wallet_from_raw(save_script: GDScript, raw: String) -> int:
	_write_raw(raw)
	var s: Node = _fresh(save_script)
	var wallet: int = s.get_wallet()
	s.free()
	return wallet

func _delete_temp() -> void:
	if FileAccess.file_exists(TEMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
