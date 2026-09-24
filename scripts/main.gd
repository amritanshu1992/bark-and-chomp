extends Node2D

@onready var player: Node2D = $Player
@onready var rival: Node2D = $Rival
@onready var run_over_bg: ColorRect = $UI/RunOverBg
@onready var run_over_label: Label = $UI/RunOverBg/RunOverLabel
@onready var revive_bg: ColorRect = $UI/ReviveBg
@onready var treat_button: Button = $UI/ReviveBg/TreatButton

## A run's treats bank exactly once, whichever way the run ends.
var _run_banked := false
var _banked_amount := 0

func _ready() -> void:
	player.died.connect(_on_player_died)

## Phase 3.2: first death each run offers a revive (GDD 6.4); declining it,
## or a second death, falls through to the run-over screen. The tree is
## already paused by player.gd; UI keeps working since the UI CanvasLayer is
## process_mode ALWAYS.
func _on_player_died() -> void:
	if player.can_offer_revive():
		_refresh_treat_button()
		revive_bg.visible = true
	else:
		_show_run_over()

## The run is truly over here (no revive left or it was declined), so this
## run's treats bank to the wallet (GDD 10.1).
func _show_run_over() -> void:
	var distance_m: float = player.distance_traveled / player.PX_PER_UNIT
	var banked := _bank_run_treats()
	run_over_label.text = "Run over!\nDistance: %.0fm\nTreats: +%d\nWallet: %d" % [distance_m, banked, Save.get_wallet()]
	run_over_bg.visible = true

## Phase 3.1a: the treat revive can draw on this run's (unbanked) treats as
## well as the wallet. Shown disabled with the balance when unaffordable, so
## the player learns the option exists.
func _revive_cost() -> int:
	return player.tuning.revive_cost_treats

func _treats_available() -> int:
	return Save.get_wallet() + player.treats_collected

func _refresh_treat_button() -> void:
	var cost := _revive_cost()
	var available := _treats_available()
	if available >= cost:
		treat_button.disabled = false
		treat_button.text = "%d treats" % cost
	else:
		treat_button.disabled = true
		treat_button.text = "%d treats\n(you have %d)" % [cost, available]

func _on_watch_ad_button_pressed() -> void:
	AdService.show_rewarded("revive", _do_revive)

## Spends this run's treats first, then the wallet. Never touches the Zoomie
## meter. Guarded so a stray second press (prompt already gone) or an
## unaffordable press does nothing.
func _on_treat_button_pressed() -> void:
	var cost := _revive_cost()
	if not revive_bg.visible or _treats_available() < cost:
		return
	var from_run: int = mini(cost, player.treats_collected)
	player.treats_collected -= from_run
	Save.try_spend(cost - from_run)
	_do_revive()

func _do_revive() -> void:
	revive_bg.visible = false
	rival.clear_hazards()
	# The single placed Obstacle may already be gone (Zoomies free it).
	var obstacle := get_node_or_null("Obstacle")
	if obstacle != null:
		obstacle.clear_if_on_screen()
	player.revive()

## Idempotent: returns what this run banked, adding it to the wallet only on
## the first call.
func _bank_run_treats() -> int:
	if not _run_banked:
		_run_banked = true
		_banked_amount = player.treats_collected
		Save.add_treats(_banked_amount)
	return _banked_amount

func _on_no_button_pressed() -> void:
	if not revive_bg.visible:
		return
	revive_bg.visible = false
	_show_run_over()

## Restart ends the run too (including from the revive prompt), so bank
## first -- otherwise the reload would silently drop this run's treats.
func _on_restart_button_pressed() -> void:
	_bank_run_treats()
	get_tree().paused = false
	get_tree().reload_current_scene()
