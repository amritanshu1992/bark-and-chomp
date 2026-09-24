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
