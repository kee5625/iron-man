extends Node3D
## Title screen. Background is the real greybox city (different seed) with a
## slow-orbiting camera — the game sells itself behind the menu. UI is built
## in code: START FLIGHT / SETTINGS / QUIT with keyboard/gamepad focus nav.

const SettingsMenu := preload("res://scripts/settings_menu.gd")

const CYAN := Color(0.45, 0.85, 1.0)
const DIM := Color(0.45, 0.85, 1.0, 0.55)

var _start_btn: Button
var _ui_layer: CanvasLayer

@onready var pivot: Node3D = $CameraPivot


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Settings.register_environment($WorldEnvironment.environment)
	_build_ui()


func _process(delta: float) -> void:
	pivot.rotation.y += delta * 0.04


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(root)

	var title := Label.new()
	title.text = "IRONMAN"
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", CYAN)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("outline_size", 10)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -400.0
	title.offset_right = 400.0
	title.offset_top = 90.0
	title.offset_bottom = 220.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MARK ZERO — FLIGHT PROTOTYPE"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", DIM)
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.offset_left = -300.0
	subtitle.offset_right = 300.0
	subtitle.offset_top = 215.0
	subtitle.offset_bottom = 245.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -150.0
	box.offset_right = 150.0
	box.offset_top = -300.0
	box.offset_bottom = -90.0
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)

	_start_btn = _button(box, "START FLIGHT", func() -> void: SceneManager.goto_game())
	_button(box, "SETTINGS", _open_settings)
	_button(box, "QUIT", func() -> void: get_tree().quit())
	_start_btn.grab_focus()

	var version := Label.new()
	version.text = "phase 1 shell"
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -220.0
	version.offset_right = -14.0
	version.offset_top = -34.0
	version.offset_bottom = -10.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(version)


func _open_settings() -> void:
	var menu: CanvasLayer = SettingsMenu.new()
	menu.closed.connect(func() -> void: _start_btn.grab_focus())
	add_child(menu)


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -10.0)
		on_press.call()
	)
	parent.add_child(b)
	return b
