class_name DebugOverlay
extends CanvasLayer

## Lightweight debug HUD. Detects client vs server from NetworkTime state
## and shows the relevant metrics. Toggle visibility with F3.

var _label: Label

func _ready() -> void:
	layer = 100

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	font.multichannel_signed_distance_field = true
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_NORMAL
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		visible = !visible

func _process(_delta: float) -> void:
	if not visible:
		return

	var lines: PackedStringArray = []

	if not NetworkTime.is_active:
		lines.append("NetworkTime: inactive")
		_label.text = "\n".join(lines)
		return

	var clock := _get_clock()

	if clock != null:
		# Client mode
		var srv_tick: int = clock.get_server_tick()
		lines.append("=== CLIENT ===")
		lines.append("Tick:        %d" % NetworkTime.tick)
		lines.append("Clock tick:  %d" % srv_tick)
		lines.append("Tick delta:  %d" % (srv_tick - NetworkTime.tick))
		lines.append("")
		lines.append("RTT:         %.0fms" % (clock.rtt * 1000.0))
		lines.append("Lead:        %.0fms (%.1f ticks)" % [
			clock.lead_time * 1000.0,
			clock.lead_time * Globals.TICK_RATE
		])
		lines.append("Offset:      %.4f" % clock._offset)
		lines.append("Target off:  %.4f" % clock._target_offset)
		lines.append("Drift:       %.4f" % (clock._target_offset - clock._offset))
		lines.append("Stretch:     %.4f" % NetworkTime._stretch)
		lines.append("Synced:      %s" % clock.is_synced)
	else:
		# Server mode
		var sim_tick: int = NetworkTime.tick - Globals.INPUT_BUFFER_SIZE
		lines.append("=== SERVER ===")
		lines.append("Tick:        %d" % NetworkTime.tick)
		lines.append("Sim tick:    %d" % sim_tick)

	lines.append("")
	lines.append("FPS:         %d" % Engine.get_frames_per_second())
	_label.text = "\n".join(lines)

func _get_clock() -> NetworkClock:
	return NetworkTime._clock as NetworkClock
