extends CharacterBody2D

## Milestone 1.1: auto-run, gravity, tap-to-hop. No double jump in MVP.
## Milestone 1.2: charge squash cue + HOP/CHARGING/BLAST/WHIMPER debug label.
## Bark hitbox / projectile deflect itself is Milestone 1.3, not here yet.

const PX_PER_UNIT := 64.0
const CHARGE_SCALE := Vector2(1.3, 0.65)
const LABEL_FLASH_S := 0.4

@export var tuning: Tuning = preload("res://resources/tuning.tres")

@onready var input_controller: Node = $InputController
@onready var visual: ColorRect = $Visual
@onready var debug_label: Label = $UI/DebugLabel

func _ready() -> void:
	input_controller.hop_requested.connect(_on_hop_requested)
	input_controller.charge_started.connect(_on_charge_started)
	input_controller.bark_released.connect(_on_bark_released)

func _physics_process(delta: float) -> void:
	velocity.x = tuning.run_speed * PX_PER_UNIT

	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
	else:
		velocity.y += tuning.gravity * PX_PER_UNIT * delta

	move_and_slide()

func _on_hop_requested() -> void:
	if is_on_floor():
		velocity.y = -tuning.hop_impulse * PX_PER_UNIT
	_flash_label("HOP")

func _on_charge_started() -> void:
	visual.scale = CHARGE_SCALE
	debug_label.text = "CHARGING"

func _on_bark_released(full: bool) -> void:
	visual.scale = Vector2.ONE
	if full:
		_flash(Color(1.0, 0.6, 0.1), "BLAST")
	else:
		_flash(Color(0.75, 0.75, 0.75), "WHIMPER")

func _flash(color: Color, text: String) -> void:
	visual.modulate = color
	debug_label.text = text
	await get_tree().create_timer(LABEL_FLASH_S).timeout
	if debug_label.text == text:
		debug_label.text = ""
		visual.modulate = Color.WHITE

func _flash_label(text: String) -> void:
	debug_label.text = text
	await get_tree().create_timer(LABEL_FLASH_S).timeout
	if debug_label.text == text:
		debug_label.text = ""
