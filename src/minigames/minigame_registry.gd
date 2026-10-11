class_name MinigameRegistry
extends Node
## Registro central ID → {escena, metadata} (scaffold.md §7.7).
##
## - Poblado por escaneo de `src/minigames/catalog/*.tres` al arrancar.
## - Valida que cada entrada tenga id, arquetipo y escena válidos.
## - Falla RUIDOSAMENTE (push_error) ante entradas inválidas, no en silencio.
## - No conoce micro-juegos concretos: solo arquetipos.
##
## Un arquetipo se resuelve primero como escena `.tscn`; si no existe se
## instancia su script `.gd` compilado (mismo motor, cero escenas).

const CATALOG_DIR := "res://src/minigames/catalog/"
const ARCHETYPE_DIR := "res://src/minigames/archetypes/"

## metadata por id
var _by_id: Dictionary = {}      # StringName -> MinigameMetadata
## PackedScene del arquetipo por nombre de arquetipo
var _archetype_scenes: Dictionary = {}  # StringName -> PackedScene
## Script del arquetipo (fallback sin .tscn)
var _archetype_scripts: Dictionary = {} # StringName -> GDScript
var _scanned: bool = false

signal registry_loaded(count: int)


## Escanea el catálogo y precarga los arquetipos. Idempotente.
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


## Precarga escenas `.tscn` y scripts `.gd` de `src/minigames/archetypes/`.
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


## Registra una entrada del catálogo validándola. Falla ruidosamente.
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

## Metadatos por id, o null si no existe.
func get_metadata(id: StringName) -> MinigameMetadata:
	return _by_id.get(id, null) as MinigameMetadata


## Escena del arquetipo por nombre, o null si no existe.
func get_archetype_scene(archetype: StringName) -> PackedScene:
	return _archetype_scenes.get(archetype, null) as PackedScene


## True si el arquetipo existe como escena o como script.
func has_archetype(archetype: StringName) -> bool:
	return _archetype_scenes.has(archetype) or _archetype_scripts.has(archetype)


## Instancia el arquetipo: escena si existe, script compilado si no.
## Nodo base tipo Node (los arquetipos extienden Node/Node3D).
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


## Todos los ids conocidos, ordenados para determinismo.
func get_all_ids() -> Array:
	var ids: Array = _by_id.keys()
	ids.sort()
	return ids


func has_id(id: StringName) -> bool:
	return _by_id.has(id)


## Número de entradas válidas.
func size() -> int:
	return _by_id.size()


## Escanea si no se ha hecho aún (comodidad para llamadas desde el director).
func ensure_scanned() -> void:
	scan()
