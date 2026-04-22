class_name AbilityState
extends Node

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0
var current_cast: Cast = null
var current_queue: QueuedRequest = null
var pending_impacts: Array = []


class Cast:
	var request_id: int = 0
	var ability_id: int = 0
	var target: AbilityTargetSpec = null
	var start_tick: int = 0
	var lock_tick: int = 0
	var resolve_tick: int = 0
	var finish_tick: int = 0
	var impact_tick: int = 0
	var locked: bool = false
	var resolved: bool = false
	var finished: bool = false
	var impact_emitted: bool = false
	var costs_committed: bool = false
	var resolve_data: Variant = null


class QueuedRequest:
	var request_id: int = 0
	var ability_id: int = 0
	var target: AbilityTargetSpec = null
	var earliest_activate_tick: int = 0


func tick_time(delta: float) -> void:
	gcd_remaining = maxf(0.0, gcd_remaining - delta)
	anim_lock_remaining = maxf(0.0, anim_lock_remaining - delta)


func is_casting() -> bool:
	return current_cast != null and not current_cast.finished


func has_queued_request() -> bool:
	return current_queue != null


func is_on_gcd() -> bool:
	return gcd_remaining > 0.0


func is_animation_locked() -> bool:
	return anim_lock_remaining > 0.0


func start_cast_from_ability(
		request_id: int,
		ability: AbilityResource,
		target_spec: AbilityTargetSpec,
		start_tick: int) -> Cast:
	if ability == null:
		return null

	if current_cast != null and current_cast.finished and not current_cast.impact_emitted:
		pending_impacts.append(current_cast)

	var cast := Cast.new()
	cast.request_id = request_id
	cast.ability_id = ability.ability_id
	cast.target = target_spec
	cast.start_tick = start_tick
	cast.lock_tick = _get_lock_tick(start_tick, ability)
	cast.resolve_tick = _get_resolve_tick(start_tick, ability)
	cast.finish_tick = _get_finish_tick(start_tick, ability)
	cast.impact_tick = _get_impact_tick(start_tick, ability)
	cast.locked = cast.lock_tick <= start_tick
	current_cast = cast
	current_queue = null

	if ability.uses_gcd:
		gcd_remaining = AbilityConstants.GCD_DURATION
	anim_lock_remaining = AbilityConstants.ANIMATION_LOCK_DURATION

	return current_cast


func confirm_cast_timing(
		request_id: int,
		start_tick: int,
		resolve_tick: int,
		finish_tick: int,
		impact_tick: int) -> void:
	if current_cast == null or current_cast.request_id != request_id:
		return
	current_cast.start_tick = start_tick
	current_cast.resolve_tick = resolve_tick
	current_cast.finish_tick = finish_tick
	current_cast.impact_tick = impact_tick


func finish_cast(request_id: int) -> void:
	if current_cast == null or current_cast.request_id != request_id:
		return
	current_cast.finished = true


func lock_current_cast(request_id: int) -> void:
	if current_cast == null or current_cast.request_id != request_id:
		return
	current_cast.locked = true


func mark_resolved(request_id: int, resolve_data: Variant = null) -> void:
	if current_cast == null or current_cast.request_id != request_id:
		return
	current_cast.resolved = true
	current_cast.resolve_data = resolve_data


func mark_impact_emitted(request_id: int) -> void:
	if current_cast != null and current_cast.request_id == request_id:
		current_cast.impact_emitted = true
		return
	for pending_cast in pending_impacts:
		if pending_cast is Cast and pending_cast.request_id == request_id:
			(pending_cast as Cast).impact_emitted = true
			return


func resolve_current_cast(resolve_data: Variant, tick: int = -1) -> void:
	if current_cast == null:
		return
	current_cast.resolved = true
	current_cast.resolve_data = resolve_data
	if tick >= 0:
		current_cast.resolve_tick = tick


func queue_request(
		request_id: int,
		ability_id: int,
		target_spec: AbilityTargetSpec,
		earliest_activate_tick: int) -> void:
	var queued := QueuedRequest.new()
	queued.request_id = request_id
	queued.ability_id = ability_id
	queued.target = target_spec
	queued.earliest_activate_tick = earliest_activate_tick
	current_queue = queued


func clear_cast(request_id: int = 0) -> void:
	if request_id > 0 and current_cast != null and current_cast.request_id != request_id:
		return
	current_cast = null


func clear_queue(request_id: int = 0) -> void:
	if request_id > 0 and current_queue != null and current_queue.request_id != request_id:
		return
	current_queue = null


func has_pending_impact(request_id: int) -> bool:
	for pending_cast in pending_impacts:
		if pending_cast is Cast and (pending_cast as Cast).request_id == request_id:
			return true
	return false


func get_pending_impact(request_id: int):
	for pending_cast in pending_impacts:
		if pending_cast is Cast and (pending_cast as Cast).request_id == request_id:
			return pending_cast
	return null


func remove_pending_impact(request_id: int) -> void:
	var remaining: Array = []
	for pending_cast in pending_impacts:
		if pending_cast is Cast and (pending_cast as Cast).request_id == request_id:
			continue
		remaining.append(pending_cast)
	pending_impacts = remaining


func _get_ticks(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return int(ceil(seconds * float(Globals.TICK_RATE)))


func _get_lock_tick(tick: int, ability: AbilityResource) -> int:
	if ability.cast_lock_time <= 0.0:
		return tick
	return tick + _get_ticks(ability.cast_lock_time)


func _get_resolve_tick(tick: int, ability: AbilityResource) -> int:
	var total_ticks := _get_ticks(ability.cast_time)
	return tick + maxi(0, total_ticks - ability.resolve_lead_ticks)


func _get_finish_tick(tick: int, ability: AbilityResource) -> int:
	return tick + _get_ticks(ability.cast_time)


func _get_impact_tick(tick: int, ability: AbilityResource) -> int:
	return _get_finish_tick(tick, ability) + _get_ticks(AbilityConstants.IMPACT_DELAY_DURATION)
