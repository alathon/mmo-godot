class_name UIRoot
extends CanvasLayer

@onready var _hotbar: Hotbar = %Hotbar
@onready var _cast_bar: CastBar = %CastBar

var _local_ability_controller: LocalAbilityController
var _local_player: Player
var _local_player_ability_state: AbilityState
var _ground_targeting_button: HotbarButton = null
var _cast_bar_request_id: int = -1

@onready var _game_manager: GameManager = $/root/Root/Services/GameManager
@onready var _ground_targeting_mode: GroundTargetingMode = $/root/Root/Services/GroundTargetingMode
@onready var _event_gateway: EventGateway = $/root/Root/Services/EventGateway

var _request_to_hotbar_button: Dictionary[int, HotbarButton] = {}

func _ready() -> void:
	_hotbar.set_slot_activation_handler(Callable(self, "_activate_hotbar_slot"))
	_game_manager.local_player_spawned.connect(_on_player_spawn)
	_event_gateway.event_emitted.connect(_on_game_event_emitted)
	_ground_targeting_mode.target_confirmed.connect(_on_ground_target_confirmed)

func _process(_delta: float) -> void:
	_refresh_hotbar_availability()

# PUBLIC
func get_gcd_remaining() -> float:
	if _local_player_ability_state != null:
		return _local_player_ability_state.get_gcd_remaining_visual(NetworkTime.tick, NetworkTime.tick_factor)
	return 0.0

# SIGNALS
func _on_game_event_emitted(event: GameEvent):
	if event == null:
		return

	match event.type:
		GameEvent.Type.ABILITY_USE_STARTED:
			_on_ability_use_started(event)
		GameEvent.Type.ABILITY_USE_CANCELED:
			_on_ability_use_canceled(event)
		GameEvent.Type.ABILITY_USE_FINISHED:
			_on_ability_use_finished(event)
		GameEvent.Type.ABILITY_USE_IMPACT:
			_on_ability_use_impact(event)

func _on_ability_use_started(event: GameEvent):
	var data: AbilityUseStartedGameEventData = event.data as AbilityUseStartedGameEventData
	if data == null or not _is_local_source(data.source_entity_id):
		return
	if data.cast_time <= 0.0:
		return

	var ability: AbilityResource = AbilityDB.get_ability(data.ability_id)
	var ability_display_name: String = ability.get_ability_name() if ability != null else ""
	if ability_display_name.is_empty():
		ability_display_name = "Casting"

	_cast_bar_request_id = data.request_id
	_cast_bar.start_cast(ability_display_name, data.cast_time)
	return
func _on_ability_use_finished(event: GameEvent):
	var data: AbilityUseSimpleGameEventData = event.data as AbilityUseSimpleGameEventData
	if data == null:
		return
	_clear_cast_bar(data.source_entity_id, data.request_id)
	return

func _on_ability_use_canceled(event: GameEvent):
	var data: AbilityUseCanceledGameEventData = event.data as AbilityUseCanceledGameEventData
	if data == null:
		return

	_clear_cast_bar(data.source_entity_id, data.request_id)

	var btn = _request_to_hotbar_button.get(data.request_id)
	if btn == null:
		return

	btn.set_cooldown_amount(0.0)
	_request_to_hotbar_button.erase(data.request_id)

func _on_ability_use_impact(event: GameEvent):
	var btn = _request_to_hotbar_button.get(event.data.request_id)
	if btn == null:
		return
	_request_to_hotbar_button.erase(event.data.request_id)

func _on_player_spawn(player: Player):
	_local_player = player
	_local_ability_controller = player.get_node("%LocalAbilityController")
	_local_player_ability_state = player.get_node("%EntityState/%AbilityState")
	_refresh_hotbar_availability()

func _on_ground_target_confirmed(ability_id: int, target: AbilityTargetSpec) -> void:
	_activate_ground_targeted_ability(ability_id, target, _ground_targeting_button)

# INTERNAL
func _activate_hotbar_slot(button: HotbarButton) -> Dictionary:
	# TODO: Other types of hotbar slots.
	if button.slot_data_type != HotbarButton.SlotDataType.ABILITY:
		return { "accepted": false }

	if _local_player == null or _local_ability_controller == null:
		return { "accepted": false }

	var ability_id: int = int(button.slot_data)
	var ability: AbilityResource = AbilityDB.get_ability(ability_id)
	if ability == null:
		return { "accepted": false }

	if ability.target_type == AbilityResource.TargetType.GROUND:
		if _ground_targeting_mode.is_active_for(ability_id):
			var target: AbilityTargetSpec = _ground_targeting_mode.build_target_spec_at_cursor()
			if target == null:
				return { "accepted": false }
			return _activate_ground_targeted_ability(ability_id, target, button)

		_ground_targeting_button = button
		if not _ground_targeting_mode.activate(ability_id):
			_ground_targeting_button = null
			return { "accepted": false }
		return {
			"accepted": true,
			"cooldown": 0.0,
			"request_id": -1,
			"entered_targeting": true,
		}

	var result = _local_ability_controller.try_activate_from_hotbar(ability_id, NetworkTime.tick)
	if not result.accepted:
		return { "accepted": false }

	_request_to_hotbar_button.set(result.request_id, button)

	return {
		"accepted": true,
		"cooldown": result.cooldown,
		"request_id": result.request_id
	}

func _activate_ground_targeted_ability(
		ability_id: int,
		target: AbilityTargetSpec,
		button: HotbarButton) -> Dictionary:
	if _local_ability_controller == null:
		return { "accepted": false }

	var result: Dictionary = _local_ability_controller.try_activate_ground_target(
			ability_id,
			target,
			NetworkTime.tick)
	if not bool(result.get("accepted", false)):
		return { "accepted": false }

	var request_id: int = int(result.get("request_id", -1))
	if button != null:
		button.set_cooldown_amount(float(result.get("cooldown", 0.0)))
		if request_id > 0:
			_request_to_hotbar_button.set(request_id, button)

	_ground_targeting_button = null
	_ground_targeting_mode.deactivate()
	return result

func _clear_cast_bar(source_entity_id: int, request_id: int) -> void:
	if not _is_local_source(source_entity_id):
		return
	if _cast_bar_request_id > 0 and request_id > 0 and request_id != _cast_bar_request_id:
		return

	_cast_bar.clear_cast()
	_cast_bar_request_id = -1

func _is_local_source(source_entity_id: int) -> bool:
	return _local_player != null and source_entity_id == _local_player.id

func _refresh_hotbar_availability() -> void:
	for button in _hotbar.get_buttons():
		var unavailable := false
		if _local_ability_controller != null and button.slot_data_type == HotbarButton.SlotDataType.ABILITY:
			unavailable = _local_ability_controller.is_hotbar_ability_unavailable(int(button.slot_data))
		button.set_unavailable(unavailable)
