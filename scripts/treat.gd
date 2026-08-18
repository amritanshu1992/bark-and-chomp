extends Area2D

## Milestone 1.5: pooled treat pickup. Feeds the player's Zoomie meter on contact.
## Vertical-orientation migration: previously fully static once activated,
## because the player used to move toward it. Now the player's X/Y are both
## fixed, so the treat itself needs the same fixed-_progress + per-frame
## render pattern as obstacle/rival/projectile.
##
## Collection is resolved by progress-crossing + player.is_hop_clearing(),
## same as obstacle.gd -- a hop timed over a treat lets it pass by uncollected
## instead of relying on Area2D shape overlap, which testing showed a hop
## essentially never wins against a fast-scrolling target.

signal returned_to_pool(treat: Area2D)

const LANE_X := 360.0

var _progress: float = 0.0
var _player: Node2D
var _resolved: bool = false

func _ready() -> void:
	visible = false

func activate(progress: float, player_ref: Node2D) -> void:
	_progress = progress
	_player = player_ref
	_resolved = false
	global_position = Vector2(LANE_X, _player.get_track_y(_progress))
	visible = true

func _physics_process(_delta: float) -> void:
	if not visible:
		return
	global_position.y = _player.get_track_y(_progress)
	if _resolved or _player.distance_traveled < _progress:
		return
	_resolved = true
	var cleared: bool = _player.has_method("is_hop_clearing") and _player.is_hop_clearing()
	if not cleared and _player.has_method("on_treat_collected"):
		_player.on_treat_collected()
	_return_to_pool()

func _return_to_pool() -> void:
	visible = false
	returned_to_pool.emit(self)
