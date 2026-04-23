class_name HotbarButton
extends TextureButton

signal slot_pressed(slot_id: StringName)

@onready var cooldown: TextureProgressBar = $Cooldown
@onready var key: Label = $Key
@onready var time: Label = $Time
@onready var timer: Timer = $Timer

enum SlotDataType {
	NONE,
	MACRO,
	ABILITY,
	ITEM
}

var slot_id: StringName = &""
var slot_data_type: SlotDataType = SlotDataType.NONE
var slot_data: Variant
var _show_cooldown_left: bool = false

func _ready() -> void:
	timer.one_shot = true
	set_process(false)
	cooldown.value = 0.0
	cooldown.max_value = 1.0
	time.text = ""
	timer.timeout.connect(_on_timer_timeout)
	pressed.connect(_on_pressed)

func _on_pressed():
	slot_pressed.emit(slot_id)

func bind_key(input_key: InputEventKey, display_text: String):
	key.text = display_text
	shortcut = Shortcut.new()
	shortcut.events = [input_key]

func set_slot_data(slot_data_type: SlotDataType, slot_data: Variant) -> void:
	self.slot_data_type = slot_data_type
	self.slot_data = slot_data

func show_cooldown(show: bool) -> void:
	_show_cooldown_left = show

func _process(_delta: float) -> void:
	time.text = _format_time(timer.time_left)
	cooldown.value = timer.time_left

func activate_button(cooldown_amt: float, disable: bool):
	if cooldown_amt:
		cooldown.max_value = cooldown_amt
		timer.start(cooldown_amt)
		time.visible = _show_cooldown_left
		set_process(true)
	else:
		time.visible = false
	disabled = disable

func _on_timer_timeout() -> void:
	disabled = false
	time.text = ""
	cooldown.value = 0
	set_process(false)

func _format_time(time: float) -> String:
	return "%3.1f" % time # TODO: Format as seconds left.
