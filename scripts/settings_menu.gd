extends CanvasLayer
## Settings panel, built entirely in code. Instanced by both the title screen
## and the pause menu. It is its own CanvasLayer at layer 90, so it always
## renders on top of whatever opened it — callers just add_child() it anywhere.
## Every widget writes straight to the Settings autoload — changes apply live
## and auto-save; there is no Apply button. Esc or BACK closes it.

signal closed

const CYAN := Color(0.45, 0.85, 1.0)
const DIM := Color(0.45, 0.85, 1.0, 0.55)


func _ready() -> void:
	layer = 90
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks behind the panel
	add_child(screen)

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.6)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim_bg)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -310.0
	panel.offset_bottom = 310.0
	screen.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", CYAN)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	_section(list, "GAMEPLAY")
	_slider(list, "Mouse Sensitivity", 0.5, 2.0, 0.05, Settings.mouse_sensitivity,
			func(v: float) -> String: return "%.2fx" % v,
			func(v: float) -> void: Settings.set_value("mouse_sensitivity", v))
	_check(list, "Invert Y", Settings.invert_y,
			func(on: bool) -> void: Settings.set_value("invert_y", on))

	_section(list, "GRAPHICS")
	_option(list, "Window Mode", ["Windowed", "Fullscreen"], Settings.window_mode,
			func(i: int) -> void: Settings.set_value("window_mode", i))
	_check(list, "VSync", Settings.vsync,
			func(on: bool) -> void: Settings.set_value("vsync", on))
	_slider(list, "Render Scale", 0.5, 1.0, 0.05, Settings.render_scale,
			func(v: float) -> String: return "%d%%" % int(v * 100.0),
			func(v: float) -> void: Settings.set_value("render_scale", v))
	_option(list, "MSAA", ["Off", "2x", "4x", "8x"], Settings.msaa,
			func(i: int) -> void: Settings.set_value("msaa", i))
	_option(list, "Shadows", ["Off", "Low", "High"], Settings.shadows,
			func(i: int) -> void: Settings.set_value("shadows", i))
	_check(list, "Glow", Settings.glow,
			func(on: bool) -> void: Settings.set_value("glow", on))
	_check(list, "Fog", Settings.fog,
			func(on: bool) -> void: Settings.set_value("fog", on))
	_slider(list, "Field of View", 70.0, 100.0, 1.0, Settings.fov,
			func(v: float) -> String: return "%d" % int(v),
			func(v: float) -> void: Settings.set_value("fov", v))
	_option(list, "Max FPS", ["Uncapped", "60", "120", "144"],
			[0, 60, 120, 144].find(Settings.max_fps),
			func(i: int) -> void: Settings.set_value("max_fps", [0, 60, 120, 144][i]))
	_check(list, "Show FPS", Settings.show_fps,
			func(on: bool) -> void: Settings.set_value("show_fps", on))

	_section(list, "AUDIO")
	_slider(list, "Master Volume", 0.0, 1.0, 0.05, Settings.master_volume,
			func(v: float) -> String: return "%d%%" % int(v * 100.0),
			func(v: float) -> void: Settings.set_value("master_volume", v))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(_close)
	outer.add_child(back)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # don't let the pause menu see it
		_close()


func _close() -> void:
	Sfx.play("ui", -10.0)
	closed.emit()
	queue_free()


# --- row builders ---

func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", DIM)
	parent.add_child(l)
	var sep := HSeparator.new()
	parent.add_child(sep)


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	parent.add_child(row)
	return row


func _slider(parent: Control, label_text: String, minv: float, maxv: float,
		step: float, value: float, fmt: Callable, on_change: Callable) -> void:
	var row := _row(parent, label_text)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.text = fmt.call(value)
	val.custom_minimum_size = Vector2(64, 0)
	s.value_changed.connect(func(v: float) -> void:
		val.text = fmt.call(v)
		on_change.call(v)
	)
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("ui", -14.0))
	row.add_child(s)
	row.add_child(val)


func _check(parent: Control, label_text: String, value: bool, on_change: Callable) -> void:
	var row := _row(parent, label_text)
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(func(on: bool) -> void:
		on_change.call(on)
		Sfx.play("ui", -12.0)
	)
	row.add_child(c)


func _option(parent: Control, label_text: String, items: Array, selected: int,
		on_change: Callable) -> void:
	var row := _row(parent, label_text)
	var o := OptionButton.new()
	for item in items:
		o.add_item(item)
	o.selected = maxi(selected, 0)
	o.custom_minimum_size = Vector2(160, 0)
	o.item_selected.connect(func(i: int) -> void:
		on_change.call(i)
		Sfx.play("ui", -12.0)
	)
	row.add_child(o)
