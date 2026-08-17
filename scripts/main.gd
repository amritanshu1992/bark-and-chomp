extends Node2D

## Dev/testing convenience only — not part of the shipped game loop yet.

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
