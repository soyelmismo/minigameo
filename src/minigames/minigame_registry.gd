class_name MinigameRegistry
extends Node
## Central registry ID → {scene, metadata} (scaffold.md §7.7).
##
## - Populated by scanning `src/minigames/catalog/*.tres` at startup.
## - Validates that every entry has a valid id, archetype and scene.
## - It fails LOUDLY (push_error) on invalid entries, not silently.
## - It does not know concrete micro-games: only archetypes.
##
## An archetype is resolved first as a `.tscn` scene; if it does not exist its
## compiled `.gd` script is instanced instead (same engine, zero scenes).

const CATALOG_DIR := "res://src/minigames/catalog/"
const ARCHETYPE_DIR := "res://src/minigames/archetypes/"

## Canonical service name. Every system that needs the catalog must resolve it
## through GameServices.lookup(&"registry") instead of building its own
## instance: the director and the roulette each used to create a private
## MinigameRegistry, and the director's copy never scanned, so micro-games ran
## with a metadata whose spawn_recipe was empty (no entities, no HUD recipe).
const SERVICE_NAME := &"registry"

## metadata by id
var _by_id: Dictionary = {}      # StringName -> MinigameMetadata
## PackedScene of the archetype by archetype name
var _archetype_scenes: Dictionary = {}  # StringName -> PackedScene
## Script of the archetype (fallback without .tscn)
var _archetype_scripts: Dictionary = {} # StringName -> GDScript
var _scanned: bool = false

signal registry_loaded(count: int)


## Scans the catalog and preloads the archetypes. Idempotent.
func scan() -> void:
	if _scanned:
		return
	_by_id.clear()
	_archetype_scenes.clear()
	_archetype_scripts.clear()
	_load_archetypes()
	_load_catalog()
	_scanned = true
	registry_loaded.emit(_by_id.size())


## Preloads `.tscn` scenes and `.gd` scripts from `src/minigames/archetypes/`.
func _load_archetypes() -> void:
	var dir := DirAccess.open(ARCHETYPE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn") or file_name.ends_with(".gd"):
			var path: String = ARCHETYPE_DIR + file_name
			var archetype_id := StringName(file_name.get_basename().replace("archetype_", "").to_upper())
			if file_name.ends_with(".tscn"):
				var scene: PackedScene = load(path) as PackedScene
				if scene != null:
					_archetype_scenes[archetype_id] = scene
			else:
				var script: GDScript = load(path) as GDScript
				if script != null:
					_archetype_scripts[archetype_id] = script
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_catalog() -> void:
	var dir := DirAccess.open(CATALOG_DIR)
	if dir == null:
		push_error("MinigameRegistry: catalog dir missing at %s" % CATALOG_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			_register_entry(CATALOG_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Registers a catalog entry, validating it. It fails loudly.
func _register_entry(path: String) -> void:
	var res: Resource = load(path)
	if res == null:
		push_error("MinigameRegistry: cannot load %s" % path)
		return
	var meta := res as MinigameMetadata
	if meta == null:
		push_error("MinigameRegistry: %s is not a MinigameMetadata" % path)
		return
	var problems := meta.validate()
	if not problems.is_empty():
		push_error(
			"MinigameRegistry: invalid entry %s -> %s" % [path, ", ".join(problems)]
		)
		return
	if _by_id.has(meta.id):
		push_error("MinigameRegistry: duplicate id '%s' in %s" % [String(meta.id), path])
		return
	if not has_archetype(meta.archetype):
		push_error(
			"MinigameRegistry: '%s' needs unknown archetype '%s' (%s)" % [
				String(meta.id), String(meta.archetype), path
			]
		)
		return
	_by_id[meta.id] = meta


# --- API ---

## Metadata by id, or null if it does not exist.
func get_metadata(id: StringName) -> MinigameMetadata:
	return _by_id.get(id, null) as MinigameMetadata


## Scene of the archetype by name, or null if it does not exist.
func get_archetype_scene(archetype: StringName) -> PackedScene:
	return _archetype_scenes.get(archetype, null) as PackedScene


## True if the archetype exists as a scene or as a script.
func has_archetype(archetype: StringName) -> bool:
	return _archetype_scenes.has(archetype) or _archetype_scripts.has(archetype)


## Instances the archetype: scene if it exists, compiled script if not.
## Base Node type (the archetypes extend Node/Node3D).
func instantiate_archetype(archetype: StringName) -> Node:
	var scene: PackedScene = get_archetype_scene(archetype)
	if scene != null:
		var instance: Node = scene.instantiate() as Node
		if instance != null:
			return instance
	var script: GDScript = _archetype_scripts.get(archetype, null) as GDScript
	if script != null:
		var from_script: Node = script.new() as Node
		if from_script != null:
			return from_script
	push_error("MinigameRegistry: cannot instantiate archetype '%s'" % String(archetype))
	return null


## All known ids, sorted for determinism.
func get_all_ids() -> Array:
	var ids: Array = _by_id.keys()
	ids.sort()
	return ids


func has_id(id: StringName) -> bool:
	return _by_id.has(id)


## Number of valid entries.
func size() -> int:
	return _by_id.size()


## Scans if it has not been done yet (convenience for calls from the director).
func ensure_scanned() -> void:
	scan()
