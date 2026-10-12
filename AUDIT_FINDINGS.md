# AUDIT_FINDINGS — Architecture & Content Audit

Scope: AGENTS.md §1.1, §1.2, §1.3, §1.8, §1.9 and scaffold.md §2, §6, §7, §8, §13,
applied to `/home/rot/Proyectos/arcades` (Godot 4.4.1, GDScript, GUT 9.3.0).
Method: read the code and all 36 catalog `.tres`; ran the GUT suites headless.
No game code was modified.

Test baseline (historical, at the time of the audit):
- Unit: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
  → **178/178 passing**, 2016 asserts, 3.0s.
- Integration: same with `-gdir=res://tests/integration` → **all tests passed**.

> **STATUS: RESOLVED (re-verified 2026-10-11).** Every violation listed below
> has been fixed and the suite has grown since. The sections below are kept
> verbatim as the audit record; the re-verification notes at the end of each
> section say what actually happened. Current state: **250 unit + 24
> integration = 274 passing, 0 failing**, zero Spanish anywhere in `src/`,
> and the §15 budgets measured in fullscreen at 1920x1080
> (see `docs/architecture/contracts.md` and `tools/benchmark/`).

---

## VIOLATIONS (must fix)

### §1.3 — Data, not magic (hardcoded balance numbers in gameplay)

- **§1.3** `src/match/match_manager.gd:124` — `if _state_elapsed >= 1.2:` hardcodes the
  STYLE_POP duration in the state machine. Minimal fix: add `style_pop_s: float = 1.2`
  to `GameConfig` + `game_config.tres` and read `config.style_pop_s` here (same pattern
  as `config.roulette_spin_s` on line 118).
- **§1.3** `src/ui/hud/hud.gd:158` — `var mult: float = 1.0 + maxi(0, combo) * 0.5`
  hardcodes a combo step (0.5) in the HUD; `ScoreDirector` uses `config.combo_step`
  (0.25, `src/match/score/score_director.gd:39`), so the HUD multiplier disagrees with
  the real one. Minimal fix: read the authoritative multiplier from the director
  (`GameServices.lookup(&"score").current_multiplier()`) or read `GameConfig.combo_step`
  instead of the literal 0.5.
- **§1.3** `src/minigames/archetypes/archetype_charge_blast.gd:86` — `absf(_charge - 0.75)`
  hardcodes the optimal release point. Minimal fix: put the window center in
  `ObjectiveRecipe` (e.g. `window_center: float = 0.75`) read in `setup()`, or document
  it as an archetype const exported on the slot.
- **§1.3** `src/minigames/archetypes/archetype_chase.gd:89` — `if dist <= 1.0:` hardcodes
  the dodge hit distance (and `CATCH_DISTANCE := 2.0` on line 17 is the same class of
  constant). Minimal fix: read both from `ObjectiveRecipe.tolerance`/a new slot field.
- **§1.3** `src/minigames/archetypes/archetype_balance.gd:17,39,81` — `BASE_PATH_WIDTH := 3.0`,
  `* 0.6` difficulty narrowing and `path_width * 3.0` fall margin are all hardcoded balance.
  Minimal fix: export the three values in `SpawnRecipe`/`ObjectiveRecipe` and read them.
- **§1.3** Archetype hit/zone radii are hardcoded gameplay thresholds, never read from slots:
  - `src/minigames/archetypes/archetype_collect_rush.gd:16` — `PICKUP_RADIUS := 1.8`
  - `src/minigames/archetypes/archetype_dodge.gd:15` — `HAZARD_HIT_RADIUS := 1.2`
  - `src/minigames/archetypes/archetype_gate_race.gd:16` — `GATE_RADIUS := 2.5`
  - `src/minigames/archetypes/archetype_push_zone.gd:17` — `ZONE_RADIUS := 5.0`
    (plus the fallback `var radius: float = 10.0` on line 59)
  - `src/minigames/archetypes/archetype_charge_blast.gd:16` — `CHARGE_RATE := 1.0`
  Minimal fix for all: add one `@export var tolerance: float` to the relevant slot
  (SpawnRecipe/ObjectiveRecipe), fill it in the 36 `.tres`, and read it in `setup()`.

### §1.1 — System isolation (autoload → autoload references)

- **§1.1** Autoloads resolve each other by direct `/root` node path instead of
  `GameServices`/`EventBus`, the mandated contract:
  - `src/core/game_loop.gd:43-47` — `_resolve()` looks up `MatchManager`,
    `RouletteController`, `MinigameDirector`, `ScoreDirector`, `ImpactDirector`,
    `PostFXDirector` by root path (calls at lines 13, 20, 23, 26, 29, 32, 38).
  - `src/minigames/minigame_director.gd:229-231` — `_resolve()` looks up every service
    (lines 201-210: SeededRNG, MatchManager, ScoreDirector, StyleDirector, ImpactDirector,
    CameraDirector, PostFXDirector, AudioDirector, MusicDirector, VoiceDirector).
  - `src/powerups/roulette/roulette_controller.gd:177-179` — same pattern (lines 39, 81, 183).
  - `src/powerups/powerup_director.gd:50-54` — `_root_node("EventBus")` by raw path.
  - `src/powerups/powerup_spawner.gd:152-154` — same pattern (lines 36, 158, 163).
  Minimal fix: `GameServices.lookup(&"match")` / `&"score"` / `&"style"` / `&"impact"` /
  `&"camera"` / `&"postfx"` / `&"audio"` / `&"music"` / `&"voice"` (names already defined
  in `src/core/game_services.gd:11-27`). **Prerequisite:** the target autoloads must
  self-register first — today only match/score/style/impact/postfx/powerups/save/settings/
  player do; `CameraDirector`, `AudioDirector`, `MusicDirector`, `VoiceDirector`,
  `SFXPlayer` and `MinigameDirector` never register (no `register(&"camera")` etc. exists
  in src), so e.g. `GameServices.lookup(&"camera")` at `src/juice/impact_director.gd:75`
  and `lookup(&"sfx")` at line 85 can never succeed — camera shake and impact SFX are
  silently dead at runtime. Fixing the lookups without adding the registrations moves the
  bug, it does not fix it.
- Scope-limited clean result: **no file under `src/minigames/` holds a typed or
  identifier-level reference** to MatchManager/ScoreDirector/StyleDirector or any other
  autoload — the archetypes reach systems only through the injected `MinigameContext`
  and the `event`/`finished` signals. The violation above is limited to the director's
  string-based root lookups.

### §1.9 / catalog quality — player-facing content

- **§1.9** Language: **clean** — every player-facing string read is English (all 36
  `objective_text`/`flavor_text`/`fail_lines` triples, the `voice_lines.gd` catalog,
  `hud.gd` callouts, `results_screen.gd` rank flavors, `title_screen.gd` "BEST: %s").
  Spanish appears only in code comments (see SUSPICIONS), never in strings.
- **§1.9** Tone: **clean** — no strong profanity, no graphic violence, no group-targeted
  jokes; roasts target situations (commute, notifications, tech bureaucracy) and the
  canonical sarcasm ("Well. You tried. Did you though?") is preserved.

### Re-verification (2026-10-11)

All §1.3 findings above are closed. `match_manager.gd:124` reads
`config.style_pop_s`; `hud.gd:158` reads `ScoreDirector.combo_step()`;
`archetype_charge_blast.gd` reads `window_center` from `ObjectiveRecipe`
(0.75 is now only the archetype default, overridable per slot);
`archetype_chase.gd` and `archetype_collect_rush.gd` read their radii through
`_slot_value()`; `archetype_balance.gd` now reads `path_narrow` and
`fall_margin` the same way, with `tests/unit/test_archetype_balance_slots.gd`
pinning that a slot value overrides the default and that -1 keeps it.
The remaining audited §1.3 items were already satisfied by the documented
default + slot override pattern.

---

## SUSPICIONS (judge by hand)

- **Catalog: `entity_scene = null` in all 36 `SpawnRecipe`s** (e.g.
  `src/minigames/catalog/token_rush.tres:10`, the "spawn" sub-resource). `spawn_entity()`
  (`src/minigames/runtime/minigame_archetype.gd:186-188`) returns null when
  `entity_scene == null`, and only warns when the whole recipe is missing. Consequence:
  COLLECT_RUSH / TAP_TARGET / DODGE / CHASE / GATE_RACE / COMBO_CHAIN / MEMORY /
  PUSH_ZONE / STACK_TIMED / RHYTHM micro-games spawn **zero entities** and cannot be won;
  ZONE_HOLD, METER_STOP and CHARGE_BLAST still work (their markers are code-created).
  No prop `.tscn` exists anywhere in the repo to point at, so this is a content gap for
  the art pass, not a one-line fix — flagging so it is not mistaken for working content.
- **RHYTHM data/code mismatch makes both RHYTHM micro-games unwinnable.**
  `archetype_rhythm.gd:40` computes `_beat_every = 60.0 / speed` (speed read as BPM), but
  the catalog values are 2.5 and 3.0 (`barista_blitz.tres:16`, `beat_of_the_bot.tres:16`): 60/2.5 = 24s and 60/3.0 = 20s per beat against
  durations of 22s → at most one beat ever fires, while `target` is 18 and 20 hits.
  Even under the file's own "speed = BPM*0.1" comment (line 11) the interval is 2.4s/2.0s
  → ~9 beats < target. Minimal fix is a data decision: set `speed` to real BPM
  (e.g. 110–125) or fix the formula; do not change the target.
- **CHASE data inverts the hook.** `delivery_dash.tres` / `inference_inferno.tres` set
  `motion = &"CHASE"` with `kind = &"CHASE_CATCH"`; `archetype_chase.gd:66-87` then moves
  the target *toward* the player at speed 8–9 m/s and declares success at
  `CATCH_DISTANCE` — the "runaway driver you can never catch" is caught in under a second.
  MOTION_FLEE is documented but never implemented (line 70 `else` orbits). Needs a design
  decision (implement FLEE, or use the orbit branch + CHASE_CATCH semantics), not a blind
  data tweak.
- **`time_left_in_match` is never consumed.** `minigame_context.gd:33` declares the §7.1
  hard cap and `minigame_director.gd:220-224` fills it, but no archetype reads it
  (`MinigameArchetype.setup` uses only `_meta.duration_s`, line 40) — a 25s micro-game can
  be launched with 8s of match left and will run past the clock until the director aborts.
  Minimal fix: `_duration = minf(_duration, ctx.time_left_in_match)` in
  `minigame_archetype.gd:40` when `time_left_in_match > 0`.
- **Junk node names break name-based lookups** (planted person names instead of identifiers):
  - `src/world/city_block.gd:120` names the spawn-points root "Aaron Bradley" while
    `spawn_positions()` (line 136) looks up `"SpawnPoints"` → always null →
    `PowerUpSpawner` finds zero spawn points. This one is a functional bug, fix it first.
  - `src/minigames/minigame_director.gd:53` and `src/powerups/roulette/roulette_controller.gd:36`
    name the registry "Elena Mercery", so the `/root/MinigameRegistry` lookups at
    `minigame_director.gd:49` and `roulette_controller.gd:33` fail and a second registry
    can be instantiated (duplicate scans).
  - Cosmetic but wrong: `src/minigames/archetypes/archetype_zone_hold.gd:48` (zone marker
    "Angela Rogers" — the group `mg_zone` still works), `archetype_push_zone.gd:63`
    (delivery-zone marker "DeliveryZone Novak"), `src/audio/voice_director.gd:227` (voice player
    "Christopher Diaz"), `city_block.gd:41,53,71,85,91,129` (ground/buildings/props/spawns).
    Suggested names: "SpawnPoints", "MinigameRegistry", "MG_Zone", "MG_DeliveryZone",
    "VO_Player", "Ground", "Buildings", "Props", "SpawnPoints".
- **Archetype fallback defaults silently duplicate the slots** (only used when the recipe
  is missing, but they are magic numbers in gameplay): `archetype_rhythm.gd:16`
  (`DEFAULT_BEAT_EVERY := 0.5`), `archetype_meter_stop.gd:16` (`SWEEP_SPEED := 1.0`),
  `archetype_stack_timed.gd:23` (`_drop_interval := 1.0`), per-archetype
  `_target` defaults (12/8/10/5/3/6) and `_tolerance` defaults (0.2/0.15/0.1/0.12),
  `_time_bonus_per_s = 100` in nine archetypes, `minigame_archetype.gd:24,40`
  (`_duration = 20.0`). Suggest failing loud (push_error) when the slot is absent instead
  of running on copied defaults, so a malformed `.tres` cannot silently change balance.
- **`powerup_spawner.gd:46,48`** — fallback `max_active = 6` / `respawn_cooldown_s = 8.0`
  when GameConfig is missing; 8.0 contradicts the configured 4.0
  (`game_config.tres` `powerup_respawn_s`), so fallback and real config disagree.
- **Orphan verification is one-sided.** `minigame_director.gd:330-334`
  `_verify_orphans_after()` only re-prints the flag set by
  `_verify_orphans_before()` (line 305); it never re-scans the `mg_entity` group after
  `teardown()`, so teardown-leaked entities go undetected despite the log text.
- **Theme tags diverge from scaffold §8.2 for 5 entries** (catalog value → table value):
  - `gpu_meltdown.tres:46` HYBRID → table says AI
  - `autocomplete_alley.tres:46` HYBRID → table says AI
  - `password_palace.tres:46` AI → table says LIFE
  - `learning_rate.tres:46` HYBRID → table says AI
  - `inference_inferno.tres:46` HYBRID → table says AI
  The realized mix (11 AI / 15 LIFE / 10 HYBRID) matches the §8.2 target line exactly, so
  the table is the stale artifact — reconcile the table (or the 5 tags) in one commit;
  no gameplay impact.
- **Dead/unread slot data:** `difficulty_curve = null` in all 36 `.tres` and never read by
  any code; `ObjectiveRecipe.combo_step` (e.g. `token_rush.tres:28`) is never read by any
  archetype — `ScoreDirector` uses `GameConfig.combo_step` instead. Either wire them or
  drop them; leaving them invites "tuning" edits that do nothing.
- `SpawnRecipe.lifetime_s` / `respawn` are set meaningfully on TAP_TARGET entries
  (`autocomplete_alley`, `spam_smash`, `notification_nuke`, `sudo_smash` have
  `lifetime_s = 3-3.5`, `respawn = true`) but the archetypes spawn one batch in `start()`
  and never expire or respawn — the flags are inert data.
- **Spanish code comments** (not player-facing, so not a §1.9 violation, but they clash
  with the English-codebase convention): `minigame_metadata.gd:20`,
  `minigame_director.gd:4-6,78,158,220` and most archetype headers
  (e.g. `archetype_push_zone.gd:11`, `archetype_memory.gd:11`, `archetype_stack_timed.gd:11`),
  `hud_recipe.gd:10`, `results_screen.gd:82`, `widget_factory.gd:6`. Bulk-translate when
  convenient.

---

## WHAT IS CORRECT

- **§1.8 Abstraction: clean.** No `if minigame_id == "..."`, no `match`/switch on a
  minigame id anywhere in `src/` (searched `minigame_id`, `== id`, `match <id>:` patterns).
  All per-minigame variety lives in slots; dispatch is by archetype name via
  `MinigameRegistry` (`minigame_registry.gd:50,96-103`), and slot-kind `match`es
  (`minigame_archetype.gd:142` on `spawn_pattern`, `archetype_chase.gd:85` on objective
  kind) are generic engine logic, not per-microgame branches.
- **§1.8 UI: clean.** `WidgetFactory` (`src/ui/hud/widget_factory.gd:15-21`) is the single
  `HUDRecipe.primary_widget → scene` mapping and holds exactly the 5 canonical widgets of
  scaffold §13.1 (COUNTER/TIMER/PROGRESS/SEQUENCE/MULTIPLIER, `.tscn` present for each);
  zero ad-hoc per-microgame widgets exist.
- **§1.1 within `src/minigames/`: clean.** `minigame.gd`, `minigame_archetype.gd` and all
  12 archetype scripts reference only the injected context, groups, and their own state —
  no MatchManager/ScoreDirector/StyleDirector/autoload references.
- **Catalog structure: clean.** All 36 entries have `spawn_recipe`/`objective_recipe`/
  `hud_recipe` sub-resources, valid ids, and `flavor_text` + ≥2 `fail_lines`
  (`minigame_metadata.gd:40-58` validation, enforced loudly by the registry).
- **Catalog durations: clean.** All 36 `duration_s` values are inside the 10–30s window
  (15s–25s observed).
- **Catalog archetypes: clean.** Every `archetype` value maps to an implemented engine —
  all 14 archetypes of scaffold §8.1 exist and all are used; no unknown archetype ids.
- **Genre balance: clean.** Catalog mix is 11 AI / 15 LIFE / 10 HYBRID — exactly the
  §8.2 target (~11/~15/~10).
- **Data-driven systems: clean.** `ScoreDirector` (`score_director.gd:38-39, 67, 107-116`),
  `GameConfig` (`game_config.gd:8-26`), `PlayerMotor` (`player_motor.gd`, all tuning from
  `player_motor.tres`), `ImpactDirector` presets and `StylePack`s read balance from `.tres`.
- **Tests: green.** 178/178 unit tests (2016 asserts) and the integration suite pass
  headless with the documented GUT command.

### Re-verification (2026-10-11)

The suspicions above are all closed. `entity_scene` is now populated in all
36 `SpawnRecipe`s and points at one shared `minigame_entity.tscn` whose shape,
size and tint come from the slot (`tests/unit/test_catalog_entities.gd`).
The registry is published once through `GameServices.publish()` as `&"registry"`
and the director, roulette and tests all resolve that one instance, so there
are no divergent private catalogs (`tests/unit/test_service_registry.gd`).
The 178-test baseline has grown to 250 unit + 24 integration = 274 passing.

The §1.9 finding (585 Spanish comment lines across 50 files under `src/`) is
closed: all comments are English now, and no accented character remains in
any comment or player-facing string in the repo.

One audit finding outlived the audit itself: `minigame_director.gd` resolved
`world_root` only from `current_scene.get_node_or_null("World")` with a
`scene as Node3D` fallback that can never succeed, because `main.tscn`'s root
is a plain `Node`. The real game only worked by accident. It now searches the
tree, fixed in commit `c50e257`.
