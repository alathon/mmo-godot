class_name ChatPanel
extends CanvasLayer

@export_node_path("Node") var combat_log_manager_path: NodePath = ^"../Services/CombatLogManager"
@export var history_limit: int = 80
@export var panel_width: float = 460.0
@export var panel_height: float = 220.0

@onready var _transcript: RichTextLabel = %Transcript
@onready var _combat_log_manager: CombatLogManager = get_node_or_null(combat_log_manager_path) as CombatLogManager
var _sink: CombatLogPanelSink
var _entries: Array[CombatLogEntry] = []


func _ready() -> void:
	layer = 20
	_connect_combat_log_manager()
	_hydrate_history()

func _exit_tree() -> void:
	if _combat_log_manager != null and _sink != null:
		_combat_log_manager.remove_sink(_sink)

func _connect_combat_log_manager() -> void:
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
