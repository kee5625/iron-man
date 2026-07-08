extends Node3D
## Procedural textured city. Same seeded grid layout as the greybox era, but
## buildings now wear real CC0 facade textures (ambientCG), get concrete roof
## slabs (so rooftops read right from the air), and stand on tiled asphalt.
##
## Facades use world-space triplanar mapping: window size stays constant no
## matter the building dimensions, no UV work needed on the generated boxes.
## The 018/020 facades ship emission maps — windows glow faintly, pops at
## golden hour and sets up night city for free later.
##
## Falls back to flat gray if a texture folder is missing, so the scene never
## breaks over a lost download.

const TEX_ROOT := "res://assets/textures/city/"
const FACADES := ["Facade018A", "Facade018B", "Facade020A", "Facade020B", "Facade006"]
const TINTS := [
	Color(1.0, 1.0, 1.0),
	Color(0.85, 0.82, 0.78),
	Color(0.78, 0.8, 0.85),
]

@export var grid_count := 11
@export var lot_size := 26.0
@export var street_width := 16.0
@export var height_min := 8.0
@export var height_max := 60.0
@export var plaza_chance := 0.12
@export var landmark_chance := 0.06
@export var rng_seed := 7
## Meters of building per facade texture tile (window scale).
@export var facade_tile_m := 8.0
## Lit-window emission strength. 0 = off.
@export var window_glow := 0.5

var _facade_mats: Array[StandardMaterial3D] = []
var _roof_mat: StandardMaterial3D
var _ground_mat: StandardMaterial3D


func _ready() -> void:
	_build_materials()

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var pitch := lot_size + street_width
	var half := (grid_count - 1) * pitch * 0.5
	_add_ground(grid_count * pitch * 2.5)
	_add_roads(pitch, half)

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
			_add_building(Vector3(w, h, d), pos,
					_facade_mats[rng.randi() % _facade_mats.size()])


func _build_materials() -> void:
	for facade in FACADES:
		for tint in TINTS:
			_facade_mats.append(_make_pbr(facade, facade_tile_m, tint, window_glow))
	_roof_mat = _make_pbr("Concrete034", 4.0, Color(0.9, 0.88, 0.85), 0.0)
	_ground_mat = _make_pbr("PavingStones070", 2.0, Color.WHITE, 0.0)


## Builds a triplanar PBR material from an ambientCG folder; flat-color
## fallback if the textures aren't there.
func _make_pbr(folder: String, tile_m: float, tint: Color,
		emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := TEX_ROOT + folder + "/" + folder + "_1K-JPG_"

	var col := _tex(base + "Color.jpg")
	if col != null:
		m.albedo_texture = col
		m.albedo_color = tint
	else:
		m.albedo_color = Color(0.55, 0.55, 0.57) * tint

	var nrm := _tex(base + "NormalGL.jpg")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm

	var rgh := _tex(base + "Roughness.jpg")
	if rgh != null:
		m.roughness_texture = rgh

	if emission > 0.0:
		var emi := _tex(base + "Emission.jpg")
		if emi != null:
			m.emission_enabled = true
			m.emission_texture = emi
			m.emission_energy_multiplier = emission

	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var s := 1.0 / tile_m
	m.uv1_scale = Vector3(s, s, s)
	return m


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _add_building(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var walls := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = size
	walls.mesh = wall_mesh
	walls.material_override = mat
	body.add_child(walls)

	# Concrete slab caps the top — hides the triplanar facade smearing across
	# the roof, and the 0.3m overhang reads as a parapet from the air.
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(size.x + 0.6, 0.5, size.z + 0.6)
	roof.mesh = roof_mesh
	roof.material_override = _roof_mat
	roof.position = Vector3(0.0, size.y * 0.5 + 0.25, 0.0)
	body.add_child(roof)

	body.position = pos
	add_child(body)


## Marked road strips down every street, plain asphalt squares at the
## intersections (hides the crossing lane-lines). Roads are visual-only planes
## floating millimeters over the collision ground — no physics seams.
## Stacking order: sidewalk 0 < N-S roads 0.03 < E-W roads 0.05 < crossings 0.07.
func _add_roads(pitch: float, half: float) -> void:
	var road_len := grid_count * pitch + street_width
	var road_mat := _make_road_mat(road_len / street_width)
	var cross_mat := _make_pbr("Asphalt010", 4.0, Color.WHITE, 0.0)

	for i in grid_count + 1:
		var c := i * pitch - half - pitch * 0.5
		_add_road_plane(Vector3(c, 0.03, 0.0), road_len, false, road_mat)
		_add_road_plane(Vector3(0.0, 0.05, c), road_len, true, road_mat)

	for i in grid_count + 1:
		for j in grid_count + 1:
			var p := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(street_width, street_width)
			p.mesh = pm
			p.material_override = cross_mat
			p.position = Vector3(i * pitch - half - pitch * 0.5, 0.07,
					j * pitch - half - pitch * 0.5)
			add_child(p)


func _add_road_plane(pos: Vector3, length: float, along_x: bool,
		mat: StandardMaterial3D) -> void:
	var p := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(street_width, length)
	p.mesh = pm
	p.material_override = mat
	p.position = pos
	if along_x:
		p.rotation.y = PI / 2.0
	add_child(p)


## Road needs directional UVs (lane markings must run along the street), so no
## triplanar here — plain UV, tiled down the plane's length.
func _make_road_mat(tiles: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := TEX_ROOT + "Road012A/Road012A_1K-JPG_"
	var col := _tex(base + "Color.jpg")
	if col != null:
		m.albedo_texture = col
	else:
		m.albedo_color = Color(0.2, 0.2, 0.21)
	var nrm := _tex(base + "NormalGL.jpg")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
	var rgh := _tex(base + "Roughness.jpg")
	if rgh != null:
		m.roughness_texture = rgh
	m.uv1_scale = Vector3(1.0, tiles, 1.0)
	return m


func _add_ground(size: float) -> void:
	var body := StaticBody3D.new()

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 1.0, size)
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, 1.0, size)
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _ground_mat
	body.add_child(mesh_inst)

	body.position = Vector3(0.0, -0.5, 0.0)
	add_child(body)
