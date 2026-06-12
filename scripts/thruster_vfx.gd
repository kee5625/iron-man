extends Node3D
## Foot thrusters: two GPUParticles3D + flickering glow light, all built at
## runtime — no asset files. Sits under Body so exhaust tilts with the lean
## (horizontal flight = feet point backward, exhaust trails behind).
## Player drives it via update_thrust() each physics frame.

const THRUST_COLOR := Color(0.5, 0.85, 1.0)

var _emitters: Array[GPUParticles3D] = []
var _mats: Array[ParticleProcessMaterial] = []
var _light: OmniLight3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for x in [-0.18, 0.18]:
		var p := _make_emitter()
		p.position = Vector3(x, -0.9, 0.0)
		add_child(p)
		_emitters.append(p)

	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, -1.0, 0.0)
	_light.light_color = THRUST_COLOR
	_light.omni_range = 6.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)


## throttle 0..1 (forward thrust input), speed in m/s.
func update_thrust(throttle: float, boosting: bool, speed: float, delta: float) -> void:
	var idle := clampf(speed / 10.0, 0.0, 0.25)
	var target := maxf(idle, throttle)
	if boosting:
		target = 1.0

	for i in _emitters.size():
		_emitters[i].amount_ratio = target
		var v := 5.0 + 18.0 * throttle + (10.0 if boosting else 0.0)
		_mats[i].initial_velocity_min = v * 0.8
		_mats[i].initial_velocity_max = v * 1.2

	var flicker := _rng.randf_range(0.85, 1.15)
	var target_energy := (0.4 + 2.2 * target + (1.5 if boosting else 0.0)) * flicker
	_light.light_energy = lerpf(_light.light_energy, target_energy, 1.0 - exp(-12.0 * delta))


func _make_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 96
	p.lifetime = 0.4
	p.local_coords = false  # leave exhaust behind in world space — reads as a speed trail
	p.emitting = true
	p.amount_ratio = 0.0

	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 7.0
	m.initial_velocity_min = 5.0
	m.initial_velocity_max = 7.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.5
	m.scale_max = 1.0

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		THRUST_COLOR,
		Color(THRUST_COLOR, 0.0),
	])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	_mats.append(m)

	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = THRUST_COLOR
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.draw_pass_1 = mesh
	return p
