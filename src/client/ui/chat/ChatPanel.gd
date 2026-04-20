class_name ChatPanel
extends CanvasLayer

@export_node_path("Node") var combat_log_manager_path: NodePath = ^"../Services/CombatLogManager"
@export var history_limit: int = 80
@export var panel_width: float = 460.0
@export var panel_height: float = 220.0

var _combat_log_manager: CombatLogManager
var _sink: CombatLogPanelSink
var _entries: Array[CombatLogEntry] = []
var _transcript: RichTextLabel


func _ready() -> void:
	layer = 20
	_build_ui()
	_connect_combat_log_manager()
	_hydrate_history()


func _exit_tree() -> void:
	if _combat_log_manager != null and _sink != null:
		_combat_log_manager.remove_sink(_sink)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_spacer)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_stylebox())
	row.add_child(panel)

	var row_spacer := Control.new()
	row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(row_spacer)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var title := Label.new()
	title.text = "Combat"
	title.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0, 0.95))
	title.add_theme_font_size_override("font_size", 15)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = false
	_transcript.fit_content = false
	_transcript.scroll_active = true
	_transcript.selection_enabled = false
	_transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.add_theme_font_size_override("normal_font_size", 13)
	_transcript.add_theme_constant_override("line_separation", 2)
	_transcript.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_transcript)


func _connect_combat_log_manager() -> void:
	_combat_log_manager = get_node_or_null(combat_log_manager_path) as CombatLogManager
	if _combat_log_manager == null:
		push_warning("ChatPanel could not find CombatLogManager at %s" % combat_log_manager_path)
		return
	_sink = CombatLogPanelSink.new(self)
	_combat_log_manager.add_sink(_sink)


func _hydrate_history() -> void:
	if _combat_log_manager == null:
		return
	var recent_entries := _combat_log_manager.get_recent_entries(history_limit)
	for entry in recent_entries:
		if entry is CombatLogEntry:
			_entries.append(entry)
	_trim_entries()
	_rebuild_transcript()


func append_entry(entry: CombatLogEntry) -> void:
	if entry == null:
		return
	_entries.append(entry)
	_trim_entries()
	_rebuild_transcript()


func _trim_entries() -> void:
	if history_limit <= 0:
		_entries.clear()
		return
	var overflow := _entries.size() - history_limit
	if overflow > 0:
		_entries = _entries.slice(overflow, _entries.size())


func _rebuild_transcript() -> void:
	if _transcript == null:
		return
	_transcript.clear()
	for entry in _entries:
		if entry == null:
			continue
		_transcript.push_color(_color_for_entry(entry))
		_transcript.add_text(entry.message)
		_transcript.pop()
		_transcript.newline()
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if _transcript == null:
		return
	_transcript.scroll_to_line(maxi(0, _transcript.get_line_count() - 1))


func _color_for_entry(entry: CombatLogEntry) -> Color:
	if entry == null:
		return Color(0.86, 0.9, 0.96, 0.92)
	match entry.severity:
		&"important":
			return Color(1.0, 0.86, 0.64, 0.98)
		&"warning":
			return Color(1.0, 0.78, 0.52, 0.96)
		_:
			return Color(0.86, 0.9, 0.96, 0.92)


func _make_panel_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.76)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.46, 0.58, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style
