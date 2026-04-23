class_name Hotbar
extends Control

const HOTBAR_BUTTONS_NUM = 12

@export var bar_id: StringName = &"hotbar_1"
@onready var _container: HBoxContainer = $HBoxContainer

var _buttons: Dictionary[StringName, HotbarButton] = {}

var slot_activation_handler: Callable

func set_slot_activation_handler(c: Callable):
	slot_activation_handler = c

func _ready():
	_setup_button_slot_ids()

func _setup_button_slot_ids():
	_buttons.clear()
	var btn_id = 1;
	for btn in _container.get_children():
		if btn.name.begins_with("HotbarButton"):
			var slot_id = "%s_slot_%s" % [bar_id, str(btn_id)]
			_buttons.set(slot_id, btn)
			btn.slot_id = slot_id
			_setup_button_keybind(slot_id, btn)
			if not btn.slot_pressed.is_connected(_on_slot_pressed):
				btn.slot_pressed.connect(_on_slot_pressed)
			btn_id += 1

	# TODO: Remove once done testing.
	# This just sets fireball on slot 1.
	var btn = _buttons.get(&"hotbar_1_slot_1")
	print("Btn: %s" % btn)
	if btn != null:
		print("Setting slot data")
		btn.set_slot_data(HotbarButton.SlotDataType.ABILITY, 1)

func _setup_button_keybind( slot_id: StringName, button: HotbarButton):
	var events = InputMap.action_get_events(slot_id)
	if events.size() > 0:
		var event = events[0]
		var keycode = OS.get_keycode_string(event.physical_keycode)
		button.bind_key(event, keycode)

func set_bar_id(id: StringName):
	bar_id = id
	_setup_button_slot_ids()

func init(id: StringName):
	bar_id = id
	_setup_button_slot_ids()

func _on_slot_pressed(slot_id: StringName):
	var btn = _buttons.get(slot_id, null)
	if btn == null:
		push_error("Activation from slot_id not in _buttons (%s)!" % slot_id)
		return
	
	if slot_activation_handler.is_null():
		return
	
	var result = slot_activation_handler.call(btn)
	
	if not bool(result.get("accepted", false)):
		return

	btn.activate_button(
		float(result.get("cooldown", 0.0)),
		bool(result.get("disable", false))
	)
