extends Node3D
## CityBlock — the playable 120m x 120m block (scaffold §11).
##
## Composes the block tiles + buildings + props + spawn points. Greyblock
## that reads intentionally (per AGENTS.md: the block must look deliberate).
## Buildings/props get swapped for Blender art in the art pass; the layout
## and spawn logic stay identical.

const TILE := preload("res://src/world/block_tile.tscn")

# Building variants: (width, depth, height, color)
const BUILDINGS := [
	[14.0, 12.0, 16.0, Color(0.55, 0.5, 0.6)],
	[12.0, 14.0, 22.0, Color(0.45, 0.55, 0.65)],
	[16.0, 10.0, 12.0, Color(0.6, 0.55, 0.45)],
	[10.0, 12.0, 28.0, Color(0.5, 0.6, 0.55)],
]

@export var block_size: float = 120.0
@export var building_count: int = 8


func _ready() -> void:
	_build_ground()
	_build_buildings()
	_build_props()
	_build_spawns()


func _build_ground() -> void:
	# One big ground slab under everything (the block tiles add detail).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2, 1)
	mat.roughness = 0.95
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(block_size, 0.4, block_size)
	ground.mesh = box
	ground.material_override = mat
	ground.position = Vector3(0, -0.2, 0)
	ground.name = "Ground"
	add_child(ground)


func _build_buildings() -> void:
	var half: float = block_size * 0.5 - 8.0
	var ring: Array[Vector3] = [
		Vector3(-half, 0, -half), Vector3(0, 0, -half), Vector3(half, 0, -half),
		Vector3(-half, 0, 0), Vector3(half, 0, 0),
		Vector3(-half, 0, half), Vector3(0, 0, half), Vector3(half, 0, half),
	]
	var root := Node3D.new()
	root.name = "Buildings"
	add_child(root)
	for i in mini(building_count, ring.size()):
		var spec: Array = BUILDINGS[i % BUILDINGS.size()]
		var w: float = spec[0]
		var d: float = spec[1]
		var h: float = spec[2]
		var c: Color = spec[3]
		var bld := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, h, d)
		bld.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.85
		bld.material_override = mat
		var pos: Vector3 = ring[i]
		bld.position = Vector3(pos.x, h * 0.5, pos.z)
		bld.name = "bld_%d" % i
		root.add_child(bld)
		# Emissive window band.
		var band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(w * 0.9, 1.2, d * 0.02)
		band.mesh = band_mesh
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = Color(1.0, 0.9, 0.6, 1)
		band_mat.emission_enabled = true
		band_mat.emission = Color(1.0, 0.85, 0.5, 1)
		band_mat.emission_energy_multiplier = 0.8
		band.material_override = band_mat
		band.position = Vector3(pos.x, h * 0.6, pos.z + d * 0.51)
		band.name = "bld_%d_windows" % i
		root.add_child(band)


func _build_props() -> void:
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var props := [
		["prop_crate", Vector3(6, 0.5, 4), Color(0.6, 0.45, 0.3)],
		["prop_hydrant", Vector3(-7, 0.5, 6), Color(0.8, 0.2, 0.2)],
		["prop_lamppost", Vector3(9, 2.0, -6), Color(0.3, 0.3, 0.35)],
		["prop_lamppost", Vector3(-9, 2.0, -6), Color(0.3, 0.3, 0.35)],
		["prop_bench", Vector3(4, 0.4, -9), Color(0.5, 0.4, 0.3)],
		["prop_can", Vector3(-5, 0.4, 9), Color(0.7, 0.7, 0.2)],
	]
	for p in props:
		var name_str: String = p[0]
		var pos: Vector3 = p[1]
		var color: Color = p[2]
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s: float = 1.0 if not "lamppost" in name_str else 0.3
		box.size = Vector3(s, s * 2 if "lamppost" in name_str else s, s)
		node.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		node.material_override = mat
		node.position = pos
		node.name = name_str
		root.add_child(node)


func _build_spawns() -> void:
	var root := Node3D.new()
	root.name = "SpawnPoints"
	add_child(root)
	var points := [
		Vector3(0, 0, 0), Vector3(10, 0, 10), Vector3(-10, 0, -10),
		Vector3(12, 0, -8), Vector3(-12, 0, 8), Vector3(8, 0, -14),
	]
	for i in mini(points.size(), 8):
		var m := Marker3D.new()
		m.position = points[i] + Vector3(0, 1.0, 0)
		m.name = "spawn_%d" % i
		root.add_child(m)


## All spawn point world positions (power-up spawner reads this).
func spawn_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var sp := get_node_or_null("SpawnPoints")
	if sp == null:
		return out
	for child in sp.get_children():
		if child is Marker3D:
			out.append((child as Marker3D).global_position)
	return out


func block_center() -> Vector3:
	return global_position
