# SCAFFOLD — ARCADE BLOCK: 5 MINUTE OVERDRIVE

> **Purpose of this file:** it is the project's master brief. Any agent
> (human or AI) must read it in full before touching code. It contains the vision,
> the architecture, the implementation contracts and the hard rules. `AGENTS.md`
> contains the work directives; this file contains the WHAT and the WHY.

> **Language:** the GAME (names, HUD, objectives, voice, flavor text) is in
> **English**. Code identifiers go in English; team docs
> (this file, the GDD) are kept in English.

---

## 1. GAME VISION

**Name:** *ARCADE BLOCK: 5 MINUTE OVERDRIVE*

**Concept:** a fast-paced 3D arcade game set on a single stylized urban
block. The player runs freely chasing bright power-ups scattered across the
map. On picking one up, a **roulette** fires and picks one of
**36 micro-games** at random, each 10-30 seconds long. Each micro-game has its
own **style pack** that temporarily transforms the look of the world and the
character (palette, sky, materials, post-processing, music, HUD). A match
lasts **exactly 5 minutes**; the goal is to maximize the score.

**The personality twist:** the neighborhood is a satirical mirror of modern
life and of tech/AI culture. The micro-games are everyday anxieties and absurd
moments of the digital era — notifications, commutes, deliveries, chatbot
hallucinations, melted GPUs, tech debt — presented with hyperactive,
self-aware humor in the vein of WarioWare / Nintendo Land. The fantasy:
*"the world is a chaotic video game and I'm the only one who knows how to
play it."*

**Design pillars (non-negotiable):**

1. **PURE ARCADE FEELING** — immediate, readable, noisy feedback, with
   *juice* on every action. Feel reference: Nintendo (Mario Kart, Wario
   Ware, Nintendo Land) — legibility over realism, surprise over fidelity.
2. **CONSTANT SURPRISE** — you never know which micro-game comes next; the world
   changes its skin drastically every 30-60s.
3. **5-MINUTE SESSION** — extremely high event density; every second matters.
   Zero deep menus, zero dead downtime.
4. **HUMOR AS MECHANIC** — the joke IS the hook. A micro-game is remembered
   because it made you laugh ("the chatbot forgot why it exists"). Humor reinforces
   legibility and identity; it is not decoration.
5. **SCORE AS LANGUAGE** — combos, multipliers, ranks (D→C→B→A→S→S+).
   The player chases the number and the record.
6. **IMPACT FRAMES ON EVERYTHING** — every hit, crash or pickup must be felt:
   hitstop, shake, FOV punch, flash, audio response.
7. **DATA-DRIVEN / MAXIMUM ABSTRACTION** — a micro-game is **data, not
   code**. The archetypes are generic engines configured with
   `.tres` (recipes). The UI auto-generates from the same data. The engineering
   goal: creating micro-game #37 must cost **one `.tres` file and
   zero lines of code** (except new assets). If code is needed for a
   micro-game, the abstraction is incomplete — fix the engine, don't
   patch the micro-game.

**Explicit anti-goal:** DO NOT write 36 micro-game scripts. If a balance
change or a new micro-game requires touching code, the design has failed.

**Player fantasy:** "I own the block. Every 30 seconds the whole neighborhood
transforms and challenges me to something new. I want more points than anyone."

**Audience / sensitivity:** absurd and irreverent but **friendly**
humor (family-adjacent). No strong profanity, no sexual content, no
graphic violence. The jokes target *situations* (tech bureaucracy, the commute,
notification anxiety), not groups of people. Think: gentle satire of
"modern life is absurd", not a roast.

---

## 2. VOICE AND TONE

The game has **one hyperactive arcade announcer voice**, self-aware and a
little passive-aggressive — like a TV host who had too much sugar. It is the
comic glue of the whole game.

**Voice rules:**
- Short phrases. Fast rhythm. Capitals for emphasis.
- Self-aware: the announcer knows it is an arcade game and says so.
- Gentle irony about tech/AI: respect the emotion, exaggerate the absurdity.
- Never cruel to the player; the "roast" is affectionate ("close. nope.").

**Announcer (VO) callouts — canonical examples:**

| Moment | VO line |
|---|---|
| match start | "FIVE MINUTES. NO MERCY. GO!" |
| power-up collected | "ROULETTE TIME! Fate is loading..." |
| roulette spinning | "What could it be? Who knows! Not me!" |
| micro-game starts | "GO GO GO!" |
| high combo | "COMBO x{5}! Show off." |
| time < 30s | "THIRTY SECONDS! PANIC!" |
| micro-game failed | "Oof. The bot is disappointed. It's a bot. It can't be. But it is." |
| micro-game perfect | "FLAWLESS. I'm telling everyone." |
| S-rank match end | "S-RANK! You absolute monster." |
| low match end | "Well. You tried. Did you though?" |

**Per-micro-game fail messages:** each one has 2-3 short comedic
variations (avoid repetition). See each one's entry in
`docs/design/minigames.md`.

---

## 3. TECH STACK

| Layer | Choice | Notes |
|---|---|---|
| Engine | **Godot 4.3+** (target 4.4 LTS) | Forward+ by default; optional `Compatibility` profile for low-end |
| Language | **GDScript** (static typing mandatory) | No C#/GDExtension extensions except for approved critical need |
| 3D Render | Forward+, HDR, ACES/AgX tonemap, HDR glow, volumetrics | See §12 |
| Modeling | **Blender 4.x** → export `.glb` (glTF 2.0) | See §11 |
| Audio | Godot buses + `AudioStreamInteractive` (4.3+) for beat-synced dynamic music | Fallback: manual mix of quantized stems |
| Testing | **GUT** (Godot Unit Test) via addon | Contract tests, deterministic RNG, score |
| Version control | git + Git LFS for binary assets | Commit convention: Conventional Commits |
| Platform target | PC (Win/Linux) first; console/laptop later | Export presets prepared from day 1 |

**Architecture golden rule:** every gameplay system is a **contract**.
No micro-game knows the MatchManager; it receives an injected
context. No system talks to another directly: via `EventBus` (decoupled
signals) or via `GameServices` (service locator). See §5 and §7.

---

## 4. PROJECT STRUCTURE

```
arcades/
├── AGENTS.md                     # Work directives for agents
├── scaffold.md                   # This file (master brief)
├── README.md
├── LICENSE.md                    # GPL-3.0 (full text)
├── project.godot
├── export_presets.cfg
├── icon.svg
├── .gitignore / .gitattributes
│
├── docs/
│   ├── design/
│   │   ├── GDD.md                # Expanded Game Design Document
│   │   ├── minigames.md          # Entry for the 36 micro-games (+ flavor/fails)
│   │   ├── art-bible.md          # Art direction, palettes, references
│   │   └── audio-design.md       # Detailed sound and music design
│   └── architecture/
│       ├── contracts.md          # Contract reference (canonical copy of §7)
│       └── roadmap.md            # Phases and tasks
│
├── assets/
│   ├── art/
│   │   ├── blender/              # .blend SOURCES (never hand-edit a .glb)
│   │   │   ├── city/             # buildings, sidewalks, street
│   │   │   ├── characters/       # player + NPCs/avatars
│   │   │   ├── props/            # block props
│   │   │   └── fx/               # micro-game effect props
│   │   ├── models/               # EXPORTED .glb (imported by Godot)
│   │   │   └── (city/ characters/ props/ fx/)
│   │   ├── textures/             # palettes, atlas, emissive
│   │   └── materials/            # shared material .tres
│   ├── audio/
│   │   ├── music/                # stems + loops per music state
│   │   ├── sfx/                  # (player/ world/ ui/ impact/ vo/)
│   │   └── ambience/             # block ambience layers
│   ├── ui/                       # sprites, icons, fonts
│   └── shaders/                  # reusable .gdshader
│
├── src/                          # ALL game code and scenes
│   ├── core/
│   │   ├── event_bus.gd          # autoload
│   │   ├── game_services.gd      # autoload — Service Locator
│   │   ├── rng/seeded_rng.gd     # deterministic RNG (tests/roulette)
│   │   ├── pooling/object_pool.gd
│   │   ├── state_machine/state_machine.gd + state.gd
│   │   └── config/game_config.gd
│   │
│   ├── match/
│   │   ├── match_manager.gd      # autoload — 5 min timer, phases, global score
│   │   ├── states/               # boot, title, countdown, freeroam, roulette,
│   │   │                         # minigame, style_pop, results
│   │   ├── score/score_director.gd
│   │   └── score/score_popup.tscn
│   │
│   ├── player/
│   │   ├── player.gd
│   │   ├── player_motor.gd       # movement (CharacterBody3D)
│   │   ├── player_avatar.tscn
│   │   └── player_input.gd
│   │
│   ├── world/
│   │   ├── city_block.tscn       # the full block (modular)
│   │   ├── block_tile.tscn       # reusable sidewalk/street tile
│   │   ├── buildings/            # building variants
│   │   └── props/                # static props + spawn points
│   │
│   ├── styles/
│   │   ├── style_director.gd     # autoload — applies/blends style packs
│   │   ├── style_pack.gd         # Resource (data contract)
│   │   ├── style_postfx.gd       # Resource (post-processing profile)
│   │   └── packs/*.tres          # the 12 style packs
│   │
│   ├── juice/
│   │   ├── impact_director.gd    # autoload — hitstop, shake, flashes
│   │   ├── impact_frame.gd       # Resource (impact preset)
│   │   ├── camera_director.gd    # autoload — camera, FOV punch, shake
│   │   ├── postfx_director.gd    # autoload — WorldEnvironment, overlays
│   │   └── screen_effects/       # flash, vignette, chromatic (fullscreen)
│   │
│   ├── audio/
│   │   ├── audio_director.gd     # autoload — buses, SFX pooling, ducking
│   │   ├── music_director.gd     # dynamic music, beat-synced states
│   │   ├── sfx_library.gd        # SFX catalog + voice rules
│   │   ├── sfx_player.gd         # voice pool with limit and priority
│   │   └── voice_lines.gd        # announcer VO catalog (by event)
│   │
│   ├── powerups/
│   │   ├── powerup_spawner.gd
│   │   ├── powerup.tscn + .gd
│   │   └── roulette/
│   │       ├── roulette_controller.gd
│   │       └── roulette_wheel.tscn
│   │
│   ├── minigames/
│   │   ├── minigame.gd           # ★ BASE CONTRACT (abstract)
│   │   ├── minigame_context.gd   # ★ dependency injection
│   │   ├── minigame_metadata.gd  # ★ data Resource
│   │   ├── minigame_result.gd    # ★ result
│   │   ├── minigame_registry.gd  # registry (ID → scene/metadata)
│   │   ├── minigame_director.gd  # orchestrates the lifecycle
│   │   ├── slots/                # ★ COMPOSITION CONTRACTS (recipes)
│   │   │   ├── spawn_recipe.gd       # what appears and how it behaves
│   │   │   ├── objective_recipe.gd   # what must be done to win
│   │   │   └── hud_recipe.gd         # how the objective is communicated
│   │   ├── archetypes/           # 14 generic engines (implement the slots)
│   │   │   ├── archetype_collect_rush.gd
│   │   │   ├── archetype_chase.gd
│   │   │   ├── archetype_dodge.gd
│   │   │   ├── archetype_tap_target.gd
│   │   │   ├── archetype_rhythm.gd
│   │   │   ├── archetype_zone_hold.gd
│   │   │   ├── archetype_gate_race.gd
│   │   │   ├── archetype_combo_chain.gd
│   │   │   ├── archetype_meter_stop.gd
│   │   │   ├── archetype_charge_blast.gd
│   │   │   ├── archetype_push_zone.gd
│   │   │   ├── archetype_memory.gd
│   │   │   ├── archetype_balance.gd
│   │   │   └── archetype_stack_timed.gd
│   │   └── catalog/              # 36 .tres definitions (pure data)
│   │
│   ├── ui/
│   │   ├── hud/hud.tscn + widgets (timer, score, combo, objective)
│   │   ├── roulette/roulette_ui.tscn
│   │   ├── screens/ (title, results, pause, settings)
│   │   └── theme/ (per-style HUD themes)
│   │
│   └── systems/
│       ├── save_system.gd
│       ├── settings.gd          # accessibility included
│       └── leaderboard.gd
│
├── addons/                       # third-party plugins (gut, etc.)
├── tests/
│   ├── unit/                     # contracts, score, rng, timers
│   └── integration/              # full headless match flow
└── tools/
    ├── blender/export_glb.py     # .blend → .glb exporter
    ├── audio/stem_mixer.py       # AudioStreamInteractive builder
    └── validate/validate_assets.py
```

---

## 5. GENERAL ARCHITECTURE

```
                          ┌──────────────────────────────┐
                          │      GameServices (SL)       │
                          │  registry of all the         │
                          │  systems (autoloads)         │
                          └──────────────┬───────────────┘
                                         │ resolves
         ┌───────────────┬───────────────┼───────────────┬──────────────┐
         ▼               ▼               ▼               ▼              ▼
    MatchManager    StyleDirector   ImpactDirector   AudioDirector  MinigameDirector
    (states)        (style packs)   (hitstop/shake)  (buses/music)  (micro-game cycle)
         │               │               │               │              │
         └───────┬───────┘               │               │              │
                 ▼                       ▼               ▼              ▼
            EventBus ────────────► all systems listen, nobody couples
```

**Match flow (match state machine):**

```
BOOT → TITLE → COUNTDOWN(3-2-1) → FREE_ROAM ──┬── power-up collected ──► ROULETTE (2-3s)
         ▲                                    │                              │
         │                                    │                    MINIGAME (10-30s)
         │                             time keeps running                     │
         │                                    │                              ▼
         │                                    ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  STYLE_POP / SCORING (1-2s)
         │                                                                   │
         └────────────────────── back to FREE_ROAM ◄─────────────────────────┘
                                               ... repeat until TIME_UP
TIME_UP → RESULTS (rank, records) → TITLE
```

The 5 min timer runs continuously (except during countdown/results). The micro-games
run **inside** the match, without pausing the global clock.

---

## 6. CORE SYSTEMS (autoloads)

Each system registers itself in `GameServices` on boot. No system
references another directly; it uses `GameServices.get(&"name")` or listens
to `EventBus` signals.

### 6.1 EventBus
Global signal bus. Events defined as constants. Only for
high-latency decoupling (states, audio, UI). Never for frame-a-frame
gameplay logic where execution order matters (there: direct call).

Canonical signals (extensible):
```
powerup_collected(minigame_id)
roulette_started / roulette_result(id)
minigame_started(id) / minigame_finished(result)
style_applied(pack_id) / style_reverted()
score_changed(total, delta) / combo_changed(combo)
impact_requested(weight)      # impact frame request
match_time_up() / match_started() / match_reset()
player_state_changed(state)   # idle/run/air/hurt/etc.
voice_requested(event_id)     # announcer VO line request
```

### 6.2 MatchManager
- Global 300s timer (configurable), the source of truth for remaining time.
- Orchestrates the state machine (§5).
- Accumulates the global score via `ScoreDirector`.
- Emits `match_time_up()` and transitions to RESULTS.
- It does not know micro-games: it only knows `MinigameDirector`.

### 6.3 ScoreDirector
- Base score + combo multiplier + remaining-time bonus + style bonus.
- Combo rises when chaining successes (power-ups without failing, back-to-back micro-games),
   resets on failure or after X seconds with no events.
- Final rank: D < C < B < A < S < S+ (thresholds in `.tres`, tunable).
- Emits `score_changed` / `combo_changed`; spawns `score_popup` (world-space).

### 6.4 StyleDirector
- Applies a `StylePack` to the world with a transition (~0.3-0.5s lerp).
- Swap strategies: `FULL_SWAP` (different materials/models),
  `SHADER_UNIFORM` (global uniforms the shader reads — preferred, cheap),
  `OVERLAY` (material_overlay on meshes).
- Auto-reverts to the base style when the micro-game ends.
- Coordinates with PostFX, Audio (music), Camera (FOV) and HUD (theme).

### 6.5 ImpactDirector
- Single API: `impact(weight: ImpactWeight)` or `impact_frame(preset: ImpactFrame)`.
- Runs global hitstop, camera shake, FOV punch, flash, chroma pulse,
  model freeze, impact audio layer.
- Everything parametrized by `.tres` presets (never hardcoded numbers in gameplay).

### 6.6 CameraDirector
- Player follow camera with soft lag (spring).
- `fov_punch(degrees, duration)`, `shake(trauma, freq, duration)`,
  `zoom_pulse(...)` for dramatic moments (roulette, impact).
- Base FOV per style pack.

### 6.7 PostFXDirector
- Controls the `WorldEnvironment` (glow, color correction, fog, SSAO/SSIL,
  tonemap) and the fullscreen effects (flash, vignette, chromatic, scanlines).
- Smooth interpolation between style profiles (pop-free transitions).

### 6.8 AudioDirector
- Bus layout (§10). SFX pool with voice limit, priority and
  interruption. Pitch/volume randomization per take. Automatic ducking
  (VO, impacts, music). Music delegated to MusicDirector.

### 6.9 MusicDirector
- Dynamic music by state (§10.2): `CALM`, `TENSION`, `PEAK`, `TRIUMPH`,
  `FAIL`. Beat-quantized transitions. Reacts to intensity (power-up
  proximity, high combo, remaining time < 30s).

### 6.10 VoiceDirector (arcade announcer)
- Catalog of VO lines by event (`voice_lines.gd` + audios).
- Anti-spam: cooldown per event, priority, never two voices at once.
- Lines are chosen with random variation (2-3 per event) to avoid fatigue.
- High ducking: the announcer is always intelligible over the music.

### 6.11 PowerUpDirector + RouletteController
- Spawner: bright power-ups scattered across the block, respawn after
  pickup with a cooldown; max N active simultaneously (constant pressure).
- On pickup: `roulette_started` → visual wheel (~2.5s) → picks a random
  micro-game via `SeededRNG` → hands off to `MinigameDirector`.

### 6.12 MinigameDirector
- Loads the chosen micro-game from `MinigameRegistry`, injects
  `MinigameContext`, runs `setup → start`, delegates `update/on_input`,
  receives `MinigameResult`, runs `teardown`, notifies the MatchManager.
- Manages cooldown between micro-games and immediate anti-repetition (avoids the
  same micro-game twice in a row unless the catalog is exhausted; it also avoids the
  same archetype twice if there are alternatives).

---

## 7. IMPLEMENTATION CONTRACTS

> Canonical copy in `docs/architecture/contracts.md`. These contracts are
> **stable**: changing them requires updating this file, the doc and the tests.

### 7.1 Minigame (base contract)

```gdscript
# src/minigames/minigame.gd
class_name Minigame
extends Node
## Base contract of EVERY micro-game. The archetypes extend it; the
## .tres definitions configure it. A micro-game NEVER references
## MatchManager, ScoreDirector or other systems directly.

signal finished(result: MinigameResult)
signal progress_changed(normalized: float)   # 0..1, for the HUD
signal event(kind: StringName, payload: Dictionary)  # juice/audio/voice hooks

# --- Lifecycle (mandatory to respect the order) ---

## Injection. No gameplay yet. Read from the context.
func setup(ctx: MinigameContext) -> void:
    push_error("%s: setup() not implemented" % get_script().resource_path)

## Starts the micro-game: start timers, spawn entities, request music.
func start() -> void:
    push_error("%s: start() not implemented" % get_script().resource_path)

## Logical frame. Do NOT use _process/_physics_process directly unless
## the archetype documents it; the director calls update().
func update(delta: float) -> void:
    pass

## Raw input; each micro-game decides what it uses (keys, mouse, stick).
func on_input(event: InputEvent) -> void:
    pass

## Clean close: return objects to the pool, stop extra music,
## leave the world as it was found.
func teardown() -> void:
    pass

# --- Metadata ---
func get_metadata() -> MinigameMetadata:
    push_error("%s: get_metadata() not implemented" % get_script().resource_path)
    return null
```

**Contract rules:**
- A micro-game ends ONLY by calling `finished(result)` or when the director
  aborts it (match timeout).
- It must be deterministic given the same `SeededRNG` and the same seed.
- It must work with keyboard, mouse AND gamepad input (see §13).
- It must not leave orphan entities or dirty global states.

### 7.2 MinigameContext (injection)

```gdscript
# src/minigames/minigame_context.gd
class_name MinigameContext
extends RefCounted

var match_manager: MatchManager
var score: ScoreDirector
var style: StyleDirector
var impact: ImpactDirector
var camera: CameraDirector
var postfx: PostFXDirector
var audio: AudioDirector
var music: MusicDirector
var voice: VoiceDirector
var player: Player
var world_root: Node3D          # parent to spawn the micro-game's entities
var arena_center: Vector3       # center of the block
var rng: SeededRNG              # deterministic per micro-game
var difficulty: float           # 0..1, rises as remaining time gets low
var time_left_in_match: float   # the micro-game must never exceed this
```

### 7.3 MinigameMetadata (Resource — THE RECIPE)

This Resource is the **heart of the data-driven design**. A micro-game is a
`.tres` of this type. NO micro-game-specific fields are added to it: the
variety lives in the `slots` (composition), not in new fields. See §8.0.

```gdscript
# src/minigames/minigame_metadata.gd
class_name MinigameMetadata
extends Resource

# --- Identity (UI + catalog) ---
@export var id: StringName                 # "token_rush"
@export var display_name: String           # "Token Rush"
@export var archetype: StringName          # "COLLECT_RUSH"
@export var duration_s: float = 20.0        # 10..30
@export var base_score: int = 1000
@export var weight: float = 1.0             # frequency in the roulette
@export var theme_tag: StringName          # AI | LIFE | HYBRID (balance/filter)

# --- Player content (English) ---
@export var objective_text: String         # "Grab tokens before it forgets!"
@export var flavor_text: String             # comic joke/description (1 line)
@export var fail_lines: PackedStringArray   # 2-3 humorous fail messages

# --- Look & sound (reuses global contracts, does not duplicate) ---
@export var style_pack_id: StringName = &"" # "" = the world's base style
@export var music_state: StringName = &"PEAK"

# --- Composition slots (see §8.0) ---
@export var input_mode: StringName          # RUN | BUTTON | STICK | LOOK | TAP
@export var spawn_recipe: SpawnRecipe       # WHICH entities appear and how
@export var objective_recipe: ObjectiveRecipe # WHAT must be done to win
@export var hud_recipe: HUDRecipe           # HOW the objective is presented in the HUD
@export var difficulty_curve: Curve         # how it scales with ctx.difficulty

# --- Tags ---
@export var tags: PackedStringArray         # filters/balance
```

### 7.3.1 Slots: composition contracts

The variety of the 36 micro-games does NOT come from 36 scripts; it comes from
combining these 5 modular contracts. A new micro-game = choose an archetype +
fill the slots in a `.tres`. If a micro-game does not fit the slots, the
corresponding slot is extended (once) instead of creating a script per micro-game.

```gdscript
# src/minigames/slots/spawn_recipe.gd
class_name SpawnRecipe
extends Resource
## WHAT appears in the arena and how it behaves.
@export var entity_scene: PackedScene      # the micro-game's prop (token, GPU...)
@export var count: int = 12
@export var count_scales_with_difficulty: bool = true
@export var spawn_radius: float = 18.0      # meters around the player
@export var spawn_pattern: StringName       # SCATTER | RING | GRID | LINE | WAVE
@export var motion: StringName              # STATIC | ORBIT | FLEE | CHASE | FALL
@export var speed: float = 4.0
@export var lifetime_s: float = -1.0        # -1 = until collected/hit
@export var respawn: bool = false           # respawn after being collected
@export var pool_group: StringName = &"mg_entity"

# src/minigames/slots/objective_recipe.gd
class_name ObjectiveRecipe
extends Resource
## WHAT must be done. The archetype evaluates this condition every frame.
@export var kind: StringName                # COLLECT_N | SURVIVE_T | TAP_N | HOLD_ZONE_T
                                             # GATES_IN_ORDER | CHAIN_N | STOP_IN_ZONE | ...
@export var target: int = 12                # N objects / N seconds / N gates
@export var tolerance: float = 0.0          # hit window (sec/beat/units)
@export var fail_on: StringName             # TIMEOUT | TOUCH_HAZARD | WRONG_INPUT | NONE
@export var time_bonus_per_s: int = 100     # points per leftover second when winning
@export var combo_step: float = 0.25        # multiplier increment per hit

# src/minigames/slots/hud_recipe.gd
class_name HUDRecipe
extends Resource
## HOW the objective is communicated. The UI auto-builds from here
## (see §13): zero HUD code per micro-game.
@export var primary_widget: StringName      # COUNTER | TIMER | PROGRESS | SEQUENCE
@export var icon: Texture2D                 # objective icon (legible silhouette)
@export var color_hint: StringName = &""    # the objective's semantic color
@export var show_flavor: bool = true        # show the joke during startup
@export var callout_on_start: StringName = &"GO GO GO!"
```

**Renderer per archetype (not per micro-game):** each archetype knows how to
render its slots. The `MinigameRegistry` resolves `archetype → base scene`;
the scene reads the recipe and auto-configures spawns, objective and HUD. That
is why micro-game #37 is a `.tres` and nothing more.

### 7.4 MinigameResult

```gdscript
# src/minigames/minigame_result.gd
class_name MinigameResult
extends RefCounted

var success: bool = false
var base_score: int = 0
var time_bonus: int = 0        # proportional to leftover time
var combo_max: int = 0
var total_score: int = 0
var grade: StringName = &"D"   # D C B A S S+
var fail_reason: StringName = &""  # TIMEOUT | WRONG_INPUT | HIT | ...
```

### 7.5 StylePack (Resource)

```gdscript
# src/styles/style_pack.gd
class_name StylePack
extends Resource

@export var id: StringName
@export var display_name: String

# --- World ---
@export var sky_top: Color
@export var sky_horizon: Color
@export var fog_color: Color
@export var fog_density: float
@export var sun_color: Color
@export var sun_energy: float
@export var ambient_color: Color
@export var ambient_energy: float

# --- Look ---
@export var material_mode: StringName      # FULL_SWAP | SHADER_UNIFORM | OVERLAY
@export var character_material: Material   # player/NPC material
@export var environment_material: Material # world materials
@export var postfx: StylePostFX            # bloom, chroma, vignette, scanline...
@export var fov_override: float = -1.0     # -1 = no override
@export var camera_offset: Vector3 = Vector3.ZERO

# --- Feedback ---
@export var music_state: StringName = &""
@export var hud_theme: Theme
@export var transition_s: float = 0.4
@export var revert_to_base_on_end: bool = true
```

### 7.6 ImpactFrame (Resource)

```gdscript
# src/juice/impact_frame.gd
class_name ImpactFrame
extends Resource

@export var hitstop_s: float = 0.06        # typical 40..120ms
@export var time_scale: float = 0.05       # scale during the hitstop
@export var shake_amplitude: float = 0.3   # trauma 0..1
@export var shake_frequency: float = 24.0
@export var shake_duration_s: float = 0.4
@export var fov_punch: float = -6.0        # degrees (negative = punch-in)
@export var chromatic_pulse: float = 0.5
@export var flash_color: Color = Color.WHITE
@export var flash_alpha: float = 0.3
@export var desaturate: float = 0.3
@export var model_freeze: bool = false     # freezes the model, the world goes on
@export var slow_mo_curve: Curve           # post-hitstop time_scale curve
@export var impact_sfx: AudioStream
```

### 7.7 MinigameRegistry

- Central registry ID → {`.tscn` scene, `MinigameMetadata`}.
- Populated by scanning `src/minigames/catalog/*.tres` on boot.
- The director resolves `id → instance`, injects the context, runs it.
- Guarantees that every catalog micro-game has a valid scene and metadata
  (validation on boot; loud failure, not silent).

---

## 8. MICRO-GAMES: ARCHETYPES AND CATALOG

### 8.0 Abstraction principle: composition, not inheritance

**The rule that saves 90% of the micro-game code:**

> A micro-game is NOT a class. It is **data** (a `MinigameMetadata` with its
> slots filled) executed by a **generic archetype**. The variety comes from
> *combining* slots, not from *inheriting* classes.

```
Micro-game #37  =  Archetype (generic engine, 14 total)
                +  SpawnRecipe        (.tres — what appears)
                +  ObjectiveRecipe    (.tres — what must be done)
                +  HUDRecipe          (.tres — how it is shown)
                +  InputMode          (RUN/BUTTON/STICK/LOOK/TAP)
                +  content/flavor     (.tres — the joke)
                ─────────────────────────────────────────────
                =  ONE .tres file. ZERO lines of code.
```

**How to mutate a micro-game (fast, without touching code):**
- Change difficulty → edit `target` / `speed` / `difficulty_curve`.
- Change theme (from AI to life) → change `entity_scene` + `flavor_text`.
- Change look → change `style_pack_id`.
- Change control → change `input_mode`.
- New micro-game with an existing mechanic → duplicate the `.tres` and adjust.

**When code IS touched (rare, and it is an architecture decision):**
1. A mechanic that **no** archetype covers → create ONE new archetype
   (a reusable generic engine), not a micro-game script.
2. A slot that does not express the necessary variation → extend THAT slot
   (e.g. add `spawn_pattern: SPIRAL`), benefiting all the micro-games that use it.
3. Never: an `if minigame_id == "token_rush"` in gameplay. That is the
   anti-pattern this design exists to eliminate.

**`archetypes/` structure:** each archetype is ONE scene + ONE class that
implements the `Minigame` by reading its slots. 14 archetypes cover the 36
micro-games. An archetype is tested once (lifecycle test + slots test) and all
its micro-games inherit that guarantee.

---

**Strategy:** 14 archetypes (implemented base contracts) + 36 concrete
micro-games as **configurations** of those archetypes. This way the 30+ are
covered with contracts that are easy to implement and to test. A full entry for
each one (with per-difficulty tuning, flavor text, fail messages and style
pack) is in `docs/design/minigames.md`.

### 8.1 Archetypes (base contracts)

| # | Archetype | Control hook | Success condition |
|---|---|---|---|
| 1 | COLLECT_RUSH | run and touch | collect N objects before time runs out |
| 2 | CHASE | chase/flee a moving one | reach/dodge a moving target |
| 3 | DODGE | dodge obstacles | survive without taking damage |
| 4 | TAP_TARGET | press/hit targets | hit N targets |
| 5 | RHYTHM | press on the beat | hits within the musical time window |
| 6 | ZONE_HOLD | hold a zone | accumulate X seconds in the zone |
| 7 | GATE_RACE | pass gates in order | complete the route in order |
| 8 | COMBO_CHAIN | chain actions without failing | chain of N with no fail |
| 9 | METER_STOP | stop a meter in a zone | stop in a valid zone N times |
| 10 | CHARGE_BLAST | charge and release | release at the optimal window/power |
| 11 | PUSH_ZONE | push objects to a zone | get N objects into the zone |
| 12 | MEMORY | repeat a sequence | replicate the pattern (Simon) |
| 13 | BALANCE | hold a trajectory | travel a narrowing path |
| 14 | STACK_TIMED | stack with timing | stack N at the target height |

### 8.2 Catalog of 36 micro-games

`theme_tag`: **AI** (tech/AI culture) · **LIFE** (modern life) · **HYBRID**
(both). The joke goes in `flavor_text`; the hook in the "Hook" column.

| # | ID | Name | Archetype | Tag | Hook (1 line) |
|---|---|---|---|---|---|
| 1 | token_rush | Token Rush | COLLECT_RUSH | AI | Grab tokens before the chatbot forgets why it exists |
| 2 | data_diet | Data Diet | COLLECT_RUSH | AI | Clean data good, junk data bad. You are the filter |
| 3 | grocery_getaway | Grocery Getaway | COLLECT_RUSH | LIFE | Grab groceries; don't let the self-checkout catch you |
| 4 | porch_pirate | Porch Pirate | COLLECT_RUSH | LIFE | Packages appear. Pirates appear. Grab first |
| 5 | hallucination_highway | Hallucination Highway | DODGE | AI | Dodge confidently-wrong answers. They're SO sure |
| 6 | gpu_meltdown | GPU Meltdown | DODGE | AI | Overheating GPUs are raining. Find shade |
| 7 | commuter_chaos | Commuter Chaos | DODGE | LIFE | 8:47 AM. Umbrellas everywhere. Good luck |
| 8 | laundry_landmine | Laundry Landmine | DODGE | LIFE | The dryer eats socks. And apparently you now |
| 9 | bias_bug_bash | Bias Bug Bash | TAP_TARGET | AI | Whack the bias bugs. They keep popping up |
| 10 | spam_smash | Spam Smash | TAP_TARGET | LIFE | "YOU WON A CRUISE!" Smash it. Smash them all |
| 11 | autocomplete_alley | Autocomplete Alley | TAP_TARGET | AI | Tap what it predicts. Or rebel. Rebelling loses points |
| 12 | notification_nuke | Notification Nuke | TAP_TARGET | LIFE | 47 notifications. Tap them before they breed |
| 13 | beat_of_the_bot | Beat of the Bot | RHYTHM | AI | Pulse to the synthetic rhythm. You can tell. Barely |
| 14 | barista_blitz | Barista Blitz | RHYTHM | LIFE | Espresso machine rhythm. Tap on the hiss |
| 15 | flow_state | Flow State | ZONE_HOLD | LIFE | Hold the focus zone. The world wants you distracted |
| 16 | silent_disco | Silent Disco | ZONE_HOLD | LIFE | Hold your headphone bubble. Everyone's screaming. Not you |
| 17 | merge_merge_merge | Merge Merge Merge | GATE_RACE | LIFE | Highway merge. Nobody zips. Nobody cares |
| 18 | prompt_chain | Prompt Chain | COMBO_CHAIN | AI | Chain the prompt words. Order matters. Obviously |
| 19 | combo_commute | Combo Commute | COMBO_CHAIN | LIFE | Transfer, transfer, transfer. Don't miss the line |
| 20 | stack_overflow | Stack Overflow | BALANCE | HYBRID | Balance the overloaded stack. Don't drop the frame |
| 21 | context_recall | Context Recall | MEMORY | AI | Remember the context. Before it's evicted |
| 22 | password_palace | Password Palace | MEMORY | LIFE | Remember the password. It was the good one |
| 23 | learning_rate | Learning Rate | METER_STOP | AI | Stop the LR in the sweet spot. Too high = explode |
| 24 | push_and_pray | Push & Pray | CHARGE_BLAST | HYBRID | Time the git push. Main branch is watching |
| 25 | feature_freeze | Feature Freeze | PUSH_ZONE | HYBRID | Push features to the release zone. Or scope creep |
| 26 | inference_inferno | Inference Inferno | CHASE | AI | Chase the runaway inference. It's fast. Too fast |
| 27 | delivery_dash | Delivery Dash | CHASE | LIFE | Chase the driver. They saw you. They keep driving |
| 28 | tech_debt_tower | Tech Debt Tower | STACK_TIMED | HYBRID | Stack the debt. It'll fall. It always falls |
| 29 | elevator_endurance | Elevator Endurance | ZONE_HOLD | LIFE | Hold the door. Someone's coming. Always |
| 30 | circular_referencing | Circular Referencing | GATE_RACE | AI | Break the infinite loop. Find the exit. There is no exit |
| 31 | agile_sprint | Agile Sprint | GATE_RACE | LIFE | Sprint through the sprint. Retrospective at the end |
| 32 | sudo_smash | Sudo Smash | TAP_TARGET | HYBRID | Type the sudo password. Fast. Before the timeout |
| 33 | not_found | 404 Not Found | DODGE | AI | Dodge the 404s. They're lost and confused. So are you |
| 34 | overfitting_olympics | Overfitting Olympics | MEMORY | AI | Memorize the training set. It won't generalize |
| 35 | fire_drill | Fire Drill | DODGE | LIFE | Office fire drill. Again. Walk, don't run. Or do. Points |
| 36 | server_room_scramble | Server Room Scramble | DODGE | HYBRID | The servers are hot. The room is hot. Everything is hot |

**Theme balance:** ~11 AI · ~15 LIFE · ~10 HYBRID. The roulette can weight by
`theme_tag` if one theme is detected to be saturating (avoids 5 AI in a row).

**Cross-cutting micro-game rules:**
- Every micro-game has **clear, legible victory and failure conditions**
  (HUD with objective and progress).
- Failing does NOT end the match: you lose the bonus, the combo resets and you
  keep going.
- Leftover time when winning converts to bonus (rewards speed).
- Every micro-game has at least 3 impact spikes (start, hits, end).
- `flavor_text` + `fail_lines` are mandatory (humor is a mechanic, pillar 4).

### 8.3 Archetype → slots mapping (implementation reference)

Each archetype declares which slots it needs and how it interprets them. This
table is the guide to implement the 14 generic engines:

| Archetype | Typical SpawnRecipe | ObjectiveRecipe (kind) | InputMode | HUDRecipe |
|---|---|---|---|---|
| COLLECT_RUSH | SCATTER, STATIC/FLEE | COLLECT_N | RUN | COUNTER |
| CHASE | motion: CHASE, moving target | CHASE_CATCH / SURVIVE_T | RUN | TIMER |
| DODGE | WAVE/FALL, motion: FALL | SURVIVE_T, fail_on: TOUCH_HAZARD | RUN | TIMER |
| TAP_TARGET | SCATTER, short lifetime | TAP_N | LOOK/TAP | COUNTER |
| RHYTHM | on beat, motion: ORBIT | TAP_N, tolerance: beat | BUTTON | PROGRESS |
| ZONE_HOLD | 1 zone (no entities) | HOLD_ZONE_T | RUN | TIMER |
| GATE_RACE | LINE, numbered gates | GATES_IN_ORDER | RUN | SEQUENCE |
| COMBO_CHAIN | sequential order | CHAIN_N | BUTTON | SEQUENCE |
| METER_STOP | animated meter | STOP_IN_ZONE, tolerance | BUTTON | PROGRESS |
| CHARGE_BLAST | 1 projectile | CHARGE_RELEASE, tolerance | BUTTON | PROGRESS |
| PUSH_ZONE | physics, motion: STATIC | PUSH_N_TO_ZONE | RUN/STICK | COUNTER |
| MEMORY | revealed sequence | MEMORY_REPLAY | BUTTON | SEQUENCE |
| BALANCE | narrowing path | BALANCE_T, fail_on: FALL | RUN | TIMER |
| STACK_TIMED | timed falling | STACK_N | BUTTON | COUNTER |

With this table, the 36 catalog micro-games are implemented by filling
`.tres` on top of these 14 engines. Cost per micro-game: **one `.tres`**.

---

## 9. STYLE PACKS (temporary appearance changes)

Each power-up/roulette applies a style pack that temporarily transforms world +
character. Preferred implementation: **SHADER_UNIFORM** — the world shader reads
global uniforms (`u_style_top`, `u_style_fog`, `u_style_saturation`,
`u_style_scanline`...) that the StyleDirector interpolates. Cheap, pop-free,
reversible. FULL_SWAP only for drastic model changes.

| Style pack | Palette/atmosphere | Look | Music |
|---|---|---|---|
| NEON_DRIFT | cyan/magenta night | emissive, rain, reflections | synthwave |
| INK_NOIR | high-contrast black & white | ink outlines, grain | noir jazz |
| TOON_POP | bright primaries | Nintendo-like cel-shading | orchestral pop |
| VHS_90 | saturated with bleeding | scanlines, chroma shift | retro chiptune |
| BIT_CRUSH | limited 8-bit palette | dither, color steps | pure chiptune |
| CHROME_BEAM | mirror gray + light | polished metal, HDR reflections | techno |
| CANDY_PLASTIC | pastel plastic | soft plastic, shine | bubblegum pop |
| KAIJU_SOFVI | matte solid colors | sofvi vinyl, exaggerated scale | kaiju march |
| SPRITE_25D | partial pixel art | 3D/2D sprite mix | 16-bit |
| PAPER_CRAFT | cut paper | cutout, hard shadows | acoustic folk |
| GOLD_RUSH | gold/black | metal shine, glitter | big band |
| WATERCOLOR | soft washes | blurred edges, washes | ambient piano |

Full definition (exact colors, materials, postfx, transition) is in
`docs/design/art-bible.md` and `src/styles/packs/*.tres`.

---

## 10. IMPACT FRAMES AND AUDIO

### 10.1 Impact frames (juice)

Rule: **every player action and every micro-game event emits an impact**.
Scale by `ImpactWeight` (LIGHT / MEDIUM / HEAVY / CRITICAL), resolved to an
`ImpactFrame.tres` preset:

| Event | Weight | Hitstop | Shake | FOV | Flash | Audio |
|---|---|---|---|---|---|---|
| pick up power-up | HEAVY | 90ms | 0.35 | -8° | white 0.3 | sub drop + click |
| micro-game hit | MEDIUM | 60ms | 0.25 | -5° | style color | pop + tone |
| combo rises | LIGHT | 40ms | 0.15 | -3° | - | short arpeggio |
| fail/damage | HEAVY | 80ms | 0.4 | +4° | red 0.25 | thud + fail line |
| roulette result | CRITICAL | 120ms | 0.5 | -10° | white 0.4 | impact + stinger |
| match end | CRITICAL | 150ms | 0.6 | -12° | style flash | fanfare |

In addition to global hitstop, support **model freeze** (the player model
freezes while the world goes on — "frozen frame" feel) and **chromatic
pulse** on CRITICAL impacts. Presets in `src/juice/impact_frame*.tres`.

### 10.2 Dynamic music

Design by **musical states** + **vertical layers**:

- States: `CALM` (base freeroam), `TENSION` (roulette / low time),
  `PEAK` (active micro-game), `TRIUMPH` (results), `FAIL` (serious failure).
- Each state has a base loop; the **intensity** controls how many layers
  (stems) sound: `drums` always, `bass` from intensity 0.3, `lead` from
  0.6, `harmony+fx` from 0.85.
- Implementation: `AudioStreamInteractive` (4.3+) with **beat-quantized**
  transitions (2 bars). Fallback: `AudioStreamPolyphonic` with
  manual crossfade at the next bar boundary (beat marker).
- Locked tempo (e.g. 128 BPM) so the whole game "breathes" the same.
- Sidechain/ducking: VO and impacts dip the music momentarily (bus duck).

**Audio buses:**

```
Master (Limiter)
├── Music      (Compressor, EQ, duck)
├── SFX        (Limiter)
│   ├── Player (pitch random ±5%)
│   ├── World
│   ├── UI
│   └── Impact (lowpass in hitstop, high duck)
├── Ambience   (Reverb send)
├── VO         (Compressor, high duck)   # arcade announcer
└── UI         (clean, no reverb)
```

**SFX rules:** layered (transient/body/tail), 3-5 variations per event,
voice-limit per group, priority + interruption to avoid saturation. Announcer
(VO) with arcade callouts per event (§2), with random variation and cooldown.

---

## 11. 3D ART PIPELINE (Blender → Godot)

**Hard conventions:**
- Scale **1 Blender unit = 1 meter** in Godot; model origin at the base
  (Godot-friendly, Y-up).
- Naming: `sm_*` (static mesh), `sk_*` (skinned), `col_*` (collision),
  `nav_*` (navmesh), `prop_*`, `bld_*` (building).
- Apply transforms (scale/rotation) before exporting.
- One `.blend` per logical asset (or per family in `lib/`); individual exports
  via the `tools/blender/export_glb.py` script → `assets/art/models/<cat>/`.
- Format: glTF 2.0 `.glb`; Godot re-imports; **never edit the .glb**.
- Bake AO to vertex colors; atlas per building to minimize materials.
- LODs for buildings; stylized low-poly prioritizes a legible silhouette.
- Budgets: building < 2k tris, prop < 300 tris, character < 8k tris.

**Modular urban block:** sidewalk/street tiles compose the block; building and
prop variants are instanced; the spawn points and navmesh are defined in the
scene. The greyblock (Phase 1) uses primitives; the final art (Phase 7)
replaces them.

**Character:** stylized ~6k tri model, simple rig, animations
(idle, run, sprint, jump, land, turn, pick_up, celebrate, hurt, dance).
Additive compensation animation (lean, squash/stretch) for juice.

**Thematic props (AI/life):** tokens, GPUs, floating speech bubbles,
notifications, packages, umbrellas, cans, boxes — designed to read in
<1s (silhouette + color). The legibility of the joke depends on the silhouette.

---

## 12. RENDER AND POST-PROCESSING

`project.godot` recommended:
- `forward_plus` renderer, 2D/3D HDR enabled, `ACES` (or AgX) tonemap,
  HDR glow with a soft `blend_mode=softlight`, discreet `bloom` (arcade
  style, not blurry).
- MSAA 2x/4x (or TAA if ghosting is controlled); per-style antialiasing.
- Light volumetric fog for block atmosphere; soft SSAO/SSIL.
- DOF only in dramatic moments (roulette), not permanent.
- Resolution scaling for low-end; configurable render scale.
- Global style shaders: `u_style_*` uniforms read by the world's base shader
  (§9). Reusable shaders in `assets/shaders/`.
- Per-style PostFX in `StylePostFX.tres`: extra bloom, chromatic, scanlines,
  vignette, saturation, desaturation during hitstop.

---

## 13. UI / HUD / UX — INTERFACE DESIGN

> Guiding principle: **the UI is data-driven just like the gameplay**. The HUD
> auto-builds from `HUDRecipe` + `MinigameMetadata`. Zero widgets
> hardcoded per micro-game. A new micro-game shows its objective without
> anyone touching the UI.

### 13.1 Auto-generated widget system

The HUD has a **fixed library of generic widgets**. Each one is a
parametrizable `.tscn`; the `HUDRecipe` chooses which to show and with what data:

| Widget | Shows | Triggered by (HUDRecipe) | Visual feedback |
|---|---|---|---|
| COUNTER | "7 / 12" + icon | COLLECT_N, TAP_N | pop + scale on rise |
| TIMER | countdown / accumulated | SURVIVE_T, HOLD_ZONE_T | red pulse < 5s |
| PROGRESS | bar with valid zone | STOP_IN_ZONE, RHYTHM | sweeping marker |
| SEQUENCE | steps in order | GATES, MEMORY, CHAIN | tick on hit, shake on fail |
| MULTIPLIER | "x3.5" | active combo | scale + noise on rise |

**Rule:** if a micro-game's objective cannot be expressed with these 5
widgets, add ONE new generic widget (not an ad-hoc one). The widgets
read their configuration from the slot, so a new micro-game "just works".

**Layout (safe area, 16:9 and ultrawide):**
- Top-left corner: **match TIMER** (always, the most prominent).
- Top-right corner: **SCORE** + **MULTIPLIER** (animated counter).
- Top-center: **micro-game objective** (COUNTER/TIMER/PROGRESS/SEQUENCE)
  + brief flavor text during startup (~2s).
- Screen edge: **power-up compass** (off-screen arrows).
- Center: **subtitled VO callouts** (accessibility).
- Never hide the HUD during micro-games: the information is the mechanic.

### 13.2 Visual aesthetic (UI art direction)

- **Nintendo arcade style:** rounded shapes, thick outlines (equivalent
  2-3px outline), high-legibility saturated colors, bold type with a
  soft shadow. Readable at a glance (<1s).
- **Hierarchy by size and motion:** what the player must look at NOW
  (timer, objective) is big and animated; the secondary (score) is stable.
- **Feedback on every change:** every number that changes pops (scale +
  color), every achievement makes noise (juice + audio). The UI is alive, not a panel.
- **Theming by style pack:** the `hud_theme` of the StylePack recolors the UI
  with the world (NEON_DRIFT → cyan/magenta HUD; INK_NOIR → monochrome). The UI
  mutates with the stage, reinforcing the transformation.
- **Roulette:** its own screen with a dramatic camera, the micro-game's
  name + objective + flavor before startup. It is the game's "announcement"
  moment.
- **Results:** big final rank (D→S+), score breakdown, local record,
  "Play Again". Celebratory by rank (fireworks at S+, awkward silence
  at D — humor lives here too).

### 13.3 Accessibility

- Full control remapping (keyboard / mouse / gamepad).
- Adjustable shake intensity and an option to disable flashes.
- Colorblind indicators for objectives/dangers (shape + color, not color alone).
- Subtitles/visual callouts in addition to voice (VO always legible without sound).
- Configurable text speed and HUD legibility.

### 13.4 Controls

- Gamepad first (Xbox/PS/Switch Pro), keyboard/mouse supported.
- Device detection and correct glyphs in the UI.
- All micro-games playable with any of the three (the metadata's `input_mode`
  defines the mode; see §13.1).

---

## 14. PHASED ROADMAP

| Phase | Deliverable | Exit gate |
|---|---|---|
| 0. Foundation | repo, project.godot, autoloads, contracts, audio buses | headless boot with no errors; contract tests pass |
| 1. Greybox | playable block, movement engine, camera, HUD, 5min timer | play 5 full minutes with smooth movement |
| 2. Core juice | impact frames, shake, FOV punch, postfx, flashes | presets apply with no pop; 60fps |
| 3. Core audio | buses, SFX pool, dynamic music, VoiceDirector | audible beat-synced transitions; no clipping; VO is intelligible |
| 4. Power-ups + roulette | spawner, pickup, wheel, selection | full power-up → micro-game loop |
| 4.5 Slots + data-driven render | SpawnRecipe/ObjectiveRecipe/HUDRecipe + 1 complete archetype | a new micro-game is ONLY a `.tres` (verified) |
| 5. Micro-games | 1 per archetype → all 36 | each playable end to end + contract test + humor reviewed; each is a `.tres` with no new code |
| 6. Style packs | 12 packs, swap/blend | reversible transformation with no artifacts |
| 7. Final art | Blender modeling, textures, environment | replaces the greyblock without breaking gameplay |
| 8. Polish | balance, accessibility, leaderboard, export | DoD gates approved |

---

## 15. DEFINITION OF DONE (quality gates)

Every gameplay deliverable must pass:

- [ ] Contract respected (setup/start/update/input/teardown).
- [ ] Determinism with a fixed seed (GUT test).
- [ ] Playable with keyboard, mouse and gamepad.
- [ ] At least 3 impact spikes (juice + audio).
- [ ] Clear, HUD-legible victory/failure condition.
- [ ] `flavor_text` + `fail_lines` written and reviewed (humor = mechanic).
- [ ] **Abstraction:** the micro-game is a `.tres` with no new gameplay
      code (if it had to write code, the archetype/slot was extended and that
      was documented). See §8.0.
- [ ] **Auto-generated UI:** the objective HUD comes from `HUDRecipe`, with
      no ad-hoc widgets. See §13.1.
- [ ] No orphan entities or dirty global state after teardown.
- [ ] Budgets: < 400 draw calls, < 250k tris/frame, < 32 simultaneous SFX
      voices, textures < 512MB (adjustable; verify in the profiler).
- [ ] No import or runtime warnings in the console.
- [ ] Steady 60fps on target hardware (verified in the monitor).
- [ ] Balanceable by data (.tres), with no hardcoded numbers.
- [ ] Documented (entry in docs/ + contract comment).

---

## 16. CONVENTIONS AND ANTI-PATTERNS

**Code:** typed GDScript, tabs, `snake_case` vars/funcs, `PascalCase`
classes/Resources, `SCREAMING_SNAKE` constants. English identifiers.

**Game content (English):** names, HUD, objectives, flavor text,
fail messages, VO — all in English. Tone guide in §2.

**Team docs (English):** this scaffold, AGENTS.md, the GDD and internal docs
are kept in English for the development team.

**Forbidden:**
- Hardcoding balance values in code (they go to `.tres`).
- **`if minigame_id == "..."` (or any switch by ID) in gameplay.** That
  switch is the sign that the abstraction failed; the variation goes in slots.
- New autoloads without updating this scaffold and AGENTS.md.
- Coupling a micro-game to another system directly (use the injected context).
- Using signals for frame-a-frame gameplay where order matters.
- Hand-editing exported assets (.glb, mixed .wav).
- Leaving the project in a state that does not compile/import.
- Breaking a contract without updating `docs/architecture/contracts.md` and tests.
- A micro-game without `flavor_text`/`fail_lines` (humor is part of the DoD).
- Ad-hoc HUD widgets per micro-game (use the widget library, §13.1).
- Humor that violates the sensitivity of §1 (strong profanity, graphic violence,
  bullying groups).

**Micro-game implementation decision tree:**
1. Does an archetype cover the mechanic? → configure its `.tres` (slots).
2. Is the mechanic new? → create an archetype in `archetypes/` + test + doc
   (a reusable generic engine, NOT a micro-game script).
3. Does a slot not express the variation? → extend THAT slot, not the micro-game.
4. Does it need new assets? → Blender (§11) → glb → import → scene.
5. Does look/music change? → define/extend a StylePack (§9).

---

## 17. QUICK MICRO-GAME TEMPLATE

**Normal case (mechanic covered by an archetype) — ZERO code:**

```
src/minigames/catalog/mi_microjuego.tres
├── id = "mi_microjuego", archetype = "COLLECT_RUSH"
├── spawn_recipe:      entity_scene = token.tscn, count = 12, pattern = SCATTER
├── objective_recipe:  kind = COLLECT_N, target = 12
├── hud_recipe:        primary_widget = COUNTER, icon = token_icon.png
├── objective_text = "Grab tokens before it forgets!"
├── flavor_text  = "It has the memory of a goldfish. A GPU goldfish."
├── fail_lines   = ["Out of context.", "The bot forgot you existed."]
└── style_pack_id = "NEON_DRIFT", music_state = "PEAK", input_mode = RUN
```

That's it. The `MinigameRegistry` registers it, the archetype runs it, the HUD
auto-generates. **Cost: one file, zero lines of code.**

**Exceptional case (new mechanic) — the engine is extended, not the
micro-game:** create ONE generic archetype in `archetypes/` (reusable by
future micro-games) + its slots test + doc. Never a `token_rush.gd` script
with logic specific to that micro-game. The normal case only adds an entry to
`docs/design/minigames.md` (the `.tres` self-documents with comments).
