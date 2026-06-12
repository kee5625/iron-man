extends Node3D
## Scatters drones over the city in an annulus around the center, at rooftop
## altitudes. When the wave is cleared, spawns the next one (+2 drones) after
## a short breather.

const Drone := preload("res://scripts/drone.gd")

@export var base_count := 12
@export var per_wave_bonus := 2
@export var inner_radius := 40.0
@export var outer_radius := 230.0
@export var min_height := 25.0
@export var max_height := 70.0
@export var wave_delay := 5.0

var wave := 1

var _rng := RandomNumberGenerator.new()
var _respawning := false


func _ready() -> void:
	add_to_group("drone_spawner")
	_rng.randomize()
	_spawn_wave()


func _physics_process(_delta: float) -> void:
	if _respawning or not get_tree().get_nodes_in_group("drones").is_empty():
		return
	_respawning = true
	wave += 1
	get_tree().create_timer(wave_delay).timeout.connect(func() -> void:
		_spawn_wave()
		_respawning = false
	)


func _spawn_wave() -> void:
	var count := base_count + per_wave_bonus * (wave - 1)
	for i in count:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(inner_radius, outer_radius)
		var pos := Vector3(cos(ang) * r, _rng.randf_range(min_height, max_height),
				sin(ang) * r)
		var d := Drone.new()
		d.position = pos  # before add_child — _ready captures this as patrol anchor
		add_child(d)
