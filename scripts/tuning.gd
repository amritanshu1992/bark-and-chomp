class_name Tuning
extends Resource

# Movement
@export var run_speed := 6.0            # 5-7 u/s -- starting speed, ramps toward run_speed_max below
@export var run_speed_max := 10.0       # Subway-Surfers-style feel pass: speed builds over a run instead of staying flat
@export var run_speed_ramp_s := 45.0    # real seconds from run_speed to run_speed_max (runs are 60-120s, so most of a run is at/near max)
@export var gravity := 28.0             # 25-30 u/s^2
@export var hop_impulse := 9.0          # 8-10 u/s

# Input
@export var bark_threshold_ms := 150    # tap vs hold boundary - LOAD-BEARING
@export var bark_full_charge_ms := 400
@export var bark_cooldown_s := 0.85     # 0.7-1.0
@export var bark_range_units := 2.5     # 2-3 dog lengths
@export var bark_hitbox_duration_s := 1.0   # fixed-length deflect window starting at full-charge commit (not release, and not extended by continued holding) -- widened from an original 0.15s post-release-only window ("a few frames" per TDD Sec4.2); 1.6 playtest found that window too tight to land even when the player understood the mechanic, and a naive "stay live for as long as held" version made holding a free-invulnerability strategy. Widened again 0.3->1.0: 0.3s only covered the ~0.18s the projectile spends inside bark_range, but total time from the rival's red telegraph flash to actual contact is ~1.26s (0.65s telegraph + ~0.61s flight, at projectile_speed+run_speed=14u/s closing speed) -- reacting to the red flash instantly (as the in-game hint tells the player to) reached full charge at only 400ms, leaving the old 0.3s window closed ~550ms before the projectile ever arrived. 1.0s covers that full gap with margin across the rival's distance-noise range.

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
@export var rival_target_distance := 11.0    # bumped from 8.5 -- playtest wanted more room between dog and vacuum
@export var rival_distance_variation := 0.75  # +/-0.5-1.0
@export var rival_rubber_band_k := 2.0        # chase correction strength
@export var rival_max_adjust := 3.0           # u/s clamp on rubber-band correction
@export var throw_interval_min_s := 3.0
@export var throw_interval_max_s := 4.0
@export var throw_telegraph_s := 0.65         # must clear bark_full_charge_ms with margin to react
@export var stun_duration_s := 2.5      # tune upward if chomps too rare

# Economy (Phase 3)
@export var revive_cost_treats := 50
