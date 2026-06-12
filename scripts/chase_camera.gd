extends Node3D
## Chase camera rig. top_level node that lags behind the player's aim:
## position lerps to the player, rotation slerps to aim (with a touch of the
## player's bank roll), FOV kicks out with speed. SpringArm prevents wall clip.

@export var follow_response := 14.0
@export var rot_response := 9.0
## Fraction of the player's bank roll applied to the camera.
@export var roll_share := 0.25
@export var base_fov := 75.0
@export var max_fov := 96.0
## Speed at which FOV reaches max.
@export var fov_speed_ref := 78.0
@export var pivot_height := 1.2

@onready var player: CharacterBody3D = get_parent()
@onready var arm: SpringArm3D = $SpringArm
@onready var cam: Camera3D = $SpringArm/Camera


func _ready() -> void:
	arm.add_excluded_object(player.get_rid())
	global_position = player.global_position + Vector3.UP * pivot_height


func _physics_process(delta: float) -> void:
	var target_pos: Vector3 = player.global_position + Vector3.UP * pivot_height
	global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_response * delta))

	var target_basis := Basis.from_euler(
		Vector3(player.aim_pitch, player.aim_yaw, player.bank * roll_share))
	global_transform.basis = global_transform.basis.slerp(
		target_basis, 1.0 - exp(-rot_response * delta)).orthonormalized()

	var t := clampf(player.velocity.length() / fov_speed_ref, 0.0, 1.0)
	var target_fov := lerpf(base_fov, max_fov, t * t)
	cam.fov = lerpf(cam.fov, target_fov, 1.0 - exp(-6.0 * delta))
