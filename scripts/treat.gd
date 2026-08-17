extends Area2D

## Milestone 1.5: pooled treat pickup. Feeds the player's Zoomie meter on contact.

signal returned_to_pool(treat: Area2D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visible = false
	monitoring = false

func activate(at_position: Vector2) -> void:
	global_position = at_position
	visible = true
	monitoring = true

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("on_treat_collected"):
		body.on_treat_collected()
	_return_to_pool()

func _return_to_pool() -> void:
	visible = false
	monitoring = false
	returned_to_pool.emit(self)
