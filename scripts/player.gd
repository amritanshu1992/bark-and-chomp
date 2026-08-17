extends CharacterBody2D

## Milestone 1.1: auto-run, gravity, tap-to-hop. No double jump in MVP.

const PX_PER_UNIT := 64.0

@export var tuning: Tuning = preload("res://resources/tuning.tres")

@onready var input_controller: Node = $InputController

func _ready() -> void:
	input_controller.hop_requested.connect(_on_hop_requested)

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
