extends Area2D

## Vertical-orientation migration: obstacle used to be a bare StaticBody2D
## the player physically slid/hopped past as they moved through the world.
## Now the player's X is fixed and nothing physically traverses the world,
## so this becomes an Area2D at a fixed target _progress that renders itself
## each frame via player.get_track_y() -- same pattern as rival/projectile/
## treat. Real hop clearance is still genuine Godot shape-overlap physics:
## a well-timed hop lifts the player's collision shape clear of this one's
## at the moment their rendered Y positions coincide.

const LANE_X := 360.0

## How far into the run this obstacle sits. Phase-1 scope: one static
## instance, no spawner (matches the pre-migration game, which also only
## ever had one placed Obstacle instance in main.tscn).
@export var target_progress: float = 1500.0

@onready var _player: Node2D = get_node("../Player")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	global_position = Vector2(LANE_X, _player.get_track_y(target_progress))

func _physics_process(_delta: float) -> void:
	global_position.y = _player.get_track_y(target_progress)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("is_invincible") and body.is_invincible():
		queue_free()
		return
	if body.has_method("on_obstacle_hit"):
		body.on_obstacle_hit()
