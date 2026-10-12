class_name MinigameMetadata
extends Resource
## The recipe of a micro-game (scaffold.md §7.3).
##
## This Resource is the heart of the data-driven design: a micro-game is a
## `.tres` of this type. NO micro-game-specific fields are added — the
## variety lives in the slots (composition), not in new fields. See §8.0.

# --- Identity (UI + catalog) ---
@export var id: StringName = &""                  # "token_rush"
@export var display_name: String = ""             # "Token Rush"
@export var archetype: StringName = &""           # "COLLECT_RUSH"
@export var duration_s: float = 20.0              # 10..30
@export var base_score: int = 1000
@export var weight: float = 1.0                   # frequency in the roulette
@export var theme_tag: StringName = &"HYBRID"     # AI | LIFE | HYBRID

# --- Player-facing content (English) ---
@export var objective_text: String = ""           # "Grab tokens before it forgets!"
@export var flavor_text: String = ""              # 1-line joke
@export var fail_lines: PackedStringArray = PackedStringArray()

# --- Look & sound (reuses global contracts, does not duplicate) ---
@export var style_pack_id: StringName = &""       # "" = base style of the world
@export var music_state: StringName = &"PEAK"

# --- Composition slots (see §8.0) ---
@export var input_mode: StringName = &"RUN"       # RUN | BUTTON | STICK | LOOK | TAP
@export var spawn_recipe: SpawnRecipe = null      # WHAT entities appear and how
@export var objective_recipe: ObjectiveRecipe = null  # WHAT has to be done
@export var hud_recipe: HUDRecipe = null          # HOW the objective is presented
@export var difficulty_curve: Curve = null        # how it scales with ctx.difficulty

# --- Tags ---
@export var tags: PackedStringArray = PackedStringArray()


## Minimal validation used by the registry (§7.7) and by the tests.
## Returns the list of problems found (empty = valid).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id is empty")
	if archetype == &"":
		problems.append("archetype is empty")
	if duration_s <= 0.0:
		problems.append("duration_s must be > 0")
	if base_score < 0:
		problems.append("base_score must be >= 0")
	if weight < 0.0:
		problems.append("weight must be >= 0")
	if not theme_tag in [&"AI", &"LIFE", &"HYBRID"]:
		problems.append("theme_tag must be AI, LIFE or HYBRID")
	if flavor_text.strip_edges() == "":
		problems.append("flavor_text is empty (humour is a mechanic, §15)")
	if fail_lines.size() < 2:
		problems.append("fail_lines needs at least 2 entries")
	return problems
