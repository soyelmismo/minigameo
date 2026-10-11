extends "res://addons/gut/test.gd"
## Art asset gate (AGENTS.md §1.5, §11): the six Blender-authored GLBs exist,
## are non-empty on disk, and import as PackedScenes with real nodes.
##
## Headless-safe: no GPU/RenderingDevice work — FileAccess + PackedScene
## loading only, so this runs in `godot --headless` CI.
##
## Naming note: local variables avoid `name`/`path` because Node already
## declares those properties and the project treats shadowing as an error.

const MODELS_DIR := "res://assets/art/models/"

# Every asset this pipeline must produce (tools/blender/build_assets.sh).
const ASSET_FILES: Array[String] = [
	"player_idle.glb",
	"powerup_orb.glb",
	"building_a.glb",
	"building_b.glb",
	"prop_bench.glb",
	"prop_sign.glb",
]

# Assets whose origin must sit on the ground contact point.
const GROUNDED_ASSETS: Array[String] = [
	"powerup_orb.glb",
	"building_a.glb",
	"building_b.glb",
	"prop_bench.glb",
	"prop_sign.glb",
]


func test_all_six_assets_exist_on_disk() -> void:
	for file in ASSET_FILES:
		var full_path: String = MODELS_DIR + file
		assert_true(FileAccess.file_exists(full_path),
				"%s exists (built by tools/blender/build_assets.sh)" % file)
		var handle := FileAccess.open(full_path, FileAccess.READ)
		assert_not_null(handle, "%s is readable" % file)
		if handle == null:
			continue
		var size: int = handle.get_length()
		handle.close()
		assert_gt(size, 0, "%s is not empty (%d bytes)" % [file, size])


func test_each_asset_loads_as_packed_scene_with_nodes() -> void:
	for file in ASSET_FILES:
		var scene: PackedScene = load(MODELS_DIR + file) as PackedScene
		assert_not_null(scene, "%s imports as a PackedScene" % file)
		if scene == null:
			continue
		var root: Node = scene.instantiate()
		assert_not_null(root, "%s instantiates" % file)
		if root == null:
			continue
		add_child_autofree(root)
		assert_true(root.get_child_count() > 0,
				"%s has child nodes (%d)" % [file, root.get_child_count()])


func test_player_fits_the_required_box() -> void:
	# Brief: the protagonist must fit a 1 x 1.8 x 1 m box, origin at its base.
	var scene: PackedScene = load(MODELS_DIR + "player_idle.glb") as PackedScene
	assert_not_null(scene, "player_idle.glb loads")
	if scene == null:
		return
	var player: Node3D = scene.instantiate() as Node3D
	add_child_autofree(player)
	var aabb: AABB = _scene_aabb(player)
	var dims: Vector3 = aabb.size
	assert_true(dims.x <= 1.0 + 0.01,
			"player width %.3f m fits 1 m" % dims.x)
	assert_true(dims.z <= 1.0 + 0.01,
			"player depth %.3f m fits 1 m" % dims.z)
	assert_true(dims.y <= 1.8 + 0.01,
			"player height %.3f m fits 1.8 m" % dims.y)
	assert_true(dims.y > 1.5, "player is roughly 1.8 m tall (%.3f)" % dims.y)
	assert_almost_eq(aabb.position.y, 0.0, 0.02,
			"origin sits at the base of the character (y=0)")


func test_assets_are_grounded() -> void:
	# Every asset keeps its origin at the ground contact point, so world code
	# can place them without an extra offset.
	for file in GROUNDED_ASSETS:
		var scene: PackedScene = load(MODELS_DIR + file) as PackedScene
		if scene == null:
			assert_true(false, "%s loads" % file)
			continue
		var node: Node3D = scene.instantiate() as Node3D
		add_child_autofree(node)
		var aabb: AABB = _scene_aabb(node)
		assert_almost_eq(aabb.position.y, 0.0, 0.02,
				"%s origin is at its base (y=%.3f)" % [file, aabb.position.y])


func test_buildings_have_emissive_windows() -> void:
	# Stylised towers: wall material + emissive window material, at minimum.
	for file in ["building_a.glb", "building_b.glb"]:
		var scene: PackedScene = load(MODELS_DIR + file) as PackedScene
		if scene == null:
			assert_true(false, "%s loads" % file)
			continue
		var node: Node3D = scene.instantiate() as Node3D
		add_child_autofree(node)
		var mats: Array = _collect_materials(node)
		assert_gte(mats.size(), 2,
				"%s has wall + window materials (%d)" % [file, mats.size()])
		var has_emissive: bool = false
		for mat in mats:
			var std := mat as StandardMaterial3D
			if std != null and std.emission_enabled:
				has_emissive = true
		assert_true(has_emissive, "%s has an emissive window material" % file)


func test_buildings_fit_the_brief_dimensions() -> void:
	# Brief: boxes with emissive windows, 8-14 m tall, 6-10 m wide.
	for file in ["building_a.glb", "building_b.glb"]:
		var scene: PackedScene = load(MODELS_DIR + file) as PackedScene
		if scene == null:
			assert_true(false, "%s loads" % file)
			continue
		var node: Node3D = scene.instantiate() as Node3D
		add_child_autofree(node)
		var aabb: AABB = _scene_aabb(node)
		var dims: Vector3 = aabb.size
		assert_true(dims.y >= 8.0 - 0.01 and dims.y <= 14.0 + 0.01,
				"%s height %.2f m is inside 8-14 m" % [file, dims.y])
		assert_true(dims.x >= 6.0 - 0.01 and dims.x <= 10.0 + 0.01,
				"%s width %.2f m is inside 6-10 m" % [file, dims.x])


func test_powerup_orb_emits() -> void:
	var scene: PackedScene = load(MODELS_DIR + "powerup_orb.glb") as PackedScene
	if scene == null:
		assert_true(false, "powerup_orb.glb loads")
		return
	var orb: Node3D = scene.instantiate() as Node3D
	add_child_autofree(orb)
	var mats: Array = _collect_materials(orb)
	var has_emissive: bool = false
	for mat in mats:
		var std := mat as StandardMaterial3D
		if std != null and std.emission_enabled \
				and std.emission_energy_multiplier > 0.0:
			has_emissive = true
	assert_true(has_emissive, "orb has an emissive material (the pickup hint)")


# --- helpers ---

func _scene_aabb(node: Node3D) -> AABB:
	# Accumulate every MeshInstance3D AABB in world space. AABB is a value
	# type in GDScript, so each level RETURNS its merged box instead of
	# mutating a shared instance.
	var boxes: Array[AABB] = []
	_collect_aabbs(node, boxes)
	if boxes.is_empty():
		return AABB()
	var merged: AABB = boxes[0]
	for i in range(1, boxes.size()):
		merged = merged.merge(boxes[i])
	return merged


func _collect_aabbs(node: Node, boxes: Array[AABB]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var local: AABB = mi.get_aabb()
		var world: AABB = local
		world.position = mi.global_transform * local.position
		boxes.append(world)
	for child in node.get_children():
		_collect_aabbs(child, boxes)


func _collect_materials(node: Node) -> Array:
	var out: Array = []
	_gather_mats(node, out)
	return out


func _gather_mats(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat != null and not out.has(mat):
				out.append(mat)
			var override := mi.material_override
			if override != null and not out.has(override):
				out.append(override)
	for child in node.get_children():
		_gather_mats(child, out)
