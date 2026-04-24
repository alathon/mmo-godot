class_name Hotbar
extends Control

const HOTBAR_BUTTONS_NUM = 12

@export var bar_id: StringName = &"hotbar_1"
@onready var _container: HBoxContainer = $HBoxContainer

var _buttons: Dictionary[StringName, HotbarButton] = {}

var slot_activation_handler: Callable

func set_slot_activation_handler(c: Callable) -> void:
	slot_activation_handler = c

func _ready() -> void:
	_setup_button_slot_ids()

func _setup_button_slot_ids() -> void:
	_buttons.clear()
	var btn_id: int = 1
	for btn in _container.get_children():
		var button: HotbarButton = btn as HotbarButton
		if button == null or not button.name.begins_with("HotbarButton"):
			continue

		var slot_id: StringName = StringName("%s_slot_%d" % [bar_id, btn_id])
		_buttons.set(slot_id, button)
		button.slot_id = slot_id
		_setup_button_keybind(slot_id, button)
		if not button.slot_pressed.is_connected(_on_slot_pressed):
			button.slot_pressed.connect(_on_slot_pressed)
		btn_id += 1

	# TODO: Remove once done testing.
	# This just sets fireball on slot 1.
	var btn = _buttons.get(&"hotbar_1_slot_1") as HotbarButton
	if btn != null:
		btn.set_slot_data(HotbarButton.SlotDataType.ABILITY, 1, true)

	var btn2 = _buttons.get(&"hotbar_1_slot_2") as HotbarButton
	if btn2 != null:
		btn2.set_slot_data(HotbarButton.SlotDataType.ABILITY, 2, true)

	var btn3 = _buttons.get(&"hotbar_1_slot_3") as HotbarButton
	if btn3 != null:
		btn3.set_slot_data(HotbarButton.SlotDataType.ABILITY, 3, true)

func _setup_button_keybind(slot_id: StringName, button: HotbarButton) -> void:
	button.clear_keybind()
	if not InputMap.has_action(slot_id):
		return

	for event in InputMap.action_get_events(slot_id):
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue

		var keycode: String = OS.get_keycode_string(key_event.physical_keycode)
		button.bind_key(key_event, keycode)
		return

func set_bar_id(id: StringName) -> void:
	bar_id = id
	_setup_button_slot_ids()

func init(id: StringName) -> void:
	bar_id = id
	_setup_button_slot_ids()

func _on_slot_pressed(slot_id: StringName) -> void:
	var btn = _buttons.get(slot_id, null)
	if btn == null:
		push_error("Activation from slot_id not in _buttons (%s)!" % slot_id)
		return
	
	if slot_activation_handler.is_null():
		return
	
	var result = slot_activation_handler.call(btn)
	
	if not bool(result.get("accepted", false)):
		return

	btn.set_cooldown_amount(float(result.get("cooldown", 0.0)))
