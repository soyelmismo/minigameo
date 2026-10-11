class_name MinigameMetadata
extends Resource
## La receta de un micro-juego (scaffold.md §7.3).
##
## Este Resource es el corazón del data-driven design: un micro-juego es un
## `.tres` de este tipo. NO se añaden campos específicos de micro-juego — la
## variedad vive en los slots (composición), no en campos nuevos. Ver §8.0.

# --- Identidad (UI + catálogo) ---
@export var id: StringName = &""                  # "token_rush"
@export var display_name: String = ""             # "Token Rush"
@export var archetype: StringName = &""           # "COLLECT_RUSH"
@export var duration_s: float = 20.0              # 10..30
@export var base_score: int = 1000
@export var weight: float = 1.0                   # frecuencia en la ruleta
@export var theme_tag: StringName = &"HYBRID"     # AI | LIFE | HYBRID

# --- Contenido del jugador (inglés) ---
@export var objective_text: String = ""           # "Grab tokens before it forgets!"
@export var flavor_text: String = ""              # chiste 1 línea
@export var fail_lines: PackedStringArray = PackedStringArray()

# --- Look & sonido (reutiliza contratos globales, no duplica) ---
@export var style_pack_id: StringName = &""       # "" = estilo base del mundo
@export var music_state: StringName = &"PEAK"

# --- Slots de composición (ver §8.0) ---
@export var input_mode: StringName = &"RUN"       # RUN | BUTTON | STICK | LOOK | TAP
@export var spawn_recipe: SpawnRecipe = null      # QUÉ entidades aparecen y cómo
@export var objective_recipe: ObjectiveRecipe = null  # QUÉ hay que hacer
@export var hud_recipe: HUDRecipe = null          # CÓMO se presenta el objetivo
@export var difficulty_curve: Curve = null        # cómo escala con ctx.difficulty

# --- Etiquetas ---
@export var tags: PackedStringArray = PackedStringArray()


## Validación mínima usada por el registro (§7.7) y por los tests.
## Devuelve la lista de problemas encontrados (vacía = válido).
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
