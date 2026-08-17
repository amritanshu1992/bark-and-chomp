extends Area2D

## Milestone 1.3: pooled projectile, flies at the dog, deflected by an active bark hitbox.
## Milestone 1.4: thrown by rival_base.gd; once deflected, hitting the rival's Area2D
## triggers its on_deflect_hit() stun reaction instead of just passing through.
## Milestone 1.5: passes through harmlessly during the player's Zoomies invincibility.

signal returned_to_pool(projectile: Area2D)

const MAX_LIFETIME_S := 5.0

var velocity_x: float = 0.0
var deflected: bool = false
var _age: float = 0.0

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_physics_process(false)
	visible = false

func launch(from_position: Vector2, speed_px_s: float) -> void:
	global_position = from_position
	velocity_x = -speed_px_s
	deflected = false
	_age = 0.0
	visual.modulate = Color.WHITE
	visible = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	global_position.x += velocity_x * delta
	_age += delta
	if _age >= MAX_LIFETIME_S:
		_return_to_pool()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bark_hitbox"):
		if deflected:
			return
		deflected = true
		velocity_x = absf(velocity_x) * 1.15
		visual.modulate = Color(1.0, 0.5, 0.0)
	elif area.is_in_group("rival"):
		if deflected and area.has_method("on_deflect_hit"):
			area.on_deflect_hit()
			_return_to_pool()

func _on_body_entered(body: Node2D) -> void:
	if deflected:
		return
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
