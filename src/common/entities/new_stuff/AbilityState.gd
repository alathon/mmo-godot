class_name AbilityState
extends Node

var gcd_remaining: float = 0.0
var anim_lock_remaining: float = 0.0
var current_cast: Cast = null
var current_queue: Cast = null

class Cast:
	var cast_request_id: int = -1
	var cast_ability_id: int = -1
	var cast_target: AbilityTargetSpec = null
	var cast_start_tick: int = 0
	var cast_lock_tick: int = 0
	var cast_resolve_tick: int = 0
	var cast_finish_tick: int = 0
	var cast_impact_tick: int = 0
	var cast_locked: bool = false
	var cast_resolve_data: Variant

func is_casting() -> bool:
	return current_cast != null

func has_queued_cast() -> bool:
	return current_queue != null

# Lock the current cast.
func lock_current_cast(tick: int = -1):
	if current_cast:
		current_cast.cast_locked = true
		if tick != -1: # Overwrite lock tick if specified
			current_cast.cast_lock_tick = tick

# Resolve the current cast.
func resolve_current_cast(resolve_data: Variant, tick: int = -1):
	if current_cast:
		current_cast.cast_resolve_data = resolve_data
		if tick != -1: # Overwrite resolve tick if specified
			current_cast.cast_resolve_tick = tick

func start_cast(tick: int, ability: AbilityResource, target_spec: AbilityTargetSpec) -> Cast:
	if current_cast != null:
		return start_queue(tick, ability, target_spec)
	
	current_cast = _cast_from_ability(tick, ability, target_spec)
	# TODO: Set gcd
	# TODO: Set animation lock
	# TODO: What decays/keeps track of gcd/anim lock. Do we run _process() in here, or rely on external to do so?
	return current_cast

func start_queue(tick: int, ability: AbilityResource, target_spec: AbilityTargetSpec) -> Cast:
	if current_cast == null:
		push_error("Tried queueing ability when we aren't casting anything!")
		return null

	current_queue = _cast_from_ability(tick, ability, target_spec)
	return current_queue

func _cast_from_ability(tick: int, ability: AbilityResource, target_spec: AbilityTargetSpec) -> Cast:
	var cast = Cast.new()
	cast = Cast.new()
	cast.cast_ability_id = ability.ability_id
	cast.cast_target = target_spec
	cast.cast_start_tick = tick
	cast.cast_lock_tick = _get_lock_tick(tick, ability)
	cast.cast_resolve_tick = _get_resolve_tick(tick, ability)
	cast.cast_finish_tick = _get_finish_tick(tick, ability)
	cast.cast_impact_tick = _get_impact_tick(tick, ability)
	return cast

func _get_ticks(seconds: float):
	return floor(seconds * Globals.TICK_RATE)

func _get_lock_tick(tick: int, ability: AbilityResource):
	var time_into_ticks = _get_ticks(ability.cast_lock_time)
	return tick + time_into_ticks

func _get_resolve_tick(tick: int, ability: AbilityResource):
	var total = _get_ticks(ability.cast_time)
	return tick + (total - ability.resolve_lead_ticks)

func _get_finish_tick(tick: int, ability: AbilityResource):
	return tick + _get_ticks(ability.cast_time)

func _get_impact_tick(tick: int, ability: AbilityResource):
	return tick + _get_ticks(AbilityConstants.IMPACT_DELAY_DURATION)
