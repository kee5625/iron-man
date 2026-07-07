extends CanvasLayer
## In-game pause menu. Owns the Esc key: pauses the tree, frees the mouse,
## shows Resume / Settings / Restart / Quit to Title. Runs at ALWAYS so it
## keeps processing while everything else is paused. Restart and Quit route
## through SceneManager (which unpauses before switching).

const SettingsMenu := preload("res://scripts/settings_menu.gd")

const CYAN := Color(0.45, 0.85, 1.0)

var _root: Control
var _resume_btn: Button
var _settings_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -140.0
	box.offset_right = 140.0
	box.offset_top = -160.0
	box.offset_bottom = 160.0
	box.add_theme_constant_override("separation", 10)
	_root.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_resume_btn = _button(box, "RESUME", _resume)
	_button(box, "SETTINGS", _open_settings)
	_button(box, "RESTART", func() -> void: SceneManager.goto_game())
	_button(box, "QUIT TO TITLE", func() -> void: SceneManager.goto_title())

	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _settings_open:
		if _root.visible:
			_resume()
		else:
			_pause()


func _pause() -> void:
	get_tree().paused = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_btn.grab_focus()
	Sfx.play("ui", -10.0)


func _resume() -> void:
	get_tree().paused = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("ui", -10.0)


func _open_settings() -> void:
	_settings_open = true
	var menu: CanvasLayer = SettingsMenu.new()
	menu.closed.connect(func() -> void:
		_settings_open = false
		_resume_btn.grab_focus()
	)
	add_child(menu)


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -10.0)
		on_press.call()
	)
	parent.add_child(b)
	return b
