extends Node
## SeededRNG — deterministic RNG wrapper (scaffold §7.2 context + §6).
##
## ALL randomness in the game (roulette, spawns, minigames) must flow through
## this so runs are reproducible for tests and replays. Same seed -> same
## sequence, guaranteed by the state dump/load pair.

var _state: int = 0
var _seed: int = 0


func _ready() -> void:
	seed(12345)


## Seed the generator. Same seed always replays the same sequence.
func seed(new_seed: int) -> void:
	_seed = new_seed
	# Warm-up scramble so low seeds diverge immediately.
	_state = new_seed
	for _i in 8:
		_state = _next()


## Current seed (for logging / replay manifests).
func current_seed() -> int:
	return _seed


## Snapshot for exact replay (store with match recordings).
func dump_state() -> int:
	return _state


## Restore a snapshot (replay / test determinism).
func load_state(state: int) -> void:
	_state = state


## xorshift32 step — pure, deterministic, fast.
func _next() -> int:
	var x: int = _state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	_state = x & 0xFFFFFFFF
	return _state


## Float in [0, 1). Explicit `self.` on internal calls: a bare `randf()`
## inside this script would resolve to the ENGINE global RNG and silently
## break determinism (scaffold §7.2).
func randf() -> float:
	return float(_next() & 0xFFFFFF) / float(0x1000000)


## Integer in [from, to] inclusive.
func randi_range(from: int, to: int) -> int:
	if to < from:
		var t := from
		from = to
		to = t
	var span: int = to - from + 1
	return from + (_next() % span)


## Pick a uniform random element; empty array returns null.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[self.randi_range(0, items.size() - 1)]


## Weighted pick: weights parallel to items. Returns null for empty input.
## Deterministic given the same seed and same input order. Uses rejection
## sampling over two random draws to avoid xorshift low-bit bias.
func pick_weighted(items: Array, weights: Array[float]) -> Variant:
	if items.is_empty() or weights.is_empty() or items.size() != weights.size():
		return null
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return items[self.randi_range(0, items.size() - 1)]
	# Rejection sampling: draw an index by value and a uniform roll; accept
	# only when the roll lands under that item's weight share (Lemire-style
	# unbiased selection with our deterministic stream).
	for _attempt in 64:
		var idx: int = _next() % items.size()
		var threshold: float = maxf(weights[idx], 0.0) / total
		if self.randf() < threshold:
			return items[idx]
	# Deterministic fallback: cumulative scan with a final uniform draw.
	var roll := self.randf() * total
	var acc := 0.0
	for i in items.size():
		acc += maxf(weights[i], 0.0)
		if roll < acc:
			return items[i]
	return items[items.size() - 1]
