# Orchestration Ledger — ARCADE BLOCK

> The orchestrator (me) keeps this file authoritative. Subagents: do NOT edit
> this file. Append your deliverable notes to `ORCH_NOTES.md` instead.

## Environment (verified by orchestrator)

- Godot 4.4.1 headless: `/home/rot/bin/godot` (on PATH via `export PATH="/home/rot/bin:$PATH"`)
- Blender 5.2.2: `/usr/bin/blender`
- GUT 9.3.0: vendored at `addons/gut/`
- Run tests:  `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`
- Run project: `godot --headless --quit` (checks autoloads/scenes load)

## Ground rules (from AGENTS.md — enforced)

1. Read `scaffold.md` FULLY before writing code.
2. Minigames are DATA (.tres over archetypes + slots). Never `if minigame_id == ...`.
3. No gameplay system references another autoload directly: GameServices or EventBus.
4. Zero hardcoded balance numbers: everything in .tres.
5. Tests first (GUT), determinism via SeededRNG, clean teardown.
6. Game text in English; team docs in Spanish.
7. Do not touch: project.godot [autoload] (orchestrator only), ORCH_LEDGER.md,
   another subsystem's folders, addons/gut/.
8. Keep the project importable at all times: after your work,
   `godot --headless --import` must show no NEW errors.

## Integration contract (for the WAVE 2 integration agent + orchestrator)

When all wave-1 notes have landed, the orchestrator registers autoloads in
project.godot in this canonical order (alphabetical within the block; the
`[autoload]` section must contain NO comments):

```
EventBus="*res://src/core/event_bus.gd"
GameServices="*res://src/core/game_services.gd"
SeededRNG="*res://src/core/rng/seeded_rng.gd"
ObjectPool="*res://src/core/pooling/object_pool.gd"
MatchManager="*res://src/match/match_manager.gd"
ScoreDirector="*res://src/match/score/score_director.gd"
StyleDirector="*res://src/styles/style_director.gd"
ImpactDirector="*res://src/juice/impact_director.gd"
CameraDirector="*res://src/juice/camera_director.gd"
PostFXDirector="*res://src/juice/postfx_director.gd"
AudioDirector="*res://src/audio/audio_director.gd"
MusicDirector="*res://src/audio/music_director.gd"
VoiceDirector="*res://src/audio/voice_director.gd"
SFXPlayer="*res://src/audio/sfx_player.gd"
PowerUpDirector="*res://src/powerups/powerup_director.gd"
RouletteController="*res://src/powerups/roulette/roulette_controller.gd"
MinigameDirector="*res://src/minigames/minigame_director.gd"
SaveSystem="*res://src/systems/save_system.gd"
SettingsManager="*res://src/systems/settings.gd"
```

Rules for the integration pass:
1. Verify every referenced path EXISTS before registering (godot --headless
   --quit fails hard on missing autoloads).
2. After registering: godot --headless --quit must be clean.
3. main.tscn wires: World (city_block instance), player instance, UI HUD,
   camera rig (CameraDirector creates its own Camera3D if scene has none).
4. Full GUT suite must pass: godot --headless -s addons/gut/gut_cmdln.gd -gexit
   (whole tests/ directory).

## Orchestration status

- WAVE 1 (Fase 0/1 foundations) — DISPATCHED, running in parallel:
  - sa-0-8d910544 — Core + Match + Score
  - sa-0-04f958a1 — Styles + Juice
  - sa-0-a871eeb3 — Player + World
  - sa-0-8379a738 — Audio
  - sa-0-3e605111 — PowerUps + Minigames framework
- WAVE 2 (pending wave 1 notes): UI/HUD agent, minigame catalog content agent
  (36 .tres), art agent (Blender props), integration agent (wire everything into
  main.tscn + register autoloads + full-suite GUT).
- After wave 2: orchestrator review pass (verify all gates, fix integration
  issues), final report to user.

## Git

- Repo initialized by orchestrator; commit 1 = toolchain + bootstrap + docs.
- Agents do NOT need to commit; orchestrator commits checkpoints between waves.

## Shared conventions (every agent MUST follow)

- GDScript, static typing mandatory. Tabs for indent. snake_case vars/funcs,
  PascalCase classes/Resources, SCREAMING_SNAKE constants. English identifiers.
- Every system autoload script lives at the canonical path from scaffold.md §4
  and registers itself in GameServices with its canonical name.
- Every new .tres resource has an `[resource]`-compatible header written by the
  Godot format; when hand-writing .tres, include `script_class` reference and
  load-verify via a GUT test that does `load("res://...")` + null check.

## Verified environment quirks (learned by orchestrator)

- `project.godot` does NOT allow comments inside [autoload]: lines like
  `# note=...` are parsed as autoload entries and break boot. Keep that
  section empty until systems land; orchestrator registers autoloads.
- Hand-written `.tscn` ext_resource ids must be non-numeric strings
  (`id="main_gd"`); numeric ids like `id="1"` break loading.
- Autoload order matters (searched before systems): EventBus and GameServices
  must be first in the list.
