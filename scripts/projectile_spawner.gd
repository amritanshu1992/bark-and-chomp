extends Node

## Milestone 1.3 test-only spawner: throws projectiles on a fixed timer since there's
## no rival yet. Will be removed/replaced once rival_base.gd's THROWING state exists
## (Milestone 1.4) — do not build this out further, it's a stand-in.

const PX_PER_UNIT := 64.0
const POOL_SIZE := 4
const SPAWN_INTERVAL_S := 2.5
const SPAWN_AHEAD_PX := 700.0

@export var tuning: Tuning = preload("res://resources/tuning.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var player: Node2D = get_node("../Player")

var _pool: Array[Area2D] = []
var _timer_s: float = 0.0

func _ready() -> void:
	for i in POOL_SIZE:
		var p: Area2D = projectile_scene.instantiate()
		add_child(p)
		p.returned_to_pool.connect(_on_returned_to_pool)
		_pool.append(p)

func _process(delta: float) -> void:
	_timer_s += delta
	if _timer_s >= SPAWN_INTERVAL_S:
		_timer_s = 0.0
		_spawn()

func _spawn() -> void:
	if _pool.is_empty():
		return
	var p: Area2D = _pool.pop_back()
	var speed := tuning.projectile_speed * PX_PER_UNIT
	p.launch(Vector2(player.global_position.x + SPAWN_AHEAD_PX, player.global_position.y - 24.0), speed)

func _on_returned_to_pool(p: Area2D) -> void:
	_pool.append(p)
