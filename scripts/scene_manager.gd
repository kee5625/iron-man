extends Node
## Autoload "SceneManager" — fade-to-black transitions between title and world.
## Runs at PROCESS_MODE_ALWAYS so transitions work out of a paused game
## (quit-to-title from the pause menu). Always unpauses before switching.

const TITLE := "res://scenes/title.tscn"
const WORLD := "res://scenes/main.tscn"

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100  # above every game CanvasLayer
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func goto_title() -> void:
	_transition(TITLE)


func goto_game() -> void:
	_transition(WORLD)


func _transition(path: String) -> void:
	if _busy:
		return
	_busy = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.25)
	await t.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.35)
	await t2.finished
	_busy = false
