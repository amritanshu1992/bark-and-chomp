extends Area2D

## Milestone 1.3: pooled projectile, flies at the dog, deflected by an active bark hitbox.
## Milestone 1.4: thrown by rival_base.gd; once deflected, hitting the rival's Area2D
## triggers its on_deflect_hit() stun reaction instead of just passing through.
## Milestone 1.5: passes through harmlessly during the player's Zoomies invincibility.
## Vertical-orientation migration: tracks _progress instead of a raw world
## position; _progress_velocity plays the same role velocity_x used to
## (negative = closing on the player, flipped positive on deflect = heading
## back toward the rival). Rendered each frame via player.get_track_y().
## Hopping does NOT clear a projectile -- tested directly during final branch
## review. A hop moves the player's capsule up, toward a descending
## projectile, so a well-timed hop makes contact happen earlier, not later;
## there is no hop timing that avoids a hit here. The only way to avoid a
## projectile is barking it away (see _on_area_entered's bark_hitbox branch
## below) before it arrives -- unlike obstacle.gd/treat.gd, which resolve via
## progress-crossing + is_hop_clearing() and genuinely are hop-dodgeable.

signal returned_to_pool(projectile: Area2D)

const MAX_LIFETIME_S := 5.0
const LANE_X := 360.0
## Deflect return speed must beat the rival's max forward pace (current run
## speed + its rubber-band adjust cap) or a deflected projectile can never
## catch a rival that's chasing at a ramped-up run speed -- 320px/s clears
## the rubber-band cap (tuning.rival_max_adjust=3u/s=192px/s) with margin.
const DEFLECT_RETURN_MARGIN_PX_S := 320.0

var _progress: float = 0.0
var _progress_velocity: float = 0.0
var deflected: bool = false
var _age: float = 0.0
var _player: Node2D

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_physics_process(false)
	visible = false
	monitoring = false

func launch(from_progress: float, speed_px_s: float, player_ref: Node2D) -> void:
	_player = player_ref
	_progress = from_progress
	_progress_velocity = -speed_px_s
	deflected = false
	_age = 0.0
	global_position = Vector2(LANE_X, _player.get_track_y(_progress))
	visual.modulate = Color.WHITE
	visible = true
	monitoring = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_progress += _progress_velocity * delta
	global_position.y = _player.get_track_y(_progress)
	_age += delta
	if _age >= MAX_LIFETIME_S:
		_return_to_pool()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bark_hitbox"):
		if deflected:
			return
		deflected = true
		# Reset the lifetime clock on deflect -- during Zoomies the closing
		# speed (and so the worst-case return margin) is much higher, and
		# without this a perfectly-timed deflect could hit MAX_LIFETIME_S
		# and silently despawn before ever reaching the rival.
		_age = 0.0
		var return_px_s: float = absf(_progress_velocity) * 1.15
		if _player and _player.has_method("get_speed_px_s"):
			return_px_s = maxf(return_px_s, _player.get_speed_px_s() + DEFLECT_RETURN_MARGIN_PX_S)
		_progress_velocity = return_px_s
		visual.modulate = Color(1.0, 0.5, 0.0)
		print_debug("Projectile deflected: return_px_s=%.1f" % return_px_s)
	elif area.is_in_group("rival"):
		if deflected and area.has_method("on_deflect_hit"):
			print_debug("Deflected projectile caught the rival")
			area.on_deflect_hit()
			_return_to_pool()

func _on_body_entered(body: Node2D) -> void:
	if deflected:
		return
	for area in get_overlapping_areas():
		if area.is_in_group("bark_hitbox"):
			return  # point-blank overlap in the same frame -- let _on_area_entered win the race
	if body.has_method("is_invincible") and body.is_invincible():
		_return_to_pool()
		return
	if body.has_method("on_projectile_hit"):
		body.on_projectile_hit()
	_return_to_pool()

func _return_to_pool() -> void:
	if not visible:
		return
	set_physics_process(false)
	set_deferred("monitoring", false)
	visible = false
	returned_to_pool.emit(self)
