# AGENTS.md — Agent Directives

> This file governs HOW any agent (AI or human) works in this repo. Read it
> together with `scaffold.md` (the WHAT/WHY). If the two conflict, `scaffold.md`
> wins on architecture and contracts; this file wins on process and discipline.

> **Game language:** all player-facing content (names, HUD, objectives, flavor
> text, fail lines, VO) goes in **English**. Team docs and internal identifiers
> follow the conventions of `scaffold.md` §16.

---

## 0. BEFORE WRITING A SINGLE LINE

1. **Read `scaffold.md` in full.** No exceptions. It is the master brief.
2. **Locate your task in the roadmap** (§14) and respect the phase gate.
3. **Do not invent contracts.** Every gameplay system is a contract (§7).
   If your task needs a new contract or a change to an existing one:
   - document it in `docs/architecture/contracts.md`,
   - update `scaffold.md` §7,
   - add/adjust the contract's GUT test,
   - and state it explicitly in your PR/commit.
4. **Determinism.** All logic with randomness (roulette, spawns, micro-games)
   must be reproducible with `SeededRNG` and a fixed seed. Tests first.
5. **Abstraction first (§8.0).** A micro-game is DATA, not code. If your
   task leads you to write logic specific to a micro-game, STOP: the
   abstraction is incomplete. Extend the archetype or the slot, not the
   micro-game. The Phase 4.5 gate verifies this.

---

## 1. HARD RULES (violating them = rejecting the deliverable)

### 1.1 System isolation
- **No micro-game** references `MatchManager`, `ScoreDirector`,
  `StyleDirector`, etc. directly. Use the injected `MinigameContext`.
- **No autoload** references another autoload directly: use
  `GameServices.get(&"name")` or `EventBus`.
- **No frame-by-frame gameplay via signals** if order matters; there the call
  is direct. Signals are for event decoupling.

### 1.2 Contracts
- `Minigame`, `MinigameContext`, `MinigameMetadata`, `MinigameResult`,
  `StylePack`, `StylePostFX`, `ImpactFrame` are **stable**. Changing them
  requires updating doc + tests + scaffold, and saying so in the commit.
- A micro-game ends ONLY via `finished(result)` or an abort by the director.
- Every micro-game runs with the same cycle: `setup → start → update →
  on_input → teardown`. Do not use direct `_process`/`_physics_process` unless
  the archetype documents it.

### 1.3 Data, not magic
- **Zero hardcoded balance numbers** in gameplay. All tuning lives in
  `.tres` (minigame metadata, style packs, impact frames, configs).
- If you tweak a value "because it felt right", it goes into a `.tres` with a
  comment.

### 1.4 Cleanliness
- After a micro-game's `teardown()`: **not a single orphan entity**, no dirty
  global state, no dangling timers. The world is left as it was found.
- Return objects to the pool; never `queue_free()` on the fly unless necessary.

### 1.5 Assets
- **Never edit `.glb`, mixed `.wav`, or hand-exported assets.** The
  source is Blender/the DAW; it is re-exported. Godot only imports.
- Sources in `assets/art/blender/`, exports in `assets/art/models/`.

### 1.6 Do not break the build
- Every deliverable must import/compile with no new warnings.
- If the project does not compile, your task is not done.

### 1.8 Abstraction (hard architecture rule)
- **No `if minigame_id == "..."` / switch by ID in gameplay.** The variety of
  micro-games lives in the **slots** (`SpawnRecipe`, `ObjectiveRecipe`,
  `HUDRecipe`), not in conditional code.
- A mechanistically covered new micro-game is **one `.tres`, zero code**.
- If code is needed: it is a new archetype (a reusable generic engine) or the
  extension of a slot — never a script with the logic of a single micro-game.
- All objective UI is auto-generated from `HUDRecipe`. **Zero ad-hoc
  widgets** per micro-game (fixed library of 5 widgets, §13.1).

### 1.9 Content language and tone (hard rule)
- **All player text in English** (names, HUD, objectives, flavor text,
  fail lines, VO). Do not mix Spanish into game strings.
- Tone follows the voice guide of `scaffold.md` §2: short, fast,
  self-aware, friendly humor. The announcer is sarcastic but NEVER cruel.
- **Sensitivity:** absurd humor, no strong profanity, no graphic violence,
  no jokes aimed at groups of people. The jokes target *situations*
  (tech bureaucracy, commute, notification anxiety).

---

## 2. WORKFLOW OF A TASK

1. **Understand** the contract/architecture involved (scaffold §6, §7).
2. **Write the test first** if the task has testable logic
   (score, roulette, RNG, timers, archetype contracts). RED before GREEN.
3. **Implement** the minimum that satisfies the contract.
4. **Verify** with the roadmap's phase gate (§14) and, if applicable, with the
   DoD gates (§15).
5. **Document**: entry in `docs/design/minigames.md` (if it is a micro-game),
   contract comment in the code, and a note in the commit if you touched a
   contract.
6. **Profile** if your task touches frame gameplay: steady 60fps, budgets
   from §15.

---

## 3. IMPLEMENTING A MICRO-GAME (checklist)

- [ ] Is there an archetype (§8.1) that covers the mechanic? → if yes, only `.tres`.
- [ ] If not: create/extend an archetype in `src/minigames/archetypes/` + test
      (a reusable generic engine, NOT a micro-game script).
- [ ] Define `MinigameMetadata.tres` filling the slots:
      - `spawn_recipe`: entity_scene, count, pattern, motion, speed.
      - `objective_recipe`: kind, target, tolerance, fail_on, time_bonus.
      - `hud_recipe`: primary_widget (of the 5 generic ones), icon, color_hint.
      - `input_mode`, `style_pack_id`, `music_state`.
- [ ] Content in English: `objective_text`, `flavor_text` (1-line joke),
      `fail_lines` (2-3 comedic variations), `theme_tag` (AI/LIFE/HYBRID).
- [ ] The joke reads in <2s and reinforces legibility.
- [ ] Victory AND failure conditions clear, legible in the HUD.
- [ ] At least 3 impact spikes (start / hits / end) with an `ImpactFrame`
      preset (no hardcoded numbers).
- [ ] Playable with keyboard, mouse AND gamepad (see `input_mode`).
- [ ] Determinism with a fixed seed (GUT test).
- [ ] Clean teardown (pool, timers, entities).
- [ ] **ZERO new gameplay code** (if there is any, an archetype/slot was extended
      and documented — see §1.8).
- [ ] Entry in `docs/design/minigames.md` (with flavor text and fail lines).
- [ ] Passes the DoD gates (§15), including abstraction (§8.0), UI (§13.1)
      and language/tone (§1.9).

---

## 4. IMPLEMENTING A STYLE PACK (checklist)

- [ ] `StylePack.tres` in `src/styles/packs/` with palette, materials, postfx,
      music, HUD theme, transition.
- [ ] Reversible: when the micro-game ends it returns to the base style with no
      artifacts.
- [ ] Coordinates: world (materials/uniforms), postfx, camera (FOV/offset),
      music (music_state), HUD (theme).
- [ ] Prefer `SHADER_UNIFORM` (cheap, no pop); `FULL_SWAP` only if the
      change of look is drastic.
- [ ] Documented in `docs/design/art-bible.md`.

---

## 5. JUICE AND AUDIO

- Every impact goes through `ImpactDirector` with a `.tres` preset
  (`ImpactFrame`). Do not insert ad-hoc hitstop/shake/flash in gameplay.
- Music is governed by `MusicDirector` (states + intensity). Do not
  play music outside of it.
- SFX always via `SFXLibrary`/`SFXPlayer` (pool, priority, voice limit).
- Announcer (VO) only via `VoiceDirector`, only on match state events
  (roulette, GO, combo, time, rank, fails). Respect the catalog in
  `voice_lines.gd`; do not oversaturate (cooldown per event, never two voices at once).

---

## 6. TESTS (GUT)

- Pure logic (score, combo, deterministic RNG, timers, registry) → unit
  tests in `tests/unit/`.
- Full match flow (boot → countdown → freeroam → roulette →
  micro-game → results) → headless integration in `tests/integration/`.
- Every contract (archetype) has a lifecycle test.
- Tests are fast and deterministic; no GPU dependencies if possible.

---

## 7. PERFORMANCE AND BUDGETS

Before considering a gameplay/visual task done:
- Steady 60fps on target hardware (verified with the Godot monitor).
- < 400 draw calls, < 250k tris/frame, < 32 simultaneous SFX voices.
- No GC spikes from massive `queue_free()` (use pooling).
- Textures and audio within budget (see §15).
- If it fails: profile, optimize (LOD, instancing, pooling, shared
  materials) and measure again.

---

## 8. ACCESSIBILITY (part of the DoD, not an extra)

All content must work with:
- Remappable input (keyboard / mouse / gamepad).
- Adjustable shake intensity and an option to disable flashes.
- Colorblind indicators for objectives/dangers.
- Visual signals in addition to voice (subtitled callouts).
- Text speed and HUD legibility.

---

## 9. GIT AND COMMUNICATION

- Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`,
  `perf:`, `art:`, `chore:`.
- One commit = one cohesive change. Do not mix refactor with feature.
- If you touched a contract: say so in the commit body and update
  `docs/architecture/contracts.md` + `scaffold.md` §7.
- Git LFS for binary assets (`.blend`, `.glb`, large `.wav`, textures).
- Do not upload generated/provisional assets that clutter the repo.

---

## 10. WHEN IN DOUBT

- **Architecture/contract** → `scaffold.md` §6/§7. Follow the contract; do
  not improvise a parallel one.
- **Micro-game mechanic** → `docs/design/minigames.md`.
- **Tone/humor of a text** → voice guide in `scaffold.md` §2.
- **Look/style** → `docs/design/art-bible.md` + `src/styles/packs/`.
- **Audio** → `docs/design/audio-design.md`.
- **Balance** → the `.tres` files are the source; do not touch code to rebalance.
- **If none of the above answers your doubt and the decision is irreversible**
  (changes a contract, a pipeline, a platform): **ask before
  implementing.**

---

## 11. DEFINITION OF "DONE"

A task is done when:
1. The code imports/compiles with no new warnings.
2. The relevant tests pass (and the new ones are written).
3. It passes the DoD gates (§15) that apply to its type.
4. It complies with the hard rules of §1 (isolation, contracts, data, cleanliness,
   abstraction, language/tone).
5. It is documented (docs/ + contract comments).
6. Performance verified (if it touches frame/perf).
7. Accessibility covered (§8).

**Abstraction test (for micro-game tasks):** the micro-game works
being only its `.tres`, with no new gameplay code or ad-hoc UI widgets.
If it fails this, it is not done — the abstraction is fixed first.

If you cannot meet something, **say so explicitly** in the deliverable with the reason
and the plan to resolve it. Do not deliver "almost done" work in silence.
