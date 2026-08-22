# Animation scaffolding (Phase 2 sub-project #2)

Bounded design, approved in-chat 2026-08-23. Written to a file at the user's
request; this is not a full architectural spec (no decomposition needed —
the change is confined to `player.gd`/`player.tscn` and
`rival_base.gd`/`rival.tscn`).

## Goal

Replace the ad hoc `visual.modulate`/`visual.scale` assignments that
currently represent player/vacuum state changes with a real
`AnimationPlayer`-driven system, so that when real sprite art and animation
rigs arrive (see `docs/asset_list.md`), only the `Animation` resource content
needs to change — not the state-machine trigger code.

## Scope decisions (from brainstorming)

1. **Replace, don't parallel.** The existing inline cues are replaced by
   AnimationPlayer tracks driving the same `Visual` ColorRect (and `Shadow`
   for the player's hop). Behavior stays visually identical today; only the
   mechanism changes.
2. **Hit and death are separate animations**, even though the GDD lists them
   as one combined "hit/death" item. `hit` plays on every non-lethal
   `on_projectile_hit()`/`on_obstacle_hit()` call and returns to `run`.
   `death` plays only when `_register_hit_and_maybe_die()` actually kills
   (the `died` signal path) and can hold on its last frame — the tree pauses
   immediately after anyway.

## Player (`player.gd` / `player.tscn`)

Add an `AnimationPlayer` node under `Player`, targeting `Visual` (and
`Shadow` where the existing hop-shadow-fade cue applies). Animations, named
to match the GDD's rig list:

`idle`, `run`, `hop`, `charge`, `blast`, `whimper`, `zoomies`, `chomp`,
`hit`, `death`, `victory`.

Each clip's content reproduces what the inline code does today:

| Animation | Replaces this existing code |
|---|---|
| `charge` | `_on_charge_started()`'s `visual.scale = CHARGE_SCALE` |
| `blast` | `_on_bark_released(true)`'s flash-orange `_flash(...)` |
| `whimper` | `_on_bark_released(false)`'s flash-grey `_flash(...)` |
| `zoomies` | `_start_zoomies()`'s `visual.modulate = ZOOMIE_COLOR` (looping) |
| `hit` | `on_projectile_hit()`/`on_obstacle_hit()`'s red flash, non-lethal case |
| `death` | same red flash, held, only on the lethal case |
| `chomp` | new — no current visual cue exists for `on_chomp_landed()` beyond the debug label; placeholder clip added now so the trigger point exists |
| `run`, `idle`, `victory` | not currently cued at all; added as named placeholder clips (can be empty/no-op) so future code has a call site without further scaffolding work |

**`hop` is an exception, not a replacement.** The existing hop visual (lift-
scale + shadow fade) is a continuous, physics-driven per-frame computation
keyed to `hop_offset`/`hop_ratio` in `_physics_process` — not a discrete
state change. It stays exactly as-is; AnimationPlayer can't reproduce a
height-tracked continuous cue without losing accuracy. `hop` is instead a
*new* discrete trigger fired once from `_on_hop_requested()`, for a future
leap-frame sprite animation to layer on top of the untouched procedural
squash/shadow cue — the two coexist once real art exists, the same way many
platformers combine a state animation with procedural stretch.

`_flash_label()`'s debug-text behavior is untouched — it's a separate debug
aid, not part of the animation system, and stays as-is.

Add a single dispatch helper:

```gdscript
func _play_anim(name: String) -> void:
    if anim_player.has_animation(name):
        anim_player.play(name)
```

Replace each direct `visual.modulate =` / `visual.scale =` assignment at the
existing trigger points with a call to `_play_anim(...)`. State-machine
logic (timers, `_is_charging`, `zoomies_active`, `died.emit()`, pausing the
tree, etc.) is untouched.

## Vacuum (`rival_base.gd` / `rival.tscn`)

Same pattern: `AnimationPlayer` under `Rival`, targeting `Visual`.
Animations: `run`, `throw`, `hit`, `stunned`, `defeat`, mapped from the
existing `State` enum transitions (`_start_throw()`'s red wind-up,
`on_deflect_hit()`'s react flash, `_enter_stunned()`'s grey, `_on_chomped()`'s
gold "defeat" flash). `_chase()`'s per-frame `_render()` position update is
unrelated to animation and stays as-is — only the `visual.modulate`/`scale`
lines move into clips.

## Not in scope

- No new game logic, no new signals, no new tunables.
- No real sprite art — clips reproduce today's placeholder ColorRect cues.
- `idle`/`victory`/`chomp` clips exist as named placeholders only; nothing
  currently calls `_play_anim("idle")` or `_play_anim("victory")` since
  there's no pre-run idle state or win condition yet.

## Testing

- Headless smoke test (`godot --headless --editor --quit`), zero errors —
  matches the project's standard scene-load sanity check.
- No new pure-logic unit test: this is a visual-behavior refactor of
  existing trigger points, not new decision logic, so there's nothing
  meaningfully unit-testable beyond what `test_hit_tracking.gd` already
  covers for the death threshold itself.
- Manual on-device pass: trigger each state (hop, charge/blast/whimper,
  treat pickup → zoomies, hit, death, vacuum stun/chomp) and confirm the
  animation-driven visuals match today's behavior. Deferred to the user,
  same as the difficulty-ramp work in sub-project #1 — not yet confirmed
  on-device as of this write-up.
