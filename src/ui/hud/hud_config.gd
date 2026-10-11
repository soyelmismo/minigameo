class_name HUDConfig
extends Resource
## Tuning de presentación del HUD (scaffold.md §13.2).
##
## AGENTS.md §1.3: cero números de balance hardcodeados — todo ajuste de
## "feel" de UI vive en `hud_config.tres`. El HUD y los widgets leen esta
## configuracción; si el .tres falta, se degrada a una instancia por defecto.

## Duración del flavor text en pantalla al arrancar el micro-juego (§13.1).
@export var flavor_duration_s: float = 2.0
## Duración por defecto de los callouts subtitulados (VO, §13.3).
@export var callout_duration_s: float = 2.5
## Escala máxima del pop al cambiar un número (§13.2).
@export var pop_scale: float = 1.35
## Duración del pop.
@export var pop_duration_s: float = 0.22
## Umbral de pulso rojo del timer de micro-juego (§13.1).
@export var pulse_threshold_s: float = 5.0
## Umbral de pulso rojo del timer de partida (§13.1).
@export var match_pulse_threshold_s: float = 30.0
## Velocidad del pulso (radianes/s).
@export var pulse_speed: float = 9.0
## Duración del shake de la SEQUENCE al fallar.
@export var shake_duration_s: float = 0.35
## Amplitud del shake en píxeles.
@export var shake_amplitude_px: float = 14.0
## Duración de la animación del contador de score.
@export var counter_duration_s: float = 0.35
## Velocidad de barrido del marcador de PROGRESS.
@export var sweep_speed: float = 0.55
## Duración del anuncio de la ruleta antes del arranque (§13.2).
@export var announce_duration_s: float = 2.6
## Escala del pop del score (§13.2: todo número que cambia hace pop).
@export var score_pop_scale: float = 1.18
