extends Control
## North-up minimap, bottom-right. A SubViewport with a top-down orthographic
## camera re-renders the actual city (shares the main world — own_world_3d off),
## and a draw overlay adds the player arrow + red drone blips. No textures.

const MAP_PX := 200.0
const CYAN := Color(0.45, 0.85, 1.0)
const RED := Color(1.0, 0.3, 0.25)

## Meters of world shown across the map width.
@export var view_size := 340.0
@export var cam_height := 400.0

var _viewport: SubViewport
var _cam: Camera3D
var _overlay: Control
var _player: Node3D


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -MAP_PX - 26.0
	offset_right = -26.0
	offset_top = -MAP_PX - 26.0
	offset_bottom = -26.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := ColorRect.new()
	frame.color = Color(0.0, 0.0, 0.0, 0.55)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -3.0
	frame.offset_top = -3.0
	frame.offset_right = 3.0
	frame.offset_bottom = 3.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(MAP_PX), int(MAP_PX))
	_viewport.own_world_3d = false  # render the main scene's world
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = view_size
	_cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # straight down, north (-Z) up
	_cam.far = cam_height + 200.0
	_viewport.add_child(_cam)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_player = get_tree().get_first_node_in_group("player")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_cam.global_position = _player.global_position + Vector3.UP * cam_height
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if not is_instance_valid(_player):
		return
	var center := _overlay.size * 0.5
	var scale_px := MAP_PX / view_size

	for d in get_tree().get_nodes_in_group("drones"):
		var rel: Vector3 = d.global_position - _player.global_position
		var p := center + Vector2(rel.x, rel.z) * scale_px
		if p.x < 3.0 or p.y < 3.0 or p.x > MAP_PX - 3.0 or p.y > MAP_PX - 3.0:
			continue  # off-map drones hidden — radar has a range
		_overlay.draw_circle(p, 2.5, RED)

	# Player arrow, rotated to aim. yaw 0 = -Z = screen up.
	var a: float = -_player.aim_yaw
	var tip := center + Vector2(sin(a), -cos(a)) * 8.0
	var left := center + Vector2(sin(a + 2.5), -cos(a + 2.5)) * 6.0
	var right := center + Vector2(sin(a - 2.5), -cos(a - 2.5)) * 6.0
	_overlay.draw_colored_polygon(PackedVector2Array([tip, left, right]), CYAN)
