class_name UIRoot
extends CanvasLayer

@onready var _hotbar: Hotbar = %Hotbar

var _local_ability_controller: LocalAbilityController
var _local_player: Player
var _local_player_ability_state: AbilityState

@onready var _game_manager: GameManager = $/root/Root/Services/GameManager
@onready var _ground_targeting_mode: GroundTargetingMode = $/root/Root/Services/GroundTargetingMode
@onready var _event_gateway: EventGateway = $/root/Root/Services/EventGateway

var _request_to_hotbar_button: Dictionary[int, HotbarButton]

func _ready() -> void:
	_hotbar.set_slot_activation_handler(Callable(self, "_activate_hotbar_slot"))
	_game_manager.local_player_spawned.connect(_on_player_spawn)
	_event_gateway.event_emitted.connect(_on_game_event_emitted)

# PUBLIC
func get_gcd_remaining() -> float:
	if _local_player_ability_state != null:
		return _local_player_ability_state.gcd_remaining
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
	return
func _on_ability_use_finished(event: GameEvent):
	return

func _on_ability_use_canceled(event: GameEvent):
	var btn = _request_to_hotbar_button.get(event.data.request_id)
	if btn == null:
		push_error("UIRoot._request_to_hotbar_button has no entry for request %s!" % event.data.request_id)
		return

	btn.set_cooldown_amount(0.0)
	_request_to_hotbar_button.erase(event.data.request_id)

func _on_ability_use_impact(event: GameEvent):
	var btn = _request_to_hotbar_button.get(event.data.request_id)
	if btn == null:
		push_error("UIRoot._request_to_hotbar_button has no entry for request %s!" % event.data.request_id)
		return
	_request_to_hotbar_button.erase(event.data.request_id)

func _on_player_spawn(player: Player):
	_local_player = player
	_local_ability_controller = player.get_node("%LocalAbilityController")
	_local_player_ability_state = player.get_node("%EntityState/%AbilityState")

# INTERNAL
func _activate_hotbar_slot(button: HotbarButton) -> Dictionary:
	# TODO: Other types of hotbar slots.
	if button.slot_data_type != HotbarButton.SlotDataType.ABILITY:
		return { "accepted": false }

	if _local_player == null or _local_ability_controller == null:
		return { "accepted": false }

	var ability_id := int(button.slot_data)
	var ability := AbilityDB.get_ability(ability_id)
	if ability == null:
		return { "accepted": false }

	if ability.target_type == AbilityResource.TargetType.GROUND:
		_ground_targeting_mode.activate(ability_id)
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
