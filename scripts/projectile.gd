extends Area3D
## Shared bolt for repulsors and drone fire. Built entirely in code: caller
## does add_child() then setup(). Straight-line by default; a homing_rate > 0
## steers it toward the target at a capped turn rate ("soft" homing — it can
## still miss if the target juke is hard enough).

var _vel := Vector3.ZERO
var _speed := 100.0
var _damage := 2
var _homing := 0.0
var _target: Node3D
var _life := 2.5
var _from_player := true


func setup(pos: Vector3, dir: Vector3, speed: float, damage: int,
		target: Node3D, homing_rate: float, from_player: bool, color: Color) -> void:
	global_position = pos
	_speed = speed
	_vel = dir.normalized() * speed
	_damage = damage
	_target = target
	_homing = homing_rate
	_from_player = from_player

	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.albedo_color = color
	mesh.material = mat
	add_child(mesh_inst)
	mesh_inst.mesh = mesh

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or global_position.y < -5.0:
		queue_free()
		return

	if _homing > 0.0 and is_instance_valid(_target):
		var want := (_target.global_position - global_position).normalized()
		var cur := _vel.normalized()
		var ang := cur.angle_to(want)
		if ang > 0.001:
			var axis := cur.cross(want)
			if axis.length_squared() > 0.0001:
				cur = cur.rotated(axis.normalized(), minf(ang, _homing * delta))
		_vel = cur * _speed

	global_position += _vel * delta


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if _from_player:
			return  # don't hit our own body at spawn
		if body.has_method("take_hit"):
			body.take_hit(_damage)
		queue_free()
	else:
		queue_free()  # building / floor


func _on_area_entered(area: Area3D) -> void:
	if _from_player and area.is_in_group("drones"):
		area.take_hit(_damage)
		queue_free()
