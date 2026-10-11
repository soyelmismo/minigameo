# ORCH_NOTES — handoff file for subagents

> Each agent appends ONE dated section below when it finishes. Format:

> ## AGENT: <name> | <date> | PHASE: <n>
> STATUS: DONE | BLOCKED | PARTIAL
> Files created/changed: <paths>
> Tests added: <test files> — all pass: yes/no (command output summary)
> Self-verification: `godot --headless --import` clean: yes/no
> Contract notes for other agents: <anything they must know>
> Known gaps / follow-ups: <honest list>

---

## AGENT: UI/HUD Engineer | 2026-10-10 | PHASE: 1 (HUD + widgets + screens)

STATUS: DONE

### Files created/changed

**HUD core**
- `src/ui/hud/hud.gd` + `hud.tscn` — master HUD. Duck-typed: looks up
  `/root/GameServices` first, then `/root/<Name>` for `EventBus`,
  `MinigameDirector`, `StyleDirector`, `SaveSystem`. ALL optional: with
  no systems at all it still renders and exposes public setters.
- `src/ui/hud/widget_factory.gd` — THE ONLY widget mapping
  (`HUDRecipe.primary_widget` → scene). Unknown/null kind degrades to
  COUNTER (never crashes).
- `src/ui/hud/hud_config.gd` + `hud_config.tres` — all HUD tuning
  (flavor duration, pop scale, pulse thresholds, shake, sweep speed,
  announce duration). No hardcoded numbers in the widgets (§1.3).
- `src/ui/theme/ui_colors.gd`, `src/ui/theme/panel_styler.gd`,
  `src/ui/theme/hud_base.tres`, `src/ui/theme/hud_theme_factory.gd`.

**Five generic widgets (§13.1)** — `src/ui/hud/widgets/`
`counter_widget`, `timer_widget`, `progress_widget`, `sequence_widget`,
`multiplier_widget` (.tscn + .gd each).

**Screens** — `src/ui/screens/`: `title_screen`, `results_screen`,
`pause_menu`, `settings_panel` (.tscn + .gd each), plus
`rank_thresholds.gd/.tres` (D<C<B<A<S<S+) and
`accessibility_settings.gd/.tres` (shake 0..1, flashes, colourblind
shapes, subtitles, text speed).

**Roulette** — `src/ui/roulette/roulette_ui.gd` + `.tscn`:
full-screen announcement (display_name + objective_text + flavor_text)
before the minigame starts.

**Assets** — `assets/ui/icon_factory.gd` (14 distinct-silhouette icons
generated in code), `assets/ui/generate_icons.gd`, and the 14 generated
`assets/ui/icon_*.png`.

**Tests** — `tests/unit/test_ui_widget_factory.gd`,
`tests/unit/test_ui_hud.gd`, `tests/unit/test_ui_screens.gd`.

### Tests added — all pass: YES

`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_ui_widget_factory.gd -gtest=res://tests/unit/test_ui_hud.gd -gtest=res://tests/unit/test_ui_screens.gd -gexit`

```
Scripts           3
Tests             30
  Passing         30
Asserts           110
Time              0.794s

---- All tests passed! ----
```

(9/9 widget factory + widgets, 9/9 HUD, 12/12 screens/roulette/theme.)

Self-verification: `godot --headless --import` — zero errors mentioning
`res://src/ui` or `res://tests/unit/test_ui*`. `godot --headless --quit`
— clean (no errors/warnings).

### Contract notes for other agents

**I coded against the REAL files (they existed and I read them):**
- `MinigameMetadata` (`src/minigames/minigame_metadata.gd`): `id`,
  `display_name`, `archetype`, `duration_s`, `base_score`, `weight`,
  `theme_tag`, `objective_text`, `flavor_text`, `fail_lines`,
  `style_pack_id`, `music_state`, `input_mode`, `spawn_recipe`,
  `objective_recipe`, `hud_recipe`, `difficulty_curve`, `tags`.
- `HUDRecipe` (`src/minigames/slots/hud_recipe.gd`): `primary_widget`,
  `icon`, `color_hint`, `show_flavor`, `callout_on_start`.
  NOTE the real file lists `METER` as a possible value in its comment;
  the factory maps it to the PROGRESS widget (a meter IS a progress bar
  with a sweep). The five .tscn widgets are exactly §13.1's five.
- `MinigameResult` (`src/minigames/minigame_result.gd`): `success`,
  `base_score`, `time_bonus`, `combo_max`, `total_score`, `grade`,
  `fail_reason`.
- `EventBus` (`src/core/event_bus.gd`, just landed): signals match my
  subscriptions EXACTLY — `minigame_started(id: StringName)`,
  `minigame_finished(result: Resource)`, `score_changed(total: int,
  delta: int)`, `combo_changed(combo: int)`, `match_time_up()`,
  `style_applied(pack_id: StringName)`.

**For the integration agent (wave 2):**
1. My HUD subscribes to EventBus **only if the signal exists**
   (`has_signal`), so it is safe to register EventBus at any time.
2. HUD public API for driving it directly (tests / integration):
   `set_objective(recipe, objective, flavor)`, `clear_objective()`,
   `set_score(int)`, `set_combo(int)`, `set_match_time(float)`,
   `show_callout(text)`, `set_powerup_markers(PackedVector2Array)`,
   `apply_theme(Theme)`.
3. HUD looks for these OPTIONAL duck-typed methods (all degrade
   silently if missing):
   - `MinigameDirector.get_metadata_for(id) -> MinigameMetadata`
     (if absent, only setters work — fine),
   - `StyleDirector.get_hud_theme() -> Theme` (if absent, use
     `hud.apply_theme(HudThemeFactory.theme_for(pack_id))`),
   - `SaveSystem.get_best_score() -> int` (title screen; local 0 if
     absent).
4. Theme per style pack: `HudThemeFactory.theme_for(&"NEON_DRIFT")`
   covers all 12 packs of §9. When `StylePack.hud_theme` is populated,
   the HUD uses that Theme via `StyleDirector.get_hud_theme()`.
5. To make the counter widget show the objective target, set the meta
   `objective_target` (int) on the HUDRecipe instance, or call
   `set_target()` on the widget. Simplest for archetypes: after building
   the objective, call `hud.set_objective(recipe, text, flavor)` and
   then set the target on `hud.current_objective_widget()`.
6. Widget↔minigame progress hooks the HUD does NOT own (archetypes
   should drive them): CounterWidget `set_value(int)`;
   TimerWidget `set_duration(s)` / `set_accumulate_mode(bool)`;
   ProgressWidget `set_zone(center, half_width)`; SequenceWidget
   `set_step_count(n)` / `hit_step()` / `miss_step()`;
   MultiplierWidget `set_value(float)`. The HUD creates the widget but
   the archetype (or a small bridge) feeds it. This is the intended
   seam: widgets are data-fed, not minigame-specific.
7. No new autoloads from me. `project.godot` untouched.
8. `EventBus.minigame_finished` passes a `Resource`; I treat it as
   `Object` and only read `.success` (duck-typed) — no coupling.

**Colourblind accessibility (§13.3):** every generated icon has a
distinct silhouette (circle/heart/star/square/triangle/diamond/plus/
bell/bolt/gear/clock/check/cross/arrow) plus thick dark outline, so
objectives are distinguishable by SHAPE not just colour. The settings
panel exposes `colorblind_indicators` for gameplay systems to read.

### Known gaps / follow-ups (honest)

1. **Power-up compass is a functional placeholder**: arrows are
   positioned from normalised screen coordinates
   (`set_powerup_markers`), but the world→screen projection is owned by
   PowerUpDirector (not my territory). It lights arrows correctly given
   positions; it needs a caller in wave 2/3.
2. **VO callouts are subtitles only** — I do not play audio.
   VoiceDirector can emit the same text; the HUD never touches audio
   (AGENTS.md §5).
3. **`hud_config.tres` thresholds are placeholders pending balance**:
   rank thresholds (C=5k..S+=100k) are my proposal — the ScoreDirector
   is authoritative for the real ones; the results screen accepts any
   `RankThresholds` resource so the integration agent can swap it.
4. **Widget↔archetype bridge** (noted in point 6) is the one seam that
   needs a wave-2 owner. It is deliberately thin and duck-typed.
5. **Controls remapping UI** (§13.4) is NOT implemented — only the
   settings entry exists. Remapping is an input-system concern
   (Player/Input agent), so I left it out rather than invent a parallel
   input map.
6. `_probe_tmp.gd` (pre-existing, not mine) still sits in
   `tests/unit/` and FAILS to parse — it breaks a whole-suite GUT run.
   The integration agent must delete it before running the full suite.
   `src/core/event_bus.gd` + `game_services.gd` had parse errors during
   my session (their owner fixed them); verify at integration time.

### Bugs I hit and fixed during this session (per orchestrator request)

- `_ = delta` style statements are PARSE ERRORS in GDScript 4.4 (must be
  `var _ := delta` or just removed). Broke TimerWidget.
- Parameters shadowing same-named methods (`objective_text` param vs
  `objective_text()` func; `value` param vs `value()` func; `name` param
  vs `Node.name`) are errors under this project's warning settings.
  Renamed all of them.
- `theme` is NOT a property of CanvasLayer — it must be set on the child
  Control (Root). HUD theme swap now applies to `%Root`.
- A widget script attached to a plain child `Node` inside a .tscn does
  not become that node's script — instance the widget's .tscn instead.
- `%UniqueName` references must have `unique_name_in_owner = true` in
  the scene, or `_ready` crashes on them.
- Tween-based pops need frame waits in tests; added `_await_settled`
  helpers that poll until the scale returns to 1.
