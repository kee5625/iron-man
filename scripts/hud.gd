extends CanvasLayer
## Runtime-built flight HUD. Bottom-left: speed/altitude/mode. Bottom-center:
## hull bar (amber) over energy bar (cyan). Center: crosshair dot; lock-on
## diamond tracks the locked drone. Top-right: wave drone counter. Red flash
## overlay on damage. Player + weapons push values in; the HUD polls nothing.

const CYAN := Color(0.45, 0.85, 1.0)
const DIM := Color(0.45, 0.85, 1.0, 0.55)
const RED := Color(1.0, 0.3, 0.25)
const AMBER := Color(1.0, 0.72, 0.3)

var _speed_label: Label
var _alt_label: Label
var _mode_label: Label
var _drones_label: Label
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
var _hull_bar: ProgressBar
var _hull_fill: StyleBoxFlat
var _overlay: Control
var _flash: ColorRect
var _lock_pos := Vector2.ZERO
var _has_lock := false
var _combat_btn: CheckButton
var _fps_label: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.15, 0.1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	var box := VBoxContainer.new()
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 28.0
	box.offset_top = -170.0
	box.offset_right = 340.0
	box.offset_bottom = -28.0
	root.add_child(box)

	_mode_label = _make_label(20, DIM)
	box.add_child(_mode_label)
	_speed_label = _make_label(46, CYAN)
	box.add_child(_speed_label)
	_alt_label = _make_label(22, DIM)
	box.add_child(_alt_label)

	_drones_label = _make_label(22, RED)
	_drones_label.anchor_left = 1.0
	_drones_label.anchor_right = 1.0
	_drones_label.offset_left = -300.0
	_drones_label.offset_right = -28.0
	_drones_label.offset_top = 20.0
	_drones_label.offset_bottom = 56.0
	_drones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_drones_label)

	_hull_fill = StyleBoxFlat.new()
	_hull_fill.bg_color = AMBER
	_hull_fill.set_corner_radius_all(4)
	_hull_bar = _make_bar(_hull_fill, -54.0, -44.0)
	root.add_child(_hull_bar)

	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = CYAN
	_energy_fill.set_corner_radius_all(4)
	_energy_bar = _make_bar(_energy_fill, -38.0, -28.0)
	root.add_child(_energy_bar)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	root.add_child(_overlay)

	# Top-center combat toggle. Clickable once the mouse is freed (Esc); the
	# T key toggles it any time, including mid-flight with the mouse captured.
	_combat_btn = CheckButton.new()
	_combat_btn.text = "COMBAT (T)"
	_combat_btn.button_pressed = Game.combat_enabled
	_combat_btn.anchor_left = 0.5
	_combat_btn.anchor_right = 0.5
	_combat_btn.offset_left = -80.0
	_combat_btn.offset_right = 80.0
	_combat_btn.offset_top = 16.0
	_combat_btn.offset_bottom = 52.0
	_combat_btn.add_theme_color_override("font_color", CYAN)
	_combat_btn.toggled.connect(func(on: bool) -> void: Game.set_combat(on))
	root.add_child(_combat_btn)

	_fps_label = _make_label(16, Color(1, 1, 1, 0.6))
	_fps_label.offset_left = 14.0
	_fps_label.offset_top = 10.0
	_fps_label.offset_right = 120.0
	_fps_label.offset_bottom = 34.0
	root.add_child(_fps_label)

	Game.combat_toggled.connect(_on_combat_toggled)
	_on_combat_toggled(Game.combat_enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_combat"):
		Game.toggle_combat()


func _on_combat_toggled(enabled: bool) -> void:
	_combat_btn.set_pressed_no_signal(enabled)
	_hull_bar.visible = enabled
	_drones_label.visible = enabled
	if not enabled:
		_has_lock = false
		_overlay.queue_redraw()


func update_stats(speed: float, altitude: float, mode: String,
		energy: float, energy_max: float, boost_locked: bool) -> void:
	_fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_speed_label.text = "%3.0f m/s" % speed
	_alt_label.text = "ALT %4.0f m" % altitude
	_mode_label.text = mode
	_energy_bar.max_value = energy_max
	_energy_bar.value = energy
	_energy_fill.bg_color = RED if boost_locked else CYAN
	_mode_label.modulate = Color(1.0, 0.75, 0.4) if mode == "BOOST" else Color.WHITE


func update_combat(hull: float, hull_max: float, drones_left: int, wave: int) -> void:
	_hull_bar.max_value = hull_max
	_hull_bar.value = hull
	_hull_fill.bg_color = RED if hull < hull_max * 0.3 else AMBER
	_drones_label.text = "WAVE %d   DRONES %d" % [wave, drones_left]


func set_lock(screen_pos: Vector2, has_lock: bool) -> void:
	_lock_pos = screen_pos
	_has_lock = has_lock
	_overlay.queue_redraw()


func flash_hit() -> void:
	_flash.color.a = 0.28
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.35)


func _draw_overlay() -> void:
	var center := _overlay.size * 0.5
	_overlay.draw_circle(center, 2.5, CYAN)
	_overlay.draw_arc(center, 9.0, 0.0, TAU, 24, DIM, 1.5)
	if _has_lock:
		_overlay.draw_arc(_lock_pos, 16.0, 0.0, TAU, 4, RED, 2.5)  # 4 segments = diamond
		_overlay.draw_circle(_lock_pos, 2.0, RED)


func _make_bar(fill: StyleBoxFlat, top: float, bottom: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -180.0
	bar.offset_right = 180.0
	bar.offset_top = top
	bar.offset_bottom = bottom
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l
