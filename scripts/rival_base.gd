class_name RivalBase
extends Area2D

## Milestone 1.4: placeholder vacuum AI. Base class so guest monsters (later
## phases) are pure reskins -- override sprites/SFX/art only, not this logic.
## Owns its own projectile pool and throw timer, replacing the Milestone 1.3
## test-only projectile_spawner.gd stand-in.
## Milestone 1.5: CAUGHT is wired up -- while STUNNED, a chomp_window_s opens
## the instant the player is in Zoomies; overlap within that window is a CHOMP
## (big payout, respawn ahead), letting the window expire is a miss (early
## recovery, "vacuum recovers and escapes" per the GDD).
## Vertical-orientation migration: this rival no longer tracks its own state
## via global_position.x. It tracks an explicit _progress float (same role
## global_position.x used to play) and renders each frame via
## player.get_track_y(_progress), staying pinned to the single lane's X.

enum State { CHASING, THROWING, STUNNED, REACT, CAUGHT }

const PX_PER_UNIT := 64.0
const LANE_X := 360.0
const POOL_SIZE := 4
const REACT_DURATION_S := 0.3
const KNOCKBACK_PX := 40.0
const CHOMP_RADIUS_PX := 90.0
const CAUGHT_RESPAWN_DELAY_S := 0.6
const RESPAWN_MARGIN_PX := 200.0  # TDD Sec7.1: respawn ahead at target_distance + margin
const NOISE_FREQUENCY := 0.4  # slow sine drift; not a called-out tunable in the TDD

@export var tuning: Tuning = preload("res://resources/tuning.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var player: Node2D = get_node("../Player")
@onready var visual: ColorRect = $Visual

var _progress: float = 0.0
var _state: State = State.CHASING
var _throw_timer_s: float = 0.0
var _react_timer_s: float = 0.0
var _stun_timer_s: float = 0.0
var _chomp_window_s: float = -1.0
var _time: float = 0.0
var _pool: Array[Area2D] = []
var _first_throw_done: bool = false

func _ready() -> void:
	_progress = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT
	_render()
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
			if _state == State.REACT:
				_react_timer_s -= delta
				if _react_timer_s <= 0.0:
					_enter_stunned()
		State.STUNNED:
			# No active herding while stunned -- just keep pace with the player's BASE
			# (non-Zoomies) speed, deliberately, so it "slows"/holds its relative spot
			# instead of literally freezing in place, while still being slower than
			# a Zoomies-boosted player -- that speed gap is what makes catching it possible.
			_progress += tuning.run_speed * PX_PER_UNIT * delta
			_render()
			_stun_timer_s -= delta
			_update_chomp_window(delta)
			if _state == State.STUNNED and _stun_timer_s <= 0.0:
				_recover_to_chasing()
		State.CAUGHT:
			# Same fix as STUNNED: keep pace with the player's current speed during the
			# catch celebration instead of freezing in place, or a Zoomies-boosted
			# player would leave it stranded far behind before the respawn below runs.
			_progress += _player_speed_px_s() * delta
			_render()

func _render() -> void:
	global_position = Vector2(LANE_X, player.get_track_y(_progress))

func _player_speed_px_s() -> float:
	if player.has_method("get_speed_px_s"):
		return player.get_speed_px_s()
	return tuning.run_speed * PX_PER_UNIT

func _chase(delta: float) -> void:
	var desired: float = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT \
		+ sin(_time * NOISE_FREQUENCY) * tuning.rival_distance_variation * PX_PER_UNIT
	var error: float = desired - _progress
	var max_adjust_px := tuning.rival_max_adjust * PX_PER_UNIT
	var adjust := clampf(error * tuning.rival_rubber_band_k, -max_adjust_px, max_adjust_px)
	var vel := _player_speed_px_s() + adjust
	_progress += vel * delta
	_render()

func _reroll_throw_timer() -> void:
	_throw_timer_s = randf_range(tuning.throw_interval_min_s, tuning.throw_interval_max_s)

func _start_throw() -> void:
	if not _first_throw_done:
		_first_throw_done = true
		if player.has_method("maybe_show_bark_hint"):
			await player.maybe_show_bark_hint()
	_state = State.THROWING
	visual.modulate = Color(1.0, 0.2, 0.1)  # loud wind-up cue -- attacks are never cheap
	visual.scale = Vector2(1.4, 1.4)
	await get_tree().create_timer(tuning.throw_telegraph_s).timeout
	if _state != State.THROWING:
		return  # deflect-hit landed mid-telegraph; don't let the throw stomp REACT/STUNNED
	_throw_projectile()
	visual.modulate = Color.WHITE
	visual.scale = Vector2.ONE
	_reroll_throw_timer()
	_state = State.CHASING

func _throw_projectile() -> void:
	if _pool.is_empty():
		return
	var p: Area2D = _pool.pop_back()
	p.launch(_progress, tuning.projectile_speed * PX_PER_UNIT, player)

func _on_projectile_returned(p: Area2D) -> void:
	_pool.append(p)

func on_deflect_hit() -> void:
	if _state == State.STUNNED or _state == State.REACT or _state == State.CAUGHT:
		return
	_state = State.REACT
	_react_timer_s = REACT_DURATION_S
	_progress += KNOCKBACK_PX
	_render()
	visual.scale = Vector2.ONE
	visual.modulate = Color(1.0, 0.3, 0.3)
	if player.has_method("add_meter"):
		player.add_meter(tuning.deflect_hit_meter_value)

func _enter_stunned() -> void:
	_state = State.STUNNED
	_stun_timer_s = tuning.stun_duration_s
	_chomp_window_s = -1.0
	visual.modulate = Color(0.6, 0.6, 0.6)

func _update_chomp_window(delta: float) -> void:
	var player_zoomies: bool = player.has_method("is_zoomies_active") and player.is_zoomies_active()
	if not player_zoomies:
		_chomp_window_s = -1.0
		return
	if _chomp_window_s < 0.0:
		_chomp_window_s = tuning.chomp_window_s
	if global_position.distance_to(player.global_position) <= CHOMP_RADIUS_PX:
		_on_chomped()
		return
	_chomp_window_s -= delta
	if _chomp_window_s <= 0.0:
		_recover_to_chasing()  # miss: vacuum recovers and escapes

func _recover_to_chasing() -> void:
	visual.modulate = Color.WHITE
	# Escape animation stand-in: the vacuum was frozen in place for react+stun while
	# the player kept advancing, so a plain rubber-band correction would leave it
	# crawling back into frame for several seconds. Snap back into range instead.
	_progress = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT
	_render()
	_chomp_window_s = -1.0
	_state = State.CHASING

func _on_chomped() -> void:
	_state = State.CAUGHT
	visual.modulate = Color(1.0, 0.85, 0.2)  # dust-bag-burst stand-in
	if player.has_method("on_chomp_landed"):
		player.on_chomp_landed()
	await get_tree().create_timer(CAUGHT_RESPAWN_DELAY_S).timeout
	_progress = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT + RESPAWN_MARGIN_PX
	_render()
	visual.modulate = Color.WHITE
	_reroll_throw_timer()
	_state = State.CHASING
