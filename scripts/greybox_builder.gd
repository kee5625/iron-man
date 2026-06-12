extends Node3D
## Procedural greybox city: grid of box buildings separated by streets.
## Free, deterministic (seeded), throwaway — replaced by real blocks later.
## Varied grays + occasional landmark towers give the eye speed/depth cues.

@export var grid_count := 11
@export var lot_size := 26.0
@export var street_width := 16.0
@export var height_min := 8.0
@export var height_max := 60.0
@export var plaza_chance := 0.12
@export var landmark_chance := 0.06
@export var rng_seed := 7


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var pitch := lot_size + street_width
	var half := (grid_count - 1) * pitch * 0.5
	_add_floor(grid_count * pitch * 2.5)

	var mats: Array[StandardMaterial3D] = []
	for g in [0.45, 0.55, 0.65, 0.75]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(g, g, g)
		mats.append(m)

	for ix in grid_count:
		for iz in grid_count:
			if rng.randf() < plaza_chance:
				continue
			var h := rng.randf_range(height_min, height_max)
			if rng.randf() < landmark_chance:
				h = height_max * rng.randf_range(1.3, 1.8)
			var w := lot_size * rng.randf_range(0.6, 1.0)
			var d := lot_size * rng.randf_range(0.6, 1.0)
			var pos := Vector3(ix * pitch - half, h * 0.5, iz * pitch - half)
			_add_box(Vector3(w, h, d), pos, mats[rng.randi() % mats.size()])


func _add_floor(size: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.34, 0.36)
	_add_box(Vector3(size, 1.0, size), Vector3(0.0, -0.5, 0.0), m)


func _add_box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var box_body := StaticBody3D.new()

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	box_body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	box_body.add_child(mesh_inst)

	box_body.position = pos
	add_child(box_body)
