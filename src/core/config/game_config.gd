class_name GameConfig
extends Resource
## Central tuning resource (scaffold §1.3: zero hardcoded balance).
##
## Everything tunable lives here as .tres data; gameplay code reads from it.
## The MatchManager, ScoreDirector and systems load this at boot.

@export var match_length_s: float = 300.0          # the 5-minute match
@export var countdown_s: float = 3.0               # 3-2-1 GO
@export var roulette_spin_s: float = 2.5           # dramatic spin duration
@export var minigame_cooldown_s: float = 1.5       # gap between minigames
@export var powerups_max_active: int = 6           # concurrent on the block
@export var powerup_respawn_s: float = 4.0         # after pickup
@export var combo_timeout_s: float = 6.0           # combo resets after this
@export var combo_step: float = 0.25               # multiplier per chain step
@export var combo_max: float = 9.9                 # multiplier cap
@export var time_bonus_per_s: int = 100            # leftover-time bonus
@export var music_bpm: float = 128.0               # locked global tempo
@export var sfx_max_voices: int = 32               # scaffold §15 budget
@export var voice_cooldown_s: float = 3.0          # anti-spam per VO event

# Rank thresholds (score needed for each rank), D is the floor.
@export var rank_c: int = 5000
@export var rank_b: int = 12000
@export var rank_a: int = 25000
@export var rank_s: int = 45000
@export var rank_s_plus: int = 70000
