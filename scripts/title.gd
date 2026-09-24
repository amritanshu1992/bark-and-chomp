extends Control

## Phase 3.4a title screen -- the app's main scene. Play starts a run;
## Settings opens the shared overlay. Android Back closes the overlay if
## it's open, otherwise quits (project.godot sets quit_on_go_back=false so
## Back arrives here as a notification).

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var wallet_label: Label = $WalletLabel
@onready var settings: Control = $Settings

func _ready() -> void:
	wallet_label.text = "Treats: %d" % Save.get_wallet()
	settings.visibility_changed.connect(_on_settings_visibility_changed)

## Hide the title's own items while the settings overlay is up, so nothing
## shows through or overlaps it (only the background stays).
func _on_settings_visibility_changed() -> void:
	for child in get_children():
		if child != settings and child.name != "Bg":
			child.visible = not settings.visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if settings.is_open():
			settings.close()
		else:
			get_tree().quit()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_settings_button_pressed() -> void:
	settings.open()
