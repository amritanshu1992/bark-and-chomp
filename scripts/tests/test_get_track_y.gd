extends SceneTree

## Standalone headless unit test for player.gd's get_track_y() pure function.
## Run with: godot --headless -s res://scripts/tests/test_get_track_y.gd
## This project has no test framework installed, so this is a plain
## SceneTree-script runner test -- the only piece of this migration that's a
## pure function cheap enough to warrant one.

func _init() -> void:
	var PlayerScript := load("res://scripts/player.gd")
	var p = PlayerScript.new()
	p.distance_traveled = 500.0

	var ok := true

	if not is_equal_approx(p.get_track_y(500.0), p.BASELINE_Y):
		push_error("FAIL: progress == distance_traveled must render at BASELINE_Y")
		ok = false

	if not is_equal_approx(p.get_track_y(700.0), p.BASELINE_Y - 200.0):
		push_error("FAIL: progress ahead of distance_traveled must render above baseline (smaller Y)")
		ok = false

	if not is_equal_approx(p.get_track_y(300.0), p.BASELINE_Y + 200.0):
		push_error("FAIL: progress behind distance_traveled must render below baseline (larger Y)")
		ok = false

	if ok:
		print("PASS: get_track_y")
	else:
		print("FAIL: get_track_y")
	quit(0 if ok else 1)
