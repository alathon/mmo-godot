class_name HotbarButton
extends TextureButton

signal slot_pressed(slot_id: StringName)

const EMPTY_TEXTURE_PATH := "res://assets/abilities/hotbar_black.png"
static var _shared_empty_texture:Texture2D = preload(EMPTY_TEXTURE_PATH)

@onready var key: Label = $Key

@onready var cooldown: ColorRect = $Cooldown
@onready var cooldown_time: Label = $Time
@onready var cooldown_timer: Timer = $Timer
@onready var unavailable_backdrop: Panel = $UnavailableBackdrop
@onready var unavailable_x: Label = $UnavailableX

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
var slot_data: Variant = null
var uses_gcd: bool = false
var _show_cooldown_left: bool = false
var _unavailable: bool = false

func _ready() -> void:
	cooldown_timer.one_shot = true
	gcd.value = ui_root.get_gcd_remaining()
	gcd.max_value = AbilityConstants.GCD_DURATION
	cooldown.visible = false
	cooldown_time.text = ""
	unavailable_backdrop.visible = false
	unavailable_x.visible = false
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	pressed.connect(_on_pressed)
	clear_slot()

func _on_pressed() -> void:
	if slot_data_type == SlotDataType.NONE:
		return
	slot_pressed.emit(slot_id)

func bind_key(input_key: InputEventKey, display_text: String) -> void:
	key.text = display_text
	shortcut = Shortcut.new()
	shortcut.events = [input_key]

func clear_keybind() -> void:
	key.text = ""
	shortcut = null

func set_slot_data(slot_data_type: SlotDataType, slot_data: Variant, uses_gcd: bool) -> void:
	self.slot_data_type = slot_data_type
	self.slot_data = slot_data
	self.uses_gcd = uses_gcd

	gcd.visible = uses_gcd
	set_icon(_get_icon_for_slot())

func clear_slot() -> void:
	slot_data_type = SlotDataType.NONE
	slot_data = null
	uses_gcd = false
	gcd.visible = false
	set_unavailable(false)
	set_cooldown_amount(0.0)
	cooldown_time.text = ""
	set_icon(null)

func set_icon(icon: Texture2D) -> void:
	texture_normal = icon if icon != null else _shared_empty_texture

func set_unavailable(value: bool) -> void:
	_unavailable = value
	unavailable_backdrop.visible = value
	unavailable_x.visible = value and slot_data_type == SlotDataType.ABILITY

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

func _get_icon_for_slot() -> Texture2D:
	if slot_data_type != SlotDataType.ABILITY:
		return null

	var ability_id: int = int(slot_data)
	if ability_id <= 0:
		return null

	var ability: AbilityResource = AbilityDB.get_ability(ability_id)
	if ability == null:
		return null

	return ability.icon
