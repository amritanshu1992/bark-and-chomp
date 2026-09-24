extends SceneTree

## Standalone headless unit test for Phase 3.2's revive flow: player.gd's
## revive state reset + post-revive grace invincibility, and the AdService
## rewarded-ad stub. Run with: godot --headless -s res://scripts/tests/test_revive.gd

func _init() -> void:
	var PlayerScript := load("res://scripts/player.gd")
	var AdServiceScript := load("res://scripts/ad_service.gd")
	var ok := true

	# A fresh run offers exactly one revive.
	var p = PlayerScript.new()
	p.tuning.hits_to_die = 3
	p.tuning.hit_window_s = 8.0
	p.tuning.revive_grace_s = 1.5
	if not p.can_offer_revive():
		push_error("FAIL: a fresh run should offer a revive")
		ok = false

	# Die, then revive: the rolling hit window must be cleared, otherwise the
	# very next hit would re-kill the dog instantly.
	p.register_hit(0.0)
	p.register_hit(1.0)
	p.register_hit(2.0)
	p.begin_revive_grace()
	if p.register_hit(2.5):
		push_error("FAIL: revive must clear the hit window -- one hit after revive killed the dog")
		ok = false
	if p.can_offer_revive():
		push_error("FAIL: a second death in the same run must not offer another revive")
		ok = false

	# Grace invincibility: on right after revive, off once revive_grace_s elapses.
	var p2 = PlayerScript.new()
	p2.tuning.revive_grace_s = 1.5
	if p2.is_invincible():
		push_error("FAIL: should not be invincible before any revive")
		ok = false
	p2.begin_revive_grace()
	if not p2.is_invincible():
		push_error("FAIL: should be invincible immediately after revive")
		ok = false
	p2.tick_revive_grace(1.0)
	if not p2.is_invincible():
		push_error("FAIL: should still be invincible 1.0s into a 1.5s grace")
		ok = false
	p2.tick_revive_grace(0.6)
	if p2.is_invincible():
		push_error("FAIL: grace invincibility should end after revive_grace_s")
		ok = false

	# AdService stub: Phases 1-3 always succeed, synchronously.
	var got := {"called": false}
	AdServiceScript.show_rewarded("revive", func() -> void: got.called = true)
	if not got.called:
		push_error("FAIL: AdService.show_rewarded stub must call on_success")
		ok = false

	if ok:
		print("PASS: revive flow")
	else:
		print("FAIL: revive flow")
	quit(0 if ok else 1)
