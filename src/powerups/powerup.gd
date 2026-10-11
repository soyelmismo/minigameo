class_name PowerUp
extends Area3D
## Power-up recogible en la cuadra (scaffold.md §6.11).
##
## Placeholder estilizado intencional: malla emisiva + órbita de brillo.
## Bob/idle procedural y giro van aquí; el balance (cooldown, número
## concurrente) vive en el spawner como datos.

const DEFAULT_PICKUP_RADIUS := 1.6

## Emitida al ser recogido (por overlap de área o por proximidad).
signal collected(body: Node)

@export var bob_amplitude: float = 0.25
@export var bob_speed: float = 2.0
@export var spin_speed: float = 1.5
@export var pickup_radius: float = DEFAULT_PICKUP_RADIUS

var _base_y: float = 0.0
var _t: float = 0.0
var _taken: bool = false


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	# Grupo para que el spawner y el director lo encuentren sin acoplamiento.
	add_to_group(&"powerup")


func _physics_process(delta: float) -> void:
	if _taken:
		return
	_idle(delta)


## Animación idle: bob + giro. Puramente cosmética, sin balance.
func _idle(delta: float) -> void:
	_t += delta * bob_speed
	position.y = _base_y + sin(_t) * bob_amplitude
	rotate_y(delta * spin_speed)


func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	# Duck-typed: cualquier cuerpo con `is_player` o el nombre del jugador.
	if _is_player(body):
		take(body)


## Fallback por distancia cuando no hay físicas (tests headless, jugador lejos).
func check_proximity(player: Node3D) -> bool:
	if _taken or player == null or not is_instance_valid(player):
		return false
	if global_position.distance_to(player.global_position) <= pickup_radius:
		take(player)
		return true
	return false


## Marca el power-up como recogido y lo retira de la escena.
func take(by: Node) -> void:
	if _taken:
		return
	_taken = true
	collected.emit(by)
	set_deferred(&"monitoring", false)
	queue_free()


func is_taken() -> bool:
	return _taken


## El jugador se reconoce por duck-typing, nunca por clase concreta.
func _is_player(body: Node) -> bool:
	if body == null:
		return false
	if body.has_method("is_player") and bool(body.is_player()):
		return true
	if body.is_in_group(&"player"):
		return true
	if body.name == &"Player":
		return true
	return false
