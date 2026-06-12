extends CanvasLayer
## Runtime-built flight HUD: big speed readout + altitude + mode tag
## (bottom-left), boost energy bar (bottom-center). No scene files, no assets.
## Player pushes values in via update_stats() each physics frame.

const CYAN := Color(0.45, 0.85, 1.0)
const DIM := Color(0.45, 0.85, 1.0, 0.55)
const RED := Color(1.0, 0.3, 0.25)

var _speed_label: Label
var _alt_label: Label
var _mode_label: Label
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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

	_energy_bar = ProgressBar.new()
	_energy_bar.show_percentage = false
	_energy_bar.anchor_left = 0.5
	_energy_bar.anchor_right = 0.5
	_energy_bar.anchor_top = 1.0
	_energy_bar.anchor_bottom = 1.0
	_energy_bar.offset_left = -180.0
	_energy_bar.offset_right = 180.0
	_energy_bar.offset_top = -38.0
	_energy_bar.offset_bottom = -28.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	bg.set_corner_radius_all(4)
	_energy_fill = StyleBoxFlat.new()
	_energy_fill.bg_color = CYAN
	_energy_fill.set_corner_radius_all(4)
	_energy_bar.add_theme_stylebox_override("background", bg)
	_energy_bar.add_theme_stylebox_override("fill", _energy_fill)
	root.add_child(_energy_bar)


func update_stats(speed: float, altitude: float, mode: String,
		energy: float, energy_max: float, boost_locked: bool) -> void:
	_speed_label.text = "%3.0f m/s" % speed
	_alt_label.text = "ALT %4.0f m" % altitude
	_mode_label.text = mode
	_energy_bar.max_value = energy_max
	_energy_bar.value = energy
	_energy_fill.bg_color = RED if boost_locked else CYAN
	_mode_label.modulate = Color(1.0, 0.75, 0.4) if mode == "BOOST" else Color.WHITE


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l
