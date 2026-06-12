extends Area3D
## Hover drone. Patrols a lazy circle around its spawn point; when the player
## gets close it orbits them and fires slow, slightly-homing bolts (dodgeable
## at cruise speed — threat comes from numbers, not accuracy).
## Dies in 2 repulsor hits, pops an explosion burst. All geometry built in code.

const Projectile := preload("res://scripts/projectile.gd")

const ENGAGE_RANGE := 140.0
const FIRE_RANGE := 110.0
const BOLT_SPEED := 45.0
const BOLT_DAMAGE := 8
const ORBIT_RADIUS := 35.0
const ENGAGE_SPEED := 14.0
const PATROL_SPEED := 6.0

var hp := 4

var _player: Node3D
var _spawn_pos := Vector3.ZERO
var _angle := 0.0
var _bob := 0.0
var _fire_timer := 2.0
var _mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("drones")
	_rng.randomize()
	_spawn_pos = global_position
	_angle = _rng.randf() * TAU
	_bob = _rng.randf() * TAU
	_fire_timer = _rng.randf_range(1.0, 2.5)

	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 1.4  # squashed sphere — reads "drone", not "ball"
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.16, 0.16, 0.18)
	_mat.metallic = 0.7
	_mat.roughness = 0.4
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.25, 0.15)
	_mat.emission_energy_multiplier = 1.2
	mesh.material = _mat
	mesh_inst.mesh = mesh
	add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	col.shape = shape
	add_child(col)

	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_bob += delta * 2.0
	var to_player := _player.global_position - global_position
	var dist := to_player.length()

	if dist < ENGAGE_RANGE:
		_angle += delta * 0.5
		var goal := _player.global_position \
				+ Vector3(cos(_angle), 0.0, sin(_angle)) * ORBIT_RADIUS
		goal.y = _player.global_position.y + 6.0 + sin(_bob) * 2.0
		global_position = global_position.move_toward(goal, ENGAGE_SPEED * delta)

		_fire_timer -= delta
		if _fire_timer <= 0.0 and dist < FIRE_RANGE:
			_fire_timer = _rng.randf_range(1.4, 2.4)
			_shoot()
	else:
		_angle += delta * 0.8
		var goal := _spawn_pos + Vector3(cos(_angle), 0.0, sin(_angle)) * 8.0
		goal.y = _spawn_pos.y + sin(_bob) * 1.5
		global_position = global_position.move_toward(goal, PATROL_SPEED * delta)


func _shoot() -> void:
	var dir := (_player.global_position - global_position).normalized()
	var bolt := Projectile.new()
	get_tree().current_scene.add_child(bolt)
	bolt.setup(global_position + dir * 2.0, dir, BOLT_SPEED, BOLT_DAMAGE,
			_player, 0.5, false, Color(1.0, 0.35, 0.2))
	Sfx.play_at("drone_shot", global_position, -4.0)


func take_hit(damage: int) -> void:
	hp -= damage
	_mat.emission_energy_multiplier = 6.0  # hit flash
	var tween := create_tween()
	tween.tween_property(_mat, "emission_energy_multiplier", 1.2, 0.25)
	if hp <= 0:
		_explode()


func _explode() -> void:
	var burst := GPUParticles3D.new()
	burst.amount = 60
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.ZERO
	m.spread = 180.0
	m.initial_velocity_min = 10.0
	m.initial_velocity_max = 22.0
	m.gravity = Vector3(0.0, -4.0, 0.0)
	m.scale_min = 0.5
	m.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.9, 0.5, 1.0),
		Color(1.0, 0.4, 0.1, 1.0),
		Color(0.3, 0.3, 0.3, 0.0),
	])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	burst.process_material = m

	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	burst.draw_pass_1 = mesh

	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)
	Sfx.play_at("explosion", global_position, 2.0)
	queue_free()
