extends SceneTree

## Standalone headless unit test for the Phase 2 juice helpers (scripts/juice.gd)
## and player.gd's shake_camera() state.
## Run with: godot --headless -s res://scripts/tests/test_juice.gd

func _init() -> void:
	var ok := true

	# Juice.spawn_burst: adds a one-shot CPUParticles2D under the given parent
	# and starts it emitting immediately.
	var container := Node2D.new()
	root.add_child(container)
	Juice.spawn_burst(container, Vector2(10.0, 20.0), Color.RED, 5)
	await process_frame
	if container.get_child_count() != 1:
		push_error("FAIL: spawn_burst should add exactly one particle node")
		ok = false
	else:
		var particles: CPUParticles2D = container.get_child(0)
		if not particles.emitting:
			push_error("FAIL: spawn_burst's particles should be emitting")
			ok = false
		if not particles.one_shot:
			push_error("FAIL: spawn_burst's particles should be one_shot")
			ok = false

	# Juice.hit_stop: drops Engine.time_scale immediately (synchronously, before
	# its first await suspends it -- checked with no intervening yield, since a
	# yield's real-world timing isn't fixed and could race the restore below),
	# then restores it on a real-time timer regardless of the scale it just set.
	Juice.hit_stop(self, 0.1, 0.05)
	if not is_equal_approx(Engine.time_scale, 0.1):
		push_error("FAIL: hit_stop should drop Engine.time_scale immediately")
		ok = false
	await create_timer(0.15, true, false, true).timeout
	if not is_equal_approx(Engine.time_scale, 1.0):
		push_error("FAIL: hit_stop should restore Engine.time_scale after duration_s")
		ok = false

	# player.gd's shake_camera(): decays over real _physics_process ticks and
	# stops perturbing the camera once its duration elapses.
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.shake_camera(20.0, 0.001)
	await physics_frame
	await physics_frame
	if player._shake_time_left > 0.0:
		push_error("FAIL: shake_camera's timer should decay to 0 after its duration elapses")
		ok = false

	print("PASS: juice helpers" if ok else "FAIL")
	quit(0 if ok else 1)
