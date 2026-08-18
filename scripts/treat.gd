extends Area2D

## Milestone 1.5: pooled treat pickup. Feeds the player's Zoomie meter on contact.
## Vertical-orientation migration: previously fully static once activated,
## because the player used to move toward it. Now the player's X/Y are both
## fixed, so the treat itself needs the same fixed-_progress + per-frame
## render pattern as obstacle/rival/projectile.

signal returned_to_pool(treat: Area2D)

const LANE_X := 360.0

var _progress: float = 0.0
var _player: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visible = false
	monitoring = false

func activate(progress: float, player_ref: Node2D) -> void:
	_progress = progress
	_player = player_ref
	global_position = Vector2(LANE_X, _player.get_track_y(_progress))
	visible = true
	monitoring = true

func _physics_process(_delta: float) -> void:
	if visible:
		global_position.y = _player.get_track_y(_progress)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("on_treat_collected"):
		body.on_treat_collected()
	_return_to_pool()

func _return_to_pool() -> void:
	visible = false
	monitoring = false
	returned_to_pool.emit(self)
