extends Node

## Milestone 1.5: periodic treat spawner feeding the Zoomie meter. Endless-world
## recycling + hop-teaching treat arcs (TDD Sec9's fuller spawner.gd, difficulty-
## ramp-aware) are out of scope for the fixed Phase-1 prototype track -- this is
## a plain interval spawner, enough to test meter fill -> Zoomies -> Chomp.

const POOL_SIZE := 6
const SPAWN_INTERVAL_S := 1.5
## Must clear the visible world height with margin so treats spawn off the
## top of the screen instead of popping in mid-lane -- 500.0 was a leftover
## horizontal-layout value (spawned ~49% down the visible screen on the
## portrait test device). ~1560px is the tallest plausible visible world
## height on the 19.5:9 test device.
const SPAWN_AHEAD_PX := 1600.0

@export var treat_scene: PackedScene = preload("res://scenes/treat.tscn")

@onready var player: Node2D = get_node("../Player")

var _pool: Array[Area2D] = []
var _timer_s: float = 0.0

func _ready() -> void:
	for i in POOL_SIZE:
		var t: Area2D = treat_scene.instantiate()
		add_child(t)
		t.returned_to_pool.connect(_on_returned_to_pool)
		_pool.append(t)

func _process(delta: float) -> void:
	_timer_s += delta
	if _timer_s >= SPAWN_INTERVAL_S:
		_timer_s = 0.0
		_spawn()

func _spawn() -> void:
	if _pool.is_empty():
		return
	var t: Area2D = _pool.pop_back()
	t.activate(player.distance_traveled + SPAWN_AHEAD_PX, player)

func _on_returned_to_pool(t: Area2D) -> void:
	_pool.append(t)
