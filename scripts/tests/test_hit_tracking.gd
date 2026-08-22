extends SceneTree

## Standalone headless unit test for player.gd's register_hit() rolling-window
## death check. Run with: godot --headless -s res://scripts/tests/test_hit_tracking.gd

func _init() -> void:
	var PlayerScript := load("res://scripts/player.gd")
	var ok := true

	# Three hits within the window: dies on the third, not before.
	var p = PlayerScript.new()
	p.tuning.hits_to_die = 3
	p.tuning.hit_window_s = 5.0

	if p.register_hit(0.0):
		push_error("FAIL: should not die on 1st hit")
		ok = false
	if p.register_hit(1.0):
		push_error("FAIL: should not die on 2nd hit")
		ok = false
	if not p.register_hit(2.0):
		push_error("FAIL: should die on 3rd hit within window")
		ok = false

	# Hits outside the rolling window get pruned -- a gap resets progress
	# toward death instead of accumulating forever.
	var p2 = PlayerScript.new()
	p2.tuning.hits_to_die = 3
	p2.tuning.hit_window_s = 5.0

	p2.register_hit(0.0)
	p2.register_hit(1.0)
	if p2.register_hit(20.0):
		push_error("FAIL: old hits outside the window must not count toward death")
		ok = false
	if p2.register_hit(20.5):
		push_error("FAIL: should not die with only 2 hits inside the window after the gap")
		ok = false
	if not p2.register_hit(21.0):
		push_error("FAIL: 3rd hit within the window after the gap should trigger death")
		ok = false

	if ok:
		print("PASS: register_hit rolling window")
	else:
		print("FAIL: register_hit rolling window")
	quit(0 if ok else 1)
