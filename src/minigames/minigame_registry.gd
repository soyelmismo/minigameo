class_name MinigameRegistry
extends Node
## Registro central ID → {escena, metadata} (scaffold.md §7.7).
##
## - Poblado por escaneo de `src/minigames/catalog/*.tres` al arrancar.
## - Valida que cada entrada tenga id, arquetipo y escena válidos.
## - Falla RUIDOSAMENTE (push_error) ante entradas inválidas, no en silencio.
## - No conoce micro-juegos concretos: solo arquetipos.

const CATALOG_DIR := "res://src/minigames/catalog/"
const ARCHETYPE_SCENE_DIR := "res://src/minigames/archetypes/"

## metadata por id
var _by_id: Dictionary = {}      # StringName -> MinigameMetadata
## PackedScene del arquetipo por nombre de arquetipo
var _archetype_scenes: Dictionary = {}  # StringName -> PackedScene
var _scanned: bool = false

signal registry_loaded(count: int)


## Escanea el catálogo y precarga las escenas de arquetipo. Idempotente.
func scan() -> void:
	if _scanned:
		return
	_by_id.clear()
	_archetype_scenes.clear()
	_load_archetype_scenes()
	_load_catalog()
	_scanned = true
	registry_loaded.emit(_by_id.size())


## Precarga las escenas `.tscn` de `src/minigames/archetypes/`.
## Un arquetipo sin escena no es fatal: se instancia el script compilado.
func _load_archetype_scenes() -> void:
	var dir := DirAccess.open(ARCHETYPE_SCENE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var path: String = ARCHETYPE_SCENE_DIR + file_name
			var scene: PackedScene = load(path) as PackedScene
			if scene != null:
				var archetype_id := StringName(file_name.get_basename().replace("archetype_", "").to_upper())
				_archetype_scenes[archetype_id] = scene
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
	if not _archetype_scenes.has(meta.archetype):
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
