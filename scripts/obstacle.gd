extends Area2D

## Vertical-orientation migration: obstacle used to be a bare StaticBody2D
## the player physically slid/hopped past as they moved through the world.
## Now the player's X is fixed and nothing physically traverses the world,
## so this becomes an Area2D at a fixed target _progress that renders itself
## each frame via player.get_track_y() -- same pattern as rival/projectile/
## treat.
##
## Hop clearance is resolved by progress-crossing + player.is_hop_clearing(),
## not raw Area2D shape overlap -- on-device testing showed a hop essentially
## never wins a genuine capsule-vs-box overlap race against a fast-scrolling
## obstacle (the player's rise and the obstacle's approach both eat into the
## same combined-half-height margin, leaving a real but vanishingly small
## landable window). Resolving once, at the exact moment the obstacle reaches
## the player's line, against the player's current airborne state, is what
## actually gives hopping real, reliable effect.

const LANE_X := 360.0

## How far into the run this obstacle sits. Phase-1 scope: one static
## instance, no spawner (matches the pre-migration game, which also only
## ever had one placed Obstacle instance in main.tscn).
@export var target_progress: float = 1500.0

@onready var _player: Node2D = get_node("../Player")

var _resolved: bool = false

func _ready() -> void:
	global_position = Vector2(LANE_X, _player.get_track_y(target_progress))

func _physics_process(_delta: float) -> void:
	global_position.y = _player.get_track_y(target_progress)
	if _resolved or _player.distance_traveled < target_progress:
		return
	_resolved = true
	if _player.has_method("is_invincible") and _player.is_invincible():
		queue_free()
		return
	if _player.has_method("is_hop_clearing") and _player.is_hop_clearing():
		return
	if _player.has_method("on_obstacle_hit"):
		_player.on_obstacle_hit()
