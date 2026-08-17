extends Node

## Pure input interpretation: tap = hop, hold = bark charge/release.
## No gameplay logic here - only signals, so this can be tested headlessly.

signal hop_requested
signal charge_started
signal bark_released(full: bool)
signal zoomie_nudge_requested

enum State { IDLE, TIMING, CHARGING, COOLDOWN }

@export var tuning: Tuning = preload("res://resources/tuning.tres")

var zoomies_active := false

var _state: State = State.IDLE
var _touch_start_ms: int = 0
var _cooldown_end_ms: int = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_touch(event.pressed)

func _process(_delta: float) -> void:
	match _state:
		State.TIMING:
			if Time.get_ticks_msec() - _touch_start_ms >= tuning.bark_threshold_ms:
				_state = State.CHARGING
				charge_started.emit()
		State.COOLDOWN:
			if Time.get_ticks_msec() >= _cooldown_end_ms:
				_state = State.IDLE

func _on_touch(pressed: bool) -> void:
	if zoomies_active:
		if not pressed:
			zoomie_nudge_requested.emit()
		return
	if pressed:
		_on_touch_down()
	else:
		_on_touch_up()

func _on_touch_down() -> void:
	if _state == State.IDLE:
		_touch_start_ms = Time.get_ticks_msec()
		_state = State.TIMING

func _on_touch_up() -> void:
	match _state:
		State.TIMING:
			hop_requested.emit()
			_state = State.IDLE
		State.CHARGING:
			var charge_ms := Time.get_ticks_msec() - _touch_start_ms
			bark_released.emit(charge_ms >= tuning.bark_full_charge_ms)
			_state = State.COOLDOWN
			_cooldown_end_ms = Time.get_ticks_msec() + int(tuning.bark_cooldown_s * 1000.0)

func get_state_name() -> String:
	match _state:
		State.IDLE: return "IDLE"
		State.TIMING: return "TIMING"
		State.CHARGING: return "CHARGING"
		State.COOLDOWN: return "COOLDOWN"
	return "?"
