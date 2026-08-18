extends Area2D

## Milestone 1.3: pooled projectile, flies at the dog, deflected by an active bark hitbox.
## Milestone 1.4: thrown by rival_base.gd; once deflected, hitting the rival's Area2D
## triggers its on_deflect_hit() stun reaction instead of just passing through.
## Milestone 1.5: passes through harmlessly during the player's Zoomies invincibility.
## Vertical-orientation migration: tracks _progress instead of a raw world
## position; _progress_velocity plays the same role velocity_x used to
## (negative = closing on the player, flipped positive on deflect = heading
## back toward the rival). Rendered each frame via player.get_track_y().
## Hop-height clearance needs no extra code here -- it's genuine Area2D shape
## overlap: a well-timed hop lifts the player's shape clear of this one's at
## the moment their rendered Y positions coincide, so a miss from an arriving
## projectile falls out of physics the same way a miss on a static obstacle does.

signal returned_to_pool(projectile: Area2D)

const MAX_LIFETIME_S := 5.0
const LANE_X := 360.0

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

func launch(from_progress: float, speed_px_s: float, player_ref: Node2D) -> void:
	_player = player_ref
	_progress = from_progress
	_progress_velocity = -speed_px_s
	deflected = false
	_age = 0.0
	global_position = Vector2(LANE_X, _player.get_track_y(_progress))
	visual.modulate = Color.WHITE
	visible = true
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
		_progress_velocity = absf(_progress_velocity) * 1.15
		visual.modulate = Color(1.0, 0.5, 0.0)
	elif area.is_in_group("rival"):
		if deflected and area.has_method("on_deflect_hit"):
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
	set_physics_process(false)
	visible = false
	returned_to_pool.emit(self)
