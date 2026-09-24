extends Control

## Phase 3.4a: reusable Settings overlay, instanced by both the title screen
## and the pause menu. Talks only to the Save autoload, which persists the
## values and applies them to the SFX/Music buses. Owners route Android
## Back through is_open()/close().

@onready var sound_toggle: CheckButton = $SoundToggle
@onready var music_toggle: CheckButton = $MusicToggle
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	version_label.text = "v%s" % (version if not version.is_empty() else "dev")

## Syncs the toggles without re-writing the save.
func open() -> void:
	sound_toggle.set_pressed_no_signal(Save.is_sound_on())
	music_toggle.set_pressed_no_signal(Save.is_music_on())
	visible = true

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _on_sound_toggle_toggled(on: bool) -> void:
	Save.set_sound_on(on)

func _on_music_toggle_toggled(on: bool) -> void:
	Save.set_music_on(on)

func _on_close_button_pressed() -> void:
	close()
