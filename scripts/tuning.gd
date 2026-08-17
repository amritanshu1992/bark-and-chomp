class_name Tuning
extends Resource

# Movement
@export var run_speed := 6.0            # 5-7 u/s
@export var gravity := 28.0             # 25-30 u/s^2
@export var hop_impulse := 9.0          # 8-10 u/s

# Input
@export var bark_threshold_ms := 150    # tap vs hold boundary - LOAD-BEARING
@export var bark_full_charge_ms := 400
@export var bark_cooldown_s := 0.85     # 0.7-1.0
@export var bark_range_units := 2.5     # 2-3 dog lengths
@export var bark_hitbox_duration_s := 0.15  # "a few frames" per TDD Sec4.2

# Projectile
@export var projectile_speed := 8.0     # u/s, toward player

# Zoomies
@export var zoomie_duration_s := 4.0
@export var zoomie_speed_mult := 2.25   # 2-2.5x
@export var zoomie_nudge_impulse := 4.0 # tap steering during zoomies
@export var chomp_window_s := 1.5

# Meter
@export var meter_max := 100.0
@export var treat_meter_value := 8.0
@export var deflect_hit_meter_value := 20.0  # deflects feed meter (stun/meter sync fix)

# Rival
@export var rival_target_distance := 8.5     # bumped from plan's 6.0 -- playtest found throws too close/fast to react to
@export var rival_distance_variation := 0.75  # +/-0.5-1.0
@export var rival_rubber_band_k := 2.0        # chase correction strength
@export var rival_max_adjust := 3.0           # u/s clamp on rubber-band correction
@export var throw_interval_min_s := 3.0
@export var throw_interval_max_s := 4.0
@export var throw_telegraph_s := 0.65         # must clear bark_full_charge_ms with margin to react
@export var stun_duration_s := 2.5      # tune upward if chomps too rare

# Economy (Phase 3)
@export var revive_cost_treats := 50
