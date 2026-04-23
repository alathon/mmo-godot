extends CanvasLayer

@onready var _hotbar: Hotbar = %Hotbar

var _local_ability_controller: LocalAbilityController
var _local_player: Player
@onready var _game_manager: GameManager = $/root/Root/Services/GameManager
@onready var _ground_targeting_mode: GroundTargetingMode = $/root/Root/Services/GroundTargetingMode

func _ready() -> void:
	_hotbar.set_slot_activation_handler(Callable(self, "_activate_hotbar_slot"))
	_game_manager.local_player_spawned.connect(_on_player_spawn)

func _on_player_spawn(player: Player):
	_local_player = player
	_local_ability_controller = player.get_node("%LocalAbilityController")
	
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
			"disable": false,
			"entered_targeting": true,
		}

	var result = _local_ability_controller.try_activate_from_hotbar(ability_id, NetworkTime.tick)
	if not result.accepted:
		return { "accepted": false }

	return {
		"accepted": true,
		"cooldown": result.cooldown,
		"disable": result.disable
	}
