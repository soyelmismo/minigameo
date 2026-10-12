class_name HUDConfig
extends Resource
## HUD presentation tuning (scaffold.md §13.2).
##
## AGENTS.md §1.3: zero hardcoded balance numbers — every adjustment of
## UI "feel" lives in `hud_config.tres`. The HUD and the widgets read this
## config; if the .tres is missing, it degrades to a default instance.

## Duration of the flavor text on screen when the micro-game starts (§13.1).
@export var flavor_duration_s: float = 2.0
## Default duration of the subtitled callouts (VO, §13.3).
@export var callout_duration_s: float = 2.5
## Maximum pop scale when a number changes (§13.2).
@export var pop_scale: float = 1.35
## Duration of the pop.
@export var pop_duration_s: float = 0.22
## Decay constants (1/s) of the HudAnim exponential approach: how fast a pop
## returns to rest and a counter reaches its target. Higher = snappier.
@export var pop_decay: float = 22.0
@export var counter_decay: float = 6.0
## Red pulse threshold of the micro-game timer (§13.1).
@export var pulse_threshold_s: float = 5.0
## Red pulse threshold of the match timer (§13.1).
@export var match_pulse_threshold_s: float = 30.0
## Pulse speed (radians/s).
@export var pulse_speed: float = 9.0
## Duration of the SEQUENCE shake on failure.
@export var shake_duration_s: float = 0.35
## Shake amplitude in pixels.
@export var shake_amplitude_px: float = 14.0
## Duration of the score counter animation.
@export var counter_duration_s: float = 0.35
## Sweep speed of the PROGRESS marker.
@export var sweep_speed: float = 0.55
## Duration of the roulette announcement before the start (§13.2).
@export var announce_duration_s: float = 2.6
## Score pop scale (§13.2: every number that changes pops).
@export var score_pop_scale: float = 1.18
