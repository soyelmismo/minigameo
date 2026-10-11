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

func _ready() -> void:
	# Self-register under &"core": every system resolves the locator via
	# lookup(&"core") and then registers itself there (§6 contract). Without
	# this self-registration every player of that pattern fails silently.
	_services[CORE] = self


## Publish an autoload singleton under its canonical service name.
##
## Only a node that actually IS the `/root/<autoload_name>` singleton may claim
## the name. A test double or a second copy created inside a scene (dozens of
## tests do `load(SCRIPT).new()`) also runs that script's `_ready()`, and
## without this guard its self-registration would clobber the live service.
## The clobber is invisible until the double is freed, when the
## dangling-reference guard in resolve() drops the key and the real autoload
## never re-registers — leaving shake, SFX, camera, audio and settings dead
## for the rest of the run, usually with no error anywhere.
func publish(autoload_name: String, service_name: StringName, instance: Object) -> void:
	if instance == null or service_name.is_empty():
		return
	if not is_instance_valid(instance):
		return
	var singleton: Node = get_tree().root.get_node_or_null("/root/" + autoload_name)
	if singleton != instance:
		return  # not the live autoload: a stand-in must not claim the name
	register(service_name, instance)


## Register a service under its canonical name. Later registrations win.
func register(service_name: StringName, instance: Object) -> void:
	if instance == null:
		push_warning("GameServices: refusing to register null for '%s'" % service_name)
		return
	_services[service_name] = instance


## Resolve a service. Returns null when absent (callers must degrade).
## A registration whose instance has since been freed is dropped on read:
## returning a dangling reference would crash every consumer. The value is
## held as Variant because assigning a freed Object to a typed variable
## already errors in Godot 4.
func resolve(service_name: StringName) -> Object:
	var found: Variant = _services.get(service_name, null)
	if found == null:
		return null
	if not is_instance_valid(found):
		_services.erase(service_name)
		return null
	return found as Object


## Drop a registration (scene teardown: the instance is going away and the
## locator must not hand out a dangling reference).
func unregister(service_name: StringName) -> void:
	_services.erase(service_name)


func has_service(service_name: StringName) -> bool:
	return _services.has(service_name)


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
