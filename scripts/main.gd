extends Node2D

@onready var player: Node2D = $Player
@onready var rival: Node2D = $Rival
@onready var run_over_bg: ColorRect = $UI/RunOverBg
@onready var run_over_label: Label = $UI/RunOverBg/RunOverLabel
@onready var revive_bg: ColorRect = $UI/ReviveBg

func _ready() -> void:
	player.died.connect(_on_player_died)

## Phase 3.2: first death each run offers a revive (GDD 6.4); declining it,
## or a second death, falls through to the run-over screen. The tree is
## already paused by player.gd; UI keeps working since the UI CanvasLayer is
## process_mode ALWAYS.
func _on_player_died() -> void:
	if player.can_offer_revive():
		revive_bg.visible = true
	else:
		_show_run_over()

## The run is truly over here (no revive left or it was declined), so this
## is the one place this run's treats bank to the wallet (GDD 10.1).
func _show_run_over() -> void:
	var distance_m: float = player.distance_traveled / player.PX_PER_UNIT
	var banked: int = player.treats_collected
	Save.add_treats(banked)
	run_over_label.text = "Run over!\nDistance: %.0fm\nTreats: +%d\nWallet: %d" % [distance_m, banked, Save.get_wallet()]
	run_over_bg.visible = true

func _on_watch_ad_button_pressed() -> void:
	AdService.show_rewarded("revive", _on_revive_ad_success)

func _on_revive_ad_success() -> void:
	revive_bg.visible = false
	rival.clear_hazards()
	# The single placed Obstacle may already be gone (Zoomies free it).
	var obstacle := get_node_or_null("Obstacle")
	if obstacle != null:
		obstacle.clear_if_on_screen()
	player.revive()

func _on_no_button_pressed() -> void:
	revive_bg.visible = false
	_show_run_over()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
