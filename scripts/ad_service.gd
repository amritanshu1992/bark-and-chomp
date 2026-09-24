class_name AdService

## Phase 3.2: rewarded-ad seam. Every ad slot (revive now; double treats,
## Zoomie head start, daily chest later) goes through show_rewarded() so the
## real mediation SDK (Phase 4.1) replaces only this function's body, not any
## call site. Static-only, no autoload -- same reasoning as juice.gd.

## Phases 1-3 stub: the "ad" always succeeds, immediately.
static func show_rewarded(_slot: String, on_success: Callable) -> void:
	on_success.call()
