extends Node2D

## Subway-Surfers-style feel pass: a small fixed ring of recycling stripe
## bars scrolling down the lane, so the world reads as constantly moving
## even though placeholder art has no ground texture yet. Rendered the same
## way every other track entity is -- fixed progress value, get_track_y()
## each frame -- but recycled forward by the full ring span once a stripe
## scrolls below the viewport, instead of pooled/instanced like obstacle/
## treat, since there's no gameplay logic attached, just a fixed count of
## flat rects reused forever.

const STRIPE_COUNT := 12
const STRIPE_SPACING_PX := 160.0
const STRIPE_HEIGHT := 16.0
const RECYCLE_SPAN_PX := STRIPE_COUNT * STRIPE_SPACING_PX

@onready var _player: Node2D = get_node("../Player")

var _stripes: Array[ColorRect] = []
var _progresses: Array[float] = []

func _ready() -> void:
	var width := get_viewport_rect().size.x
	for i in STRIPE_COUNT:
		var stripe := ColorRect.new()
		stripe.size = Vector2(width, STRIPE_HEIGHT)
		stripe.color = Color(1.0, 1.0, 1.0, 0.08)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)
		_stripes.append(stripe)
		_progresses.append(_player.distance_traveled + i * STRIPE_SPACING_PX)

func _physics_process(_delta: float) -> void:
	# Must be a world-Y (camera-anchor-derived), not a raw viewport size --
	# get_track_y() output is world-space, and comparing it against a plain
	# viewport length only coincided by accident, leaving the top ~36% of the
	# lane unstriped on the actual portrait test device. get_offscreen_bottom_y()
	# is the same camera-anchored helper treat.gd already uses correctly.
	var recycle_y: float = _player.get_offscreen_bottom_y() + STRIPE_HEIGHT
	for i in _stripes.size():
		var y: float = _player.get_track_y(_progresses[i])
		if y > recycle_y:
			_progresses[i] += RECYCLE_SPAN_PX
			y = _player.get_track_y(_progresses[i])
		_stripes[i].global_position = Vector2(0.0, y)
