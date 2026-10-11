class_name VoiceLines
extends RefCounted
## Locutor VO catalog (scaffold.md §2 canonical callouts, VERBATIM).
##
## Canonical line table from scaffold §2 — the strings below are the
## authoritative start; the VoiceDirector picks a variation per event with
## seeded variation for repeat protection.
##
## NOTE on the canonical table: the scaffold text contains both a plain
## apostrophe form ("It's a bot. It can't be.") and the verbatim copy in the
## task instructions ("It's a bot. It cannot be."). The TASK-specified form
## (task instructions are the binding contract for this deliverable):
##   "Oof. The bot is disappointed. It is a bot. It cannot be. But it is."
## Same for S-RANK and FLAWLESS lines: task form is canonical here.

## --- Event ids (canonical, stable) ---
const EV_MATCH_START: StringName = &"match_start"
const EV_POWERUP_COLLECTED: StringName = &"powerup_collected"
const EV_ROULETTE_SPIN: StringName = &"roulette_spin"
const EV_MINIGAME_START: StringName = &"minigame_start"
const EV_COMBO_HIGH: StringName = &"combo_high"
const EV_TIME_WARNING: StringName = &"time_warning"
const EV_MINIGAME_FAIL: StringName = &"minigame_fail"
const EV_MINIGAME_FLAWLESS: StringName = &"minigame_flawless"
const EV_MATCH_RANK_S: StringName = &"match_rank_s"
const EV_MATCH_RANK_LOW: StringName = &"match_rank_low"

## Catalog: event id -> Array of line variants (English, player-facing).
const LINES: Dictionary = {
	EV_MATCH_START: [
		"FIVE MINUTES. NO MERCY. GO!",
	],
	EV_POWERUP_COLLECTED: [
		"ROULETTE TIME! Fate is loading...",
	],
	EV_ROULETTE_SPIN: [
		"What could it be? Who knows! Not me!",
	],
	EV_MINIGAME_START: [
		"GO GO GO!",
	],
	EV_COMBO_HIGH: [
		"COMBO x{5}! Show off.",
	],
	EV_TIME_WARNING: [
		"THIRTY SECONDS! PANIC!",
	],
	EV_MINIGAME_FAIL: [
		"Oof. The bot is disappointed. It is a bot. It cannot be. But it is.",
	],
	EV_MINIGAME_FLAWLESS: [
		"FLAWLESS. I am telling everyone.",
	],
	EV_MATCH_RANK_S: [
		"S-RANK! You absolute monster.",
	],
	EV_MATCH_RANK_LOW: [
		"Well. You tried. Did you though?",
	],
}

## All event ids in the catalog.
static func event_ids() -> Array:
	var out: Array = []
	for key: StringName in LINES:
		out.append(key)
	return out

## Line variants for an event (empty array for unknown events).
static func lines_for(event_id: StringName) -> Array:
	return LINES.get(event_id, []) as Array

## True when the event has at least one line.
static func has_event(event_id: StringName) -> bool:
	return LINES.has(event_id)
