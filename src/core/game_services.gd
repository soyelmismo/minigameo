class_name GameServices
extends Node
## GameServices — service locator (scaffold §6).
##
## Systems register themselves at autoload time; everyone else resolves them
## by canonical StringName instead of referencing autoloads directly
## (AGENTS.md §1.1). All lookups degrade gracefully when a service is absent.
##
## NOTE on naming: `get`/`has` would collide with native Object/Node methods
## in GDScript, so the API is `resolve`/`has_service`.

const CORE := &"core"
const MATCH := &"match"
const SCORE := &"score"
const STYLE := &"style"
const IMPACT := &"impact"
const CAMERA := &"camera"
const POSTFX := &"postfx"
const AUDIO := &"audio"
const MUSIC := &"music"
const VOICE := &"voice"
const SFX := &"sfx"
const POWERUPS := &"powerups"
const ROULETTE := &"roulette"
const MINIGAMES := &"minigames"
const SAVE := &"save"
const SETTINGS := &"settings"
const PLAYER := &"player"

var _services: Dictionary[StringName, Object] = {}


## Register a service under its canonical name. Later registrations win.
func register(service_name: StringName, instance: Object) -> void:
	if instance == null:
		push_warning("GameServices: refusing to register null for '%s'" % service_name)
		return
	_services[service_name] = instance


## Resolve a service. Returns null when absent (callers must degrade).
func resolve(service_name: StringName) -> Object:
	return _services.get(service_name, null)


func has_service(service_name: StringName) -> bool:
	return _services.has(service_name)


## Convenience typed getters for the hot paths.
func get_match() -> Node:
	return resolve(MATCH) as Node


func get_score() -> Node:
	return resolve(SCORE) as Node


## Static lookup usable from anywhere without a node reference (duck-typed,
## degrades silently when the locator is absent).
static func lookup(service_name: StringName) -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var locator := tree.root.get_node_or_null(^"/root/GameServices")
	if locator == null or not locator.has_method("resolve"):
		return null
	return locator.resolve(service_name)
