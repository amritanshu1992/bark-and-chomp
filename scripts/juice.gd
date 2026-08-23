class_name Juice

## Phase 2 juice: tiny stateless helpers shared by player.gd/rival_base.gd/
## projectile.gd for the impact moments called out in docs/asset_list.md's
## Juice section (hit-stop, screen shake, particle bursts). Static-only, no
## autoload -- these are pure fire-and-forget effects, not a subsystem with
## its own lifecycle. Screen shake itself lives in player.gd instead (it's
## continuous per-frame state tied to the one Camera2D the game has).

## Briefly drops Engine.time_scale then restores it on a REAL-TIME timer
## (ignore_time_scale=true) so the restore isn't itself slowed by the scale
## dip it just applied. Engine.time_scale is global, so this needs no
## reference to the caller beyond its SceneTree.
static func hit_stop(tree: SceneTree, scale: float, duration_s: float) -> void:
	Engine.time_scale = scale
	await tree.create_timer(duration_s, true, false, true).timeout
	Engine.time_scale = 1.0

## Placeholder flat-color particle burst (no texture/art yet, matching every
## other Phase 2 placeholder). One-shot CPUParticles2D, added under `parent`
## at `position`, frees itself once spent.
static func spawn_burst(parent: Node, burst_position: Vector2, color: Color, count: int) -> void:
	var particles := CPUParticles2D.new()
	parent.add_child(particles)
	particles.global_position = burst_position
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 400.0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = color
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
