extends CharacterBody2D

## Milestone 1.1: auto-run, gravity, tap-to-hop. No double jump in MVP.
## Milestone 1.2: charge squash cue + HOP/CHARGING/BLAST/WHIMPER debug label.
## Milestone 1.3: bark hitbox / projectile deflect.
## Milestone 1.5: Zoomie meter, Zoomies (speed/invincibility/obstacle-destroy),
## tap-nudge steering, and reacting to a landed Chomp (called by rival_base.gd).
## Vertical-orientation migration: the player no longer physically traverses
## the world. `distance_traveled` is the "how far into the run" clock every
## other entity reads via get_track_y(); the player itself stays pinned at
## (FIXED_X, BASELINE_Y) minus a local hop offset, computed manually each
## frame instead of via move_and_slide()/is_on_floor() -- there is no literal
## floor body to slide against any more.

const PX_PER_UNIT := 64.0
const FIXED_X := 360.0
const BASELINE_Y := 1000.0
## Subway-Surfers-style feel pass: pulls the camera's world-anchor point up
## so the player renders lower in frame (not dead center), leaving more
## visible runway above for the rival/obstacles/treats to be seen coming.
const CAMERA_Y_OFFSET_PX := 486.0
const CHARGE_SCALE := Vector2(1.3, 0.65)
const HOP_VISUAL_LIFT_SCALE := 1.32
const HOP_SHADOW_MIN_ALPHA := 0.15
const HOP_SHADOW_MAX_ALPHA := 0.4
## A flat parabola (same gravity up and down) reads as an abrupt "snap" --
## floating a bit longer near the top and dropping faster at the bottom is
## the standard jump-feel trick and reads as a proper hop instead. Also
## widens the hop-clearance window (more time above HOP_CLEARANCE_MIN_PX),
## which playtesting separately flagged as feeling too tight.
const HOP_RISE_GRAVITY_MULT := 0.8
const HOP_FALL_GRAVITY_MULT := 1.6
const LABEL_FLASH_S := 0.4
const BARK_HINT_S := 2.5
const BARK_HINT_TEXT := "Watch the vacuum!\nThe instant it turns RED,\nHOLD to bark it back!"
const ZOOMIE_COLOR := Color(1.0, 0.4, 0.8)
const METER_BAR_MAX_WIDTH := 260.0

@export var tuning: Tuning = preload("res://resources/tuning.tres")

@onready var input_controller: Node = $InputController
@onready var visual: ColorRect = $Visual
@onready var shadow: ColorRect = $Shadow
@onready var camera: Camera2D = $Camera2D
@onready var debug_label: Label = $UI/DebugLabel
@onready var meter_bar_fill: ColorRect = $UI/MeterBarFill
@onready var hint_label: Label = $UI/HintLabel
@onready var bark_hitbox: Area2D = $BarkHitbox
@onready var bark_hitbox_shape: CollisionShape2D = $BarkHitbox/CollisionShape2D

var distance_traveled: float = 0.0
var hop_offset: float = 0.0
var hop_velocity: float = 0.0
var meter: float = 0.0
var zoomies_active: bool = false
var _current_speed_px_s: float = 0.0
var _flash_id: int = 0
var _bark_hitbox_token: int = 0
var _has_charged_ever: bool = false
var _zoomies_time_left: float = 0.0
var _is_charging: bool = false
var _max_hop_offset_px: float = 1.0
var _run_time_elapsed: float = 0.0

func _ready() -> void:
	input_controller.hop_requested.connect(_on_hop_requested)
	input_controller.charge_started.connect(_on_charge_started)
	input_controller.bark_ready.connect(_on_bark_ready)
	input_controller.bark_released.connect(_on_bark_released)
	input_controller.zoomie_nudge_requested.connect(_on_zoomie_nudge_requested)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(96.0, tuning.bark_range_units * PX_PER_UNIT)
	bark_hitbox_shape.shape = shape
	bark_hitbox_shape.position = Vector2(0.0, -shape.size.y / 2.0)

	global_position = Vector2(FIXED_X, BASELINE_Y)
	# Apex height of a full hop (v^2 / 2g), used to normalize the lift-scale/
	# shadow-fade cue below so it reads correctly across tuning changes.
	# Uses the rise-phase gravity (see HOP_RISE_GRAVITY_MULT) since that's
	# the gravity actually in effect on the way up to the apex.
	_max_hop_offset_px = (tuning.hop_impulse * tuning.hop_impulse) / (2.0 * tuning.gravity * HOP_RISE_GRAVITY_MULT) * PX_PER_UNIT

## Returns the screen Y an entity at the given progress should render at
## right now. progress > distance_traveled = still ahead (ie. "up the
## screen", smaller Y, hasn't reached the player yet).
func get_track_y(progress: float) -> float:
	return BASELINE_Y - (progress - distance_traveled)

## World Y of the bottom edge of the viewport, given the camera's fixed
## world-anchor offset (see CAMERA_Y_OFFSET_PX). A dodged/resolved entity
## should keep scrolling down past the player instead of vanishing right at
## the player's line -- this is the threshold past which it's actually
## offscreen and safe to hide/free.
func get_offscreen_bottom_y() -> float:
	return BASELINE_Y - CAMERA_Y_OFFSET_PX + get_viewport_rect().size.y / 2.0

func _physics_process(delta: float) -> void:
	_run_time_elapsed += delta
	var ramp_ratio := clampf(_run_time_elapsed / tuning.run_speed_ramp_s, 0.0, 1.0)
	var base_speed_u_s := lerpf(tuning.run_speed, tuning.run_speed_max, ramp_ratio)
	var speed_mult := tuning.zoomie_speed_mult if zoomies_active else 1.0
	_current_speed_px_s = base_speed_u_s * PX_PER_UNIT * speed_mult
	distance_traveled += _current_speed_px_s * delta

	if hop_offset > 0.0 or hop_velocity != 0.0:
		var gravity_mult := HOP_FALL_GRAVITY_MULT if hop_velocity < 0.0 else HOP_RISE_GRAVITY_MULT
		hop_velocity -= tuning.gravity * PX_PER_UNIT * gravity_mult * delta
		hop_offset += hop_velocity * delta
		if hop_offset <= 0.0:
			hop_offset = 0.0
			hop_velocity = 0.0

	global_position = Vector2(FIXED_X, BASELINE_Y - hop_offset)
	# Camera is a child of Player -- cancel the parent's hop bob in local
	# space so the camera's global Y always stays pinned at
	# BASELINE_Y - CAMERA_Y_OFFSET_PX (see const comment above).
	camera.position = Vector2(0.0, hop_offset - CAMERA_Y_OFFSET_PX)

	# Pseudo-3D hop cue: the sprite scales up as hop height increases, so a
	# hop reads as lifting toward the camera rather than just sliding up the
	# screen. Shadow counters the parent's hop bob the same way the camera
	# does, so it stays pinned at ground level while the sprite rises off
	# it, and just fades (no scale change -- shrinking read as visual noise
	# on top of the sprite's own scale-up, per playtest feedback).
	# sqrt-eased so the cue reaches near-peak intensity quickly and holds it,
	# instead of tracking the raw parabola (which only grazes the top for an
	# instant) -- needed to keep the cue readable now that the snappier hop
	# halved hang time versus the original tuning this was designed against.
	var raw_hop_ratio := clampf(hop_offset / _max_hop_offset_px, 0.0, 1.0)
	var hop_ratio := sqrt(raw_hop_ratio)
	shadow.position = Vector2(0.0, hop_offset)
	shadow.modulate.a = lerpf(HOP_SHADOW_MAX_ALPHA, HOP_SHADOW_MIN_ALPHA, hop_ratio)
	if not _is_charging:
		visual.scale = Vector2.ONE * lerpf(1.0, HOP_VISUAL_LIFT_SCALE, hop_ratio)

	if zoomies_active:
		_zoomies_time_left -= delta
		if _zoomies_time_left <= 0.0:
			_end_zoomies()

func _on_hop_requested() -> void:
	if hop_offset <= 0.0 and hop_velocity == 0.0:
		hop_velocity = tuning.hop_impulse * PX_PER_UNIT
	_flash_label("HOP")

func _on_zoomie_nudge_requested() -> void:
	hop_velocity = tuning.zoomie_nudge_impulse * PX_PER_UNIT
	_flash_label("NUDGE")

func _on_charge_started() -> void:
	_is_charging = true
	visual.scale = CHARGE_SCALE
	debug_label.text = "CHARGING"
	_has_charged_ever = true

## Called by the rival on its first-ever throw telegraph -- 1.6 silent-observation
## playtest found hold-to-bark is not discoverable unprompted, so this is a minimal
## in-fiction nudge (not the full FTUE tutorial, which is deliberately Phase 3 scope
## per the project plan Sec3.4). Only fires if the player has never held at all.
## Pauses the whole game world for the duration -- reading the hint shouldn't cost
## run distance or leave the player exposed to the throw it's explaining. The rival
## awaits this before starting its telegraph, so the full throw runway begins fresh
## after unpausing.
func maybe_show_bark_hint() -> void:
	if _has_charged_ever:
		return
	get_tree().paused = true
	hint_label.text = BARK_HINT_TEXT
	await get_tree().create_timer(BARK_HINT_S).timeout
	hint_label.text = ""
	get_tree().paused = false

func _on_bark_ready() -> void:
	## Deflect hitbox goes live for a fixed window starting the instant a hold reaches
	## full charge -- point-blank contact is covered without requiring release-instant
	## precision, but the window does NOT extend for as long as the player keeps
	## holding, so holding indefinitely is not free invulnerability: the skill is
	## timing *when you commit* to full charge, not just when you release.
	bark_hitbox.monitorable = true
	_bark_hitbox_token += 1
	var my_token := _bark_hitbox_token
	await get_tree().create_timer(tuning.bark_hitbox_duration_s).timeout
	if _bark_hitbox_token == my_token:
		bark_hitbox.monitorable = false

func _on_bark_released(full: bool) -> void:
	_is_charging = false
	visual.scale = Vector2.ONE
	if full:
		_flash(Color(1.0, 0.6, 0.1), "BLAST")
	else:
		_flash(Color(0.75, 0.75, 0.75), "WHIMPER")

func add_meter(amount: float) -> void:
	if zoomies_active:
		return
	meter = minf(meter + amount, tuning.meter_max)
	_update_meter_bar()
	if meter >= tuning.meter_max:
		_start_zoomies()

func on_treat_collected() -> void:
	add_meter(tuning.treat_meter_value)
	_flash_label("TREAT")

func on_chomp_landed() -> void:
	_flash_label("CHOMP!")

func _start_zoomies() -> void:
	zoomies_active = true
	_zoomies_time_left = tuning.zoomie_duration_s
	meter = 0.0
	_update_meter_bar()
	input_controller.zoomies_active = true
	visual.modulate = ZOOMIE_COLOR
	debug_label.text = "ZOOMIES!"

func _end_zoomies() -> void:
	zoomies_active = false
	input_controller.zoomies_active = false
	visual.modulate = Color.WHITE
	if debug_label.text == "ZOOMIES!":
		debug_label.text = ""

func is_zoomies_active() -> bool:
	return zoomies_active

func is_invincible() -> bool:
	return zoomies_active

## Whether the player is currently airborne enough for a hop to count as
## clearing an obstacle/treat. Deliberately not raw shape-overlap physics
## (see obstacle.gd/treat.gd) -- with the player's rendered Y racing a
## fast-scrolling ground object toward the same on-screen line, exact
## capsule-vs-box overlap only clears with near-frame-perfect timing, which
## on-device testing showed doesn't work at all in practice. This threshold
## is deliberately low relative to hop apex (~164px at default tuning) so
## most of a hop's ~0.86s hang time counts as "clearing" -- the skill is
## roughly timing the hop, not micro-timing an overlap window.
const HOP_CLEARANCE_MIN_PX := 20.0

func is_hop_clearing() -> bool:
	return hop_offset > HOP_CLEARANCE_MIN_PX

func get_speed_px_s() -> float:
	return _current_speed_px_s

func on_obstacle_cleared() -> void:
	_flash(Color(0.3, 1.0, 0.3), "DODGED!")

func on_treat_dodged() -> void:
	_flash_label("DODGED!")

func on_projectile_hit() -> void:
	## Placeholder "ouch" cue — real hit consequences (revive flow, GameManager)
	## land in a later phase; this just makes misses visible during playtesting.
	_flash(Color(1.0, 0.0, 0.0), "HIT")

func on_obstacle_hit() -> void:
	## Placeholder "ouch" cue, same convention as on_projectile_hit(). Obstacles
	## used to be a literal physical blocker the player slid against; now that
	## the player's X is fixed and nothing physically traverses the world, a
	## miss is represented as an explicit hit consequence instead.
	_flash(Color(1.0, 0.0, 0.0), "OUCH")

func _update_meter_bar() -> void:
	var ratio := clampf(meter / tuning.meter_max, 0.0, 1.0)
	meter_bar_fill.size.x = METER_BAR_MAX_WIDTH * ratio

func _flash(color: Color, text: String) -> void:
	visual.modulate = color
	_flash_label(text)

func _flash_label(text: String) -> void:
	debug_label.text = text
	_flash_id += 1
	var my_id := _flash_id
	await get_tree().create_timer(LABEL_FLASH_S).timeout
	if _flash_id == my_id:
		debug_label.text = "ZOOMIES!" if zoomies_active else ""
		visual.modulate = ZOOMIE_COLOR if zoomies_active else Color.WHITE
