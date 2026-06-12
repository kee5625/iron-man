extends Node3D
## Repulsor weapon system, child of Player. Soft lock-on: nearest drone inside
## an aim cone gets the lock; bolts fired while locked steer gently toward it.
## Hold fire to stream — shots alternate hands. Pushes the lock reticle to HUD.

const Projectile := preload("res://scripts/projectile.gd")

@export var fire_rate := 6.0
@export var bolt_speed := 130.0
@export var bolt_damage := 2
@export var lock_cone_deg := 14.0
@export var lock_range := 260.0
## Turn rate (rad/s) of bolts while locked. 0 = dumbfire.
@export var lock_homing := 2.2

var lock_target: Node3D

var _cooldown := 0.0
var _side := 0.35

@onready var player: CharacterBody3D = get_parent()
@onready var cam: Camera3D = player.get_node("CameraRig/SpringArm/Camera")


func _physics_process(delta: float) -> void:
	_update_lock()
	_cooldown -= delta
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_action_pressed("fire") and _cooldown <= 0.0:
		_fire()
		_cooldown = 1.0 / fire_rate


## Brief fire suppression — used when the click that recaptures the mouse
## shouldn't also fire a shot.
func suppress(seconds: float) -> void:
	_cooldown = maxf(_cooldown, seconds)


func _update_lock() -> void:
	var aim := Basis.from_euler(Vector3(player.aim_pitch, player.aim_yaw, 0.0))
	var fwd := -aim.z
	var best: Node3D = null
	var best_score := INF
	for d in get_tree().get_nodes_in_group("drones"):
		var to: Vector3 = d.global_position - player.global_position
		var dist := to.length()
		if dist > lock_range or dist < 2.0:
			continue
		var ang := rad_to_deg(fwd.angle_to(to / dist))
		if ang > lock_cone_deg:
			continue
		var score := ang + dist * 0.01  # prefer center-of-aim, tiebreak near
		if score < best_score:
			best_score = score
			best = d
	if best != null and lock_target == null:
		Sfx.play("lock", -14.0)
	lock_target = best

	if lock_target != null and not cam.is_position_behind(lock_target.global_position):
		player.hud.set_lock(cam.unproject_position(lock_target.global_position), true)
	else:
		player.hud.set_lock(Vector2.ZERO, false)


func _fire() -> void:
	var aim := Basis.from_euler(Vector3(player.aim_pitch, player.aim_yaw, 0.0))
	var origin: Vector3 = player.global_position + aim * Vector3(_side, -0.2, -1.6)
	_side = -_side
	var dir: Vector3
	var homing := 0.0
	if is_instance_valid(lock_target):
		dir = (lock_target.global_position - origin).normalized()
		homing = lock_homing
	else:
		dir = -aim.z
	# Inherit forward speed so bolts never trail behind you at full boost.
	var speed := bolt_speed + maxf(player.velocity.dot(dir), 0.0)

	var bolt := Projectile.new()
	get_tree().current_scene.add_child(bolt)
	bolt.setup(origin, dir, speed, bolt_damage, lock_target, homing, true,
			Color(0.5, 0.85, 1.0))
	Sfx.play("repulsor", -9.0)
