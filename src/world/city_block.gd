extends Node3D
## CityBlock — the playable 120 m x 120 m block (scaffold §11, graphics brief).
##
## Composition: ground + streets + buildings + props + spawn points. The layout
## is generated procedurally but strictly DETERMINISTIC: every random choice
## (height jitter, which windows are lit, rooftop clutter) flows through a
## private SeededRNG instance seeded with `gen_seed`, so the block is identical
## on every run — the unit tests resolve this exact node tree.
##
## Premium pass (greybox that reads as a dusk city block, not primitives):
##   * real streets: asphalt, sidewalks, lane dashes, crosswalks;
##   * windows and neon that EMIT, feeding the environment glow;
##   * a warm low rim light so building edges read at dusk;
##   * shared materials + MultiMesh instancing so the whole block costs a
##     handful of draw calls (~1.5k tris of primitives; scaffold §15 budget
##     is <400 draw calls and <250k tris/frame).
##
## Buildings/props get swapped for Blender art in the art pass; the group
## names ("Ground", "Buildings", "Props", "SpawnPoints"), the ring layout and
## the spawn positions stay stable — tests resolve them.

const SeededRNGScript := preload("res://src/core/rng/seeded_rng.gd")

# Building variants: (width, depth, height, material index).
const BUILDINGS := [
	[14.0, 12.0, 16.0, 0],
	[12.0, 14.0, 22.0, 1],
	[16.0, 10.0, 12.0, 2],
	[10.0, 12.0, 28.0, 3],
]

# Palette (dusk city). Kept as data at the top of the file so the look is
# tunable without hunting through logic (§1.3).
const BUILDING_COLORS := [
	Color(0.23, 0.24, 0.28),  # concrete
	Color(0.30, 0.20, 0.17),  # brick
	Color(0.16, 0.19, 0.23),  # slate
	Color(0.18, 0.22, 0.20),  # oxidized glass
]
const COLOR_ASPHALT := Color(0.045, 0.045, 0.055)
const COLOR_WALK := Color(0.30, 0.29, 0.27)
const COLOR_MARKING := Color(0.82, 0.79, 0.66)
const COLOR_WET := Color(0.02, 0.02, 0.03)
const COLOR_WINDOW_WARM := Color(1.0, 0.78, 0.42)
const COLOR_WINDOW_COOL := Color(0.45, 0.85, 1.0)
const COLOR_NEON_CYAN := Color(0.2, 1.0, 1.0)
const COLOR_NEON_MAGENTA := Color(1.0, 0.15, 0.75)

# Window grid rhythm (metres): a window every 2.4 m horizontally, one storey
# every 3.2 m vertically.
const WINDOW_SPACING_X := 2.4
const WINDOW_SPACING_Y := 3.2
const WINDOW_W := 1.35
const WINDOW_H := 1.7
const WINDOW_LIT_CHANCE := 0.82     # the rest read as dark windows
const WINDOW_COOL_CHANCE := 0.15    # of the lit ones: cool office light
const NEON_BUILDINGS := [0, 2, 5]   # which ring slots get a neon sign

@export var block_size: float = 120.0
@export var building_count: int = 8
## Fixed generation seed: same seed -> identical block every run.
@export var gen_seed: int = 20260611


func _ready() -> void:
	# Publish the block under the canonical name (AGENTS.md §1.1) so systems
	# resolve it by name instead of walking the tree. Only a real scene node
	# publishes, so a test double cannot claim the name.
	GameServices.publish("CityBlock", &"block", self)
	var rng: Object = SeededRNGScript.new()
	rng.seed(gen_seed)
	_build_ground()
	_build_buildings(rng)
	_build_props()
	_build_spawns()


# --- Materials (shared: one material per look, reused by every instance) ---

func _mat_building(idx: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BUILDING_COLORS[idx]
	mat.roughness = 0.9
	mat.metallic = 0.05
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.4
	return mat


func _mat_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _mat_simple(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


# --- Ground + streets ----------

func _build_ground() -> void:
	# One big base slab under everything; top surface at y = 0.0 exactly like
	# the greybox, so nothing that touches the floor moves.
	var mat := _mat_simple(COLOR_ASPHALT, 0.98)
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(block_size, 0.4, block_size)
	ground.mesh = box
	ground.material_override = mat
	ground.position = Vector3(0, -0.2, 0)
	ground.name = "Ground"
	add_child(ground)

	var streets := Node3D.new()
	streets.name = "Streets"
	ground.add_child(streets)

	# Two crossing avenues through the middle of the block.
	_add_box(streets, "Road_X", Vector3(block_size, 0.04, 14.0), Vector3(0, 0.0, 0), mat)
	_add_box(streets, "Road_Z", Vector3(14.0, 0.04, block_size), Vector3(0, 0.0, 0), mat)

	# Lane dashes along the centre lines (skip the intersection itself).
	var dash_mat := _mat_simple(COLOR_MARKING, 0.6)
	dash_mat.emission_enabled = true
	dash_mat.emission = COLOR_MARKING
	dash_mat.emission_energy_multiplier = 0.15
	for i in 8:
		var x: float = -56.0 + i * 16.0
		if absf(x) > 10.0:
			_add_box(streets, "Dash_X_%d" % i, Vector3(2.4, 0.02, 0.22),
				Vector3(x, 0.02, 0.0), dash_mat)
		var z: float = -56.0 + i * 16.0
		if absf(z) > 10.0:
			_add_box(streets, "Dash_Z_%d" % i, Vector3(0.22, 0.02, 2.4),
				Vector3(0.0, 0.02, z), dash_mat)

	# Crosswalks where the avenues meet.
	for i in 5:
		var cx: float = -2.5 + i * 1.25
		_add_box(streets, "Crosswalk_N_%d" % i, Vector3(0.55, 0.02, 12.0),
			Vector3(cx, 0.02, 9.0), dash_mat)
		_add_box(streets, "Crosswalk_S_%d" % i, Vector3(0.55, 0.02, 12.0),
			Vector3(cx, 0.02, -9.0), dash_mat)


func _add_box(parent: Node, prop_name: String, size: Vector3, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = pos
	node.name = prop_name
	parent.add_child(node)
	return node


# --- Buildings ----------

func _build_buildings(rng: Object) -> void:
	var half: float = block_size * 0.5 - 8.0
	var ring: Array[Vector3] = [
		Vector3(-half, 0, -half), Vector3(0, 0, -half), Vector3(half, 0, -half),
		Vector3(-half, 0, 0), Vector3(half, 0, 0),
		Vector3(-half, 0, half), Vector3(0, 0, half), Vector3(half, 0, half),
	]
	var root := Node3D.new()
	root.name = "Buildings"
	add_child(root)

	# Shared facade materials (4 variants reused across 8 buildings).
	var mats: Array[StandardMaterial3D] = []
	for i in BUILDINGS.size():
		mats.append(_mat_building(i))

	var warm_mat := _mat_emissive(COLOR_WINDOW_WARM, 1.6)
	var cool_mat := _mat_emissive(COLOR_WINDOW_COOL, 1.8)
	var warm_xforms: Array[Transform3D] = []
	var cool_xforms: Array[Transform3D] = []
	var neon_mat := _mat_emissive(COLOR_NEON_CYAN, 2.4)
	var neon_magenta := _mat_emissive(COLOR_NEON_MAGENTA, 2.4)
	var neon_mesh := QuadMesh.new()
	neon_mesh.size = Vector2(1.0, 1.0)

	var sidewalk_mat := _mat_simple(COLOR_WALK, 0.9)
	var clutter_mat := _mat_simple(Color(0.25, 0.26, 0.28), 0.8, 0.15)
	var tank_mat := _mat_simple(Color(0.35, 0.3, 0.22), 0.7, 0.25)

	for i in mini(building_count, ring.size()):
		var spec: Array = BUILDINGS[i % BUILDINGS.size()]
		var w: float = spec[0]
		var d: float = spec[1]
		var h: float = spec[2] * (0.9 + rng.randf() * 0.25)  # deterministic jitter
		var mat_idx: int = spec[3]
		var pos: Vector3 = ring[i]
		var base: float = 0.3  # sidewalk pad top

		# Sidewalk pad + curb read around the building foot.
		_add_box(root, "Building_%d_Sidewalk" % i,
			Vector3(w + 3.4, 0.3, d + 3.4), Vector3(pos.x, 0.15, pos.z), sidewalk_mat)

		var bld := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, h, d)
		bld.mesh = box
		bld.material_override = mats[mat_idx]
		bld.position = Vector3(pos.x, base + h * 0.5, pos.z)
		bld.name = "Building_%d" % i
		root.add_child(bld)

		# Window grid on the faces that look at the play area (the far faces
		# are never seen from inside the block: half the quads for free).
		var faces: Array = []  # (axis: 0 = x-facing, 1 = z-facing, sign)
		if absf(pos.x) > 0.001:
			faces.append([0, signf(pos.x)])
		if absf(pos.z) > 0.001:
			faces.append([1, signf(pos.z)])
		for face in faces:
			var axis: int = face[0]
			var sgn: float = face[1]
			var span: float = d if axis == 0 else w
			var cols: int = maxi(int(span / WINDOW_SPACING_X), 2)
			var rows: int = maxi(int((h - 2.0) / WINDOW_SPACING_Y), 2)
			var step: float = span / cols
			for c in cols:
				for r in rows:
					if rng.randf() > WINDOW_LIT_CHANCE:
						continue
					var local: float = -span * 0.5 + (c + 0.5) * step
					var y: float = base + 1.6 + r * WINDOW_SPACING_Y
					var theta: float
					var wp: Vector3
					if axis == 0:
						theta = (-PI * 0.5) if sgn > 0.0 else PI * 0.5
						wp = Vector3(pos.x + sgn * (w * 0.5 + 0.03), y,
							pos.z + local)
					else:
						theta = PI if sgn > 0.0 else 0.0
						wp = Vector3(pos.x + local, y, pos.z + sgn * (d * 0.5 + 0.03))
					var xf := Transform3D.IDENTITY \
						.scaled(Vector3(WINDOW_W, WINDOW_H, 1.0)) \
						.rotated_local(Vector3.UP, theta)
					xf.origin = wp
					if rng.randf() < WINDOW_COOL_CHANCE:
						cool_xforms.append(xf)
					else:
						warm_xforms.append(xf)

		# Rooftop clutter: water tank / AC unit, antenna on the tall ones.
		if h > 18.0:
			_add_box(root, "Building_%d_Antenna" % i, Vector3(0.2, 5.0, 0.2),
				Vector3(pos.x - w * 0.25, base + h + 2.5, pos.z), clutter_mat)
		if rng.randf() < 0.75:
			_add_box(root, "Building_%d_Tank" % i, Vector3(2.2, 2.2, 2.2),
				Vector3(pos.x + w * 0.2, base + h + 1.1, pos.z - d * 0.2),
				tank_mat)
		if rng.randf() < 0.6:
			_add_box(root, "Building_%d_AC" % i, Vector3(1.6, 0.8, 1.2),
				Vector3(pos.x - w * 0.2, base + h + 0.4, pos.z + d * 0.25),
				clutter_mat)

		# Neon sign on a few facades: emissive, feeds the glow.
		if i in NEON_BUILDINGS:
			var neon_color: Material = neon_mat if i % 2 == 0 else neon_magenta
			var strip_h: float = 0.55
			var strip_w: float = minf(minf(w, d), 9.0)
			var npos: Vector3
			var ntheta: float
			if absf(pos.x) > 0.001:
				var sgn: float = signf(pos.x)
				npos = Vector3(pos.x + sgn * (w * 0.5 + 0.08),
					base + h * 0.6, pos.z)
				ntheta = (-PI * 0.5) if sgn > 0.0 else PI * 0.5
			else:
				var sgn2: float = signf(pos.z)
				npos = Vector3(pos.x, base + h * 0.6,
					pos.z + sgn2 * (d * 0.5 + 0.08))
				ntheta = PI if sgn2 > 0.0 else 0.0
			var neon_node := MeshInstance3D.new()
			neon_node.mesh = neon_mesh
			neon_node.material_override = neon_color
			var nxf := Transform3D.IDENTITY \
				.scaled(Vector3(strip_w, strip_h, 1.0)) \
				.rotated_local(Vector3.UP, ntheta)
			nxf.origin = npos
			neon_node.transform = nxf
			neon_node.name = "Building_%d_Neon" % i
			root.add_child(neon_node)

	# All lit windows: two MultiMeshes (warm / cool) = two draw calls for the
	# whole block instead of ~180 individual meshes.
	_add_window_multimesh(root, "WindowsWarm", warm_xforms, warm_mat)
	_add_window_multimesh(root, "WindowsCool", cool_xforms, cool_mat)

	_add_dusk_rim_light(root)


func _add_window_multimesh(parent: Node, node_name: String,
		xforms: Array[Transform3D], mat: Material) -> void:
	if xforms.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = quad
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	# Explicit bounds: windows span the whole ring; a bad default AABB would
	# cull half of them.
	mm.custom_aabb = AABB(Vector3(-block_size * 0.5, 0.0, -block_size * 0.5),
		Vector3(block_size, 40.0, block_size))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.name = node_name
	parent.add_child(node)


## Warm low sun we cannot put in main.tscn (the base rig light sits at a high
## elevation there). No shadows: the rig light owns the shadow pass; this one
## only warms the facades so the block reads as dusk.
func _add_dusk_rim_light(parent: Node) -> void:
	var light := DirectionalLight3D.new()
	var az := deg_to_rad(235.0)
	var el := deg_to_rad(22.0)
	var origin := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * 90.0
	# The node is not in the tree yet: look_at() needs one (and errors), so the
	# direction is computed with look_at_from_position() which is tree-free.
	light.look_at_from_position(origin, Vector3(0.0, 6.0, 0.0), Vector3.UP)
	light.light_color = Color(1.0, 0.70, 0.42)
	light.light_energy = 0.6
	light.shadow_enabled = false
	light.name = "DuskRimLight"
	parent.add_child(light)


# --- Props ----------

func _build_props() -> void:
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)

	var crate_mat := _mat_simple(Color(0.42, 0.3, 0.18), 0.85)
	var hydrant_mat := _mat_simple(Color(0.7, 0.15, 0.15), 0.6, 0.1)
	var metal_mat := _mat_simple(Color(0.3, 0.3, 0.35), 0.5, 0.6)
	var bench_mat := _mat_simple(Color(0.4, 0.3, 0.2), 0.9)
	var can_mat := _mat_simple(Color(0.75, 0.72, 0.25), 0.4, 0.3)
	var wet_mat := _mat_simple(COLOR_WET, 0.08, 0.85)

	# Original greybox props (names stable: the tree layout is tested).
	_add_box(root, "prop_crate", Vector3(1.0, 1.0, 1.0), Vector3(6, 0.5, 4), crate_mat)
	_add_box(root, "prop_hydrant", Vector3(0.5, 1.0, 0.5), Vector3(-7, 0.5, 6), hydrant_mat)
	_add_box(root, "prop_lamppost_a", Vector3(0.3, 4.0, 0.3), Vector3(9, 2.0, -6), metal_mat)
	_add_box(root, "prop_lamppost_b", Vector3(0.3, 4.0, 0.3), Vector3(-9, 2.0, -6), metal_mat)
	_add_box(root, "prop_bench", Vector3(2.0, 0.8, 0.7), Vector3(4, 0.4, -9), bench_mat)
	_add_box(root, "prop_can", Vector3(0.6, 0.8, 0.6), Vector3(-5, 0.4, 9), can_mat)

	# Emissive lamp heads: they light at dusk and feed the glow (no real
	# lights: forward+ shadow cost stays at one directional light).
	var head_mat := _mat_emissive(Color(1.0, 0.85, 0.55), 1.8)
	_add_box(root, "prop_lamppost_head_a", Vector3(0.5, 0.25, 0.5), Vector3(9, 4.1, -6), head_mat)
	_add_box(root, "prop_lamppost_head_b", Vector3(0.5, 0.25, 0.5), Vector3(-9, 4.1, -6), head_mat)

	# Street clutter that makes the block read as a city, not a test scene.
	_add_box(root, "prop_trash_bin", Vector3(0.7, 1.0, 0.7), Vector3(11, 0.5, 9), metal_mat)
	_add_box(root, "prop_cone_0", Vector3(0.5, 0.7, 0.5), Vector3(-3, 0.35, 5.5), hydrant_mat)
	_add_box(root, "prop_cone_1", Vector3(0.5, 0.7, 0.5), Vector3(4, 0.35, -5.5), hydrant_mat)
	_add_box(root, "prop_newspaper_box", Vector3(0.8, 1.1, 0.5), Vector3(-12, 0.55, 0), crate_mat)
	_add_box(root, "prop_neon_sign_post", Vector3(0.25, 5.0, 0.25), Vector3(0, 2.5, 20), metal_mat)
	var sign := _add_box(root, "prop_neon_sign", Vector3(2.4, 1.2, 0.12),
		Vector3(0, 5.0, 20), _mat_emissive(COLOR_NEON_MAGENTA, 2.0))
	sign.rotation.y = deg_to_rad(35.0)

	# Wet asphalt patches: dark, near-mirror roughness. They catch the sky
	# and neon for a "rained-on city" read at almost no cost.
	_add_box(root, "prop_wet_road_0", Vector3(7.0, 0.03, 5.0), Vector3(16, 0.03, 1.5), wet_mat)
	_add_box(root, "prop_wet_road_1", Vector3(5.0, 0.03, 6.0), Vector3(-18, 0.03, -2.0), wet_mat)


# --- Spawn points ----------

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
		m.name = "Spawn_%d" % i
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
