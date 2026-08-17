class_name RivalBase
extends Area2D

## Milestone 1.4: placeholder vacuum AI. Base class so guest monsters (later
## phases) are pure reskins -- override sprites/SFX/art only, not this logic.
## CAUGHT is reserved in the enum but not wired until Milestone 1.5 (Zoomies/Chomp).
## Owns its own projectile pool and throw timer now, replacing the Milestone 1.3
## test-only projectile_spawner.gd stand-in.

enum State { CHASING, THROWING, STUNNED, REACT, CAUGHT }

const PX_PER_UNIT := 64.0
const POOL_SIZE := 4
const REACT_DURATION_S := 0.3
const KNOCKBACK_PX := 40.0
const NOISE_FREQUENCY := 0.4  # slow sine drift; not a called-out tunable in the TDD

@export var tuning: Tuning = preload("res://resources/tuning.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var player: Node2D = get_node("../Player")
@onready var visual: ColorRect = $Visual

var _state: State = State.CHASING
var _throw_timer_s: float = 0.0
var _time: float = 0.0
var _pool: Array[Area2D] = []

func _ready() -> void:
	for i in POOL_SIZE:
		var p: Area2D = projectile_scene.instantiate()
		add_child(p)
		p.returned_to_pool.connect(_on_projectile_returned)
		_pool.append(p)
	_reroll_throw_timer()

func _physics_process(delta: float) -> void:
	_time += delta
	match _state:
		State.CHASING:
			_chase(delta)
			_throw_timer_s -= delta
			if _throw_timer_s <= 0.0:
				_start_throw()
		State.THROWING, State.REACT:
			_chase(delta)
		State.STUNNED:
			# No active herding while stunned -- just keep pace with the player's base
			# speed so it "slows"/holds its relative spot instead of literally freezing
			# in world-space (which left it behind the camera for the whole stun window).
			global_position.x += tuning.run_speed * PX_PER_UNIT * delta

func _chase(delta: float) -> void:
	var desired_x := player.global_position.x + tuning.rival_target_distance * PX_PER_UNIT \
		+ sin(_time * NOISE_FREQUENCY) * tuning.rival_distance_variation * PX_PER_UNIT
	var error := desired_x - global_position.x
	var max_adjust_px := tuning.rival_max_adjust * PX_PER_UNIT
	var adjust := clampf(error * tuning.rival_rubber_band_k, -max_adjust_px, max_adjust_px)
	var vel_x := tuning.run_speed * PX_PER_UNIT + adjust
	global_position.x += vel_x * delta

func _reroll_throw_timer() -> void:
	_throw_timer_s = randf_range(tuning.throw_interval_min_s, tuning.throw_interval_max_s)

func _start_throw() -> void:
	_state = State.THROWING
	visual.modulate = Color(1.0, 0.2, 0.1)  # loud wind-up cue -- attacks are never cheap
	visual.scale = Vector2(1.4, 1.4)
	await get_tree().create_timer(tuning.throw_telegraph_s).timeout
	_throw_projectile()
	visual.modulate = Color.WHITE
	visual.scale = Vector2.ONE
	_reroll_throw_timer()
	_state = State.CHASING

func _throw_projectile() -> void:
	if _pool.is_empty():
		return
	var p: Area2D = _pool.pop_back()
	p.launch(global_position, tuning.projectile_speed * PX_PER_UNIT)

func _on_projectile_returned(p: Area2D) -> void:
	_pool.append(p)

func on_deflect_hit() -> void:
	if _state == State.STUNNED or _state == State.REACT:
		return
	_state = State.REACT
	global_position.x += KNOCKBACK_PX
	visual.modulate = Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(REACT_DURATION_S).timeout
	_state = State.STUNNED
	visual.modulate = Color(0.6, 0.6, 0.6)
	await get_tree().create_timer(tuning.stun_duration_s).timeout
	visual.modulate = Color.WHITE
	# Escape animation stand-in: the vacuum was frozen in place for react+stun while
	# the player kept auto-running, so a plain rubber-band correction would leave it
	# crawling back into frame for several seconds. Snap back into range instead.
	global_position.x = player.global_position.x + tuning.rival_target_distance * PX_PER_UNIT
	_state = State.CHASING
