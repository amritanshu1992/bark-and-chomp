extends Node2D

@onready var player: Node2D = $Player
@onready var run_over_bg: ColorRect = $UI/RunOverBg
@onready var run_over_label: Label = $UI/RunOverBg/RunOverLabel

func _ready() -> void:
	player.died.connect(_on_player_died)

func _on_player_died() -> void:
	var distance_m: float = player.distance_traveled / player.PX_PER_UNIT
	run_over_label.text = "Run over!\nDistance: %.0fm\nTreats: %d" % [distance_m, player.treats_collected]
	run_over_bg.visible = true

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
