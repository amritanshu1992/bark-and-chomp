# Vertical Orientation (Single-Lane Runner) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Bark & Chomp's world from a horizontal side-scroller (`velocity.x` auto-run, `velocity.y` gravity/hop) to a vertical, single-lane, auto-climbing runner, with the phone locked to portrait — with zero change to input scheme, mechanics, or tuning magnitudes.

**Architecture:** Split "how far into the run" from "the player's own screen position." `player.gd` gains a `distance_traveled` accumulator (replaces the role `player.global_position.x` used to play) and stays visually pinned at a fixed screen point (`FIXED_X`, `BASELINE_Y` minus a local hop offset). Every other moving entity (rival, projectile, obstacle, treat) tracks its own `_progress` float and renders each frame via `player.get_track_y(_progress) = BASELINE_Y - (_progress - distance_traveled)`. Real Godot Area2D/CharacterBody2D shape overlap still drives all hit detection — it happens naturally when two entities' rendered Y positions coincide, exactly mirroring how collision worked when the player physically moved through a static horizontal world.

**Tech Stack:** Godot 4.7.1, GDScript 2.0. No test framework is installed in this project (grep confirms GUT is mentioned only aspirationally in `technical_design_document.md`, never actually set up). This plan's tasks therefore verify with the project's real, already-established convention instead of fabricating a framework that isn't there: a headless smoke test after every change, and a mandatory human on-device playtest as the actual definition of done (see "Testing convention" below). The one place a genuine automated test is both cheap and valuable — `get_track_y()`, a pure function — gets a real write-test/verify-fail/implement/verify-pass cycle in Task 2.

**Spec:** `docs/superpowers/specs/2026-08-18-vertical-orientation-design.md`

## Testing convention for this plan

This codebase has no unit test runner. The project's actual, already-validated definition of done (see `technical_design_document.md` §13, and this session's entire Round 1–5 debugging history) is:

1. **Headless smoke test** after every change — catches script/scene parse errors, nothing more:
   ```
   "C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" --headless --path "D:\AI\Business\claud\Bark and Chomp" --quit-after 60
   ```
   Expected: exit code 0, no `SCRIPT ERROR` / `Parse Error` / `Invalid get index` lines in output.
2. **Human on-device playtest** — the only thing that verifies actual gameplay feel/correctness. This is Task 8, at the end, not per-task.

Every task below uses step 1. Task 2 additionally gets a real automated unit test for `get_track_y()`, since it's a pure function cheap to test in isolation via Godot's `-s` script-runner flag — this is the plan's one true TDD cycle; every other task's "test" is the smoke test.

## Global Constraints

- No lane system, no lateral/steering input, no new input scheme — `scripts/input_controller.gd` is **not touched** by any task in this plan.
- `scripts/tuning.gd` numeric values are **not changed** — `run_speed=6.0`, `gravity=28.0`, `hop_impulse=9.0`, `bark_range_units=2.5`, `bark_hitbox_duration_s=1.0`, `projectile_speed=8.0`, `rival_target_distance=8.5`, `rival_distance_variation=0.75`, `rival_rubber_band_k=2.0`, `rival_max_adjust=3.0`, `zoomie_nudge_impulse=4.0`. Only what axis/accumulator these magnitudes apply to changes.
- `PX_PER_UNIT := 64.0` stays the shared px-per-tuning-unit conversion, duplicated as a local const per script (matches this codebase's existing convention — it's already duplicated between `player.gd` and `rival_base.gd`).
- New shared constants, identical value in every file that needs them (duplicated per the same existing-convention reasoning as `PX_PER_UNIT`): `FIXED_X`/`LANE_X := 360.0` (center of the new 720px-wide portrait viewport), `BASELINE_Y := 1000.0` (the player's fixed screen row before hop offset, in the new 1280px-tall portrait viewport).
- Viewport becomes `720×1280` portrait (from `1280×720` landscape); `window/handheld/orientation` becomes `"portrait"`.
- Godot binary: `C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64.exe` (GUI) / `..._console.exe` (headless/console — always use this one for the smoke test and the `-s` unit test).
- Collision at the "did the hop clear it" moment is **genuine Godot Area2D shape-overlap physics** — no manual "is the player currently hopping" boolean check is added anywhere. A well-timed hop naturally lifts the player's collision shape clear of an obstacle's/projectile's shape at the moment their rendered Y positions coincide, exactly as gravity/hop already provides real spatial clearance in the horizontal game today. Do not add a shortcut check that duplicates what shape overlap already does correctly.
- Commit only the files each task lists. Do not sweep in other already-modified-but-unrelated files from earlier session work.

---

### Task 1: Portrait viewport + project settings

**Files:**
- Modify: `project.godot:19-23`
- Modify: `technical_design_document.md:13-15`

**Interfaces:** None (no code, config/doc only).

- [ ] **Step 1: Swap the display settings to portrait**

In `project.godot`, change:
```ini
[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation="landscape"
```
to:
```ini
[display]

window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation="portrait"
```

- [ ] **Step 2: Update the stale TDD orientation line**

In `technical_design_document.md`, find the line (around line 13):
```
Orientation: landscape. Base resolution 1280×720, stretch mode `canvas_items`, aspect `expand`.
```
Change to:
```
Orientation: portrait. Base resolution 720×1280, stretch mode `canvas_items`, aspect `expand`.
```

- [ ] **Step 3: Smoke test**

Run:
```
"C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" --headless --path "D:\AI\Business\claud\Bark and Chomp" --quit-after 60
```
Expected: exit code 0, zero script/scene errors. (The game will still visually run as the old horizontal layout at this point — that's expected; nothing else has changed yet.)

- [ ] **Step 4: Commit**

```bash
git add project.godot technical_design_document.md
git commit -m "Switch project display settings to portrait for vertical orientation"
```

---

### Task 2: `player.gd` — two-accumulator core (distance_traveled, get_track_y, hop offset)

**Files:**
- Create: `scripts/tests/test_get_track_y.gd`
- Modify: `scripts/player.gd` (full rewrite of `_physics_process`, hop/nudge handlers, camera de-bob, bark hitbox orientation, new `on_obstacle_hit`)
- Modify: `scenes/player.tscn:37-38, 42-81` (Camera2D initial position, UI repositioning for 720-wide portrait)

**Interfaces:**
- Produces (used by every later task): `player.distance_traveled: float`, `func get_track_y(progress: float) -> float`, `func is_invincible() -> bool` (unchanged, already exists), `func get_speed_px_s() -> float` (same name, new implementation), `func on_obstacle_hit() -> void` (new), `const FIXED_X := 360.0`, `const BASELINE_Y := 1000.0`.
- Consumes: `Tuning` resource fields listed in Global Constraints (unchanged names/values).

- [ ] **Step 1: Write the failing test for `get_track_y`**

Create `scripts/tests/test_get_track_y.gd`:
```gdscript
extends SceneTree

## Standalone headless unit test for player.gd's get_track_y() pure function.
## Run with: godot --headless -s res://scripts/tests/test_get_track_y.gd
## This project has no test framework installed, so this is a plain
## SceneTree-script runner test -- the only piece of this migration that's a
## pure function cheap enough to warrant one.

func _init() -> void:
	var PlayerScript := load("res://scripts/player.gd")
	var p = PlayerScript.new()
	p.distance_traveled = 500.0

	var ok := true

	if not is_equal_approx(p.get_track_y(500.0), p.BASELINE_Y):
		push_error("FAIL: progress == distance_traveled must render at BASELINE_Y")
		ok = false

	if not is_equal_approx(p.get_track_y(700.0), p.BASELINE_Y - 200.0):
		push_error("FAIL: progress ahead of distance_traveled must render above baseline (smaller Y)")
		ok = false

	if not is_equal_approx(p.get_track_y(300.0), p.BASELINE_Y + 200.0):
		push_error("FAIL: progress behind distance_traveled must render below baseline (larger Y)")
		ok = false

	if ok:
		print("PASS: get_track_y")
	else:
		print("FAIL: get_track_y")
	quit(0 if ok else 1)
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```
"C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" --headless --path "D:\AI\Business\claud\Bark and Chomp" -s "res://scripts/tests/test_get_track_y.gd"
```
Expected: an error/crash — `get_track_y` and `distance_traveled` don't exist yet on `player.gd` (`Invalid assignment` / `Invalid call. Nonexistent function 'get_track_y'`), non-zero exit code.

- [ ] **Step 3: Rewrite `player.gd`**

Replace the full contents of `scripts/player.gd` with:
```gdscript
extends CharacterBody2D

## Milestone 1.1: auto-run, gravity, tap-to-hop. No double jump in MVP.
## Milestone 1.2: charge squash cue + HOP/CHARGING/BLAST/WHIMPER debug label.
## Milestone 1.3: bark hitbox / projectile deflect.
## Milestone 1.5: Zoomie meter, Zoomies (speed/invincibility/obstacle-destroy),
## tap-nudge steering, and reacting to a landed Chomp (called by rival_base.gd).
## Vertical-orientation migration: the player no longer physically traverses
## the world. `distance_traveled` is the "how far into the run" clock every
## other entity reads via get_track_y(); the player itself stays pinned at
## (FIXED_X, BASELINE_Y) minus a local hop offset, computed manually each
## frame instead of via move_and_slide()/is_on_floor() -- there is no literal
## floor body to slide against any more.

const PX_PER_UNIT := 64.0
const FIXED_X := 360.0
const BASELINE_Y := 1000.0
const CHARGE_SCALE := Vector2(1.3, 0.65)
const LABEL_FLASH_S := 0.4
const BARK_HINT_S := 2.5
const BARK_HINT_TEXT := "Watch the vacuum!\nThe instant it turns RED,\nHOLD to bark it back!"
const ZOOMIE_COLOR := Color(1.0, 0.4, 0.8)
const METER_BAR_MAX_WIDTH := 260.0

@export var tuning: Tuning = preload("res://resources/tuning.tres")

@onready var input_controller: Node = $InputController
@onready var visual: ColorRect = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var debug_label: Label = $UI/DebugLabel
@onready var meter_bar_fill: ColorRect = $UI/MeterBarFill
@onready var hint_label: Label = $UI/HintLabel
@onready var bark_hitbox: Area2D = $BarkHitbox
@onready var bark_hitbox_shape: CollisionShape2D = $BarkHitbox/CollisionShape2D

var distance_traveled: float = 0.0
var hop_offset: float = 0.0
var hop_velocity: float = 0.0
var meter: float = 0.0
var zoomies_active: bool = false
var _current_speed_px_s: float = 0.0
var _flash_id: int = 0
var _bark_hitbox_token: int = 0
var _has_charged_ever: bool = false
var _zoomies_time_left: float = 0.0

func _ready() -> void:
	input_controller.hop_requested.connect(_on_hop_requested)
	input_controller.charge_started.connect(_on_charge_started)
	input_controller.bark_ready.connect(_on_bark_ready)
	input_controller.bark_released.connect(_on_bark_released)
	input_controller.zoomie_nudge_requested.connect(_on_zoomie_nudge_requested)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(96.0, tuning.bark_range_units * PX_PER_UNIT)
	bark_hitbox_shape.shape = shape
	bark_hitbox_shape.position = Vector2(0.0, -shape.size.y / 2.0)

	global_position = Vector2(FIXED_X, BASELINE_Y)

## Returns the screen Y an entity at the given progress should render at
## right now. progress > distance_traveled = still ahead (ie. "up the
## screen", smaller Y, hasn't reached the player yet).
func get_track_y(progress: float) -> float:
	return BASELINE_Y - (progress - distance_traveled)

func _physics_process(delta: float) -> void:
	var speed_mult := tuning.zoomie_speed_mult if zoomies_active else 1.0
	_current_speed_px_s = tuning.run_speed * PX_PER_UNIT * speed_mult
	distance_traveled += _current_speed_px_s * delta

	if hop_offset > 0.0 or hop_velocity != 0.0:
		hop_velocity -= tuning.gravity * PX_PER_UNIT * delta
		hop_offset += hop_velocity * delta
		if hop_offset <= 0.0:
			hop_offset = 0.0
			hop_velocity = 0.0

	global_position = Vector2(FIXED_X, BASELINE_Y - hop_offset)
	# Camera is a child of Player -- cancel the parent's hop bob in local
	# space so the camera's global Y always stays pinned at BASELINE_Y.
	camera.position = Vector2(0.0, hop_offset)

	if zoomies_active:
		_zoomies_time_left -= delta
		if _zoomies_time_left <= 0.0:
			_end_zoomies()

func _on_hop_requested() -> void:
	if hop_offset <= 0.0 and hop_velocity == 0.0:
		hop_velocity = tuning.hop_impulse * PX_PER_UNIT
	_flash_label("HOP")

func _on_zoomie_nudge_requested() -> void:
	hop_velocity = tuning.zoomie_nudge_impulse * PX_PER_UNIT
	_flash_label("NUDGE")

func _on_charge_started() -> void:
	visual.scale = CHARGE_SCALE
	debug_label.text = "CHARGING"
	_has_charged_ever = true

## Called by the rival on its first-ever throw telegraph -- 1.6 silent-observation
## playtest found hold-to-bark is not discoverable unprompted, so this is a minimal
## in-fiction nudge (not the full FTUE tutorial, which is deliberately Phase 3 scope
## per the project plan Sec3.4). Only fires if the player has never held at all.
## Pauses the whole game world for the duration -- reading the hint shouldn't cost
## run distance or leave the player exposed to the throw it's explaining. The rival
## awaits this before starting its telegraph, so the full throw runway begins fresh
## after unpausing.
func maybe_show_bark_hint() -> void:
	if _has_charged_ever:
		return
	get_tree().paused = true
	hint_label.text = BARK_HINT_TEXT
	await get_tree().create_timer(BARK_HINT_S).timeout
	hint_label.text = ""
	get_tree().paused = false

func _on_bark_ready() -> void:
	## Deflect hitbox goes live for a fixed window starting the instant a hold reaches
	## full charge -- point-blank contact is covered without requiring release-instant
	## precision, but the window does NOT extend for as long as the player keeps
	## holding, so holding indefinitely is not free invulnerability: the skill is
	## timing *when you commit* to full charge, not just when you release.
	bark_hitbox.monitorable = true
	_bark_hitbox_token += 1
	var my_token := _bark_hitbox_token
	await get_tree().create_timer(tuning.bark_hitbox_duration_s).timeout
	if _bark_hitbox_token == my_token:
		bark_hitbox.monitorable = false

func _on_bark_released(full: bool) -> void:
	visual.scale = Vector2.ONE
	if full:
		_flash(Color(1.0, 0.6, 0.1), "BLAST")
	else:
		_flash(Color(0.75, 0.75, 0.75), "WHIMPER")

func add_meter(amount: float) -> void:
	if zoomies_active:
		return
	meter = minf(meter + amount, tuning.meter_max)
	_update_meter_bar()
	if meter >= tuning.meter_max:
		_start_zoomies()

func on_treat_collected() -> void:
	add_meter(tuning.treat_meter_value)
	_flash_label("TREAT")

func on_chomp_landed() -> void:
	_flash_label("CHOMP!")

func _start_zoomies() -> void:
	zoomies_active = true
	_zoomies_time_left = tuning.zoomie_duration_s
	meter = 0.0
	_update_meter_bar()
	input_controller.zoomies_active = true
	visual.modulate = ZOOMIE_COLOR
	debug_label.text = "ZOOMIES!"

func _end_zoomies() -> void:
	zoomies_active = false
	input_controller.zoomies_active = false
	visual.modulate = Color.WHITE
	if debug_label.text == "ZOOMIES!":
		debug_label.text = ""

func is_zoomies_active() -> bool:
	return zoomies_active

func is_invincible() -> bool:
	return zoomies_active

func get_speed_px_s() -> float:
	return _current_speed_px_s

func on_projectile_hit() -> void:
	## Placeholder "ouch" cue — real hit consequences (revive flow, GameManager)
	## land in a later phase; this just makes misses visible during playtesting.
	_flash(Color(1.0, 0.0, 0.0), "HIT")

func on_obstacle_hit() -> void:
	## Placeholder "ouch" cue, same convention as on_projectile_hit(). Obstacles
	## used to be a literal physical blocker the player slid against; now that
	## the player's X is fixed and nothing physically traverses the world, a
	## miss is represented as an explicit hit consequence instead.
	_flash(Color(1.0, 0.0, 0.0), "OUCH")

func _update_meter_bar() -> void:
	var ratio := clampf(meter / tuning.meter_max, 0.0, 1.0)
	meter_bar_fill.size.x = METER_BAR_MAX_WIDTH * ratio

func _flash(color: Color, text: String) -> void:
	visual.modulate = color
	_flash_label(text)

func _flash_label(text: String) -> void:
	debug_label.text = text
	_flash_id += 1
	var my_id := _flash_id
	await get_tree().create_timer(LABEL_FLASH_S).timeout
	if _flash_id == my_id:
		debug_label.text = "ZOOMIES!" if zoomies_active else ""
		visual.modulate = ZOOMIE_COLOR if zoomies_active else Color.WHITE
```

- [ ] **Step 4: Run the unit test to verify it passes**

Run the same `-s` command as Step 2. Expected: prints `PASS: get_track_y`, exit code 0.

- [ ] **Step 5: Update `scenes/player.tscn` — camera and UI for portrait**

Change the `Camera2D` node's initial position (it's overridden every frame by `player.gd`, but keep the on-disk value sane):
```
[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(0, 0)
```

Reposition `HintLabel` to fit the new 720px-wide viewport (was sized for 1280px-wide landscape) and sit lower where there's now vertical room:
```
[node name="HintLabel" type="Label" parent="UI"]
offset_left = 20.0
offset_top = 450.0
offset_right = 700.0
offset_bottom = 700.0
theme_override_font_sizes/font_size = 42
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 6
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3
mouse_filter = 2
```
`DebugLabel`, `MeterBarBg`, `MeterBarFill` already fit within 720px width unchanged — leave them as-is.

- [ ] **Step 6: Smoke test**

Run the standard headless smoke test (see Testing convention). Expected: exit 0, zero script/scene errors. (The player will now sit still on screen with a HOP wobble; the rest of the world hasn't been converted yet, so obstacle/rival/treat/projectile will look wrong until later tasks — expected at this point.)

- [ ] **Step 7: Commit**

```bash
git add scripts/tests/test_get_track_y.gd scripts/player.gd scenes/player.tscn
git commit -m "Rewrite player.gd around distance_traveled/get_track_y two-accumulator model"
```

---

### Task 3: `main.tscn` — remove Ground, update scene-file defaults

**Files:**
- Modify: `scenes/main.tscn`

**Interfaces:** None (scene-file only; no script changes).

- [ ] **Step 1: Remove the `Ground` node and its collision shape resource**

In `scenes/main.tscn`, delete the `Ground` `StaticBody2D` node (and its `CollisionShape2D`/`Visual` children) and the now-unused `RectangleShape2D_1` sub_resource it referenced. There is no literal floor any more — `BASELINE_Y` in `player.gd` is a plain constant, not a collidable body.

- [ ] **Step 2: Update placed-node default positions for the new portrait layout**

Update `Player`, `Obstacle`, and `Rival` instance positions to sane on-disk defaults (all three are overwritten every physics frame by their own scripts once Tasks 2/4/5 land, so these values only matter for the very first frame / editor preview):
```
[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(360, 1000)

[node name="Obstacle" parent="." instance=ExtResource("2")]
position = Vector2(360, 1000)

[node name="Rival" parent="." instance=ExtResource("4")]
position = Vector2(360, 1000)
```

The resulting scene file (aside from the `load_steps` count dropping by one since the Ground shape resource is gone) should look like:
```
[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="1"]
[ext_resource type="PackedScene" path="res://scenes/obstacle.tscn" id="2"]
[ext_resource type="Script" path="res://scripts/main.gd" id="3"]
[ext_resource type="PackedScene" path="res://scenes/rival.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/treat_spawner.gd" id="5"]

[node name="Main" type="Node2D"]
script = ExtResource("3")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(360, 1000)

[node name="Obstacle" parent="." instance=ExtResource("2")]
position = Vector2(360, 1000)

[node name="Rival" parent="." instance=ExtResource("4")]
position = Vector2(360, 1000)

[node name="TreatSpawner" type="Node" parent="."]
script = ExtResource("5")

[node name="UI" type="CanvasLayer" parent="."]

[node name="RestartButton" type="Button" parent="UI"]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -160.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = 80.0
grow_horizontal = 0
text = "Restart"

[connection signal="pressed" from="UI/RestartButton" to="." method="_on_restart_button_pressed"]
```

- [ ] **Step 3: Smoke test**

Run the standard headless smoke test. Expected: exit 0, zero script/scene errors.

- [ ] **Step 4: Commit**

```bash
git add scenes/main.tscn
git commit -m "Remove literal Ground node; update scene defaults for portrait"
```

---

### Task 4: `rival_base.gd` — migrate to `_progress`

**Files:**
- Modify: `scripts/rival_base.gd` (full contents below)

**Interfaces:**
- Consumes: `player.distance_traveled: float`, `player.get_track_y(progress: float) -> float`, `player.get_speed_px_s() -> float` (all from Task 2).
- Produces (used by Task 6): `rival._progress: float` (readable by the throw-projectile call site inside this same file, and conceptually by `projectile.launch()`'s first argument in Task 6).

- [ ] **Step 1: Rewrite `rival_base.gd`**

Replace the full contents of `scripts/rival_base.gd` with:
```gdscript
class_name RivalBase
extends Area2D

## Milestone 1.4: placeholder vacuum AI. Base class so guest monsters (later
## phases) are pure reskins -- override sprites/SFX/art only, not this logic.
## Owns its own projectile pool and throw timer, replacing the Milestone 1.3
## test-only projectile_spawner.gd stand-in.
## Milestone 1.5: CAUGHT is wired up -- while STUNNED, a chomp_window_s opens
## the instant the player is in Zoomies; overlap within that window is a CHOMP
## (big payout, respawn ahead), letting the window expire is a miss (early
## recovery, "vacuum recovers and escapes" per the GDD).
## Vertical-orientation migration: this rival no longer tracks its own state
## via global_position.x. It tracks an explicit _progress float (same role
## global_position.x used to play) and renders each frame via
## player.get_track_y(_progress), staying pinned to the single lane's X.

enum State { CHASING, THROWING, STUNNED, REACT, CAUGHT }

const PX_PER_UNIT := 64.0
const LANE_X := 360.0
const POOL_SIZE := 4
const REACT_DURATION_S := 0.3
const KNOCKBACK_PX := 40.0
const CHOMP_RADIUS_PX := 90.0
const CAUGHT_RESPAWN_DELAY_S := 0.6
const RESPAWN_MARGIN_PX := 200.0  # TDD Sec7.1: respawn ahead at target_distance + margin
const NOISE_FREQUENCY := 0.4  # slow sine drift; not a called-out tunable in the TDD

@export var tuning: Tuning = preload("res://resources/tuning.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var player: Node2D = get_node("../Player")
@onready var visual: ColorRect = $Visual

var _progress: float = 0.0
var _state: State = State.CHASING
var _throw_timer_s: float = 0.0
var _react_timer_s: float = 0.0
var _stun_timer_s: float = 0.0
var _chomp_window_s: float = -1.0
var _time: float = 0.0
var _pool: Array[Area2D] = []
var _first_throw_done: bool = false

func _ready() -> void:
	_progress = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT
	_render()
	for i in POOL_SIZE:
		var p: Area2D = projectile_scene.instantiate()
		add_child(p)
		p.returned_to_pool.connect(_on_projectile_returned)
		_pool.append(p)
	_reroll_throw_timer()

func _physics_process(delta: float) -> void:
	_time += delta
	match _state:
		State.CHASING:
			_chase(delta)
			_throw_timer_s -= delta
			if _throw_timer_s <= 0.0:
				_start_throw()
		State.THROWING, State.REACT:
			_chase(delta)
			if _state == State.REACT:
				_react_timer_s -= delta
				if _react_timer_s <= 0.0:
					_enter_stunned()
		State.STUNNED:
			# No active herding while stunned -- just keep pace with the player's BASE
			# (non-Zoomies) speed, deliberately, so it "slows"/holds its relative spot
			# instead of literally freezing in place, while still being slower than
			# a Zoomies-boosted player -- that speed gap is what makes catching it possible.
			_progress += tuning.run_speed * PX_PER_UNIT * delta
			_render()
			_stun_timer_s -= delta
			_update_chomp_window(delta)
			if _state == State.STUNNED and _stun_timer_s <= 0.0:
				_recover_to_chasing()
		State.CAUGHT:
			# Same fix as STUNNED: keep pace with the player's current speed during the
			# catch celebration instead of freezing in place, or a Zoomies-boosted
			# player would leave it stranded far behind before the respawn below runs.
			_progress += _player_speed_px_s() * delta
			_render()

func _render() -> void:
	global_position = Vector2(LANE_X, player.get_track_y(_progress))

func _player_speed_px_s() -> float:
	if player.has_method("get_speed_px_s"):
		return player.get_speed_px_s()
	return tuning.run_speed * PX_PER_UNIT

func _chase(delta: float) -> void:
	var desired := player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT \
		+ sin(_time * NOISE_FREQUENCY) * tuning.rival_distance_variation * PX_PER_UNIT
	var error := desired - _progress
	var max_adjust_px := tuning.rival_max_adjust * PX_PER_UNIT
	var adjust := clampf(error * tuning.rival_rubber_band_k, -max_adjust_px, max_adjust_px)
	var vel := _player_speed_px_s() + adjust
	_progress += vel * delta
	_render()

func _reroll_throw_timer() -> void:
	_throw_timer_s = randf_range(tuning.throw_interval_min_s, tuning.throw_interval_max_s)

func _start_throw() -> void:
	if not _first_throw_done:
		_first_throw_done = true
		if player.has_method("maybe_show_bark_hint"):
			await player.maybe_show_bark_hint()
	_state = State.THROWING
	visual.modulate = Color(1.0, 0.2, 0.1)  # loud wind-up cue -- attacks are never cheap
	visual.scale = Vector2(1.4, 1.4)
	await get_tree().create_timer(tuning.throw_telegraph_s).timeout
	if _state != State.THROWING:
		return  # deflect-hit landed mid-telegraph; don't let the throw stomp REACT/STUNNED
	_throw_projectile()
	visual.modulate = Color.WHITE
	visual.scale = Vector2.ONE
	_reroll_throw_timer()
	_state = State.CHASING

func _throw_projectile() -> void:
	if _pool.is_empty():
		return
	var p: Area2D = _pool.pop_back()
	p.launch(_progress, tuning.projectile_speed * PX_PER_UNIT, player)

func _on_projectile_returned(p: Area2D) -> void:
	_pool.append(p)

func on_deflect_hit() -> void:
	if _state == State.STUNNED or _state == State.REACT or _state == State.CAUGHT:
		return
	_state = State.REACT
	_react_timer_s = REACT_DURATION_S
	_progress += KNOCKBACK_PX
	_render()
	visual.scale = Vector2.ONE
	visual.modulate = Color(1.0, 0.3, 0.3)
	if player.has_method("add_meter"):
		player.add_meter(tuning.deflect_hit_meter_value)

func _enter_stunned() -> void:
	_state = State.STUNNED
	_stun_timer_s = tuning.stun_duration_s
	_chomp_window_s = -1.0
	visual.modulate = Color(0.6, 0.6, 0.6)

func _update_chomp_window(delta: float) -> void:
	var player_zoomies: bool = player.has_method("is_zoomies_active") and player.is_zoomies_active()
	if not player_zoomies:
		_chomp_window_s = -1.0
		return
	if _chomp_window_s < 0.0:
		_chomp_window_s = tuning.chomp_window_s
	if global_position.distance_to(player.global_position) <= CHOMP_RADIUS_PX:
		_on_chomped()
		return
	_chomp_window_s -= delta
	if _chomp_window_s <= 0.0:
		_recover_to_chasing()  # miss: vacuum recovers and escapes

func _recover_to_chasing() -> void:
	visual.modulate = Color.WHITE
	# Escape animation stand-in: the vacuum was frozen in place for react+stun while
	# the player kept advancing, so a plain rubber-band correction would leave it
	# crawling back into frame for several seconds. Snap back into range instead.
	_progress = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT
	_render()
	_chomp_window_s = -1.0
	_state = State.CHASING

func _on_chomped() -> void:
	_state = State.CAUGHT
	visual.modulate = Color(1.0, 0.85, 0.2)  # dust-bag-burst stand-in
	if player.has_method("on_chomp_landed"):
		player.on_chomp_landed()
	await get_tree().create_timer(CAUGHT_RESPAWN_DELAY_S).timeout
	_progress = player.distance_traveled + tuning.rival_target_distance * PX_PER_UNIT + RESPAWN_MARGIN_PX
	_render()
	visual.modulate = Color.WHITE
	_reroll_throw_timer()
	_state = State.CHASING
```

- [ ] **Step 2: Smoke test**

Run the standard headless smoke test. Expected: exit 0, zero script/scene errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/rival_base.gd
git commit -m "Migrate rival_base.gd from global_position.x to _progress"
```

---

### Task 5: Obstacle — new `obstacle.gd`, scene conversion to Area2D

**Files:**
- Create: `scripts/obstacle.gd`
- Modify: `scenes/obstacle.tscn` (convert `StaticBody2D` → `Area2D`)

**Interfaces:**
- Consumes: `player.distance_traveled` (unused directly — obstacle only needs `player.get_track_y()`), `player.get_track_y(progress: float) -> float`, `player.is_invincible() -> bool`, `player.on_obstacle_hit() -> void` (all from Task 2).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write `scripts/obstacle.gd`**

```gdscript
extends Area2D

## Vertical-orientation migration: obstacle used to be a bare StaticBody2D
## the player physically slid/hopped past as they moved through the world.
## Now the player's X is fixed and nothing physically traverses the world,
## so this becomes an Area2D at a fixed target _progress that renders itself
## each frame via player.get_track_y() -- same pattern as rival/projectile/
## treat. Real hop clearance is still genuine Godot shape-overlap physics:
## a well-timed hop lifts the player's collision shape clear of this one's
## at the moment their rendered Y positions coincide.

const LANE_X := 360.0

## How far into the run this obstacle sits. Phase-1 scope: one static
## instance, no spawner (matches the pre-migration game, which also only
## ever had one placed Obstacle instance in main.tscn).
@export var target_progress: float = 1500.0

@onready var _player: Node2D = get_node("../Player")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	global_position = Vector2(LANE_X, _player.get_track_y(target_progress))

func _physics_process(_delta: float) -> void:
	global_position.y = _player.get_track_y(target_progress)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("is_invincible") and body.is_invincible():
		queue_free()
		return
	if body.has_method("on_obstacle_hit"):
		body.on_obstacle_hit()
```

- [ ] **Step 2: Convert `scenes/obstacle.tscn` from `StaticBody2D` to `Area2D`**

Replace the full contents of `scenes/obstacle.tscn` with:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/obstacle.gd" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(64, 96)

[node name="Obstacle" type="Area2D" groups=["obstacle"]]
collision_layer = 64
collision_mask = 2
script = ExtResource("1")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -32.0
offset_top = -48.0
offset_right = 32.0
offset_bottom = 48.0
mouse_filter = 2
color = Color(0.8, 0.2, 0.2, 1)
```
(`collision_layer = 64` is a new, previously-unused layer bit; `collision_mask = 2` detects the Player's `collision_layer = 2`, same pattern as `treat.tscn`'s `layer=32 / mask=2`.)

- [ ] **Step 3: Smoke test**

Run the standard headless smoke test. Expected: exit 0, zero script/scene errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/obstacle.gd scenes/obstacle.tscn
git commit -m "Convert obstacle to progress-tracking Area2D"
```

---

### Task 6: `projectile.gd` — migrate to `_progress`

**Files:**
- Modify: `scripts/projectile.gd` (full contents below)

**Interfaces:**
- Consumes: `player.get_track_y(progress: float) -> float`, `player.is_invincible() -> bool`, `player.on_projectile_hit() -> void` (all from Task 2); `rival._progress: float` (from Task 4, read at the call site inside `rival_base.gd::_throw_projectile()`, already updated in Task 4's rewrite).
- Produces: `func launch(from_progress: float, speed_px_s: float, player_ref: Node2D) -> void` — **signature change** from the old `launch(from_position: Vector2, speed_px_s: float)`. `rival_base.gd::_throw_projectile()` was already updated to call the new signature in Task 4.

- [ ] **Step 1: Rewrite `projectile.gd`**

Replace the full contents of `scripts/projectile.gd` with:
```gdscript
extends Area2D

## Milestone 1.3: pooled projectile, flies at the dog, deflected by an active bark hitbox.
## Milestone 1.4: thrown by rival_base.gd; once deflected, hitting the rival's Area2D
## triggers its on_deflect_hit() stun reaction instead of just passing through.
## Milestone 1.5: passes through harmlessly during the player's Zoomies invincibility.
## Vertical-orientation migration: tracks _progress instead of a raw world
## position; _progress_velocity plays the same role velocity_x used to
## (negative = closing on the player, flipped positive on deflect = heading
## back toward the rival). Rendered each frame via player.get_track_y().
## Hop-height clearance needs no extra code here -- it's genuine Area2D shape
## overlap: a well-timed hop lifts the player's shape clear of this one's at
## the moment their rendered Y positions coincide, so a miss from an arriving
## projectile falls out of physics the same way a miss on a static obstacle does.

signal returned_to_pool(projectile: Area2D)

const MAX_LIFETIME_S := 5.0
const LANE_X := 360.0

var _progress: float = 0.0
var _progress_velocity: float = 0.0
var deflected: bool = false
var _age: float = 0.0
var _player: Node2D

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_physics_process(false)
	visible = false

func launch(from_progress: float, speed_px_s: float, player_ref: Node2D) -> void:
	_player = player_ref
	_progress = from_progress
	_progress_velocity = -speed_px_s
	deflected = false
	_age = 0.0
	global_position = Vector2(LANE_X, _player.get_track_y(_progress))
	visual.modulate = Color.WHITE
	visible = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	_progress += _progress_velocity * delta
	global_position.y = _player.get_track_y(_progress)
	_age += delta
	if _age >= MAX_LIFETIME_S:
		_return_to_pool()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bark_hitbox"):
		if deflected:
			return
		deflected = true
		_progress_velocity = absf(_progress_velocity) * 1.15
		visual.modulate = Color(1.0, 0.5, 0.0)
	elif area.is_in_group("rival"):
		if deflected and area.has_method("on_deflect_hit"):
			area.on_deflect_hit()
			_return_to_pool()

func _on_body_entered(body: Node2D) -> void:
	if deflected:
		return
	for area in get_overlapping_areas():
		if area.is_in_group("bark_hitbox"):
			return  # point-blank overlap in the same frame -- let _on_area_entered win the race
	if body.has_method("is_invincible") and body.is_invincible():
		_return_to_pool()
		return
	if body.has_method("on_projectile_hit"):
		body.on_projectile_hit()
	_return_to_pool()

func _return_to_pool() -> void:
	set_physics_process(false)
	visible = false
	returned_to_pool.emit(self)
```

- [ ] **Step 2: Smoke test**

Run the standard headless smoke test. Expected: exit 0, zero script/scene errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/projectile.gd
git commit -m "Migrate projectile.gd from velocity_x to progress/progress_velocity"
```

---

### Task 7: Treats — migrate `treat.gd` and `treat_spawner.gd` to `_progress`

**Files:**
- Modify: `scripts/treat.gd` (full contents below)
- Modify: `scripts/treat_spawner.gd:32-36`

**Interfaces:**
- Consumes: `player.distance_traveled: float`, `player.get_track_y(progress: float) -> float` (both from Task 2).
- Produces: `func activate(progress: float, player_ref: Node2D) -> void` — **signature change** from the old `activate(at_position: Vector2)`. `treat_spawner.gd::_spawn()` is updated in this same task to call the new signature.

- [ ] **Step 1: Rewrite `treat.gd`**

Replace the full contents of `scripts/treat.gd` with:
```gdscript
extends Area2D

## Milestone 1.5: pooled treat pickup. Feeds the player's Zoomie meter on contact.
## Vertical-orientation migration: previously fully static once activated,
## because the player used to move toward it. Now the player's X/Y are both
## fixed, so the treat itself needs the same fixed-_progress + per-frame
## render pattern as obstacle/rival/projectile.

signal returned_to_pool(treat: Area2D)

const LANE_X := 360.0

var _progress: float = 0.0
var _player: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visible = false
	monitoring = false

func activate(progress: float, player_ref: Node2D) -> void:
	_progress = progress
	_player = player_ref
	global_position = Vector2(LANE_X, _player.get_track_y(_progress))
	visible = true
	monitoring = true

func _physics_process(_delta: float) -> void:
	if visible:
		global_position.y = _player.get_track_y(_progress)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("on_treat_collected"):
		body.on_treat_collected()
	_return_to_pool()

func _return_to_pool() -> void:
	visible = false
	monitoring = false
	returned_to_pool.emit(self)
```

- [ ] **Step 2: Update `treat_spawner.gd::_spawn()`**

In `scripts/treat_spawner.gd`, change:
```gdscript
func _spawn() -> void:
	if _pool.is_empty():
		return
	var t: Area2D = _pool.pop_back()
	t.activate(Vector2(player.global_position.x + SPAWN_AHEAD_PX, player.global_position.y))
```
to:
```gdscript
func _spawn() -> void:
	if _pool.is_empty():
		return
	var t: Area2D = _pool.pop_back()
	t.activate(player.distance_traveled + SPAWN_AHEAD_PX, player)
```

- [ ] **Step 3: Smoke test**

Run the standard headless smoke test. Expected: exit 0, zero script/scene errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/treat.gd scripts/treat_spawner.gd
git commit -m "Migrate treat pickups from static world position to progress tracking"
```

---

### Task 8: Full integration — build, deploy, human playtest, handoff update

**Files:**
- Modify: `handoff.md` (new session entry)

**Interfaces:** None — this is the closing verification task, not a code task.

- [ ] **Step 1: Rebuild the script-class cache and run a longer smoke test**

```
"C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" --headless --editor --path "D:\AI\Business\claud\Bark and Chomp" --quit
"C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" --headless --path "D:\AI\Business\claud\Bark and Chomp" --quit-after 120
```
Expected: exit 0, zero script/scene errors, across the whole migrated game running together for the first time.

- [ ] **Step 2: Build and deploy to the physical Android test device**

```
"C:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" --headless --export-debug "Android" "builds/android/bark_and_chomp.apk"
adb install -r builds/android/bark_and_chomp.apk
adb shell am force-stop com.barkandchomp.game
adb shell monkey -p com.barkandchomp.game -c android.intent.category.LAUNCHER 1
```
Expected: clean build (only the pre-existing harmless "no project icon" warning), install succeeds, app launches in portrait.

- [ ] **Step 3: Human on-device playtest — the real definition of done for this migration**

Hand off to the user. Per the spec's Testing section, this is **not** a resume of the old Milestone 1.6 findings — it's a fresh pass, because the horizontal game's validated deflect-timing/discoverability findings don't automatically transfer to a vertical single-lane feel even though the underlying mechanics are unchanged. Confirm at minimum:
- Player renders fixed on screen; hop visibly bobs up and clears an oncoming obstacle when timed well, and visibly fails to clear it when mistimed.
- Rival renders above the player and holds its rubber-banded distance as the world scrolls past.
- Bark hitbox reliably deflects a projectile approaching from above.
- A hop performed as a projectile arrives lets it pass by without a hit (shape-overlap clearance).
- Treats spawn ahead, scroll down to the player, and register on contact.
- Zoomies still destroys an obstacle on overlap instead of registering a hit.
- Portrait orientation and UI (DebugLabel, HintLabel, meter bar) are legible and don't overlap.

- [ ] **Step 4: Update `handoff.md`**

Add a new session entry documenting: the vertical-orientation migration is implemented and deployed; the Milestone 1.6 silent-observation playtest protocol must be re-run from scratch (divergence from `bark_and_chomp_project_plan.md`'s original horizontal-prototype-assumed Phase 1 sequencing, as already flagged in the design spec); results of the Step 3 playtest once the user reports back. Bump the "Last updated" line.

- [ ] **Step 5: Commit**

```bash
git add handoff.md
git commit -m "Note vertical-orientation migration deployed; 1.6 playtest protocol needs a fresh pass"
```
