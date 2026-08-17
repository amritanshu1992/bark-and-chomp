extends CharacterBody2D

## Milestone 1.1: auto-run, gravity, tap-to-hop. No double jump in MVP.
## Milestone 1.2: charge squash cue + HOP/CHARGING/BLAST/WHIMPER debug label.
## Milestone 1.3: bark hitbox / projectile deflect.
## Milestone 1.5: Zoomie meter, Zoomies (speed/invincibility/obstacle-destroy),
## tap-nudge steering, and reacting to a landed Chomp (called by rival_base.gd).

const PX_PER_UNIT := 64.0
const CHARGE_SCALE := Vector2(1.3, 0.65)
const LABEL_FLASH_S := 0.4
const ZOOMIE_COLOR := Color(1.0, 0.4, 0.8)
const METER_BAR_MAX_WIDTH := 260.0

@export var tuning: Tuning = preload("res://resources/tuning.tres")

@onready var input_controller: Node = $InputController
@onready var visual: ColorRect = $Visual
@onready var debug_label: Label = $UI/DebugLabel
@onready var meter_bar_fill: ColorRect = $UI/MeterBarFill
@onready var bark_hitbox: Area2D = $BarkHitbox
@onready var bark_hitbox_shape: CollisionShape2D = $BarkHitbox/CollisionShape2D

var meter: float = 0.0
var zoomies_active: bool = false
var _zoomies_time_left: float = 0.0

func _ready() -> void:
	input_controller.hop_requested.connect(_on_hop_requested)
	input_controller.charge_started.connect(_on_charge_started)
	input_controller.bark_released.connect(_on_bark_released)
	input_controller.zoomie_nudge_requested.connect(_on_zoomie_nudge_requested)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(tuning.bark_range_units * PX_PER_UNIT, 96.0)
	bark_hitbox_shape.shape = shape
	bark_hitbox_shape.position = Vector2(shape.size.x / 2.0, 0.0)

func _physics_process(delta: float) -> void:
	var speed_mult := tuning.zoomie_speed_mult if zoomies_active else 1.0
	velocity.x = tuning.run_speed * PX_PER_UNIT * speed_mult

	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
	else:
		velocity.y += tuning.gravity * PX_PER_UNIT * delta

	move_and_slide()

	if zoomies_active:
		_zoomies_time_left -= delta
		if _zoomies_time_left <= 0.0:
			_end_zoomies()
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider()
			if collider and collider.is_in_group("obstacle"):
				collider.queue_free()

func _on_hop_requested() -> void:
	if is_on_floor():
		velocity.y = -tuning.hop_impulse * PX_PER_UNIT
	_flash_label("HOP")

func _on_zoomie_nudge_requested() -> void:
	velocity.y = -tuning.zoomie_nudge_impulse * PX_PER_UNIT
	_flash_label("NUDGE")

func _on_charge_started() -> void:
	visual.scale = CHARGE_SCALE
	debug_label.text = "CHARGING"

func _on_bark_released(full: bool) -> void:
	visual.scale = Vector2.ONE
	if full:
		_flash(Color(1.0, 0.6, 0.1), "BLAST")
		_activate_bark_hitbox()
	else:
		_flash(Color(0.75, 0.75, 0.75), "WHIMPER")

func _activate_bark_hitbox() -> void:
	bark_hitbox.monitorable = true
	await get_tree().create_timer(tuning.bark_hitbox_duration_s).timeout
	bark_hitbox.monitorable = false

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

func get_speed_px_s() -> float:
	return velocity.x

func on_projectile_hit() -> void:
	## Placeholder "ouch" cue — real hit consequences (revive flow, GameManager)
	## land in a later phase; this just makes misses visible during playtesting.
	_flash(Color(1.0, 0.0, 0.0), "HIT")

func _update_meter_bar() -> void:
	var ratio := clampf(meter / tuning.meter_max, 0.0, 1.0)
	meter_bar_fill.size.x = METER_BAR_MAX_WIDTH * ratio

func _flash(color: Color, text: String) -> void:
	visual.modulate = color
	debug_label.text = text
	await get_tree().create_timer(LABEL_FLASH_S).timeout
	if debug_label.text == text:
		debug_label.text = ""
		visual.modulate = ZOOMIE_COLOR if zoomies_active else Color.WHITE

func _flash_label(text: String) -> void:
	debug_label.text = text
	await get_tree().create_timer(LABEL_FLASH_S).timeout
	if debug_label.text == text:
		debug_label.text = "ZOOMIES!" if zoomies_active else ""
