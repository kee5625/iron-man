extends CharacterBody3D
## Anthem-style flight model.
##
## Mouse aims. W thrusts along aim — velocity *steers* toward aim instead of
## snapping, so turns carry momentum and wide arcs feel weighty.
## Nose down past ~20° = dive: higher speed cap + bonus accel (gravity fantasy).
## Pull up = keep dive speed briefly (overspeed bleeds off slowly) → skim-and-climb.
## No forward thrust = hover: drifty, precise, strafe/vertical translate.
## Space/Ctrl vertical, Shift boost, S brake. Esc frees mouse, click recaptures.

enum FlightState { GROUNDED, AIRBORNE }

@export_group("Mouse")
@export var mouse_sens := 0.0022
@export var pitch_limit_deg := 85.0

@export_group("Hover")
@export var hover_max_speed := 9.0
## Velocity response in hover (higher = snappier).
@export var hover_response := 6.0
## Response while braking down from cruise speed (lower = longer skid).
@export var brake_response := 2.2

@export_group("Cruise")
@export var cruise_speed := 38.0
@export var cruise_accel := 22.0
@export var boost_speed := 78.0
@export var boost_accel := 48.0
## Decel rate back toward cap after a dive leaves you over the limit.
@export var overspeed_bleed := 9.0
## Strafe/vertical nudge strength while cruising.
@export var lateral_accel := 14.0

@export_group("Dive & Climb")
@export var dive_speed_bonus := 45.0
@export var dive_accel_bonus := 35.0
## How nose-down (0..1 of straight down) before dive bonus starts.
@export var dive_start := 0.35
## Fraction of speed cap lost when climbing straight up.
@export var climb_penalty := 0.45

@export_group("Handling")
## How fast velocity direction aligns to aim, per second. Lower = heavier.
@export var turn_rate_cruise := 2.6
@export var turn_rate_boost := 1.7
@export var bank_max_deg := 65.0
@export var bank_response := 5.0

@export_group("Ground")
@export var walk_speed := 7.0
@export var walk_accel := 40.0
@export var gravity := 24.0
@export var takeoff_speed := 10.0

@export_group("Energy")
@export var energy_max := 100.0
@export var boost_drain := 22.0
@export var energy_regen := 20.0
## Seconds after boosting before regen starts.
@export var regen_delay := 0.8
## Once drained to zero, boost stays locked until energy recovers past this.
@export var boost_min_energy := 12.0

@export_group("Hull")
@export var hull_max := 100.0
@export var hull_regen := 12.0
## Seconds after last hit before hull regen starts.
@export var hull_regen_delay := 4.0

var aim_yaw := 0.0
var aim_pitch := 0.0
var bank := 0.0
var state := FlightState.AIRBORNE
var boosting := false
var energy := 100.0
var hull := 100.0

var _visual_pitch := 0.0
var _prev_yaw := 0.0
var _pitch_limit := 0.0
var _throttle := 0.0
var _regen_timer := 0.0
var _boost_locked := false
var _hull_timer := 0.0
var _spawn_xform := Transform3D.IDENTITY
var _audio_thr := 0.0
var _was_boosting := false
var _thruster_sfx: AudioStreamPlayer
var _wind_sfx: AudioStreamPlayer

@onready var body: Node3D = $Body
@onready var vfx: Node3D = $Body/ThrusterVFX
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	add_to_group("player")
	_pitch_limit = deg_to_rad(pitch_limit_deg)
	_spawn_xform = global_transform
	hull = hull_max
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_thruster_sfx = AudioStreamPlayer.new()
	_thruster_sfx.stream = Sfx.stream("thruster")
	_thruster_sfx.volume_db = -36.0
	add_child(_thruster_sfx)
	_thruster_sfx.play()
	_wind_sfx = AudioStreamPlayer.new()
	_wind_sfx.stream = Sfx.stream("wind")
	_wind_sfx.volume_db = -50.0
	add_child(_wind_sfx)
	_wind_sfx.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		aim_yaw = wrapf(aim_yaw - event.relative.x * mouse_sens, -PI, PI)
		aim_pitch = clampf(aim_pitch - event.relative.y * mouse_sens, -_pitch_limit, _pitch_limit)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$Weapons.suppress(0.3)  # recapture click shouldn't also fire


func _physics_process(delta: float) -> void:
	if state == FlightState.GROUNDED:
		_ground_move(delta)
	else:
		_fly(delta)
	move_and_slide()
	_update_energy(delta)
	_update_visuals(delta)
	vfx.update_thrust(_throttle, boosting, velocity.length(), delta)
	_update_audio(delta)
	_update_hud()


func _update_audio(delta: float) -> void:
	if boosting and not _was_boosting:
		Sfx.play("boost", -6.0)
	_was_boosting = boosting

	var thr_target := 0.0
	if state == FlightState.AIRBORNE:
		thr_target = 1.15 if boosting else maxf(_throttle, 0.18)  # 0.18 = hover idle
	_audio_thr = lerpf(_audio_thr, thr_target, 1.0 - exp(-6.0 * delta))
	_thruster_sfx.volume_db = lerpf(-36.0, -8.0, clampf(_audio_thr, 0.0, 1.0))
	_thruster_sfx.pitch_scale = 0.8 + _audio_thr * 0.55

	var spd_t := clampf(velocity.length() / boost_speed, 0.0, 1.0)
	_wind_sfx.volume_db = lerpf(-50.0, -10.0, pow(spd_t, 1.4))
	_wind_sfx.pitch_scale = 0.85 + spd_t * 0.6


func _fly(delta: float) -> void:
	var aim := Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0))
	var fwd := -aim.z
	var right := aim.x
	var thrust := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var strafe := Input.get_action_strength("strafe_right") - Input.get_action_strength("strafe_left")
	var vert := Input.get_action_strength("ascend") - Input.get_action_strength("descend")
	boosting = Input.is_action_pressed("boost") and thrust > 0.0 \
			and not _boost_locked and energy > 0.0
	_throttle = maxf(thrust, 0.0)

	if thrust > 0.0:
		var accel := boost_accel if boosting else cruise_accel
		var cap := boost_speed if boosting else cruise_speed

		var dive := clampf((-fwd.y - dive_start) / (1.0 - dive_start), 0.0, 1.0)
		cap += dive_speed_bonus * dive
		accel += dive_accel_bonus * dive
		cap *= 1.0 - climb_penalty * maxf(fwd.y, 0.0)

		var speed := velocity.length()
		if speed > cap:
			speed = move_toward(speed, cap, overspeed_bleed * delta)
		else:
			speed = move_toward(speed, cap * thrust, accel * delta)

		var turn := turn_rate_boost if boosting else turn_rate_cruise
		var dir := velocity.normalized() if velocity.length() > 1.0 else fwd
		dir = dir.slerp(fwd, clampf(turn * delta, 0.0, 1.0)).normalized()
		velocity = dir * speed
		velocity += (right * strafe + Vector3.UP * vert) * lateral_accel * delta
	else:
		# Hover / brake: exponential approach to a drift velocity.
		var flat_fwd := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var target := (flat_fwd * thrust + right * strafe + Vector3.UP * vert) * hover_max_speed
		var resp := hover_response if velocity.length() < cruise_speed * 0.5 else brake_response
		velocity = velocity.lerp(target, 1.0 - exp(-resp * delta))

		if is_on_floor() and velocity.length() < 5.0 and vert <= 0.0:
			state = FlightState.GROUNDED
			boosting = false


func _update_energy(delta: float) -> void:
	if boosting:
		energy = maxf(energy - boost_drain * delta, 0.0)
		_regen_timer = regen_delay
		if energy <= 0.0:
			_boost_locked = true
	else:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			energy = minf(energy + energy_regen * delta, energy_max)
	if _boost_locked and energy >= boost_min_energy:
		_boost_locked = false

	_hull_timer -= delta
	if _hull_timer <= 0.0:
		hull = minf(hull + hull_regen * delta, hull_max)


func take_hit(damage: int) -> void:
	hull -= damage
	_hull_timer = hull_regen_delay
	hud.flash_hit()
	Sfx.play("hit", -4.0)
	if hull <= 0.0:
		_respawn()


func _respawn() -> void:
	global_transform = _spawn_xform
	velocity = Vector3.ZERO
	hull = hull_max
	energy = energy_max
	_boost_locked = false
	state = FlightState.AIRBORNE


func _ground_move(delta: float) -> void:
	_throttle = 0.0
	boosting = false
	var yaw_basis := Basis.from_euler(Vector3(0.0, aim_yaw, 0.0))
	var input := Input.get_vector("strafe_left", "strafe_right", "move_back", "move_forward")
	var dir := yaw_basis * Vector3(input.x, 0.0, -input.y)
	velocity.x = move_toward(velocity.x, dir.x * walk_speed, walk_accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * walk_speed, walk_accel * delta)
	velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ascend"):
		state = FlightState.AIRBORNE
		velocity.y = takeoff_speed
	elif not is_on_floor() and velocity.y < -3.0:
		# Walked off an edge — hover catches the fall.
		state = FlightState.AIRBORNE


func _update_visuals(delta: float) -> void:
	var speed_t := clampf(velocity.length() / cruise_speed, 0.0, 1.0)
	var yaw_rate := wrapf(aim_yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.0001)
	_prev_yaw = aim_yaw

	var target_bank := clampf(yaw_rate * 0.6, -1.0, 1.0) * deg_to_rad(bank_max_deg) * speed_t
	bank = lerp_angle(bank, target_bank, 1.0 - exp(-bank_response * delta))

	# Lean the body into the flight direction as speed builds.
	var target_pitch := aim_pitch * speed_t
	_visual_pitch = lerp_angle(_visual_pitch, target_pitch, 1.0 - exp(-6.0 * delta))

	body.rotation = Vector3(_visual_pitch, aim_yaw, bank)


func _update_hud() -> void:
	var mode := "GROUNDED"
	if state == FlightState.AIRBORNE:
		if boosting:
			mode = "BOOST"
		elif velocity.length() > hover_max_speed * 1.3:
			mode = "CRUISE"
		else:
			mode = "HOVER"
	hud.update_stats(velocity.length(), global_position.y, mode,
			energy, energy_max, _boost_locked)
	var spawner := get_tree().get_first_node_in_group("drone_spawner")
	var wave: int = spawner.wave if spawner != null else 1
	hud.update_combat(hull, hull_max,
			get_tree().get_nodes_in_group("drones").size(), wave)
