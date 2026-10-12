# Architecture Contracts

This file is the **canonical reference for the stable contracts** of the game, as
implemented in the source tree today. `scaffold.md` §7 is the design brief; this
document describes what the code actually does, with the exact signatures read
from the sources.

## What a contract is here

A contract is a **stable interface** between two parts of the game: a class, a
`Resource` or an autoload that other systems depend on by name and shape rather
than by implementation. AGENTS.md §1.2 lists them explicitly:

> `Minigame`, `MinigameContext`, `MinigameMetadata`, `MinigameResult`,
> `StylePack`, `StylePostFX`, `ImpactFrame` are **stable**. Changing them
> requires updating doc + tests + scaffold, and saying so in the commit.

The other contracts in this document (the service registry, the event bus, the
directors and the micro-game runtime) are stable in the same sense: they are the
surfaces every other file builds on.

Two isolation rules govern all of them, and every contract below respects them:

- **A micro-game never references `MatchManager`, `ScoreDirector`,
  `StyleDirector` or any other system directly.** It uses the injected
  `MinigameContext` (`src/minigames/minigame_context.gd`) and checks for `null`
  before use, because every field is nullable (AGENTS.md §1.1).
- **No autoload references another autoload directly.** Systems resolve each
  other through `GameServices.lookup(&"name")` or communicate through
  `EventBus` (AGENTS.md §1.1).

Where a contract degrades rather than fails, that is a deliberate guarantee: a
missing service resolves to `null` and the caller must degrade silently, so a
headless test run and a boot with a missing asset behave the same way as a
complete game.

---

## GameServices (service registry)

**Purpose** — the service locator that lets every autoload resolve every other
autoload by a canonical `StringName` instead of by path, which is what AGENTS.md
§1.1 requires. It is the mechanism behind "no autoload references another
autoload directly".

**Source:** `src/core/game_services.gd`

### Signatures (read from source)

```gdscript
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

func publish(autoload_name: String, service_name: StringName, instance: Object) -> void
func register(service_name: StringName, instance: Object) -> void
func resolve(service_name: StringName) -> Object
func unregister(service_name: StringName) -> void
func has_service(service_name: StringName) -> bool
static func lookup(service_name: StringName) -> Object
```

The API is `resolve`/`has_service` rather than `get`/`has` because `get` and
`has` would collide with native `Object`/`Node` methods in GDScript
(`src/core/game_services.gd:8-9`).

### Guarantees

- **`publish()` only accepts the live autoload singleton** (`:48-56`). It
  compares the instance against `get_tree().root.get_node_or_null("/root/" +
  autoload_name)` and refuses anything else. This is what stops a test double
  built with `load(SCRIPT).new()` — which runs the same `_ready()` — from
  clobbering the real service and then leaving a dangling key when it is freed.
- **`resolve()` never hands back a freed reference** (`:72-79`). A registration
  whose instance is no longer valid is dropped from the map on read and `null`
  is returned. The stored value is held as `Variant` because assigning a freed
  `Object` to a typed variable already errors in Godot 4.
- **An unknown service resolves to `null`, never raises** (`:72-73`). A typo
  degrades instead of crashing mid-match.
- **`register()` refuses `null`** (`:60-64`) with a `push_warning`, so the map
  can never contain a key that lies.
- **Later registrations win** (`:59`), which is what lets tests substitute a
  stub under a canonical name and restore the previous one afterwards.
- `GameServices` self-registers under `&"core"` in its own `_ready()` (`:35`),
  so the `lookup(&"core")` → `register(...)` pattern works for non-autoload
  services such as the registry, the config and the player.
- `static func lookup()` works with no node reference at all (`:94-101`): it
  walks `Engine.get_main_loop()` to `/root/GameServices` and degrades to `null`
  when absent.

### Publisher and consumer

Published by itself (`src/core/game_services.gd:35`). Consumed by essentially
every system: `MatchManager`, `ScoreDirector`, `StyleDirector`, `ImpactDirector`,
`CameraDirector`, `MusicDirector`, `SFXPlayer`, `VoiceDirector`, `SaveSystem`,
`SettingsManager`, `MinigameDirector`, `RouletteController`, `Player` and the
power-up systems.

### Test coverage

- `tests/unit/test_service_registry.gd` — `test_every_catalogued_autoload_resolves_by_canonical_name`
  (`:37`) pins the full autoload → canonical-name table;
  `test_impact_director_resolves_camera_not_null` (`:51`) and
  `test_impact_director_resolves_sfx_not_null` (`:62`) pin the exact lookups the
  impact path performs; `test_no_key_aliases_two_different_systems` (`:71`);
  `test_lookup_degrades_gracefully_for_unknown_service` (`:92`);
  `test_register_unregister_round_trip` (`:100`);
  `test_freed_instance_is_never_handed_back` (`:110`);
  `test_register_refuses_null` (`:124`).
- `tests/unit/test_core.gd:34,46` — basic register/resolve and null rejection.
- `tests/integration/test_stress_match.gd:937` —
  `test_service_registry_names_are_symmetric` scans `src/` and asserts that
  every registered name has a consumer and every consumed name has a publisher,
  which is the guard against a dead or dangling registration.

---

## EventBus (global signal bus)

**Purpose** — typed signals with canonical `StringName` event ids, so systems
emit and listen without holding references to each other. Scaffold §6.1 and the
header comment (`src/core/event_bus.gd:2-17`) restrict it to **event
decoupling**: never frame-by-frame gameplay where execution order matters, which
is a direct call.

**Source:** `src/core/event_bus.gd`

### Signatures (read from source)

```gdscript
signal powerup_collected(minigame_id: StringName)
signal roulette_started()
signal roulette_result(id: StringName)
signal minigame_started(id: StringName)
signal minigame_announced(meta: Resource)
signal minigame_finished(result: MinigameResult)
signal style_applied(pack_id: StringName)
signal style_reverted()
signal score_changed(total: int, delta: int)
signal combo_changed(combo: int)
signal impact_requested(weight: int)
signal match_time_up()
signal match_started()
signal match_reset()
signal match_tick(time_left: float)
signal player_state_changed(state: StringName)
signal voice_requested(event_id: StringName)

static func signal_name_for(event: StringName) -> String
func emit_event(event: StringName, arg0: Variant = null, arg1: Variant = null) -> void
static func emit(event: StringName, arg0: Variant = null, arg1: Variant = null) -> void
```

### Signals and their payloads

| Signal | Payload | Emitted by |
| --- | --- | --- |
| `powerup_collected` | `minigame_id: StringName` | `PowerUpDirector` |
| `roulette_started` | — | `RouletteController` (`roulette_controller.gd:78`) and `MatchManager.request_roulette()` (`match_manager.gd:153`) |
| `roulette_result` | `id: StringName` — the chosen micro-game id | `RouletteController._finish_spin()` (`roulette_controller.gd:99`) |
| `minigame_started` | `id: StringName` | `MinigameDirector.play()` (`minigame_director.gd:204`) |
| `minigame_announced` | `meta: Resource` (a `MinigameMetadata`) — the full-screen announcement beat carrying name, objective and flavour text | `MinigameDirector._announce()` (`minigame_director.gd:215`) |
| `minigame_finished` | `result: MinigameResult` | `MinigameDirector._on_minigame_finished()` (`minigame_director.gd:401`) |
| `style_applied` | `pack_id: StringName` | `StyleDirector.apply_pack()` (`style_director.gd:75`) |
| `style_reverted` | — | `StyleDirector.revert_to_base()` (`style_director.gd:92`) |
| `score_changed` | `total: int, delta: int` | `ScoreDirector.add_points()` (`score_director.gd:79`) |
| `combo_changed` | `combo: int` | `ScoreDirector` (`score_director.gd:57,65`) |
| `impact_requested` | `weight: int` | Declared and consumed by `AudioDirector._on_impact_requested` (`audio_director.gd:475`); **no emitter in gameplay** — see the note in `ImpactDirector` below |
| `match_time_up` | — | `MatchManager.advance()` (`match_manager.gd:112`) |
| `match_started` | — | `MatchManager.start_match()` (`match_manager.gd:137`) |
| `match_reset` | — | `MatchManager.end_match()` (`match_manager.gd:216`) |
| `match_tick` | `time_left: float`, once per whole second | `MatchManager._announce_tick()` (`match_manager.gd:146`) |
| `player_state_changed` | `state: StringName` — `idle` / `run` / `air` / `hurt` | `Player._physics_process()` (`player.gd:48`) |
| `voice_requested` | `event_id: StringName` | Declared and mapped (`event_bus.gd:37,60`); consumed by `AudioDirector` (`audio_director.gd:368`) |

### Guarantees

- **`signal_name_for()` is the canonical event-id → signal-name map**
  (`:43-61`). Emit helpers route through it so callers pass `StringName` ids
  instead of holding a reference to the bus node.
- **`emit()` and `emit_event()` degrade silently** when the bus is absent
  (`:79-98`), so early boot and tests can emit with no bus in the tree.
- **An unknown event id is a loud `push_warning`, not a crash** (`:91`), so a
  typo in an event id is caught rather than swallowed.
- Both emit helpers support the zero-, one- and two-argument shapes the
  canonical list uses, dispatching on whether `arg0`/`arg1` are `null`
  (`:93-98`).
- `match_tick` fires at **1 Hz, never per frame**: `_announce_tick()` only emits
  when the whole-second value changes (`match_manager.gd:142-147`).

### Publisher and consumer

Published by the autoload itself. Consumers include `VoiceDirector`, which
subscribes to seven match events in `connect_match_events()`
(`voice_director.gd:90-105`); `MatchManager`, which listens for `roulette_result`
(`match_manager.gd:56-64`); `MinigameDirector`, which listens for
`match_time_up` (`minigame_director.gd:54-62`); `PostFXDirector`, `AudioDirector`
and the HUD.

### Test coverage

- `tests/unit/test_core.gd:6` — `test_event_bus_has_canonical_signals` asserts
  the full canonical signal list exists.
- `tests/unit/test_core.gd:20` — `test_event_bus_signal_delivery` proves a
  signal actually reaches a subscriber.
- `tests/unit/test_voice_wiring.gd:32-88` — the match-event → VO mapping, the
  combo milestone, the time warning, the fail/flawless pick and that
  `disconnect_match_events()` drops every subscription.
- `tests/unit/test_scoring_and_roulette.gd:86` — the roulette result is
  delivered to `MatchManager` through the bus and drives the state machine.

---

## Minigame (base contract)

**Purpose** — the base contract of every micro-game. Archetypes extend it, `.tres`
definitions configure it, and the rules in AGENTS.md §1.2 hang off it.

**Source:** `src/minigames/minigame.gd`

### Signatures (read from source)

```gdscript
class_name Minigame
extends Node

signal finished(result: MinigameResult)
signal progress_changed(normalized: float)
signal event(kind: StringName, payload: Dictionary)

func setup(ctx: MinigameContext) -> void
func start() -> void
func is_running() -> bool
func update(delta: float) -> void
func on_input(input_event: InputEvent) -> void
func teardown() -> void
func get_metadata() -> MinigameMetadata
func get_context() -> MinigameContext
func finish_with(result: MinigameResult) -> void
```

The input hook is named `on_input(input_event)` rather than `on_input(event)`
so it does not shadow the contract's own `event` signal (`minigame.gd:63`).

### Guarantees

- **A micro-game ends ONLY via `finished(result)` or a director abort** — the
  single valid exit. `finish_with(result)` is the helper archetypes call
  (`:88-89`).
- **The lifecycle order is `setup → start → update → on_input → teardown`**, and
  `_process`/`_physics_process` must not be used unless the archetype documents
  it (`:12-14`). The director drives `update()`/`on_input()`.
- **`_running` is owned by the contract base** (`:29`) so every archetype reads
  one flag rather than each keeping its own.
- **`setup()` stores the injected context and reads metadata from it**
  (`:39-43`); it deliberately does not warn, because `MinigameArchetype`
  overrides `setup()` and calls `super.setup()`, so this runs on every single
  micro-game of a match (`:35-38`).
- `progress_changed` carries a normalised `0..1` value for the auto-generated
  HUD (§13.1); `event(kind, payload)` is the juice/audio/VO hook, with `kind`
  values such as `"start"`, `"hit"`, `"miss"`, `"milestone"`, `"success"`,
  `"fail"`.
- **The context is the only route to other systems.** The header states it
  explicitly: a micro-game never references `MatchManager`, `ScoreDirector` or
  others directly (`:6-7`).

### Publisher and consumer

Published as a base class by the archetypes in `src/minigames/archetypes/`
(14 of them) via `MinigameArchetype`. Consumed by `MinigameDirector`
(`src/minigames/minigame_director.gd`), which calls `setup()`, `start()`,
`update()`, `on_input()`, `teardown()` and connects `finished`; and by the
integration tests.

### Test coverage

- `tests/unit/test_archetype_state_readers.gd` — archetypes instantiate through
  the registry and expose their progress readers (`:19-38`).
- `tests/integration/test_full_match.gd:511` —
  `test_minigame_results_feed_the_score_pipeline` asserts the context carries a
  live `ScoreDirector`, emits `finished` and checks the payout.
- `tests/integration/test_stress_match.gd:483` —
  `test_every_catalog_minigame_teardown_leaves_the_tree_clean`, the §1.4
  cleanliness gate for every catalog entry.
- `tests/integration/test_stress_match.gd:558` — no dangling timer, tween or
  subscription after teardown.

---

## MinigameArchetype (archetype lifecycle)

**Purpose** — the shared base for the 14 archetypes. It centralises the
repeated machinery (duration timer, progress, juice events, recipe-driven
spawns, orphan cleanup) so each archetype only declares its mechanic by reading
its slots. No archetype branches on `minigame_id`; the variation lives in the
data (AGENTS.md §1.8).

**Source:** `src/minigames/runtime/minigame_archetype.gd`

### Signatures (read from source)

```gdscript
const PATTERN_SCATTER := &"SCATTER"
const PATTERN_RING := &"RING"
const PATTERN_GRID := &"GRID"
const PATTERN_LINE := &"LINE"
const PATTERN_WAVE := &"WAVE"
const MOTION_STATIC := &"STATIC"
const MOTION_ORBIT := &"ORBIT"
const MOTION_FLEE := &"FLEE"
const MOTION_CHASE := &"CHASE"
const MOTION_FALL := &"FALL"

func setup(ctx: MinigameContext) -> void
func _slot_value(field: StringName, archetype_default: float) -> float
func start() -> void
func update(delta: float) -> void
func advance(_delta: float) -> void
func on_timeout() -> void
func get_elapsed() -> float
func get_time_left() -> float
func is_running() -> bool
func is_finished() -> bool
func bump_combo() -> int
func set_progress(normalized: float) -> void
func emit_event(kind: StringName, payload: Dictionary = {}) -> void
func finish_success(time_bonus_per_s: int = 0) -> void
func finish_fail(reason: StringName) -> void
func spawn_point(index: int, total: int, center: Vector3, radius: float) -> Vector3
func spawn_entity(at: Vector3) -> Node
func clear_spawned() -> void
func teardown() -> void
```

`advance()` and `on_timeout()` are the two hooks a concrete archetype
implements/overrides: `advance()` is the per-frame mechanic step, `on_timeout()`
the default action when `duration_s` runs out (which survival archetypes
override to win instead of fail).

### Guarantees

- **A micro-game never outlives its match** (`:41-46`). `setup()` clamps
  `_duration` to `min(duration_s, ctx.time_left_in_match)` whenever
  `time_left_in_match > 0`, so a 25 s micro-game launched with 8 s left does not
  run past the clock.
- **The duration clock is driven by `update()`, not `_process`** (`:76-82`):
  `update()` accumulates `_elapsed`, calls `advance(delta)`, then calls
  `on_timeout()` when the budget is spent. A finished micro-game ignores further
  frames.
- **`finish_success()` / `finish_fail()` are idempotent** (`:134-153`): a second
  call after `_finished` is set returns without emitting again, so a late frame
  cannot double-pay or double-report.
- `finish_success()` computes the time bonus as
  `round(get_time_left() * time_bonus_per_s)` and takes `base_score` from the
  metadata; `finish_fail(reason)` reports base `0` and the `fail_reason`.
- **`spawn_point()` is deterministic** (`:159-200`): `RING`, `GRID` and `LINE`
  are pure geometry, and only `SCATTER` draws randomness, from `ctx.rng` when
  present (falling back to the engine RNG when it is not).
- **`spawn_entity()` returns `null` rather than raising** when there is no
  context, no world root, no recipe or no entity scene (`:205-211`).
- **Slot data decides the look** (`:218, :228-236`): `_configure_entity()` pushes
  `entity_tint`, `entity_size`, `entity_shape` and `lifetime_s` onto the spawned
  node, each guarded by `_set_export()` so a scene that does not expose a field
  is left alone rather than raising (`:254-256`).
- **`_slot_value()` is the §1.3 tuning bridge** (`:52-66`): a `.tres` field of
  `-1` or an absent slot means "use the archetype default", so an unconfigured
  `.tres` behaves exactly as before and a filled one retunes with no code change.
- **`clear_spawned()` is idempotent** (`:260-267`): it removes and frees every
  node the micro-game created, and `teardown()` calls it plus clears `_running`
  and `_finished` (`:270-273`).

### Publisher and consumer

Published as a base class; extended by all 14 archetypes in
`src/minigames/archetypes/`. Consumed by `MinigameDirector` through the
`Minigame` contract, and by the tests that instantiate archetypes through the
registry.

### Test coverage

- `tests/unit/test_archetype_state_readers.gd` — `COLLECT_RUSH`, `ZONE_HOLD` and
  `PUSH_ZONE` instantiate and expose their progress state (`:19-38`).
- `tests/unit/test_archetype_chase_motion.gd` — the `CHASE` motion contract.
- `tests/unit/test_catalog_winnability.gd:46-116` — every duration is inside the
  brief window, every target fits inside its duration, `CHASE` motion does not
  invert the objective, and rhythm speed is a real BPM.
- `tests/integration/test_stress_match.gd:483,558` — teardown cleanliness for
  every catalog entry.
- `tests/unit/test_match_loop.gd:134` —
  `test_minigame_never_runs_past_match_time` pins the duration clamp.

---

## MinigameContext (dependency injection)

**Purpose** — the single injected object that gives a micro-game access to every
system it might need, without referencing any autoload. This is the mechanism
that satisfies AGENTS.md §1.1 for micro-games.

**Source:** `src/minigames/minigame_context.gd`

### Fields and signatures (read from source)

```gdscript
class_name MinigameContext
extends RefCounted

var match_manager: Object = null   # MatchManager — time left, state
var score: Object = null           # ScoreDirector — add score
var style: Object = null           # StyleDirector — apply style packs
var impact: Object = null          # ImpactDirector — per-impact juice
var camera: Object = null          # CameraDirector — shake/FOV
var postfx: Object = null          # PostFXDirector — fullscreen effects
var audio: Object = null           # AudioDirector — buses/ducking
var music: Object = null           # MusicDirector — music states
var voice: Object = null           # VoiceDirector — arcade announcer
var player: Node3D = null          # the player (CharacterBody3D)
var world_root: Node3D = null      # parent for spawning entities
var arena_center: Vector3 = Vector3.ZERO
var metadata: MinigameMetadata = null
var rng: Object = null             # deterministic SeededRNG per micro-game
var difficulty: float = 0.0        # 0..1, rises as remaining time gets low
var time_left_in_match: float = 0.0  # the micro-game must never exceed this

static func create(
	p_rng: Object = null,
	p_world_root: Node3D = null,
	p_arena_center: Vector3 = Vector3.ZERO,
	p_player: Node3D = null,
	p_difficulty: float = 0.0,
	p_time_left_in_match: float = 0.0
) -> MinigameContext
func clear() -> void
```

The system fields are typed `Object`, not their concrete classes, so the
injection stays duck-typed and a missing system is a `null` field rather than a
type error. Scaffold §7.2 shows the idealised typed version; the implementation
deliberately relaxes it for the degradation guarantee.

### Guarantees

- **Every field is nullable** (`:6-8`). The director resolves each system at
  injection time and degrades silently if it does not exist yet; a micro-game
  must check `if ctx.score != null` before use.
- **The metadata travels in the context** (`:26-28`): the director resolves it
  from the registry and injects it, so the archetype does not go looking for it
  itself. `MinigameArchetype.setup()` only falls back to `get_metadata()` when
  `ctx.metadata` is `null` (`minigame_archetype.gd:39`).
- **`create()` builds the minimum useful context for tests** (`:37-52`): rng,
  world root, arena centre, player, difficulty and match time left.
- **`clear()` drops every reference** (`:56-68`) and the director calls it after
  teardown, so no context outlives the micro-game that owned it.
- **`time_left_in_match` is the hard cap** (§7.1). `MinigameArchetype.setup()`
  clamps the duration to it, and `MinigameDirector._build_context()` fills it
  from `MatchManager.time_left()` (`minigame_director.gd:291-295`).

### Publisher and consumer

Built by `MinigameDirector._build_context()`
(`src/minigames/minigame_director.gd:269-296`), which resolves every field
through the service registry. Consumed by every archetype through `setup()` and
`get_context()`, and asserted directly by the integration tests.

### Test coverage

- `tests/integration/test_full_match.gd:511` — asserts `ctx.score` is a live
  `ScoreDirector` on a running micro-game.
- `tests/integration/test_stress_match.gd:1246` —
  `test_missing_dependencies_degrade_silently` proves the nullable contract.
- `tests/unit/test_archetype_state_readers.gd` and the archetype tests build
  contexts through `MinigameContext.create()`.

---

## MinigameMetadata (the recipe)

**Purpose** — the `Resource` at the heart of the data-driven design: a
micro-game *is* a `.tres` of this type. No micro-game-specific fields are added
to it; the variety lives in the slots (AGENTS.md §8.0, §1.8).

**Source:** `src/minigames/minigame_metadata.gd`

### Fields and signatures (read from source)

```gdscript
class_name MinigameMetadata
extends Resource

@export var id: StringName = &""                    # "token_rush"
@export var display_name: String = ""
@export var archetype: StringName = &""             # "COLLECT_RUSH"
@export var duration_s: float = 20.0                # 10..30
@export var base_score: int = 1000
@export var weight: float = 1.0                     # roulette frequency
@export var theme_tag: StringName = &"HYBRID"       # AI | LIFE | HYBRID
@export var objective_text: String = ""
@export var flavor_text: String = ""
@export var fail_lines: PackedStringArray = PackedStringArray()
@export var style_pack_id: StringName = &""         # "" = the world's base style
@export var music_state: StringName = &"PEAK"
@export var input_mode: StringName = &"RUN"         # RUN | BUTTON | STICK | LOOK | TAP
@export var spawn_recipe: SpawnRecipe = null
@export var objective_recipe: ObjectiveRecipe = null
@export var hud_recipe: HUDRecipe = null
@export var difficulty_curve: Curve = null
@export var tags: PackedStringArray = PackedStringArray()

func validate() -> PackedStringArray
```

### Guarantees

- **`validate()` returns the list of problems, empty meaning valid**
  (`:40-58`). It requires a non-empty `id`, a non-empty `archetype`,
  `duration_s > 0`, `base_score >= 0`, `weight >= 0`, `theme_tag` in
  `[AI, LIFE, HYBRID]`, a non-empty `flavor_text` (humour is a mechanic, §15)
  and **at least 2 `fail_lines`**.
- The registry calls `validate()` on every entry and **fails loudly** with
  `push_error` on a problem, rather than silently accepting it
  (`minigame_registry.gd:94-99`).
- `style_pack_id == &""` means "use the world's base style", and the director
  treats it that way (`minigame_director.gd:331`).
- All player-facing text is English, per AGENTS.md §1.9.

### Publisher and consumer

Published as a `Resource`; the 36 entries live in
`src/minigames/catalog/*.tres`. Consumed by `MinigameRegistry` (which indexes
it), `MinigameDirector` (which injects it into the context and reads
`style_pack_id` / `music_state`), `RouletteController` (which reads `weight`
and `theme_tag`), and the HUD (which reads `objective_text`, `flavor_text` and
`hud_recipe` through `MinigameDirector.get_metadata_for()`, `hud.gd:356-359`).

### Test coverage

- `tests/unit/test_catalog.gd:93` — `test_catalog_has_36_entries`.
- `tests/unit/test_catalog.gd:102` — `test_all_entries_load_with_sane_fields`
  (the `validate()` contract across the whole catalog).
- `tests/unit/test_catalog.gd:134` — `test_player_text_is_english_and_funny`.
- `tests/unit/test_catalog.gd:151` — `test_no_duplicate_ids`.
- `tests/unit/test_catalog.gd:180` — `test_theme_balance_matches_scaffold_8_2`.
- `tests/unit/test_catalog.gd:197` — `test_every_archetype_represented`.
- `tests/unit/test_catalog_winnability.gd` — duration, target and motion sanity
  per entry.

---

## SpawnRecipe, ObjectiveRecipe, HUDRecipe (the composition slots)

**Purpose** — the three slots that make a micro-game composition instead of
code. `SpawnRecipe` says WHAT appears and how it behaves, `ObjectiveRecipe` says
WHAT must be done, `HUDRecipe` says HOW the objective is communicated. A new
micro-game whose mechanic is already covered is one `.tres` and zero code
(AGENTS.md §1.8).

**Sources:** `src/minigames/slots/spawn_recipe.gd`,
`src/minigames/slots/objective_recipe.gd`,
`src/minigames/slots/hud_recipe.gd`

### Fields and signatures (read from source)

```gdscript
class_name SpawnRecipe
extends Resource
@export var entity_scene: PackedScene = null
@export var count: int = 12
@export var count_scales_with_difficulty: bool = true
@export var spawn_radius: float = 18.0
@export var spawn_pattern: StringName = &"SCATTER"  # SCATTER | RING | GRID | LINE | WAVE
@export var motion: StringName = &"STATIC"          # STATIC | ORBIT | FLEE | CHASE | FALL
@export var speed: float = 4.0
@export var lifetime_s: float = -1.0                # -1 = until collected/hit
@export var respawn: bool = false
@export var pool_group: StringName = &"mg_entity"
@export var entity_size: float = 0.6
@export var entity_tint: Color = Color(0.35, 0.85, 1.0)
@export var entity_shape: StringName = &"SPHERE"    # SPHERE | BOX | DIAMOND | RING
func resolve_count(difficulty: float) -> int

class_name ObjectiveRecipe
extends Resource
@export var kind: StringName = &"COLLECT_N"   # COLLECT_N | SURVIVE_T | TAP_N | HOLD_ZONE_T
                                              # GATES_IN_ORDER | CHAIN_N | STOP_IN_ZONE | ...
@export var target: int = 12
@export var tolerance: float = 0.0
@export var fail_on: StringName = &"TIMEOUT"  # TIMEOUT | TOUCH_HAZARD | WRONG_INPUT | NONE
@export var time_bonus_per_s: int = 100
@export var combo_step: float = 0.25
@export var reach_m: float = -1.0            # -1 = the archetype default
@export var charge_rate: float = -1.0
@export var sweep_speed: float = -1.0
@export var path_width: float = -1.0

class_name HUDRecipe
extends Resource
@export var primary_widget: StringName = &"COUNTER"  # COUNTER | TIMER | PROGRESS | SEQUENCE | METER
@export var icon: Texture2D = null
@export var color_hint: StringName = &""
@export var show_flavor: bool = true
@export var callout_on_start: StringName = &"GO GO GO!"
```

### Guarantees

- **`resolve_count(difficulty)` scales the count up to +50 %** at difficulty 1
  when `count_scales_with_difficulty` is set, and never returns less than 1
  (`spawn_recipe.gd:29-33`).
- **A tuning field of `-1` means "use the archetype default"**
  (`objective_recipe.gd:13-20`), read through `_slot_value()`. An unconfigured
  `.tres` therefore behaves exactly as before the field existed.
- `pool_group` defaults to `&"mg_entity"` — the group the director's orphan
  guard scans, which ties the slot to the §1.4 cleanliness invariant.
- `HUDRecipe.primary_widget` is one of the five fixed widgets (§13.1); an
  unknown value degrades to `COUNTER` rather than failing
  (`widget_factory.gd:22-24`).

### Publisher and consumer

Published as `Resource`s, owned by each `MinigameMetadata` `.tres`. Consumed by
the archetypes (which read `spawn_recipe` and `objective_recipe`) and by
`WidgetFactory` / the HUD (which read `hud_recipe`).

### Test coverage

- `tests/unit/test_ui_widget_factory.gd:8` — `test_every_kind_maps_to_scene`
  covers the fixed widget library; `:26` `test_unknown_kind_degrades_to_counter`
  and `:35` `test_null_recipe_degrades_to_counter` cover the degradation rule.
- `tests/unit/test_ui_hud.gd:17` — `test_set_objective_builds_widget_from_recipe`
  builds the objective from a recipe.
- `tests/unit/test_catalog.gd` and `test_catalog_winnability.gd` validate the
  filled slots across all 36 entries.

---

## MinigameResult

**Purpose** — the payload a micro-game hands back when it ends. It is the
adapter between the archetype's view of success and the director's scoring
rules, so a micro-game never has to know how scoring works.

**Source:** `src/minigames/minigame_result.gd`

### Fields and signatures (read from source)

```gdscript
class_name MinigameResult
extends RefCounted

var success: bool = false
var base_score: int = 0
var time_bonus: int = 0        # proportional to leftover time
var combo_max: int = 0
var total_score: int = 0
var grade: StringName = &"D"   # D C B A S S+
var fail_reason: StringName = &""  # TIMEOUT | WRONG_INPUT | HIT | ...

static func make(
	p_success: bool,
	p_base_score: int,
	p_time_bonus: int,
	p_combo_max: int,
	p_fail_reason: StringName = &""
) -> MinigameResult
static func grade_for(combo_peak: int, did_succeed: bool) -> StringName
func _to_string() -> String
```

### Guarantees

- **`make()` computes the total and fills the grade** (`:16-31`):
  `total_score = base_score + time_bonus`, and `grade` comes from
  `grade_for(combo_max, success)`.
- **`grade_for()` thresholds by combo peak** (`:36-49`): a failure is always
  `D`; otherwise `S+` at ≥20, `S` at ≥15, `A` at ≥10, `B` at ≥6, `C` at ≥3 and
  `D` below. These are the per-micro-game grade thresholds; the *match* rank
  thresholds live in `GameConfig` and are applied by `ScoreDirector`.
- `total_score` deliberately **includes the unscaled time bonus**
  (see `ScoreDirector.add_minigame_result`).

### Publisher and consumer

Published as a `RefCounted` value object. Produced by
`MinigameArchetype.finish_success()` / `finish_fail()` through `finish_with()`,
and by `MinigameDirector.abort()`. Consumed by `ScoreDirector.add_minigame_result()`,
`MatchManager.finish_minigame()`, `VoiceDirector._on_minigame_finished()` and the
results screen.

### Test coverage

- `tests/integration/test_full_match.gd:511` — asserts the payload carries
  `base + time bonus` and the grade from the combo peak (5 → `C`), then that
  the director pays it into the match score.
- `tests/unit/test_scoring_and_roulette.gd:43` —
  `test_minigame_result_adds_score_through_the_director`; `:57` the failed case
  breaks the combo and still counts the base; `:68` the time bonus joins
  unscaled; `:78` a null result is rejected.

---

## MinigameDirector

**Purpose** — orchestrates the micro-game lifecycle: loads the choice from the
registry, injects the context, runs `setup → start`, delegates
`update`/`on_input`, receives the result, runs teardown with an orphan
assertion, and notifies the match. It owns the anti-repetition cooldown.

**Source:** `src/minigames/minigame_director.gd`

### Signatures (read from source)

```gdscript
@export var cooldown_s: float = 3.0

func get_metadata_for(id: StringName) -> MinigameMetadata
func get_active_metadata() -> MinigameMetadata
func is_active() -> bool
func get_cooldown_left() -> float
func reset_runtime() -> void
func update(delta: float) -> void
func on_input(event: InputEvent) -> void
func play(id: StringName, difficulty: float = 0.0) -> bool
func abort(reason: StringName = &"MATCH_TIMEOUT") -> void
func pick_next(rng: Object = null) -> StringName
func get_active() -> Minigame
func get_active_id() -> StringName
func get_history() -> Array
```

### Guarantees

- **`play()` returns `bool` — `true` only when the micro-game is actually
  running** (`:159-207`). It refuses with `false` (and a warning or error) when
  another micro-game is already active (`:160-165`), when the cooldown is still
  running (`:166-168`), when the id is unknown (`:171-173`) or when the
  archetype cannot be instantiated (`:181-188`). This is the contract that lets
  `MatchManager.start_minigame()` recover instead of deadlocking in an empty
  `MINIGAME` state.
- **`play()` is the only place a micro-game is started**, and it orders the
  calls exactly: `add_child(mg)` → `connect(finished)` → `setup(ctx)` →
  `start()` → record history → emit `minigame_started` → apply style and music
  → announce (`:192-207`).
- **`_build_context()` resolves every system through the service registry**
  (`:269-296`), so the director never reaches for a sibling autoload by path
  (§1.1). It falls back to a `/root/<name>` lookup only for a service that never
  self-registers.
- **`_apply_style_and_music()` runs only for a declared pack/state**
  (`:329-336`): an empty `style_pack_id` or `music_state` is a no-op, so the
  world's base look is left alone.
- **`_check_match_timeout()` aborts a running micro-game the moment the match
  clock hits zero** (`:338-343`), and `_on_match_time_up()` does the same from
  the bus (`:65-68`), so a micro-game can never outlive its match.
- **`_on_minigame_finished()` is the single teardown path** (`:346-384`): it
  clears `_active` *first*, runs the orphan verification before and after
  `teardown()`, pays the result into `ScoreDirector`, fires the impact
  (`WEIGHT_CRITICAL` on success, `WEIGHT_HEAVY` on failure), reverts the style,
  tells `MatchManager`, emits `minigame_finished` and arms the cooldown.
- **`abort()` forces a failure result** with `fail_reason` `MATCH_TIMEOUT` by
  default (`:220-224`) — it does not free the node, it goes through the same
  signal path so teardown happens exactly once.
- **`pick_next()` avoids immediate repetition** (`:230-250`): never the same id
  twice in a row, and avoids the same *archetype* twice when an alternative
  exists. Selection is deterministic when an `rng` with `randi_range` is passed.
- **`reset_runtime()` clears the runtime state without touching the registry**
  (`:132-137`), which is what a match restart needs.

### Publisher and consumer

Published as an autoload under `&"minigames"`
(`minigame_director.gd:40`). Consumed by `MatchManager`
(`match_manager.gd:194` — resolved through `GameServices.lookup(&"minigames")`,
with a `/root/MinigameDirector` fallback for a bare test harness), by
`GameLoopDriver` (`game_loop.gd:23-25`), and by the HUD, which calls
`get_metadata_for()` (`hud.gd:356`).

### Test coverage

- `tests/unit/test_scoring_and_roulette.gd:86` — the roulette result reaches the
  director through the bus, and a refused play recovers to `FREE_ROAM` instead
  of deadlocking.
- `tests/integration/test_full_match.gd:379` — the full flow from title to
  results; `:511` the result feeds the score pipeline; `:553` the same seed
  replays the same micro-game sequence.
- `tests/integration/test_stress_match.gd:483` — teardown leaves the tree clean
  for every catalog entry; `:891` the roulette result reaches the director even
  on cooldown; `:829` the orphan guard scans a populated group; `:1200` only one
  registry instance is alive.

---

## MinigameRegistry

**Purpose** — the central `id → {scene, metadata}` registry, published as a
service so the director, the roulette and the HUD all share one instance.

**Source:** `src/minigames/minigame_registry.gd`

### Signatures (read from source)

```gdscript
const SERVICE_NAME := &"registry"
signal registry_loaded(count: int)

func scan() -> void
func get_metadata(id: StringName) -> MinigameMetadata
func get_archetype_scene(archetype: StringName) -> PackedScene
func has_archetype(archetype: StringName) -> bool
func instantiate_archetype(archetype: StringName) -> Node
func get_all_ids() -> Array
func has_id(id: StringName) -> bool
func size() -> int
func ensure_scanned() -> void
```

### Guarantees

- **`scan()` is idempotent** (`:35-44`) and emits `registry_loaded(count)` once
  the catalog is loaded.
- **Every catalog entry is validated and fails loudly** (`:85-110`): an
  unreadable file, an entry that is not a `MinigameMetadata`, a `validate()`
  problem, a duplicate id, or an unknown archetype each `push_error` and skip
  the entry. Nothing is silently accepted.
- **An archetype resolves as a `.tscn` first, then as a compiled `.gd` script**
  (`:132-144`) — same engine, zero scenes. `has_archetype()` covers both.
- **`get_all_ids()` is sorted** (`:148-151`), so iteration and `pick_next()`
  are deterministic.
- **`SERVICE_NAME` is the shared canonical name** (`:16-21`): both the director
  and the roulette resolve `&"registry"` instead of each building a private
  instance, and whichever one builds it registers it so the other gets the same
  node.

### Publisher and consumer

Published as the service `&"registry"` (`minigame_registry.gd:21`) by whichever
system builds it — `MinigameDirector._ensure_registry()`
(`minigame_director.gd:91-96`) or `RouletteController._resolve_registry()`
(`roulette_controller.gd:56-59`). Consumed by `MinigameDirector`
(`get_metadata`, `instantiate_archetype`, `get_all_ids`), `RouletteController`
(`get_all_ids`, `get_metadata`), the HUD (indirectly, through
`MinigameDirector.get_metadata_for()`) and the tests.

### Test coverage

- `tests/unit/test_catalog.gd` — the whole catalog contract: 36 entries, sane
  fields, English copy, no duplicate ids, theme balance, every archetype
  represented.
- `tests/unit/test_archetype_state_readers.gd:12-17` — builds a registry, scans
  it and instantiates archetypes from it.
- `tests/integration/test_stress_match.gd:1200` — only one registry instance is
  alive, which is the guard against the private-instance bug.

---

## MatchManager

**Purpose** — the match state machine and the match clock. It is the source of
truth for remaining time and it is the only system that knows the state
sequence.

**Source:** `src/match/match_manager.gd`

### Signatures (read from source)

```gdscript
enum State { BOOT, TITLE, COUNTDOWN, FREE_ROAM, ROULETTE, MINIGAME, STYLE_POP, TIME_UP, RESULTS }

func current_state() -> State
func time_left() -> float
func clock_running() -> bool
func transition_to(new_state: State) -> void
func advance(delta: float) -> void
func start_match() -> void
func request_roulette() -> void
func start_minigame(minigame_id: StringName) -> bool
func finish_minigame(result: MinigameResult) -> void
func end_match() -> void
```

The states are `BOOT → TITLE → COUNTDOWN → FREE_ROAM → ROULETTE → MINIGAME →
STYLE_POP → FREE_ROAM … → TIME_UP → RESULTS`. There is **no `PAUSED` state**:
pausing is the pause menu setting `get_tree().paused`, not a match state (see
"Contracts found missing or inconsistent" below).

### Guarantees

- **The clock runs continuously except during countdown and results**
  (`clock_running()`, `:90-92`): it ticks in `FREE_ROAM`, `ROULETTE`,
  `MINIGAME` and `STYLE_POP`, and never stops for a micro-game.
- **`start_minigame()` returns `bool` and only commits to `MINIGAME` once the
  director confirms the play** (`:166-187`). If the director refuses, it
  `push_warning`s and recovers to `FREE_ROAM` instead of leaving the match
  sitting in an empty `MINIGAME` state.
- **The roulette result starts the micro-game through the event bus**
  (`_on_roulette_result`, `:62-64`), so the roulette never needs to know the
  state machine exists.
- **The `ROULETTE` state has a deadlock fallback** (`:120-125`): if no
  `roulette_result` arrives within `config.roulette_spin_s`, `advance()` calls
  `start_minigame(_pending_minigame_id)` itself, so the match never stalls.
- **`finish_minigame()` does not re-emit `minigame_finished`** (`:203-206`):
  the director already emitted it, so a second emission would deliver the same
  event twice to every subscriber.
- **`advance()` clamps the clock at zero** and emits `match_time_up` exactly
  once (`:108-113`).
- **`start_match()` resets the clock and the tick watermark** (`:132-137`) so a
  restart is clean.
- Headless-testable by design: transitions are direct calls with an explicit
  delta, with no hard 3D dependency (`:9-10`).

### Publisher and consumer

Published as an autoload under `&"match"` (`match_manager.gd:42`). Consumed by
`MinigameDirector` (as `ctx.match_manager` for `time_left()`, and for
`finish_minigame()`), by `GameLoopDriver` (`game_loop.gd:13-15`), and by the UI
screens.

Note: `MatchManager` also has a `_register_self()` (`:71-76`) that publishes
`&"match"` and registers `&"config"` on the locator, but it is **never called**
by any code — the `&"config"` registration it performs never happens. Both
`_load_config()` in `ScoreDirector` (`score_director.gd:37`) and
`SFXPlayer._refresh_from_config()` (`sfx_player.gd:91`) therefore fall through
to loading `game_config.tres` from disk.

### Test coverage

- `tests/unit/test_match.gd` — title start, countdown then freeroam, the
  roulette cycle, the timer expiring, the frozen countdown, the roulette
  timeout never deadlocking, and the score/combo/rank rules.
- `tests/unit/test_match_loop.gd:48-134` — the config is five minutes, the clock
  advances only in running states, one tick per second, the match ends at time
  up, the roulette → minigame → back round trip, and a minigame never runs past
  match time.
- `tests/unit/test_scoring_and_roulette.gd:86` — the roulette result drives the
  state machine through the bus, including the refusal recovery path.

---

## ScoreDirector

**Purpose** — the scoring language of the arcade: base points, a combo
multiplier, a leftover-time bonus and ranks. It is the adapter between a
`MinigameResult` and the match score.

**Source:** `src/match/score/score_director.gd`

### Signatures (read from source)

```gdscript
func combo_step() -> float
func register_success() -> void
func break_combo() -> void
func current_multiplier() -> float
func add_points(points: int) -> void
func spawn_score_popup(points: int) -> void
func score_minigame(base: int, time_left_s: float) -> int
func add_minigame_result(result: MinigameResult) -> int
func reset() -> void
func current_rank() -> StringName
func rank_for_score(score: int) -> StringName
func advance(delta: float) -> void
```

### Guarantees

- **`add_minigame_result()` is the micro-game scoring adapter** (`:127-139`): a
  success registers the combo (raising the multiplier), a failure breaks it;
  the multiplier applies to `base_score` only, and `time_bonus` joins unscaled
  because it already derives from the archetype's `ObjectiveRecipe`. It returns
  the points gained and rejects a `null` result with `0`.
- **The multiplier is clamped** to `config.combo_max` (`:56`) and the step is
  read from `GameConfig` rather than a literal (`combo_step()`, `:48-49`).
- **`break_combo()` never touches the total score** (`:61-66`) — only the combo
  and the multiplier.
- **The combo decays on its own** (`advance()`, `:173-178`): the timer runs
  down and the combo breaks when it expires, so chaining must be continuous.
- **`add_points()` ignores non-positive values** (`:75-76`) and emits
  `score_changed(total, delta)` on every accepted change.
- **Score popups are pooled, never `queue_free()`d on the fly** (`:87-98`,
  `POPUP_POOL_MAX = 24`), which is the §1.4/§7 rule for hot paths. The pool and
  its parent resolve lazily, so a headless run without those nodes shows
  nothing instead of failing.
- **`rank_for_score()` thresholds come from `GameConfig`** (`rank_c` …
  `rank_s_plus`) — data, not code (§1.3).
- `reset()` (`:142-147`) zeroes score, combo, multiplier and the combo timer.

### Publisher and consumer

Published as an autoload under `&"score"` (`score_director.gd:32`). Consumed by
`MinigameDirector` (through `ctx.score` and for
`add_minigame_result()`), by `GameLoopDriver` (`advance()`, `game_loop.gd:26-28`),
and by the HUD and results screen (which read `total_score`, `combo` and
`current_rank()`).

The popup position resolves the player through
`GameServices.lookup(&"player")` (`:202-206`) rather than a direct autoload
reference, and falls back to the world origin.

### Test coverage

- `tests/unit/test_match.gd:77-140` — score starts at zero, the combo raises the
  multiplier, the cap, `break_combo` resetting the multiplier, the time bonus,
  the multiplier applied, the combo timeout decaying, the rank thresholds and
  `reset()` clearing everything.
- `tests/unit/test_scoring_and_roulette.gd:43-86` — a `MinigameResult` pays
  through the director, a failure breaks the combo and still counts the base,
  the time bonus joins unscaled, and a null result is rejected.
- `tests/integration/test_full_match.gd:511` — the end-to-end payout, including
  the exact arithmetic (`1200 × 1.25 + 300`).

---

## MinigameEntity

**Purpose** — the single generic entity scene every micro-game that spawns
things uses. What makes "token_rush" look different from "gpu_meltdown" is not a
different scene or script, it is the slot data the archetype pushes into the
exported fields below (§8.0: data, not code).

**Source:** `src/minigames/runtime/minigame_entity.gd`

### Fields and signatures (read from source)

```gdscript
enum Shape { SPHERE, BOX, DIAMOND, RING }

@export var tint: Color = Color(0.35, 0.85, 1.0)
@export var shape: int = Shape.SPHERE
@export var size: float = 0.6
@export var lifetime_s: float = -1.0          # -1 = never expires
@export var rotation_speed: Vector3 = Vector3(0.0, 1.6, 0.0)
signal collected(by: Node)

func take(by: Node) -> void
func is_taken() -> bool
func set_lifetime(seconds: float) -> void
```

### Guarantees

- **`take(by)` is the pickup contract and is safe to call more than once**
  (`:61-67`): only the first call wins, which prevents a combo from
  double-counting.
- **An expired entity can no longer be collected** (`:72-73`, `:155-159`):
  `_expire()` sets `_taken` before despawning.
- **`lifetime_s <= 0` means "stays until taken"** (`:76-79`), matching the
  `SpawnRecipe.lifetime_s` default of `-1`.
- **The entity cleans itself up** (`:162-168`): on despawn it leaves the
  `&"mg_entity"` group and frees itself, so the director's orphan guard finds
  nothing to sweep.
- `tint` and `shape` are setters that rebuild the visual immediately
  (`:19-26`), which is what lets `_configure_entity()` reconfigure an already
  spawned node.
- The mesh deliberately uses low segment counts (`:92-128`) to stay inside the
  §15 primitive budget; `rotation_speed` is a field, not a const, so a `.tres`
  or an archetype can slow a heavy entity down.

### Publisher and consumer

Published as the `Area3D` scene the `SpawnRecipe.entity_scene` points at. Spawned
by `MinigameArchetype.spawn_entity()` and consumed by the archetypes, which
connect to `collected(by)`.

### Test coverage

- `tests/unit/test_catalog_entities.gd` — the catalog's entity scenes.
- `tests/integration/test_stress_match.gd:829` — the orphan guard scans a
  populated `mg_entity` group; `:483` every catalog micro-game's teardown leaves
  the tree clean.

---

## RouletteController

**Purpose** — micro-game selection: on power-up pickup it spins, then makes a
weighted, anti-repetitive, theme-anti-saturated, deterministic choice and hands
it to `MatchManager` through the event bus.

**Source:** `src/powerups/roulette/roulette_controller.gd`

### Signatures (read from source)

```gdscript
@export var spin_duration_s: float = 2.5
signal spin_started(duration_s: float)
signal spin_finished(id: StringName)

func spin() -> StringName
func update(delta: float) -> void
func is_spinning() -> bool
func get_pending_id() -> StringName
func get_last_id() -> StringName
func get_spin_progress() -> float
func get_theme_history() -> Array
func register_theme_for_test(id: StringName) -> void
```

### Guarantees

- **`spin()` picks immediately but delivers late** (`:65-80`): the deterministic
  choice is made at once and returned, so the wheel UI can label it while the
  spin is still in flight; the `roulette_result` is only emitted once
  `spin_duration_s` has elapsed (`:84-90`, `:92-106`).
- **The pick is weighted by `MinigameMetadata.weight`** (`:137-153`), with each
  weight floored at `0.0001` so a zero weight can never divide by zero.
- **Immediate anti-repetition** (`:157-160`): the same id is never chosen twice
  in a row while an alternative exists, matching the director's rule.
- **Theme anti-saturation** (`:14`, `:164-182`): never 5 rounds in a row of the
  same `theme_tag`, unless the catalog is exhausted.
- **Determinism** (`:195-198`): the roll comes from `SeededRNG.randf()` when the
  service resolves, and from the engine RNG only as a fallback. Same seed →
  same choice.
- **The controller never plays the micro-game itself** (`:101-106`). It emits
  `roulette_result` and `MatchManager` drives the director, which is what stops
  a cross-system reference and a duplicate `minigame_started` when the pick is
  refused.
- `spin()` refuses to start a second spin (`:66-68`) and errors on an empty
  catalog (`:70-72`) rather than emitting a nonsense result.

### Publisher and consumer

Published as an autoload under `&"roulette"`
(`roulette_controller.gd:38`). Consumed by `GameLoopDriver`, which calls
`update(delta)` while the match is in the `ROULETTE` state
(`game_loop.gd:20-22`), and by the wheel UI through `get_pending_id()` /
`get_spin_progress()`. The registry it spins from is resolved through
`&"registry"` (`:48`) so it shares the director's catalog.

### Test coverage

- `tests/unit/test_match.gd:25` — `test_roulette_cycle`.
- `tests/unit/test_scoring_and_roulette.gd:86,138` — the roulette result starts
  the minigame through the bus, and the game loop ticks the roulette.
- `tests/integration/test_full_match.gd:553` —
  `test_same_seed_replays_the_same_minigame_sequence`, the determinism gate for
  selection.
- `tests/integration/test_stress_match.gd:766` — the power-up director starts
  the roulette; `:891` the roulette result reaches the director even on
  cooldown.

---

## CameraDirector

**Purpose** — the follow camera, and the single entry point for screen shake and
FOV effects. Every shake in the game goes through `shake()`, which is where the
accessibility multiplier is applied.

**Source:** `src/juice/camera_director.gd`

### Signatures (read from source)

```gdscript
func set_camera(cam: Camera3D) -> void
func set_target(t: Node3D) -> void
func set_offset(off: Vector3) -> void
func shake(trauma: float, freq: float = 24.0, duration: float = 0.4) -> void
func shake_offset(delta: float) -> Vector3
func fov_punch(degrees: float, duration: float = 0.25) -> void
func zoom_pulse(degrees: float, duration: float = 1.0) -> void
func update_camera(delta: float) -> void
```

### Guarantees

- **`shake()` applies the accessibility scale at the single entry point**
  (`:113-124`, `_shake_scale()` `:127-132`): a player who asks for less shake —
  or none — gets it everywhere at once, because the multiplier is read from
  `SettingsManager` here and never at each call site. A scale of `0` makes
  `shake()` a no-op.
- **Trauma accumulates and decays** (`TRAUMA_DECAY = 1.6`, `TRAUMA_MAX = 1.0`,
  `:17-18`), so overlapping shakes add up but are bounded.
- **`shake_offset()` is deterministic noise, not RNG** (`:139-146`): a sine
  triple driven by the trauma and the elapsed time, which keeps shake
  reproducible and cheap.
- **The follow is frame-rate independent** (`:242-255`): exponential smoothing
  `1 - exp(-follow_stiffness * delta)` rather than a linear lerp, so the camera
  feels identical at 30, 60 or 144 fps.
- **`_aim_at()` never issues a colinear `look_at`** (`:225-238`): below a
  `COLUMNAR_EPSILON` horizontal separation the aim is nudged sideways along the
  camera's own right vector, so no degenerate basis (and no Godot warning) can
  occur.
- **FOV is clamped to 30…110 degrees** (`:181`) and the roll to `roll_max`
  degrees (`:260-267`), so the frame can never disorient.
- All tuning is exported (`follow_stiffness`, `lookahead`, `speed_fov_per_unit`,
  `roll_per_unit` …) rather than hardcoded (§1.3).

### Publisher and consumer

Published as an autoload under `&"camera"`
(`camera_director.gd:70`). Consumed by `ImpactDirector`, which resolves it
through `GameServices.lookup(&"camera")` and calls `shake()` and `fov_punch()`
(`impact_director.gd:87-91`), and by `MinigameContext` (as `ctx.camera`).

### Test coverage

- `tests/unit/test_camera_director_basis.gd` — the default offset is not on the
  player's vertical axis (`:37`), the basis stays orthonormal every frame
  (`:48`), the aim guard never issues a colinear `look_at` (`:73`), and the
  follow produces a real third-person framing (`:90`).

---

## ImpactDirector

**Purpose** — the single juice API. Gameplay never inserts hitstop, shake or
flash directly; it calls `impact(weight)` or `impact_frame(preset)` and the
director runs the whole package from `.tres` data.

**Source:** `src/juice/impact_director.gd`

### Signatures (read from source)

```gdscript
const WEIGHT_LIGHT := 0
const WEIGHT_MEDIUM := 1
const WEIGHT_HEAVY := 2
const WEIGHT_CRITICAL := 3

func impact(weight: int) -> void
func impact_frame(frame: ImpactFrame) -> void
func advance(delta: float) -> void
func current_flash() -> Dictionary
func in_hitstop() -> bool
```

### Guarantees

- **`impact(weight)` resolves the matching preset from `PRESET_DIR`** and falls
  back to `ImpactFrame.preset(weight)` when the file is missing (`:58-62`,
  `_preset_name` `:109-115`), so juice never silently disappears.
- **`impact_frame()` runs the whole package**: hitstop via `Engine.time_scale`,
  camera shake + FOV punch through the `&"camera"` service, the flash state, and
  the impact audio through the `&"sfx"` service (`:66-99`).
- **The hitstop restore is idempotent and always lands** (`:135-142`): it is
  called from `advance()`, from a wall-clock safety net in `_process()` and from
  `NOTIFICATION_EXIT_TREE`, whichever comes first. `Engine.time_scale` is
  global state, so a paused driving loop must never be able to leave the world
  in slow motion — hence the explicit deadline (`:23-27`, `:85`) and
  `process_mode = PROCESS_MODE_ALWAYS` (`:40`).
- **The restore value is only sampled when no hitstop was already armed**
  (`:69-80`): sampling it unconditionally made a second impact in the same frame
  write back the already-slowed value, leaving the world in 20× slow motion for
  the rest of the match.
- **`advance()` restores the time scale and decays the flash** (`:121-130`).
- **`impact_requested` is deliberately NOT emitted here** (`:100-107`): the
  signal looks like a request this director should answer, so emitting it after
  the fact would look inverted to the natural "gameplay emits, juice listens"
  wiring and could re-enter this function. Gameplay calls `impact()` directly;
  the bus stays for the events that are genuinely observed.
- `current_flash()` returns `{"color": Color, "alpha": float}` for the
  `PostFXDirector` to draw (`:145-147`).

### Publisher and consumer

Published as an autoload under `&"impact"`
(`impact_director.gd:37`). Consumed by `MinigameDirector`, which fires
`WEIGHT_CRITICAL` on success and `WEIGHT_HEAVY` on failure
(`minigame_director.gd:367-369`), and through `MinigameContext` as
`ctx.impact`. `GameLoopDriver` calls `advance()` (`game_loop.gd:29-31`).

### Test coverage

- `tests/unit/test_styles.gd:70` — `test_all_impact_presets_load`; `:83` —
  `test_impact_weight_ordering`; `:94` —
  `test_impact_director_hitstop_restores_time`.
- `tests/unit/test_audio_pipeline.gd:96,223,247` — every impact tier is
  registered as impact-group audio, an impact plays and releases its voice, and
  impact voices come from the shared pool.
- `tests/integration/test_stress_match.gd:679` —
  `test_back_to_back_impacts_restore_normal_speed`.

---

## ImpactFrame

**Purpose** — a `.tres` preset for one impact event. All juice numbers live
here as data; gameplay only says "impact(weight)".

**Source:** `src/juice/impact_frame.gd`

### Fields and signatures (read from source)

```gdscript
class_name ImpactFrame
extends Resource

@export var hitstop_s: float = 0.06          # 40..120ms typical
@export var time_scale: float = 0.05         # time_scale during hitstop
@export var shake_amplitude: float = 0.3     # trauma 0..1
@export var shake_frequency: float = 24.0
@export var shake_duration_s: float = 0.4
@export var fov_punch: float = -6.0          # degrees (negative = punch in)
@export var chromatic_pulse: float = 0.5
@export var flash_color: Color = Color.WHITE
@export var flash_alpha: float = 0.3
@export var desaturate: float = 0.3
@export var model_freeze: bool = false       # freeze model, world keeps moving
@export var slow_mo_curve: Curve = null      # time_scale curve after hitstop
@export var impact_sfx: AudioStream = null

static func preset(weight: int) -> ImpactFrame
```

### Guarantees

- **`preset(weight)` is the factory for the four canonical weights** (`:28-63`)
  and its documented semantics are LIGHT = combo step, MEDIUM = minigame hit,
  HEAVY = powerup/fail, CRITICAL = roulette result/match end (`:6-11`).
- **The four presets are monotonically ordered** in hitstop, shake, punch and
  flash, so a heavier impact is unambiguously heavier.
- A weight outside the four known values returns the MEDIUM preset (`:63`).
- `impact_sfx` is a bare `AudioStream`, not a catalog id, which is why
  `SFXPlayer` has a separate `play_impact()` route for it.

### Publisher and consumer

Published as a `Resource`; the presets live in `src/juice/presets/*.tres`.
Consumed by `ImpactDirector.impact()` and `impact_frame()`, and by
`SFXPlayer.play_impact()` for the audio layer.

### Test coverage

- `tests/unit/test_styles.gd:70` — `test_all_impact_presets_load`; `:83` —
  `test_impact_weight_ordering`.
- `tests/unit/test_audio_pipeline.gd:96` — every impact tier is registered as
  impact-group audio.

---

## StyleDirector

**Purpose** — applies a `StylePack` to the world with a smooth blend and
auto-reverts when the micro-game ends.

**Source:** `src/styles/style_director.gd`

### Signatures (read from source)

```gdscript
func apply_pack_id(pack_id: StringName) -> void
func apply_pack(pack: StylePack) -> void
func revert_to_base() -> void
func current_pack() -> StylePack
func is_styled() -> bool
```

### Guarantees

- **`apply_pack_id()` loads from `PACK_DIR` by a lowercased id** (`:53-61`) and
  warns (rather than crashing) when the pack is missing. An empty id means
  "revert to base", not "apply nothing".
- **The transition is a blend, not a pop** (`:65-74`): `_blend_step()` lerps the
  environment values from the snapshot to the target over
  `1 / max(pack.transition_s, 0.01)` per second (`:150-172`).
- **`revert_to_base()` clears the global shader uniforms *before* blending
  back** (`:79-92`, `:144-147`): without that the world carried the last pack's
  saturation/scanline look into the next micro-game, which is a §1.4 violation
  ("leave the world as it was found").
- **Only `SHADER_UNIFORM` packs touch global shader parameters**
  (`:135-141`); a `FULL_SWAP` or `OVERLAY` pack is left to its own path.
- The base environment is captured once at ready (`:31-47`) and restored as a
  duplicate, so a revert never mutates the captured dictionary.
- `apply_pack()` and `revert_to_base()` each emit exactly one bus event
  (`style_applied(pack_id)` / `style_reverted()`), which is what the
  `PostFXDirector` and the HUD theme listen to.

### Publisher and consumer

Published as an autoload under `&"style"`
(`style_director.gd:27`). Consumed by `MinigameDirector` through
`_apply_style_and_music()` (`minigame_director.gd:329-332`) and through
`ctx.style`, and by `PostFXDirector`, which listens to `style_applied` /
`style_reverted`.

### Test coverage

- `tests/unit/test_styles.gd:50` — `test_style_director_degrades_headless`;
  `:61` — `test_style_director_unknown_pack_warns_not_crashes`.
- `tests/unit/test_scoring_and_roulette.gd:165` —
  `test_style_director_applies_a_pack_by_id`.
- `tests/integration/test_stress_match.gd:1060` —
  `test_style_pack_uniforms_are_cleared_on_revert`.

---

## StylePack and StylePostFX

**Purpose** — a `StylePack` is one temporary visual transformation of the world
(one of the 12 looks of scaffold §9); `StylePostFX` is its post-processing
profile.

**Sources:** `src/styles/style_pack.gd`, `src/styles/style_postfx.gd`

### Fields and signatures (read from source)

```gdscript
class_name StylePack
extends Resource
@export var id: StringName = &""
@export var display_name: String = ""
@export var sky_top: Color = Color(0.25, 0.45, 0.9)
@export var sky_horizon: Color = Color(0.8, 0.85, 0.95)
@export var fog_color: Color = Color(0.7, 0.75, 0.85)
@export var fog_density: float = 0.0
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 1.2
@export var ambient_color: Color = Color(0.55, 0.6, 0.7)
@export var ambient_energy: float = 0.6
@export var material_mode: StringName = &"SHADER_UNIFORM"  # FULL_SWAP | SHADER_UNIFORM | OVERLAY
@export var character_material: Material = null
@export var environment_material: Material = null
@export var postfx: StylePostFX = null
@export var fov_override: float = -1.0        # -1 = no override
@export var camera_offset: Vector3 = Vector3.ZERO
@export var music_state: StringName = &""
@export var hud_theme: Theme = null
@export var transition_s: float = 0.4
@export var revert_to_base_on_end: bool = true
@export var style_uniforms: Dictionary = {}

class_name StylePostFX
extends Resource
@export var bloom_intensity: float = 0.4
@export var chromatic: float = 0.0        # 0..1 RGB split amount
@export var vignette: float = 0.25        # 0..1 dark corners
@export var scanline: float = 0.0         # 0..1 CRT lines
@export var saturation: float = 1.0       # 0 = greyscale, 1 = normal
@export var desaturate: float = 0.0       # hitstop/impact desaturation
@export var glow_strength: float = 1.0    # multiplier on Godot glow
@export var glow_bloom: float = 0.15      # 0..1 haziness

func lerp_to(other: StylePostFX, t: float) -> StylePostFX
```

### Guarantees

- **`StylePostFX.lerp_to()` is a pure function** (`:20-31`): it builds a new
  profile, clamps `t` to 0..1 and interpolates all eight fields, so style
  changes never pop.
- **All tuning is data** — the director never hardcodes a palette; it reads
  `pack.postfx` and `pack.style_uniforms`.
- `material_mode` defaults to the cheap, pop-free `SHADER_UNIFORM` strategy
  (§6.4), with `FULL_SWAP` and `OVERLAY` available for drastic look changes.
- `fov_override` of `-1` means "no override", and `style_pack_id == &""` on a
  `MinigameMetadata` means "the world's base style".

### Publisher and consumer

Published as `Resource`s; the 12 packs live in `src/styles/packs/*.tres`.
Consumed by `StyleDirector` (which applies the pack) and `PostFXDirector`
(which reads `pack.postfx`), and by `MinigameMetadata.style_pack_id` as a
reference by id.

### Test coverage

- `tests/unit/test_styles.gd:36` — `test_style_postfx_lerp`.
- `tests/unit/test_art_assets.gd` / the style pack suite validates the pack
  resources load and are complete.

---

## MusicDirector

**Purpose** — dynamic music by state, with a phase-locked vertical stem stack
and a ducking API for VO and impacts.

**Source:** `src/audio/music_director.gd`

### Signatures (read from source)

```gdscript
const STATE_CALM: StringName = &"CALM"
const STATE_TENSION: StringName = &"TENSION"
const STATE_PEAK: StringName = &"PEAK"
const STATE_TRIUMPH: StringName = &"TRIUMPH"
const STATE_FAIL: StringName = &"FAIL"
const ALL_STATES: Array[StringName] = [STATE_CALM, STATE_TENSION, STATE_PEAK, STATE_TRIUMPH, STATE_FAIL]
const LAYER_DRUMS: StringName = &"drums"
const LAYER_BASS: StringName = &"bass"
const LAYER_LEAD: StringName = &"lead"
const LAYER_HARMONY: StringName = &"harmony"
const LAYER_FX: StringName = &"fx"
const GATE_BASS: float = 0.3
const GATE_LEAD: float = 0.6
const GATE_HARMONY_FX: float = 0.85

func play_music_state(state: StringName, state_intensity: float = -1.0) -> void
func duck(amount_db: float, duration_s: float) -> void
func unduck(fade_s: float = -1.0) -> void
func tick(delta: float) -> void
func advance(delta: float) -> void
func layers_for_intensity(value: float) -> Array[StringName]
func active_layers() -> Array[StringName]
func crossfade_s() -> float
func ladder_snapshot() -> Dictionary
func state_layer_set(state: StringName) -> Array[StringName]
func set_stem(state: StringName, layer: StringName, stream: AudioStream) -> void
func get_stem(state: StringName, layer: StringName) -> AudioStream
func set_time_source(source: Object) -> void
```

### Guarantees

- **The intensity gates are the scaffold §10.2 thresholds, verbatim** (`:66-68`):
  drums always, bass ≥ 0.3, lead ≥ 0.6, harmony+fx ≥ 0.85.
  `layers_for_intensity()` is a pure function of those gates (`:261-271`).
- **`STATE_INTENSITY` is THE ladder data** (`:76-82`): state → default
  intensity, applied whenever a caller requests a state without an explicit
  intensity. CALM 0.15, TENSION 0.65, PEAK 0.9, TRIUMPH 1.0, FAIL 0.3.
- **A state change is immediate; the layer mix lands on the next 2-bar
  boundary** (`:184-195`) and is applied as a volume crossfade, never a hard
  cut.
- **Silence discipline** (`:527-559`): a layer that is not wanted fades to
  `SILENCE_DB` and is then *stopped*; a returning layer restarts phase-aligned
  from the music clock, so it never seams or doubles.
- **Crossfades are a constant dB/second rate over the audible span** (`:540-550`,
  `:283-284`), capped by the switch cadence, so every fade actually settles
  instead of chasing its target forever.
- **Ducking is a ramp, re-anchored to wherever the duck currently is**
  (`:229-231`, `:499-524`), so a half-finished duck releases over the full fade
  time rather than crawling. `duck()` with `duration_s >= DUCK_TIMED_MIN_S`
  (0.25) auto-releases; a smaller value is a fade-only request that holds until
  `unduck()` — which is how `VoiceDirector` drives it.
- **Missing stems degrade to a logged no-op, never a crash** (`:31`, `:419-432`):
  without the individual stems the pre-mixed `music_full.wav` bed plays instead.
- **BPM is data** (`:356-361`): read from `GameConfig.music_bpm`, and an
  explicitly set value wins so a test is never overwritten by the file.
- `tick()` accepts an injected absolute clock (`:236-249`), which is what makes
  the ladder testable without audio.

### Publisher and consumer

Published as an autoload under `&"music"`
(`music_director.gd:351`, via `_register_service()`). Consumed by
`MinigameDirector` (`music.play_music_state(meta.music_state, 0.9)`,
`minigame_director.gd:333-335`), by `VoiceDirector` (duck/unduck through an
injected duck-typed reference, `voice_director.gd:315-323`), by `SFXPlayer`
(optional `music_director` reference, `sfx_player.gd:62`), by `AudioDirector`
(the public façade) and through `MinigameContext` as `ctx.music`.

### Test coverage

- `tests/unit/test_music_ladder.gd` — the locked BPM (`:27`), the monotonic
  intensity ladder (`:46`), more layers audible as intensity climbs (`:59`),
  silence is a real layer set (`:70`), the crossfade never pops (`:81`), ducking
  is a real gain and recovers (`:89`), layer gain is finite and ordered (`:113`),
  and the snapshot is a complete readable state (`:124`).
- `tests/unit/test_audio_pipeline.gd:141,162,247,287,307,323` — the announcer
  ducks the music and hands it back, the duck is held while speaking and
  released once, freeroam is calm and grows with the combo, a micro-game owns
  the music, a failed micro-game drops to FAIL, and impacts duck the music by
  weight.

---

## SFXPlayer

**Purpose** — the pooled SFX voice player. Every sound effect in the game goes
through it, including the impact frames' own audio.

**Source:** `src/audio/sfx_player.gd`

### Signatures (read from source)

```gdscript
const MAX_VOICES_HARD_LIMIT: int = 64
const DEFAULT_MAX_VOICES: int = 32
const IMPACT_PRIORITY: int = 90
const IMPACT_GROUP: StringName = &"impact"
const MAX_PRIORITY: int = 255

func set_group_cap(group: StringName, cap: int) -> void
func play_impact(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer
func play(sfx_id: StringName, volume_db_offset: float = 0.0) -> AudioStreamPlayer
func playing_voices() -> int
func stop_all() -> void
```

### Guarantees

- **`play()` never throws and returns `null` when skipped** (`:182-227`): a
  null library, an unknown id, an active cooldown, a saturated group cap, a
  saturated per-id cap or a missing stream each skip with at most one warning.
- **Voice stealing is lowest-priority-first, oldest on ties** (`:251-277`): a
  higher-priority voice is never stolen by a lower one; when everything is at
  or above the incoming priority the oldest of them is taken.
- **The pool can never exceed `MAX_VOICES_HARD_LIMIT` (64)** (`:20`, the
  `max_voices` setter `:57-59`), so a typo in a `.tres` cannot melt the audio
  thread. `DEFAULT_MAX_VOICES` (32) is only the fallback when no config
  resolves; `GameConfig.sfx_max_voices` is the authoritative budget (§1.3).
- **`play_impact()` routes an `ImpactFrame`'s bare `AudioStream`** through the
  same pool and the same priority/stealing policy as `play()` (`:154-178`).
  It exists because the impact lookup used to resolve to null and the method
  did not exist, so the audio layer of every impact frame was silently dropped.
- **The group that is incremented is the group that is decremented**
  (`:166`, `:173`): binding the constant instead of the configured
  `impact_group` leaked the counter upward forever, which saturated the impact
  cap after a handful of hits.
- **`stop_all()` resets the bookkeeping** (`:237-247`) — a stopped voice never
  emits `finished()`, so without the reset the group/id counters would stay
  armed forever.
- **Per-take randomization** is bounded: pitch ±5 %, volume ±1.5 dB
  (`:25-26`, `:216-217`).
- All routing values (priority, bus, group, volume) are read from `GameConfig`
  with an explicit-wins guard, so a test or a runtime tweak is never overwritten
  by the file (`:88-111`).

### Publisher and consumer

Published as an autoload under `&"sfx"`
(`sfx_player.gd:80`). Consumed by `ImpactDirector`
(`GameServices.lookup(&"sfx")` → `play_impact()`,
`impact_director.gd:97-99`) and by `AudioDirector`, which exposes `play_sfx()`
as the public façade.

### Test coverage

- `tests/unit/test_sfx_player.gd` — the voice cap blocks overflow (`:18`), the
  default max voices is 32 (`:39`), lowest priority is stolen (`:46`), oldest
  stolen on equal priority (`:68`), higher priority never stolen by lower
  (`:87`), pitch/volume randomization bounds (`:105`), group concurrency cap
  (`:124`), and missing stream / unknown id / null library never crash
  (`:140,150,157`).
- `tests/unit/test_audio_pipeline.gd:179,196,223,247` — impact routing is data
  from the config, an impact plays and releases its voice, impact voices come
  from the shared pool, and the impact group cap is registered for the
  configured group.
- `tests/unit/test_audio_buses.gd` / `test_audio_assets.gd` — the bus layout and
  the catalog assets.

---

## VoiceDirector

**Purpose** — the arcade announcer. One VO line at a time, priority-ordered,
anti-spammed, and always ducking the music while it speaks.

**Source:** `src/audio/voice_director.gd`

### Signatures (read from source)

```gdscript
const DEFAULT_COOLDOWN_S: float = 3.0
const COMBO_MILESTONE: int = 5
const TIME_WARNING_S: float = 30.0
const DEFAULT_DUCK_DB: float = -10.0
const DEFAULT_DUCK_FADE_S: float = 0.15

func setup(catalog: VoiceLines, rng: RandomNumberGenerator = null) -> void
func connect_match_events() -> void
func disconnect_match_events() -> void
func speak(event_id: StringName) -> bool
func priority_for(event_id: StringName) -> int
func is_speaking() -> bool
func current_event() -> StringName
func queue_length() -> int
func stop() -> void
func cooldown_remaining_s(event_id: StringName) -> float
func set_time_source(source: Object) -> void
func set_clock_msec(t: float) -> void
```

### Guarantees

- **One line at a time; higher priority preempts, equal or lower queues**
  (`:179-197`). `speak()` returns `true` only when the line started
  immediately.
- **Anti-spam cooldown per event**, default 3 s, overridable per event id
  through `cooldown_overrides` (`:18`, `:306-311`).
- **Only the combo milestone earns a line** (`COMBO_MILESTONE = 5`,
  `:143-147`): a VO line per combo step would be spam.
- **The time warning fires only in the last 30 seconds** (`:149-152`).
- **Success and failure pick different lines** (`:154-160`: `EV_MINIGAME_FLAWLESS`
  vs `EV_MINIGAME_FAIL`).
- **Music ducking while speaking** (`:315-323`), through an injected,
  duck-typed `music_director` that may be null — no direct autoload reference
  (§1.1).
- **A missing VO asset degrades to a silent, zero-length line** (`:239-252`,
  `:254-265`), so the queue still advances deterministically in tests.
- **`disconnect_match_events()` really drops every subscription** (`:109-122`):
  it disconnects by the stored callable, and the connection guard verifies the
  actual connections rather than trusting a flag.
- The clock is injectable (`set_time_source` / `set_clock_msec`), which is what
  makes the cooldown and queue logic testable.

### Publisher and consumer

Published as an autoload under `&"voice"`
(`voice_director.gd:78`). Consumed through `MinigameContext` as `ctx.voice`, and
by `AudioDirector`, which calls `play_voice(event_id)` as the public façade and
subscribes to `voice_requested` on the bus.

### Test coverage

- `tests/unit/test_voice_wiring.gd` — the match events request the right lines
  (`:32`), the combo line only on the milestone (`:56`), the time warning only
  near the end (`:68`), the fail/flawless pick (`:80`), and that disconnect
  drops every subscription (`:88`).
- `tests/unit/test_audio_pipeline.gd:109,141,162` — every announcer line has
  real audio, the announcer ducks the music and hands it back, and the duck is
  held while speaking and released once.

---

## SaveSystem

**Purpose** — local records and settings persistence. It owns the best
score/rank and every accessibility setting, in `user://` as JSON.

**Source:** `src/systems/save_system.gd`

### Signatures (read from source)

```gdscript
const SAVE_PATH := "user://arcade_block_save.json"
const SETTINGS_PATH := "user://arcade_block_settings.json"

func submit_score(score: int, rank: StringName) -> bool
func reset() -> void
func get_setting(key: StringName, default_value: Variant = null) -> Variant
func set_setting(key: StringName, value: Variant) -> void
```

### Guarantees

- **`submit_score()` returns `true` only for a new best** (`:28-34`) and writes
  the file; a lower score changes nothing.
- **Score and accessibility settings are persisted separately**
  (`SAVE_PATH` vs `SETTINGS_PATH`, `:7-8`), so wiping the record does not wipe a
  player's accessibility choices.
- **`get_setting()` takes a default** (`:45-47`), so a missing key degrades to
  the caller's fallback rather than to `null`.
- **`set_setting()` writes through immediately** (`:49-52`).
- **A malformed or unreadable settings file leaves the defaults in place and
  says so** (`:95-110`), rather than silently wiping a player's choices.
- **Everything degrades when the filesystem is unavailable** — every `FileAccess`
  open is null-checked, so a headless test run behaves the same as a full boot.

### Publisher and consumer

Published as an autoload under `&"save"`
(`save_system.gd:22`). Consumed by `SettingsManager`, which resolves it through
`GameServices.lookup(&"save")` (`settings.gd:30`), and by the results screen,
which calls `submit_score()`.

### Test coverage

- `tests/integration/test_stress_match.gd:1170` —
  `test_accessibility_settings_survive_a_relaunch`, which is the persistence
  gate for exactly this contract.
- `tests/unit/test_screens_integration.gd` — the results screen submitting a
  score.
- `tests/unit/test_accessibility_settings.gd` /
  `test_accessibility_remaining.gd` — the settings surface over the save.

---

## SettingsManager

**Purpose** — the single source of truth for accessibility and gameplay
settings, backed by `SaveSystem`.

**Source:** `src/systems/settings.gd`

### Signatures (read from source)

```gdscript
const DEFAULTS := {
	"shake_intensity": 1.0,
	"flashes_enabled": true,
	"colorblind_indicators": false,
	"subtitles_enabled": true,
	"text_speed": 1.0,
}

func get_value(key: String) -> Variant
func set_value(key: String, value: Variant) -> void
func shake_scale() -> float
func flashes_enabled() -> bool
func subtitles_enabled() -> bool
func text_speed() -> float
```

### Guarantees

- **The defaults are declared once as data** (`:8-14`) and applied before any
  persisted value is read, so a fresh install always has a complete set.
- **Persisted values win over the defaults** (`:28-34`), each read with its own
  default as the fallback.
- **`shake_scale()` is clamped to 0..1** (`:48-49`), which is what makes
  `CameraDirector.shake()` a no-op at `0`.
- **`text_speed()` is clamped to 0.5..2.0** (`:62`).
- **`set_value()` writes through to the save immediately** (`:41-44`), so a
  change survives a relaunch without an explicit save step.
- `subtitles_enabled()` is the text twin of every VO line (§8).

### Publisher and consumer

Published as an autoload under `&"settings"`
(`settings.gd:27`). Consumed by `CameraDirector._shake_scale()`
(`camera_director.gd:129`) and by the accessibility settings UI.

### Test coverage

- `tests/unit/test_accessibility_settings.gd` and
  `tests/unit/test_accessibility_remaining.gd`.
- `tests/integration/test_stress_match.gd:1170` — settings survive a relaunch.

---

## SeededRNG

**Purpose** — the deterministic RNG wrapper. All randomness in the game —
roulette, spawns, micro-games — must flow through it so runs are reproducible.

**Source:** `src/core/rng/seeded_rng.gd`

### Signatures (read from source)

```gdscript
func seed(new_seed: int) -> void
func current_seed() -> int
func dump_state() -> int
func load_state(state: int) -> void
func randf() -> float
func randi_range(from: int, to: int) -> int
func pick(items: Array) -> Variant
func pick_weighted(items: Array, weights: Array[float]) -> Variant
```

### Guarantees

- **Same seed → same sequence**, guaranteed by the `dump_state()` /
  `load_state()` pair (`:31-37`) and pinned by tests.
- **`seed()` warms up with 8 scramble steps** (`:17-23`) so low seeds diverge
  immediately instead of producing correlated first draws.
- **`randf()` is an explicit `self.randf()` internally** (`:50-54`): a bare
  `randf()` inside the script would resolve to the engine's global RNG and
  silently break determinism.
- **`randi_range()` normalises an inverted range** (`:58-65`).
- **`pick_weighted()` uses rejection sampling over two draws** (`:77-100`) to
  avoid xorshift low-bit bias, with a deterministic cumulative-scan fallback.
  It returns `null` for empty or mismatched input.

### Publisher and consumer

Published as an autoload (the `/root/SeededRNG` singleton). Consumed by
`MinigameDirector._build_context()` as `ctx.rng`
(`minigame_director.gd:272`), by `RouletteController._randf()`
(`roulette_controller.gd:195-198`), by `MinigameArchetype.spawn_point()` for
`SCATTER`, and by `MinigameDirector.pick_next()`.

### Test coverage

- `tests/unit/test_core.gd:55-136` — same-seed determinism, different seeds
  diverging, state replay, `randi_range` bounds, and `pick_weighted` being both
  deterministic and weight-favouring.
- `tests/unit/test_archetype_state_readers.gd:40` — `current_seed()` /
  `dump_state()` / `load_state()` are readable state.
- `tests/integration/test_full_match.gd:553` — the same seed replays the same
  micro-game sequence.

---

## GameLoopDriver

**Purpose** — the single per-frame tick for the match systems that must be
driven deterministically rather than by their own `_process`.

**Source:** `src/core/game_loop.gd`

### Signatures (read from source)

```gdscript
func _physics_process(delta: float) -> void
func _unhandled_input(event: InputEvent) -> void
```

### Guarantees

- **A fixed, ordered tick** (`:12-36`): `MatchManager.advance()` →
  `RouletteController.update()` → `MinigameDirector.update()` →
  `ScoreDirector.advance()` → `ImpactDirector.advance()`. Order matters (§1.1):
  clock first, then gameplay, then juice.
- **Input is forwarded to the micro-game director only** (`:39-42`).
- **`PostFXDirector` is deliberately NOT advanced here** (`:32-36`): it is an
  autoload and runs its own `_process`; advancing it here too made every fade
  run at double rate. If it ever loses its `_process`, this is where it must
  come back.
- Every resolved system is duck-typed and may be missing (`_resolve()`,
  `:45-49`), so a partial boot or a test harness works.

### Publisher and consumer

Published as an autoload. Consumed by nothing — it is the frame driver itself.
Its contract is the *order* it imposes, which the integration tests pin.

### Test coverage

- `tests/unit/test_match_loop.gd` — the clock advancing only in running states,
  one tick per second, and the match ending at time up.
- `tests/unit/test_scoring_and_roulette.gd:138` — the game loop ticks the
  roulette.
- `tests/integration/test_stress_match.gd:1290` — postfx is advanced exactly
  once per frame, which pins the double-advance rule above.

---

## Service registry: which services are published, and by whom

Every entry below is published at autoload time through
`GameServices.publish("<AutoloadName>", &"<service name>", self)`, which refuses
anything that is not the live `/root/<AutoloadName>` singleton. The canonical
names are the `const`s at `src/core/game_services.gd:11-27`.

| Autoload (publisher) | Service name | Primary consumers |
| --- | --- | --- |
| `GameServices` (self, `game_services.gd:35`) | `&"core"` | `Player` and any non-autoload service registering itself |
| `MatchManager` (`match_manager.gd:42`) | `&"match"` | `MinigameDirector` (context + `finish_minigame`) |
| `ScoreDirector` (`score_director.gd:32`) | `&"score"` | `MinigameDirector`, HUD, results screen |
| `StyleDirector` (`style_director.gd:27`) | `&"style"` | `MinigameDirector` (`apply_pack_id` / `revert_to_base`) |
| `ImpactDirector` (`impact_director.gd:37`) | `&"impact"` | `MinigameDirector` |
| `CameraDirector` (`camera_director.gd:70`) | `&"camera"` | `ImpactDirector` (`shake` / `fov_punch`) |
| `PostFXDirector` (`postfx_director.gd:56`) | `&"postfx"` | `MinigameContext` (`ctx.postfx`) |
| `AudioDirector` (`audio_director.gd:358`) | `&"audio"` | `MinigameContext` (`ctx.audio`) |
| `MusicDirector` (`music_director.gd:351`) | `&"music"` | `MinigameDirector`, `VoiceDirector` (duck) |
| `VoiceDirector` (`voice_director.gd:78`) | `&"voice"` | `MinigameContext` (`ctx.voice`) |
| `SFXPlayer` (`sfx_player.gd:80`) | `&"sfx"` | `ImpactDirector` (`play_impact`) |
| `PowerUpDirector` (`powerup_director.gd:21`) | `&"powerups"` | power-up spawner |
| `RouletteController` (`roulette_controller.gd:38`) | `&"roulette"` | wheel UI |
| `MinigameDirector` (`minigame_director.gd:40`) | `&"minigames"` | `MatchManager.start_minigame()` (`match_manager.gd:194`) |
| `SaveSystem` (`save_system.gd:22`) | `&"save"` | `SettingsManager` (`settings.gd:30`) |
| `SettingsManager` (`settings.gd:27`) | `&"settings"` | `CameraDirector._shake_scale()` (`camera_director.gd:129`) |
| `Player` (`player.gd:31`, via `register`) | `&"player"` | `CameraDirector`, `ScoreDirector`, `MinigameDirector`, power-ups |
| `MinigameRegistry` (`minigame_registry.gd:21`) | `&"registry"` | `MinigameDirector`, `RouletteController` |
| `CityBlock` (`city_block.gd:69`) | `&"block"` | power-up spawner (`powerup_spawner.gd:130`) |

Two services are registered rather than published, because they are not
autoloads:

- **`&"registry"`** — `MinigameRegistry.SERVICE_NAME`. Whichever system builds
  the catalog registers it
  (`minigame_director.gd:96`, `roulette_controller.gd:59`) so the director and
  the roulette share one instance.
- **`&"player"`** — `Player._register()` (`player.gd:24-31`) resolves
  `lookup(&"core")` and registers itself there.

`&"config"` is looked up by `ScoreDirector._load_config()`
(`score_director.gd:37`) and `SFXPlayer._refresh_from_config()`
(`sfx_player.gd:91`), but nothing publishes it at runtime: the only registration
lives in `MatchManager._register_self()` (`match_manager.gd:71-76`), which no
code calls. Both consumers therefore fall through to loading
`game_config.tres` from disk, which is why they still work.

This table is pinned by `tests/unit/test_service_registry.gd:13-30` (the
autoload → canonical-name map) and by
`tests/integration/test_stress_match.gd:937`, which scans `src/` and asserts
that every registered name has a consumer and every consumed name has a
publisher.

---

## Event bus: signals and payloads at a glance

The full per-signal table, with payload types and emitting sites, is in the
[EventBus](#eventbus-global-signal-bus) section above. In short, the sixteen
canonical events are:

| Event id | Signal | Payload |
| --- | --- | --- |
| `&"powerup_collected"` | `powerup_collected` | `minigame_id: StringName` |
| `&"roulette_started"` | `roulette_started` | — |
| `&"roulette_result"` | `roulette_result` | `id: StringName` |
| `&"minigame_started"` | `minigame_started` | `id: StringName` |
| `&"minigame_announced"` | `minigame_announced` | `meta: Resource` (`MinigameMetadata`) |
| `&"minigame_finished"` | `minigame_finished` | `result: MinigameResult` |
| `&"style_applied"` | `style_applied` | `pack_id: StringName` |
| `&"style_reverted"` | `style_reverted` | — |
| `&"score_changed"` | `score_changed` | `total: int, delta: int` |
| `&"combo_changed"` | `combo_changed` | `combo: int` |
| `&"impact_requested"` | `impact_requested` | `weight: int` |
| `&"match_time_up"` | `match_time_up` | — |
| `&"match_started"` | `match_started` | — |
| `&"match_reset"` | `match_reset` | — |
| `&"match_tick"` | `match_tick` | `time_left: float` (1 Hz) |
| `&"player_state_changed"` | `player_state_changed` | `state: StringName` |
| `&"voice_requested"` | `voice_requested` | `event_id: StringName` |

Two events are declared, mapped and consumed but have no gameplay emitter:
`impact_requested` (gameplay calls `ImpactDirector.impact()` directly, so the
signal would look inverted — see the `ImpactDirector` section) and
`voice_requested` (consumed by `AudioDirector`, but VO requests are made by
calling `VoiceDirector.speak()` directly).

---

## Contracts found missing or inconsistent

Documented, **not fixed** — every item below needs a decision from the team.

1. **There is no `PAUSED` state in `MatchManager.State`.** The enum is
   `BOOT, TITLE, COUNTDOWN, FREE_ROAM, ROULETTE, MINIGAME, STYLE_POP, TIME_UP,
   RESULTS` (`match_manager.gd:14-24`). Pausing is the pause menu setting
   `get_tree().paused` with `process_mode = PROCESS_MODE_ALWAYS`
   (`pause_menu.gd:34`), which is a tree-level pause rather than a match state.
   The behaviour is correct and covered by `tests/unit/test_pause_flow.gd`; the
   contract list just needs to say so explicitly rather than implying a
   `PAUSED` enum member.
2. **`MatchManager._register_self()` is dead code** (`match_manager.gd:71-76`).
   It is never called, so the `&"config"` service it registers is never
   published. `ScoreDirector` and `SFXPlayer` both look up `&"config"` first and
   fall back to loading `game_config.tres` from disk, which is why the bug is
   invisible. Either call it or delete it.
3. **`MatchManager` publishes `&"match"` twice** — in `_ready()`
   (`match_manager.gd:42`) and again in the dead `_register_self()`
   (`:72`). Harmless today because the second never runs, but it is the same
   registration duplicated.
4. **`HUDRecipe.primary_widget` documents a `METER` widget that does not
   exist.** The slot comment lists `COUNTER | TIMER | PROGRESS | SEQUENCE |
   METER` (`hud_recipe.gd:8`), but `WidgetFactory` implements
   `COUNTER | TIMER | PROGRESS | SEQUENCE | MULTIPLIER`
   (`widget_factory.gd:8-19`) — `MULTIPLIER` is the fifth widget, and `METER` is
   neither defined nor mapped. A `.tres` that asks for `METER` silently degrades
   to `COUNTER`.
5. **`SpawnRecipe.respawn` is declared but unused by any archetype.** The field
   exists (`spawn_recipe.gd:16`) and is part of the slot contract, but no
   archetype reads it; `MinigameArchetype.spawn_entity()` always appends a new
   node. Either an archetype honours it or the slot should say it is reserved.
6. **`MinigameMetadata.difficulty_curve` is declared but never read.** Every
   catalog entry sets it to `null` and no archetype consumes it; difficulty
   scaling is done through `SpawnRecipe.resolve_count()` and `_slot_value()`
   instead. The field is currently inert.
7. **`ImpactFrame.model_freeze` and `ImpactFrame.slow_mo_curve` are declared but
   not driven.** `ImpactDirector.impact_frame()` does not read either
   (`impact_director.gd:66-99`); the hitstop uses the scalar `time_scale` only.
8. **`StylePack` declares several fields `StyleDirector` never applies.**
   `sky_top`, `sky_horizon`, `fog_color`, `fog_density`, `sun_color`,
   `sun_energy`, `ambient_color`, `ambient_energy`, `character_material`,
   `environment_material`, `fov_override`, `camera_offset`, `hud_theme` and
   `revert_to_base_on_end` are all part of §7.5, but the director only blends
   glow/bloom/saturation from `postfx` and sets `style_uniforms`
   (`style_director.gd:105-172`, `:135-141`). The revert path is also hardcoded
   rather than honouring `revert_to_base_on_end`. The visual result is
   consistent, but the Resource advertises more than the director implements.
9. **`GameLoopDriver` resolves by `/root/<AutoloadName>`, not by canonical
   service name.** `_resolve()` (`game_loop.gd:45-49`) looks the node up by
   autoload path. It does not *reference* another autoload's class or variable,
   so it does not break AGENTS.md §1.1's letter, but it is the one consumer that
   bypasses the registry the rest of the game uses.
10. **`impact_requested` and `voice_requested` are declared, mapped and consumed
    with no gameplay emitter.** See the EventBus section. Keeping them is
    defensible (they document the intended decoupling), but they are currently
    dead ends.
11. **Several generated node names are placeholder human names**, e.g.
    `"VoicePlayer"` on the VO player (`voice_director.gd:243`),
    `"Elena Mercery"` on a registry built at runtime
    (`minigame_director.gd:92` and `roulette_controller.gd:57`), and
    `"ZoneMarker"` / `"PickupShape"` on the entity's mesh and collision shape
    (`minigame_entity.gd:86,146`). Cosmetic, but they read as leftovers and make
    debugging the node tree harder.

---

## Change protocol

`scaffold.md` §7 opens with the governing statement:

> Canonical copy in `docs/architecture/contracts.md`. These contracts are
> **stable**: changing them requires updating this file, the doc and the tests.

`AGENTS.md` §0 states it as a hard precondition:

> 3. **Do not invent contracts.** Every gameplay system is a contract (§7).
>    If your task needs a new contract or a change to an existing one:
>    - document it in `docs/architecture/contracts.md`,
>    - update `scaffold.md` §7,
>    - add/adjust the contract's GUT test,
>    - and state it explicitly in your PR/commit.

`AGENTS.md` §9 repeats it for commits:

> - If you touched a contract: say so in the commit body and update
>   `docs/architecture/contracts.md` + `scaffold.md` §7.

`AGENTS.md` §1.2 names the contracts that are stable and the required
artefacts:

> - `Minigame`, `MinigameContext`, `MinigameMetadata`, `MinigameResult`,
>   `StylePack`, `StylePostFX`, `ImpactFrame` are **stable**. Changing them
>   requires updating doc + tests + scaffold, and saying so in the commit.

`scaffold.md` §16 lists the anti-pattern that this protocol exists to prevent:

> - Breaking a contract without updating `docs/architecture/contracts.md` and
>   tests.

### So, when a contract changes

In order, all of these:

1. **Write or adjust the test first** (AGENTS.md §2 step 2): RED before GREEN.
   A contract change without a test change is not a contract change, it is a
   regression.
2. **Update `docs/architecture/contracts.md`** — this file. Update the
   signatures, the guarantees, and the publisher/consumer and test-coverage
   notes for the affected contract.
3. **Update `scaffold.md` §7** (and §6 when the change is to a core system), so
   the design brief and this document do not drift apart.
4. **State it explicitly in the commit body**, naming the contract that changed
   and why (AGENTS.md §9).
5. **One commit = one cohesive change** — do not mix a contract change with a
   refactor or a feature (AGENTS.md §9).

For a change that *adds* a contract rather than altering one, the same four
artefacts apply, plus: if it is a new autoload, `project.godot`
`[autoload]` and the registry table in this file; if it is a new event,
`EventBus.signal_name_for()` and the event table above; if it is a new service,
`GameServices.publish()` at boot and the `SERVICES` map in
`tests/unit/test_service_registry.gd`, which will otherwise fail with the
"resolved but never registered" assertion.
