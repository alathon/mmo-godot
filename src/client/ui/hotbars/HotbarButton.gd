class_name HotbarButton
extends TextureButton

signal slot_pressed(slot_id: StringName)

@onready var key: Label = $Key

@onready var cooldown: ColorRect = $Cooldown
@onready var cooldown_time: Label = $Time
@onready var cooldown_timer: Timer = $Timer

@onready var ui_root: UIRoot = $/root/Root/UI
@onready var gcd: TextureProgressBar = $GCD

enum SlotDataType {
	NONE,
	MACRO,
	ABILITY,
	ITEM
}

var slot_id: StringName = &""
var slot_data_type: SlotDataType = SlotDataType.NONE
var slot_data: Variant
var uses_gcd: bool = false
var _show_cooldown_left: bool = false

func _ready() -> void:
	cooldown_timer.one_shot = true
	gcd.value = ui_root.get_gcd_remaining()
	gcd.max_value = AbilityConstants.GCD_DURATION
	cooldown.visible = false
	cooldown_time.text = ""
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	pressed.connect(_on_pressed)

func _on_pressed():
	print("Button %s pressed" % slot_id)
	slot_pressed.emit(slot_id)

func bind_key(input_key: InputEventKey, display_text: String):
	key.text = display_text
	shortcut = Shortcut.new()
	shortcut.events = [input_key]

func set_slot_data(slot_data_type: SlotDataType, slot_data: Variant, uses_gcd: bool) -> void:
	self.slot_data_type = slot_data_type
	self.slot_data = slot_data
	self.uses_gcd = uses_gcd
	
	if uses_gcd:
		gcd.visible = true
	else:
		gcd.visible = false

func show_cooldown_text(show: bool) -> void:
	_show_cooldown_left = show

func _process(_delta: float) -> void:
	if uses_gcd:
		gcd.value = ui_root.get_gcd_remaining()

	if cooldown_timer.time_left > 0.0:
		cooldown_time.text = _format_time(cooldown_timer.time_left)

func set_cooldown_amount(cooldown_amt: float):
	if cooldown_amt > 0.0:
		cooldown_timer.start(cooldown_amt)
		cooldown_time.visible = _show_cooldown_left
		cooldown.visible = true
	else:
		cooldown_time.visible = false
		cooldown.visible = false
		if not cooldown_timer.is_stopped():
			cooldown_timer.stop()

func _on_cooldown_timer_timeout() -> void:
	cooldown_time.text = ""
	cooldown.visible = false
	cooldown_time.visible = false

func _format_time(time: float) -> String:
	return "%3.1f" % time # TODO: Format as seconds left.
