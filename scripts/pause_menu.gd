extends Control

## Phase 3.4a pause menu, instanced under main.tscn's UI layer (process_mode
## ALWAYS, so it works while the tree is paused). Opens from the pause
## button, Android Back, or the app losing focus.
##
## One rule keeps it out of everyone's way: open() does nothing if the tree
## is already paused. The revive prompt, run-over panel, and the Round-4
## bark hint all pause the tree, so none of them can be interrupted or
## double-paused, and this menu never needs to know about them by name.

signal restart_requested
signal home_requested

@onready var settings: Control = $Settings

func _ready() -> void:
	settings.visibility_changed.connect(_on_settings_visibility_changed)

## Hide the menu's own items while the settings overlay is up, so nothing
## shows through or overlaps it (only the dim stays).
func _on_settings_visibility_changed() -> void:
	for child in get_children():
		if child != settings and child.name != "Dim":
			child.visible = not settings.visible

func open() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	visible = true

func resume() -> void:
	if not visible:
		return
	settings.close()
	visible = false
	get_tree().paused = false

func is_open() -> bool:
	return visible

func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			open()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if not visible:
				open()
			elif settings.is_open():
				settings.close()
			else:
				resume()

func _on_resume_button_pressed() -> void:
	resume()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_settings_button_pressed() -> void:
	settings.open()

func _on_home_button_pressed() -> void:
	home_requested.emit()
