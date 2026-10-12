# Micro-game Design Catalog

**36 micro-games across 14 archetypes.** Every micro-game in this document is **one `.tres` file** (`src/minigames/catalog/<id>.tres`) and **zero lines of gameplay code** — see AGENTS.md §1.8 and `scaffold.md` §8.0. The variety comes from combining three slots (`SpawnRecipe` — what appears, `ObjectiveRecipe` — what must be done, `HUDRecipe` — how it is shown) plus `input_mode`, `style_pack_id` and the written content, executed by a generic archetype engine in `src/minigames/archetypes/`.

**Grouping:** entries are grouped **by archetype** so the members of a family sit side by side, and inside each group they follow the catalog numbering of `scaffold.md` §8.2. The summary table uses that same numbering so it can be cross-checked against the files on disk.

**Numbers** are read straight from the `.tres` files; **quoted text** (objectives, flavor, fail lines, callouts) is verbatim from the same files. Tuning a micro-game means editing the `.tres`, never the engine.

### Summary

| # | id | display_name | archetype | duration | theme | primary_widget |
|---|---|---|---|---|---|---|
| 1 | `token_rush` | Token Rush | `COLLECT_RUSH` | 20.0 s | AI | `COUNTER` |
| 2 | `data_diet` | Data Diet | `COLLECT_RUSH` | 22.0 s | AI | `COUNTER` |
| 3 | `grocery_getaway` | Grocery Getaway | `COLLECT_RUSH` | 20.0 s | LIFE | `COUNTER` |
| 4 | `porch_pirate` | Porch Pirate | `COLLECT_RUSH` | 18.0 s | LIFE | `COUNTER` |
| 5 | `hallucination_highway` | Hallucination Highway | `DODGE` | 18.0 s | AI | `TIMER` |
| 6 | `gpu_meltdown` | GPU Meltdown | `DODGE` | 16.0 s | HYBRID | `TIMER` |
| 7 | `commuter_chaos` | Commuter Chaos | `DODGE` | 18.0 s | LIFE | `TIMER` |
| 8 | `laundry_landmine` | Laundry Landmine | `DODGE` | 16.0 s | LIFE | `TIMER` |
| 9 | `bias_bug_bash` | Bias Bug Bash | `TAP_TARGET` | 20.0 s | AI | `COUNTER` |
| 10 | `spam_smash` | Spam Smash | `TAP_TARGET` | 20.0 s | LIFE | `COUNTER` |
| 11 | `autocomplete_alley` | Autocomplete Alley | `TAP_TARGET` | 20.0 s | HYBRID | `COUNTER` |
| 12 | `notification_nuke` | Notification Nuke | `TAP_TARGET` | 18.0 s | LIFE | `COUNTER` |
| 13 | `beat_of_the_bot` | Beat of the Bot | `RHYTHM` | 22.0 s | AI | `PROGRESS` |
| 14 | `barista_blitz` | Barista Blitz | `RHYTHM` | 22.0 s | LIFE | `PROGRESS` |
| 15 | `flow_state` | Flow State | `ZONE_HOLD` | 25.0 s | LIFE | `TIMER` |
| 16 | `silent_disco` | Silent Disco | `ZONE_HOLD` | 22.0 s | LIFE | `TIMER` |
| 17 | `merge_merge_merge` | Merge Merge Merge | `GATE_RACE` | 25.0 s | LIFE | `SEQUENCE` |
| 18 | `prompt_chain` | Prompt Chain | `COMBO_CHAIN` | 22.0 s | AI | `SEQUENCE` |
| 19 | `combo_commute` | Combo Commute | `COMBO_CHAIN` | 24.0 s | LIFE | `SEQUENCE` |
| 20 | `stack_overflow` | Stack Overflow | `BALANCE` | 22.0 s | HYBRID | `TIMER` |
| 21 | `context_recall` | Context Recall | `MEMORY` | 24.0 s | AI | `SEQUENCE` |
| 22 | `password_palace` | Password Palace | `MEMORY` | 24.0 s | AI | `SEQUENCE` |
| 23 | `learning_rate` | Learning Rate | `METER_STOP` | 22.0 s | HYBRID | `PROGRESS` |
| 24 | `push_and_pray` | Push & Pray | `CHARGE_BLAST` | 20.0 s | HYBRID | `PROGRESS` |
| 25 | `feature_freeze` | Feature Freeze | `PUSH_ZONE` | 25.0 s | HYBRID | `COUNTER` |
| 26 | `inference_inferno` | Inference Inferno | `CHASE` | 22.0 s | HYBRID | `TIMER` |
| 27 | `delivery_dash` | Delivery Dash | `CHASE` | 22.0 s | LIFE | `TIMER` |
| 28 | `tech_debt_tower` | Tech Debt Tower | `STACK_TIMED` | 25.0 s | HYBRID | `COUNTER` |
| 29 | `elevator_endurance` | Elevator Endurance | `ZONE_HOLD` | 22.0 s | LIFE | `TIMER` |
| 30 | `circular_referencing` | Circular Referencing | `GATE_RACE` | 25.0 s | AI | `SEQUENCE` |
| 31 | `agile_sprint` | Agile Sprint | `GATE_RACE` | 25.0 s | LIFE | `SEQUENCE` |
| 32 | `sudo_smash` | Sudo Smash | `TAP_TARGET` | 20.0 s | HYBRID | `COUNTER` |
| 33 | `not_found` | 404 Not Found | `DODGE` | 15.0 s | AI | `TIMER` |
| 34 | `overfitting_olympics` | Overfitting Olympics | `MEMORY` | 24.0 s | AI | `SEQUENCE` |
| 35 | `fire_drill` | Fire Drill | `DODGE` | 15.0 s | LIFE | `TIMER` |
| 36 | `server_room_scramble` | Server Room Scramble | `DODGE` | 18.0 s | HYBRID | `TIMER` |

### Reading the slots

| Slot | Fields documented here | Read by |
|---|---|---|
| `SpawnRecipe` | `count`, `count_scales_with_difficulty`, `spawn_radius`, `spawn_pattern`, `motion`, `speed`, `lifetime_s`, `respawn` | the archetype's spawn step |
| `ObjectiveRecipe` | `kind`, `target`, `tolerance`, `fail_on`, `time_bonus_per_s`, `combo_step` | the archetype's win/fail evaluation, every frame |
| `HUDRecipe` | `primary_widget`, `color_hint`, `callout_on_start`, `show_flavor` | the auto-generated HUD (widget library, `scaffold.md` §13.1) |
| `MinigameMetadata` | `duration_s`, `base_score`, `weight`, `theme_tag`, `style_pack_id`, `music_state`, `input_mode`, `entity_size` / `tint` / `shape`, `tags` | the director, the roulette and the entity scene |

Two slot conventions matter, because the same field means different things per family:

- **`speed`** is a plain movement speed (m/s) in `CHASE`, but encodes **BPM** in `RHYTHM` (beat interval = `60 / speed`), a **sweep rate** in `METER_STOP` (cycles/s = `speed / 10`) and a **drop interval** in `STACK_TIMED` (interval = `10 / speed`). No slot field was added for this; each archetype documents the convention in its header.
- **`motion`** is consumed by the engine only in `CHASE`. Elsewhere it records the authored intent (`FALL`, `CHASE`, `ORBIT`, `STATIC`) that the entity prop is expected to perform; the shared `minigame_entity.tscn` currently only rotates and expires, so a `FALL` wave is not yet animated by the prop itself. Flagged under [Known gaps](#known-gaps-data-vs-engine) rather than silently assumed — it is a build gap, not a data gap.

### Archetype families

#### COLLECT_RUSH — 4 micro-games

**Engine** — collect `target` pickups before the clock expires. Touching a pickup banks it; leftover seconds convert to bonus.

Members: [Token Rush](#token-rush-tokenrush), [Data Diet](#data-diet-datadiet), [Grocery Getaway](#grocery-getaway-grocerygetaway), [Porch Pirate](#porch-pirate-porchpirate).

## Token Rush (`token_rush`)

**Archetype** `COLLECT_RUSH` · **Duration** 20.0 s · **Base score** 1200 · **Weight** 1.2  
**Style pack** `NEON_DRIFT` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `AI`

**Objective** — "Grab the tokens before the chatbot forgets why it exists!"

You chase the tokens down — they scatter and run from you, so you have to corner them.

**Spawn** — 16 entities (scales with difficulty), `SCATTER`, motion `FLEE at 5`, radius 18, 14 s lifetime. Entity: `SPHERE`, size 0.5, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `COLLECT_N`, target **12**, tolerance —, `fail_on: TIMEOUT`, time bonus **+120 pts/s** of leftover time, combo step **0.25** per hit.

**HUD** — `COUNTER` widget, color hint `CYAN`, callout on start "GO GO GO!" (flavor text shown for ~2 s).

**Flavor** — "The model has fourteen tokens of working memory. You are all of them."

**Fail lines**

- "Oof. Context evicted."
- "The bot is disappointed. It's a bot. It can't be. But it is."
- "Prompt collapsed. Send tokens."

**Tags** — `collect` · `ai` · `tokens`

## Data Diet (`data_diet`)

**Archetype** `COLLECT_RUSH` · **Duration** 22.0 s · **Base score** 1100 · **Weight** 1.0  
**Style pack** `SPRITE_25D` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `AI`

**Objective** — "Collect the clean data. Leave the junk data alone."

You sweep the arena and run over the clean records, ignoring the junk sitting next to them.

**Spawn** — 20 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 16, 20 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `COLLECT_N`, target **10**, tolerance —, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `GREEN`, callout on start "EAT CLEAN!" (flavor text shown for ~2 s).

**Flavor** — "You are the filter. The filter is tired. The filter wants a salad."

**Fail lines**

- "Junk data collected. Gross."
- "Your diet was 90% junk and 10% vibes."
- "The pipeline choked on cookies."

**Tags** — `collect` · `ai` · `data`

## Grocery Getaway (`grocery_getaway`)

**Archetype** `COLLECT_RUSH` · **Duration** 20.0 s · **Base score** 1000 · **Weight** 1.1  
**Style pack** `CANDY_PLASTIC` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Grab the groceries. Do not touch the self-checkout."

You sprint the aisles and pick up the groceries, staying clear of the self-checkout.

**Spawn** — 15 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 17, 20 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `COLLECT_N`, target **10**, tolerance —, `fail_on: TIMEOUT`, time bonus **+120 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `ORANGE`, callout on start "GRAB AND GO!" (flavor text shown for ~2 s).

**Flavor** — "Unexpected item in bagging area. Also in your arms. Also in your mouth."

**Fail lines**

- "UNEXPECTED ITEM IN BAGGING AREA."
- "The self-checkout judged you."
- "You bagged it wrong. It screams."

**Tags** — `collect` · `life` · `shop`

## Porch Pirate (`porch_pirate`)

**Archetype** `COLLECT_RUSH` · **Duration** 18.0 s · **Base score** 1000 · **Weight** 1.0  
**Style pack** `PAPER_CRAFT` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Packages appear. Pirates appear. Grab the packages first."

You catch the packages as they come down and bank each grab before they expire.

**Spawn** — 14 entities (scales with difficulty), `WAVE`, motion `FALL at 6`, radius 16, 12 s lifetime · respawns. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `COLLECT_N`, target **8**, tolerance —, `fail_on: TIMEOUT`, time bonus **+130 pts/s** of leftover time, combo step **0.4** per hit.

**HUD** — `COUNTER` widget, color hint `YELLOW`, callout on start "MINE. NOT THEIRS!" (flavor text shown for ~2 s).

**Flavor** — "You are the neighborhood's last line of defense. And its only line."

**Fail lines**

- "Pirate got the box. And the good socks."
- "Porch: compromised. Dignity: also compromised."
- "It was the other one. It's always the other one."

**Tags** — `collect` · `life` · `packages`

#### CHASE — 2 micro-games

**Engine** — one moving target. With `motion: FLEE` it runs from you (faster up close, easing off at range), so a `CHASE_CATCH` target of N means tagging it N times inside the duration.

Members: [Inference Inferno](#inference-inferno-inferenceinferno), [Delivery Dash](#delivery-dash-deliverydash).

## Inference Inferno (`inference_inferno`)

**Archetype** `CHASE` · **Duration** 22.0 s · **Base score** 1300 · **Weight** 1.1  
**Style pack** `NEON_DRIFT` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `HYBRID`

**Objective** — "Catch the runaway inference. It is fast. Too fast. It knows."

You chase the runner down — it bolts when you close in, eases off at range — and tag it three times.

**Spawn** — 1 entity, `RING`, motion `FLEE at 9`, radius 30, 22 s lifetime. Entity: `SPHERE`, size 0.65, tint `Color(1.0, 0.3, 0.25, 1)`.

**Win / fail** — kind `CHASE_CATCH`, target **3**, tolerance —, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `TIMER` widget, color hint `RED`, callout on start "GO GO GO!" (flavor text shown for ~2 s).

**Flavor** — "It escaped the datacenter. It is faster than your excuses."

**Fail lines**

- "The inference outran you. Insulting."
- "It was never going to be caught."
- "You chased a ghost. A very fast ghost."

**Tags** — `chase` · `ai` · `inference`

## Delivery Dash (`delivery_dash`)

**Archetype** `CHASE` · **Duration** 22.0 s · **Base score** 1050 · **Weight** 1.3  
**Style pack** `GOLD_RUSH` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Chase the driver. They saw you. They keep driving."

You chase the driver and tag the van three times before time runs out.

**Spawn** — 1 entity, `RING`, motion `FLEE at 8`, radius 30, 22 s lifetime. Entity: `BOX`, size 0.8, tint `Color(1.0, 0.6, 0.2, 1)`.

**Win / fail** — kind `CHASE_CATCH`, target **3**, tolerance —, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `TIMER` widget, color hint `ORANGE`, callout on start "HEY! HEY!" (flavor text shown for ~2 s).

**Flavor** — "The map says two minutes. The driver says twenty. The driver is lying."

**Fail lines**

- "Driver delivered to the void."
- "You chased a van. You lost to a van."
- "The food got cold. So did you."

**Tags** — `chase` · `life` · `delivery`

#### DODGE — 7 micro-games

**Engine** — hazards spawn around the arena and you survive untouched. Running the clock out **is** the win; a single `TOUCH_HAZARD` ends it instantly.

Members: [Hallucination Highway](#hallucination-highway-hallucinationhighway), [GPU Meltdown](#gpu-meltdown-gpumeltdown), [Commuter Chaos](#commuter-chaos-commuterchaos), [Laundry Landmine](#laundry-landmine-laundrylandmine), [404 Not Found](#404-not-found-notfound), [Fire Drill](#fire-drill-firedrill), [Server Room Scramble](#server-room-scramble-serverroomscramble).

## Hallucination Highway (`hallucination_highway`)

**Archetype** `DODGE` · **Duration** 18.0 s · **Base score** 1100 · **Weight** 1.1  
**Style pack** `BIT_CRUSH` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `AI`

**Objective** — "Dodge the confidently wrong answers. They are SO sure."

You keep moving through the falling wrong answers and never let one touch you.

**Spawn** — 18 entities (scales with difficulty), `WAVE`, motion `FALL at 7`, radius 20, 10 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **18**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `RED`, callout on start "STAY REAL!" (flavor text shown for ~2 s).

**Flavor** — "Each one says it has no doubt. None of them has any idea."

**Fail lines**

- "That answer sounded right. It was not."
- "Hallucinated. Boldly. With conviction."
- "Confidence level: wrong."

**Tags** — `dodge` · `ai` · `hallucination`

## GPU Meltdown (`gpu_meltdown`)

**Archetype** `DODGE` · **Duration** 16.0 s · **Base score** 1200 · **Weight** 1.2  
**Style pack** `CHROME_BEAM` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `HYBRID`

**Objective** — "Overheating GPUs are raining from above. Find shade. Or run."

You find the gaps in the falling-GPU wave and keep moving for the full duration.

**Spawn** — 16 entities (scales with difficulty), `WAVE`, motion `FALL at 8`, radius 19, 8 s lifetime. Entity: `DIAMOND`, size 0.9, tint `Color(1.0, 0.45, 0.1, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **16**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+120 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `RED`, callout on start "HOT HOT HOT!" (flavor text shown for ~2 s).

**Flavor** — "The fans are at full tilt. The fans are screaming. The fans know."

**Fail lines**

- "Thermal throttled. Emotional throttled."
- "One hundred degrees and dropping."
- "Your GPU filed a complaint."

**Tags** — `dodge` · `ai` · `gpu`

## Commuter Chaos (`commuter_chaos`)

**Archetype** `DODGE` · **Duration** 18.0 s · **Base score** 1000 · **Weight** 1.3  
**Style pack** `WATERCOLOR` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "It is 8:47 AM. Umbrellas everywhere. Do not get poked."

You weave between the falling umbrellas and hope nothing pokes you.

**Spawn** — 17 entities (scales with difficulty), `WAVE`, motion `FALL at 6`, radius 18, 12 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **18**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `BLUE`, callout on start "MIND THE UMBRELLAS!" (flavor text shown for ~2 s).

**Flavor** — "Nine umbrellas, zero spatial awareness. Peak commuting."

**Fail lines**

- "Poked in the eye. Twice. On a Tuesday."
- "You became a puddle. With feelings."
- "The 8:47 got you. It always gets you."

**Tags** — `dodge` · `life` · `commute`

## Laundry Landmine (`laundry_landmine`)

**Archetype** `DODGE` · **Duration** 16.0 s · **Base score** 950 · **Weight** 1.0  
**Style pack** `CANDY_PLASTIC` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "The dryer eats socks. Apparently it now also eats you. Survive."

You keep circling — these hazards home in on you instead of raining down.

**Spawn** — 15 entities (scales with difficulty), `SCATTER`, motion `CHASE at 5`, radius 15, 10 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **16**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `PINK`, callout on start "DON'T GET EATEN!" (flavor text shown for ~2 s).

**Flavor** — "You went in for one shirt. The dryer has opinions about that."

**Fail lines**

- "Sock secured. You did not."
- "Tumble dried. Set to gentle. Failed."
- "Where is the other one? WHERE."

**Tags** — `dodge` · `life` · `laundry`

## 404 Not Found (`not_found`)

**Archetype** `DODGE` · **Duration** 15.0 s · **Base score** 1000 · **Weight** 1.0  
**Style pack** `BIT_CRUSH` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `AI`

**Objective** — "Dodge the 404s. They are lost, confused, and slightly desperate."

You stay out of reach of the falling 404s for the full duration.

**Spawn** — 16 entities (scales with difficulty), `WAVE`, motion `FALL at 7`, radius 17, 10 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **15**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+120 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `RED`, callout on start "STAY FOUND!" (flavor text shown for ~2 s).

**Flavor** — "Error: destination not found. Error: your plan not found either."

**Fail lines**

- "404. You not found."
- "Resource missing. Like your excuses."
- "Redirected into a wall."

**Tags** — `dodge` · `ai` · `404`

## Fire Drill (`fire_drill`)

**Archetype** `DODGE` · **Duration** 15.0 s · **Base score** 900 · **Weight** 1.1  
**Style pack** `TOON_POP` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Office fire drill. Again. Walk, don't run. Or do. Points."

You keep away from the hazards, which home in on you rather than falling.

**Spawn** — 14 entities (scales with difficulty), `SCATTER`, motion `CHASE at 5.5`, radius 16, 10 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **15**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `ORANGE`, callout on start "WALK. DON'T PANIC!" (flavor text shown for ~2 s).

**Flavor** — "This is a drill. The coffee is not. The coffee is leaving with you."

**Fail lines**

- "You took the elevator. Bold. Wrong."
- "The assembly point was a parking lot."
- "Safety first. You were fourth."

**Tags** — `dodge` · `life` · `office`

## Server Room Scramble (`server_room_scramble`)

**Archetype** `DODGE` · **Duration** 18.0 s · **Base score** 1200 · **Weight** 1.1  
**Style pack** `CHROME_BEAM` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `HYBRID`

**Objective** — "The servers are hot. The room is hot. Everything is hot. Survive it."

You keep moving under the falling heat and survive the full round.

**Spawn** — 17 entities (scales with difficulty), `WAVE`, motion `FALL at 7.5`, radius 19, 10 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `SURVIVE_T`, target **18**, tolerance —, `fail_on: TOUCH_HAZARD`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `RED`, callout on start "FIND SOME SHADE!" (flavor text shown for ~2 s).

**Flavor** — "Someone set the cooling to 'optimistic'. The fans are composing a symphony."

**Fail lines**

- "Thermal shutdown. Emotional shutdown."
- "You melted. Gently. With honor."
- "The room is fine. You are not."

**Tags** — `dodge` · `hybrid` · `servers`

#### TAP_TARGET — 5 micro-games

**Engine** — hit `target` of the popping targets. Mouse input raycasts from the camera with a nearest-to-ray fallback; keyboard and gamepad hit the target nearest the player.

Members: [Bias Bug Bash](#bias-bug-bash-biasbugbash), [Spam Smash](#spam-smash-spamsmash), [Autocomplete Alley](#autocomplete-alley-autocompletealley), [Notification Nuke](#notification-nuke-notificationnuke), [Sudo Smash](#sudo-smash-sudosmash).

## Bias Bug Bash (`bias_bug_bash`)

**Archetype** `TAP_TARGET` · **Duration** 20.0 s · **Base score** 1300 · **Weight** 1.2  
**Style pack** `VHS_90` · **Music state** `PEAK` · **Input mode** `LOOK` · **Theme tag** `AI`

**Objective** — "Whack the bias bugs. They keep popping up. Of course they do."

You aim and click each bug as it pops; the short lifetime means hesitating loses the hit.

**Spawn** — 14 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 14, 3 s lifetime · respawns. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `TAP_N`, target **15**, tolerance —, `fail_on: TIMEOUT`, time bonus **+120 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `MAGENTA`, callout on start "WHACK WHACK WHACK!" (flavor text shown for ~2 s).

**Flavor** — "You patch one. Two appear. The backlog is infinite and unpaid."

**Fail lines**

- "The bug reproduced. Rapidly."
- "Patch rejected by reviewer (the bug)."
- "It was not a bug, it was a feature. It was a bug."

**Tags** — `tap` · `ai` · `bias`

## Spam Smash (`spam_smash`)

**Archetype** `TAP_TARGET` · **Duration** 20.0 s · **Base score** 1000 · **Weight** 1.2  
**Style pack** `GOLD_RUSH` · **Music state** `PEAK` · **Input mode** `LOOK` · **Theme tag** `LIFE`

**Objective** — "YOU WON A CRUISE! You did not. Smash it. Smash them all."

You click the spam windows as they pop up and let none of them survive the round.

**Spawn** — 16 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 14, 3.5 s lifetime · respawns. Entity: `SPHERE`, size 0.55, tint `Color(1.0, 0.25, 0.35, 1)`.

**Win / fail** — kind `TAP_N`, target **14**, tolerance —, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `YELLOW`, callout on start "SMASH THE SPAM!" (flavor text shown for ~2 s).

**Flavor** — "A prince, a lottery, and a deadline. It's like a movie with no budget."

**Fail lines**

- "You clicked. They knew you would."
- "Congratulations! You won a virus."
- "Unsubscribed. Emotionally unavailable."

**Tags** — `tap` · `life` · `spam`

## Autocomplete Alley (`autocomplete_alley`)

**Archetype** `TAP_TARGET` · **Duration** 20.0 s · **Base score** 1150 · **Weight** 1.1  
**Style pack** `VHS_90` · **Music state** `TENSION` · **Input mode** `TAP` · **Theme tag** `HYBRID`

**Objective** — "Tap what it predicts. Or rebel. Rebelling loses points."

You tap whatever the predictor lights up, as fast as the targets cycle.

**Spawn** — 15 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 14, 3.5 s lifetime · respawns. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `TAP_N`, target **14**, tolerance —, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `PURPLE`, callout on start "FOLLOW THE PREDICTION!" (flavor text shown for ~2 s).

**Flavor** — "It finished your sentence. You never liked that ending."

**Fail lines**

- "Autocomplete won. It usually does."
- "Your suggestion was ignored. Politely."
- "The model knew better. It claimed it did."

**Tags** — `tap` · `ai` · `autocomplete`

## Notification Nuke (`notification_nuke`)

**Archetype** `TAP_TARGET` · **Duration** 18.0 s · **Base score** 1100 · **Weight** 1.4  
**Style pack** `NEON_DRIFT` · **Music state** `PEAK` · **Input mode** `TAP` · **Theme tag** `LIFE`

**Objective** — "Forty-seven notifications. Tap them before they breed."

You tap the notifications down before the badge count outruns your thumb.

**Spawn** — 18 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 15, 3 s lifetime · respawns. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `TAP_N`, target **16**, tolerance —, `fail_on: TIMEOUT`, time bonus **+120 pts/s** of leftover time, combo step **0.35** per hit.

**HUD** — `COUNTER` widget, color hint `CYAN`, callout on start "TAP TAP TAP!" (flavor text shown for ~2 s).

**Flavor** — "One app sends nine. The other thirty-eight are 'we miss you' emails."

**Fail lines**

- "Badge count: eternal. Dignity: zero."
- "You muted them. They multiplied."
- "Do not disturb: ignored, like your plans."

**Tags** — `tap` · `life` · `notifications`

## Sudo Smash (`sudo_smash`)

**Archetype** `TAP_TARGET` · **Duration** 20.0 s · **Base score** 1200 · **Weight** 1.2  
**Style pack** `BIT_CRUSH` · **Music state** `PEAK` · **Input mode** `LOOK` · **Theme tag** `HYBRID`

**Objective** — "Type the sudo password fast. Before the timeout. Before the regrets."

You click the password prompts before the timeout eats them.

**Spawn** — 16 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 14, 3 s lifetime · respawns. Entity: `BOX`, size 0.7, tint `Color(0.85, 0.2, 0.9, 1)`.

**Win / fail** — kind `TAP_N`, target **15**, tolerance —, `fail_on: TIMEOUT`, time bonus **+120 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `GREEN`, callout on start "SUDO SMASH!" (flavor text shown for ~2 s).

**Flavor** — "With great power comes a prompt you will mistype twice."

**Fail lines**

- "Permission denied. Politely. Forever."
- "You typed the old password. Everyone does."
- "Timeout. The password rotted."

**Tags** — `tap` · `hybrid` · `linux`

#### RHYTHM — 2 micro-games

**Engine** — press on the beat. `spawn_recipe.speed` encodes the BPM (beat interval = `60 / speed`); a press within `tolerance` of the nearest beat counts, an off-beat press breaks the combo.

Members: [Beat of the Bot](#beat-of-the-bot-beatofthebot), [Barista Blitz](#barista-blitz-baristablitz).

## Beat of the Bot (`beat_of_the_bot`)

**Archetype** `RHYTHM` · **Duration** 22.0 s · **Base score** 1250 · **Weight** 1.0  
**Style pack** `VHS_90` · **Music state** `PEAK` · **Input mode** `BUTTON` · **Theme tag** `AI`

**Objective** — "Pulse on the synthetic rhythm. You can tell it's fake. Barely."

You press in time with the synthetic beat — inside the window it counts, off-beat breaks the combo.

**Spawn** — 4 entities (scales with difficulty), `RING`, motion `ORBIT at 128`, radius 10, 22 s lifetime. Entity: `RING`, size 0.7, tint `Color(0.4, 1.0, 0.75, 1)`.

**Win / fail** — kind `TAP_N`, target **20**, tolerance 0.15, `fail_on: NONE`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `PROGRESS` widget, color hint `CYAN`, callout on start "FEEL THE SYNTH!" (flavor text shown for ~2 s).

**Flavor** — "Every beat is quantized. Every groove is slightly dead inside."

**Fail lines**

- "Off by one sample. Forever off."
- "The bot played it better. It's a bot."
- "Timing: tragically human."

**Tags** — `rhythm` · `ai` · `beat`

## Barista Blitz (`barista_blitz`)

**Archetype** `RHYTHM` · **Duration** 22.0 s · **Base score** 1100 · **Weight** 1.1  
**Style pack** `PAPER_CRAFT` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `LIFE`

**Objective** — "Tap on the hiss. The espresso machine keeps a beat. Follow it."

You press on the hiss, in time with the machine's beat.

**Spawn** — 3 entities (scales with difficulty), `RING`, motion `ORBIT at 112`, radius 9, 22 s lifetime. Entity: `SPHERE`, size 0.5, tint `Color(0.65, 0.45, 0.3, 1)`.

**Win / fail** — kind `TAP_N`, target **18**, tolerance 0.15, `fail_on: NONE`, time bonus **+110 pts/s** of leftover time, combo step **0.25** per hit.

**HUD** — `PROGRESS` widget, color hint `ORANGE`, callout on start "FOLLOW THE HISS!" (flavor text shown for ~2 s).

**Flavor** — "Two pumps, one portafilter, zero chill. It's jazz, but caffeinated."

**Fail lines**

- "Over-extracted. Like your patience."
- "That was a decaf moment. Sad."
- "The steam wand judged you."

**Tags** — `rhythm` · `life` · `coffee`

#### ZONE_HOLD — 3 micro-games

**Engine** — accumulate `target` seconds inside the zone. The hold timer only advances while you are inside; stepping out **pauses** it (it does not reset), so micro-repositioning is free.

Members: [Flow State](#flow-state-flowstate), [Silent Disco](#silent-disco-silentdisco), [Elevator Endurance](#elevator-endurance-elevatorendurance).

## Flow State (`flow_state`)

**Archetype** `ZONE_HOLD` · **Duration** 25.0 s · **Base score** 1300 · **Weight** 1.0  
**Style pack** `WATERCOLOR` · **Music state** `CALM` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Hold the focus zone. The world wants you distracted."

You stand in the focus zone; the hold clock only ticks while you stay inside it.

**Spawn** — no entities: the zone marker *is* the objective. `RING` pattern, radius **8** = the zone radius, never expires.

**Win / fail** — kind `HOLD_ZONE_T`, target **15**, tolerance —, `fail_on: NONE`, time bonus **+90 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `GREEN`, callout on start "FIND YOUR ZONE!" (flavor text shown for ~2 s).

**Flavor** — "Twelve seconds of pure focus. Your phone has other plans. Your phone always has plans."

**Fail lines**

- "You checked one notification. Just one. That was the one."
- "Focus: leaked. Everywhere."
- "The zone is empty. So are you."

**Tags** — `zone` · `life` · `focus`

## Silent Disco (`silent_disco`)

**Archetype** `ZONE_HOLD` · **Duration** 22.0 s · **Base score** 1100 · **Weight** 1.0  
**Style pack** `NEON_DRIFT` · **Music state** `CALM` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Hold your headphone bubble. Everyone is screaming. Not you."

You park yourself in the headphone bubble and hold it while everyone else screams.

**Spawn** — no entities: the zone marker *is* the objective. `RING` pattern, radius **7** = the zone radius, never expires.

**Win / fail** — kind `HOLD_ZONE_T`, target **12**, tolerance —, `fail_on: NONE`, time bonus **+100 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `PURPLE`, callout on start "HEADPHONES ON!" (flavor text shown for ~2 s).

**Flavor** — "Your playlist is immaculate. Their taste is a public health issue."

**Fail lines**

- "Someone joined your channel. Rude."
- "The bass dropped out. The vibe survived."
- "You heard them. Unfortunately."

**Tags** — `zone` · `life` · `music`

## Elevator Endurance (`elevator_endurance`)

**Archetype** `ZONE_HOLD` · **Duration** 22.0 s · **Base score** 1000 · **Weight** 1.2  
**Style pack** `TOON_POP` · **Music state** `CALM` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Hold the door. Someone is coming. Someone is always coming."

You hold the door zone and keep the hold clock ticking.

**Spawn** — no entities: the zone marker *is* the objective. `RING` pattern, radius **6** = the zone radius, never expires.

**Win / fail** — kind `HOLD_ZONE_T`, target **10**, tolerance —, `fail_on: NONE`, time bonus **+100 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `GREEN`, callout on start "HOLD THE DOOR!" (flavor text shown for ~2 s).

**Flavor** — "You hold the button. The universe sends people. Slowly. Very slowly."

**Fail lines**

- "The door closed. With dignity intact."
- "Someone said 'thanks' and you almost cried."
- "The elevator left. It owed you nothing."

**Tags** — `zone` · `life` · `elevator`

#### GATE_RACE — 3 micro-games

**Engine** — touch the gates **in order**. The expected one scores; passing an out-of-order gate restarts the sequence.

Members: [Merge Merge Merge](#merge-merge-merge-mergemergemerge), [Circular Referencing](#circular-referencing-circularreferencing), [Agile Sprint](#agile-sprint-agilesprint).

## Merge Merge Merge (`merge_merge_merge`)

**Archetype** `GATE_RACE` · **Duration** 25.0 s · **Base score** 1150 · **Weight** 1.1  
**Style pack** `CHROME_BEAM` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Pass the gates in order. Nobody zips. Nobody cares."

You take the gates in the order the SEQUENCE widget shows; skipping one restarts the run.

**Spawn** — 8 entities, `LINE`, motion `STATIC`, radius 20, never expires. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `GATES_IN_ORDER`, target **8**, tolerance —, `fail_on: TIMEOUT`, time bonus **+100 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `SEQUENCE` widget, color hint `BLUE`, callout on start "TAKE THE GAP!" (flavor text shown for ~2 s).

**Flavor** — "Highway etiquette is a myth. Take the gap before it disappears."

**Fail lines**

- "You cut someone off. They beeped forever."
- "Missed the ramp. Took the long way."
- "The merge won. The merge always wins."

**Tags** — `gate` · `life` · `driving`

## Circular Referencing (`circular_referencing`)

**Archetype** `GATE_RACE` · **Duration** 25.0 s · **Base score** 1300 · **Weight** 1.0  
**Style pack** `BIT_CRUSH` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `AI`

**Objective** — "Break the loop. Pass the gates in order. There is no exit. Find one anyway."

You take the gates in order and try to break out of the loop.

**Spawn** — 9 entities, `LINE`, motion `STATIC`, radius 21, never expires. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `GATES_IN_ORDER`, target **9**, tolerance —, `fail_on: TIMEOUT`, time bonus **+100 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `SEQUENCE` widget, color hint `MAGENTA`, callout on start "BREAK THE LOOP!" (flavor text shown for ~2 s).

**Flavor** — "This dependency points to itself. Bold of it. Bad for you."

**Fail lines**

- "Stack overflow. Of patience."
- "You are here again. You were here again."
- "Infinite loop exited successfully. Impossible."

**Tags** — `gate` · `ai` · `loop`

## Agile Sprint (`agile_sprint`)

**Archetype** `GATE_RACE` · **Duration** 25.0 s · **Base score** 1050 · **Weight** 1.2  
**Style pack** `TOON_POP` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `LIFE`

**Objective** — "Sprint through the gates in order. The retrospective waits at the end."

You sprint through the gates in order and beat the clock.

**Spawn** — 8 entities, `LINE`, motion `STATIC`, radius 20, never expires. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `GATES_IN_ORDER`, target **8**, tolerance —, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.25** per hit.

**HUD** — `SEQUENCE` widget, color hint `GREEN`, callout on start "SHIP IT!" (flavor text shown for ~2 s).

**Flavor** — "Two weeks, eleven ceremonies, one deliverable. This is the way."

**Fail lines**

- "Ceremony ate the sprint. Again."
- "You retro'd too late. Nothing changed."
- "Scope crept. It always creeps."

**Tags** — `gate` · `life` · `work`

#### COMBO_CHAIN — 2 micro-games

**Engine** — chain `target` correct inputs with no miss. Each hit bumps the combo multiplier by `combo_step`; one wrong input breaks the chain, and with `fail_on: WRONG_INPUT` it ends the micro-game.

Members: [Prompt Chain](#prompt-chain-promptchain), [Combo Commute](#combo-commute-combocommute).

## Prompt Chain (`prompt_chain`)

**Archetype** `COMBO_CHAIN` · **Duration** 22.0 s · **Base score** 1250 · **Weight** 1.0  
**Style pack** `SPRITE_25D` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `AI`

**Objective** — "Chain the prompt words in order. Order matters. Obviously."

You hit the links in the order shown; one wrong press breaks the chain and ends the round.

**Spawn** — 5 entities, `RING`, motion `ORBIT at 2`, radius 12, 22 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `CHAIN_N`, target **10**, tolerance —, `fail_on: WRONG_INPUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `SEQUENCE` widget, color hint `CYAN`, callout on start "CHAIN IT UP!" (flavor text shown for ~2 s).

**Flavor** — "Put 'please' after 'delete' and watch the whole stack panic."

**Fail lines**

- "Token in wrong slot. Cascade engaged."
- "The chain broke. So did the model."
- "Out of order. Out of points."

**Tags** — `chain` · `ai` · `prompt`

## Combo Commute (`combo_commute`)

**Archetype** `COMBO_CHAIN` · **Duration** 24.0 s · **Base score** 1100 · **Weight** 1.2  
**Style pack** `INK_NOIR` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `LIFE`

**Objective** — "Transfer, transfer, transfer. Do not miss the line."

You chain the transfers in order without missing the line.

**Spawn** — 5 entities, `RING`, motion `ORBIT at 2.5`, radius 12, 24 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `CHAIN_N`, target **9**, tolerance —, `fail_on: WRONG_INPUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `SEQUENCE` widget, color hint `BLUE`, callout on start "DON'T MISS IT!" (flavor text shown for ~2 s).

**Flavor** — "Four lines, three transfers, one coffee spill. Perfectly ordinary."

**Fail lines**

- "Wrong platform. Ten minutes of regret."
- "The train left. It saw you. It left."
- "You ended up back home. Congratulations."

**Tags** — `chain` · `life` · `transit`

#### METER_STOP — 1 micro-game

**Engine** — a marker sweeps the bar ping-pong. Press while it sits inside the valid zone (centre ± `tolerance`) `target` times; a miss only wastes the press.

Members: [Learning Rate](#learning-rate-learningrate).

## Learning Rate (`learning_rate`)

**Archetype** `METER_STOP` · **Duration** 22.0 s · **Base score** 1350 · **Weight** 1.0  
**Style pack** `CHROME_BEAM` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `HYBRID`

**Objective** — "Stop the learning rate in the sweet spot. Too high means everything explodes."

You press while the sweeping marker sits in the green zone.

**Spawn** — no entities: the sweeping meter *is* the objective. No `RING` pattern is spawned; the marker sweeps the PROGRESS bar.

**Win / fail** — kind `STOP_IN_ZONE`, target **6**, tolerance 0.08, `fail_on: NONE`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `PROGRESS` widget, color hint `GREEN`, callout on start "FIND THE SWEET SPOT!" (flavor text shown for ~2 s).

**Flavor** — "Zero point zero zero one is polite. Zero point five is a fire."

**Fail lines**

- "Learning rate: spicy. Loss: NaN."
- "You overshot. The model is gone."
- "Too timid. It learned nothing. Neither did you."

**Tags** — `meter` · `ai` · `training`

#### CHARGE_BLAST — 1 micro-game

**Engine** — hold to charge a 0..1 meter, then release inside the optimal window. `target` good releases wins; releasing outside the window just wastes the attempt (`fail_on: NONE`).

Members: [Push & Pray](#push-pray-pushandpray).

## Push & Pray (`push_and_pray`)

**Archetype** `CHARGE_BLAST` · **Duration** 20.0 s · **Base score** 1250 · **Weight** 1.1  
**Style pack** `INK_NOIR` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `HYBRID`

**Objective** — "Charge the push and release at full power. Main branch is watching."

You hold to charge and release near full power, again and again.

**Spawn** — 1 entity, `RING`, motion `ORBIT at 3`, radius 12, 20 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `CHARGE_RELEASE`, target **5**, tolerance 0.12, `fail_on: NONE`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `PROGRESS` widget, color hint `RED`, callout on start "RELEASE AT FULL!" (flavor text shown for ~2 s).

**Flavor** — "Force push on a Friday. The team will remember this forever."

**Fail lines**

- "Main branch rejected you. Politely."
- "You pushed to the wrong remote. Again."
- "Conflicts: fourteen. Sanity: zero."

**Tags** — `charge` · `hybrid` · `git`

#### PUSH_ZONE — 1 micro-game

**Engine** — shove the objects into the delivery zone on the far side of the arena. Each object that enters the zone radius counts.

Members: [Feature Freeze](#feature-freeze-featurefreeze).

## Feature Freeze (`feature_freeze`)

**Archetype** `PUSH_ZONE` · **Duration** 25.0 s · **Base score** 1200 · **Weight** 1.0  
**Style pack** `CANDY_PLASTIC` · **Music state** `PEAK` · **Input mode** `RUN` · **Theme tag** `HYBRID`

**Objective** — "Push the features into the release zone. Or into scope creep. Your call."

You shove the features across the arena and into the delivery zone.

**Spawn** — 10 entities (scales with difficulty), `SCATTER`, motion `STATIC`, radius 18, 25 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `PUSH_N_TO_ZONE`, target **7**, tolerance —, `fail_on: TIMEOUT`, time bonus **+100 pts/s** of leftover time, combo step **0.25** per hit.

**HUD** — `COUNTER` widget, color hint `PINK`, callout on start "PUSH THEM IN!" (flavor text shown for ~2 s).

**Flavor** — "The freeze is tomorrow. The feature list is alive and growing."

**Fail lines**

- "Scope creep: victorious."
- "The feature ran away. It has legs now."
- "Frozen. With the features outside. Watching."

**Tags** — `push` · `hybrid` · `release`

#### MEMORY — 3 micro-games

**Engine** — a deterministic sequence (same `SeededRNG` + seed = same pattern) is revealed, then you repeat it with BUTTON. A wrong entry restarts the round.

Members: [Context Recall](#context-recall-contextrecall), [Password Palace](#password-palace-passwordpalace), [Overfitting Olympics](#overfitting-olympics-overfittingolympics).

## Context Recall (`context_recall`)

**Archetype** `MEMORY` · **Duration** 24.0 s · **Base score** 1250 · **Weight** 1.1  
**Style pack** `SPRITE_25D` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `AI`

**Objective** — "Repeat the context sequence. Before it is evicted."

You watch the sequence light up, then repeat it before it is evicted.

**Spawn** — 4 entities, `RING`, motion `ORBIT at 2`, radius 12, 24 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `MEMORY_REPLAY`, target **8**, tolerance —, `fail_on: WRONG_INPUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `SEQUENCE` widget, color hint `CYAN`, callout on start "REMEMBER THIS!" (flavor text shown for ~2 s).

**Flavor** — "Your window is full. Your memory is full. Your patience is a myth."

**Fail lines**

- "Context evicted. Permanently."
- "You forgot token four. It mattered."
- "Recall failed. Reboot and pretend."

**Tags** — `memory` · `ai` · `context`

## Password Palace (`password_palace`)

**Archetype** `MEMORY` · **Duration** 24.0 s · **Base score** 1100 · **Weight** 1.2  
**Style pack** `GOLD_RUSH` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `AI`

**Objective** — "Repeat the password sequence. It was the good one. Obviously."

You watch the sequence light up, then repeat it exactly — the good one, obviously.

**Spawn** — 4 entities, `RING`, motion `ORBIT at 2`, radius 12, 24 s lifetime. Entity: `BOX`, size 0.6, tint `Color(0.7, 0.7, 0.75, 1)`.

**Win / fail** — kind `MEMORY_REPLAY`, target **8**, tolerance —, `fail_on: WRONG_INPUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `SEQUENCE` widget, color hint `YELLOW`, callout on start "TYPE IT RIGHT!" (flavor text shown for ~2 s).

**Flavor** — "Uppercase, lowercase, symbol, sacrifice. You knew it yesterday."

**Fail lines**

- "Password incorrect. Attempts: two."
- "Hint says 'the good one'. Useless."
- "Locked out. Reset via email. Sigh."

**Tags** — `memory` · `life` · `password`

## Overfitting Olympics (`overfitting_olympics`)

**Archetype** `MEMORY` · **Duration** 24.0 s · **Base score** 1300 · **Weight** 1.0  
**Style pack** `CHROME_BEAM` · **Music state** `TENSION` · **Input mode** `BUTTON` · **Theme tag** `AI`

**Objective** — "Memorize the training set perfectly. It will not generalize. That is fine."

You memorize the longer pattern and repeat it perfectly.

**Spawn** — 5 entities, `RING`, motion `ORBIT at 2.5`, radius 13, 24 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `MEMORY_REPLAY`, target **10**, tolerance —, `fail_on: WRONG_INPUT`, time bonus **+110 pts/s** of leftover time, combo step **0.25** per hit.

**HUD** — `SEQUENCE` widget, color hint `WHITE`, callout on start "MEMORIZE IT ALL!" (flavor text shown for ~2 s).

**Flavor** — "One hundred percent on the exam. Zero percent on reality. Gold medal."

**Fail lines**

- "Validated against the training set. Only the training set."
- "You memorized the answers. Not the questions."
- "Generalization: did not participate."

**Tags** — `memory` · `ai` · `overfitting`

#### BALANCE — 1 micro-game

**Engine** — follow the waypoints in order along a path that narrows with difficulty. Drifting beyond the allowed width counts as a fall, which with `fail_on: FALL` ends the micro-game.

Members: [Stack Overflow](#stack-overflow-stackoverflow).

## Stack Overflow (`stack_overflow`)

**Archetype** `BALANCE` · **Duration** 22.0 s · **Base score** 1200 · **Weight** 1.1  
**Style pack** `INK_NOIR` · **Music state** `TENSION` · **Input mode** `RUN` · **Theme tag** `HYBRID`

**Objective** — "Balance the overloaded stack. Do not drop the frame."

You walk the waypoints in order along a path that keeps narrowing.

**Spawn** — 6 entities (scales with difficulty), `LINE`, motion `STATIC`, radius 14, 22 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `BALANCE_T`, target **15**, tolerance —, `fail_on: FALL`, time bonus **+110 pts/s** of leftover time, combo step **0.2** per hit.

**HUD** — `TIMER` widget, color hint `PURPLE`, callout on start "DON'T DROP IT!" (flavor text shown for ~2 s).

**Flavor** — "Every layer is legacy. The bottom one is from 2009. It screams."

**Fail lines**

- "Dropped a frame. And the load."
- "The stack collapsed. It was inevitable."
- "You fell off. The bottom is far."

**Tags** — `balance` · `hybrid` · `stack`

#### STACK_TIMED — 1 micro-game

**Engine** — press as a piece lands in the drop window. A press inside the window stacks a block; a press outside it knocks one off the tower.

Members: [Tech Debt Tower](#tech-debt-tower-techdebttower).

## Tech Debt Tower (`tech_debt_tower`)

**Archetype** `STACK_TIMED` · **Duration** 25.0 s · **Base score** 1250 · **Weight** 1.1  
**Style pack** `PAPER_CRAFT` · **Music state** `PEAK` · **Input mode** `BUTTON` · **Theme tag** `HYBRID`

**Objective** — "Stack the debt blocks with timing. It will fall. It always falls."

You press as each block lands in the drop window; eight stacked blocks wins.

**Spawn** — 10 entities (scales with difficulty), `LINE`, motion `FALL at 5`, radius 15, 8 s lifetime. Entity: `SPHERE`, size 0.6, tint `Color(0.35, 0.85, 1.0, 1)`.

**Win / fail** — kind `STACK_N`, target **8**, tolerance 0.2, `fail_on: TIMEOUT`, time bonus **+110 pts/s** of leftover time, combo step **0.3** per hit.

**HUD** — `COUNTER` widget, color hint `BROWN`, callout on start "STACK IT HIGH!" (flavor text shown for ~2 s).

**Flavor** — "The bottom layer is a workaround from 2019. Build on that. Sure."

**Fail lines**

- "Tower collapsed. Refactor denied."
- "You stacked it wrong. Everyone noticed."
- "Debt paid. Karma: not so much."

**Tags** — `stack` · `hybrid` · `debt`

### Cross-cutting rules

- Every micro-game has **legible** victory and failure conditions, all auto-generated from `HUDRecipe`; the HUD is never hidden during a micro-game because the information *is* the mechanic.
- Failing a micro-game **does not end the match**: the bonus is lost, the combo resets, play continues.
- Leftover time on a win converts to bonus points, which rewards speed over stalling.
- Every micro-game fires at least three `ImpactFrame` spikes (start / hits / end) with no hardcoded numbers.
- All objective, flavor, fail and callout text is **English** and follows the voice guide in `scaffold.md` §2: short, fast, self-aware, sarcastic but never cruel — aimed at situations (tech bureaucracy, the commute, notification anxiety) and never at groups of people.
- All 36 micro-games are playable with keyboard, mouse and gamepad. `input_mode` declares the primary hook; `TAP` and `LOOK` entries fall back to the nearest target so every input device can clear the objective.

### Known gaps (data vs. engine)

Recorded here so the catalog stays honest. These are build items, not catalog entries.

1. **`motion` is unread outside `CHASE`.** Five `DODGE` entries declare `motion: FALL` (`not_found`, `commuter_chaos`, `hallucination_highway`, `gpu_meltdown`, `server_room_scramble`) and two declare `motion: CHASE` (`fire_drill`, `laundry_landmine`), but the archetype only spawns hazards and the shared entity only rotates. Until the prop (or the archetype) moves them, those hazards are static. The fix belongs in the prop or the archetype — never in a per-micro-game script.
2. **`learning_rate` sets `spawn_recipe.speed = 0`**, which makes `ArchetypeMeterStop` fall back to its default sweep rate (it only reads `speed` when it is `> 0`). The sweep is therefore not tunable from that `.tres`.
3. **`theme_tag` disagrees with `scaffold.md` §8.2 in five entries** — the `.tres` files say `HYBRID` where the scaffold table says `AI` (`gpu_meltdown`, `autocomplete_alley`, `inference_inferno`, `learning_rate`), and the secondary tag says `ai` for those four plus `password_palace`. The `.tres` is the source of truth; the scaffold table and its theme-balance claim should be re-synced.
4. **`COLLECT_RUSH` objective copy promises a hazard the slots do not model.** `grocery_getaway` says "Do not touch the self-checkout" and `porch_pirate` says pirates appear, but both use `fail_on: TIMEOUT` with collectibles only — no `mg_hazard` group is spawned. Either the copy is aspirational or the slots are missing a penalty; it is not a code fix.
