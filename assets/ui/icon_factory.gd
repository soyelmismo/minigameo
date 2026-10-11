class_name UIIconFactory
extends RefCounted
## Generador de iconos del HUD (assets/ui/, scaffold §13.1).
##
## Los iconos se generan por código con siluetas DISTINTAS (requisito de
## accesibilidad §13.3: forma + color, nunca solo color) y outline grueso
## oscuro (§13.2). El generador que materializa los PNG es
## `assets/ui/generate_icons.gd`; esta clase es la fuente reproducible.

const ICON_SIZE: int = 64
const OUTLINE: int = 3


static func _build(mask: Callable, fill: Color, outline: Color = UIColors.OUTLINE) -> ImageTexture:
	var n := ICON_SIZE
	var grid := PackedInt32Array()
	grid.resize(n * n)
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			grid[y * n + x] = 1 if mask.call(p) else 0
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var col := Color.TRANSPARENT
			if grid[y * n + x] == 1:
				col = fill
			else:
				var near := false
				for dy in range(-OUTLINE, OUTLINE + 1):
					for dx in range(-OUTLINE, OUTLINE + 1):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and nx < n and ny >= 0 and ny < n and grid[ny * n + nx] == 1:
							near = true
							break
					if near:
						break
				if near:
					col = outline
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if (pi.y > p.y) != (pj.y > p.y):
			var t: float = (p.y - pi.y) / (pj.y - pi.y)
			if p.x < pi.x + t * (pj.x - pi.x):
				inside = not inside
		j = i
	return inside


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2: float = ab.length_squared()
	if l2 <= 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _ngon(center: Vector2, radius: float, sides: int, rot_deg: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a: float = deg_to_rad(rot_deg + float(i) * 360.0 / float(sides))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func _star(center: Vector2, r_out: float, r_in: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r: float = r_out if i % 2 == 0 else r_in
		var a: float = deg_to_rad(-90.0 + float(i) * 180.0 / float(points))
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


# --- Siluetas (una por icono; todas distintas entre sí) ---

static func token() -> ImageTexture:
	var c := Vector2(32.0, 32.0)
	return _build(func(p: Vector2) -> bool: return p.distance_to(c) <= 23.0, UIColors.PRIMARY)


static func heart() -> ImageTexture:
	var c := Vector2(32.0, 34.0)
	return _build(
		func(p: Vector2) -> bool:
			var u: float = (p.x - c.x) / 15.0
			var v: float = (p.y - c.y) / 14.0
			var q: float = u * u + v * v - 1.0
			return q * q * q - u * u * v * v * v <= 0.0,
		UIColors.LIFE
	)


static func star() -> ImageTexture:
	var poly := _star(Vector2(32.0, 33.0), 25.0, 11.0, 5)
	return _build(func(p: Vector2) -> bool: return _point_in_poly(p, poly), UIColors.PRIMARY)


static func square() -> ImageTexture:
	var poly := _ngon(Vector2(32.0, 32.0), 22.0, 4, 45.0)
	return _build(func(p: Vector2) -> bool: return _point_in_poly(p, poly), UIColors.AI)


static func triangle() -> ImageTexture:
	var poly := _ngon(Vector2(32.0, 36.0), 25.0, 3, -90.0)
	return _build(func(p: Vector2) -> bool: return _point_in_poly(p, poly), UIColors.WARN)


static func diamond() -> ImageTexture:
	var poly := _ngon(Vector2(32.0, 32.0), 24.0, 4, 0.0)
	return _build(func(p: Vector2) -> bool: return _point_in_poly(p, poly), UIColors.HYBRID)


static func plus() -> ImageTexture:
	return _build(
		func(p: Vector2) -> bool:
			var a := p.distance_to(Vector2(32.0, 32.0))
			var h: bool = absf(p.x - 32.0) <= 8.0 and absf(p.y - 32.0) <= 24.0
			var v: bool = absf(p.y - 32.0) <= 8.0 and absf(p.x - 32.0) <= 24.0
			return h or v or a <= 0.0,
		UIColors.GOOD
	)


static func bell() -> ImageTexture:
	return _build(
		func(p: Vector2) -> bool:
			var trapezoid := _point_in_poly(
				p,
				PackedVector2Array([
					Vector2(19, 27), Vector2(45, 27), Vector2(41, 49), Vector2(23, 49)
				])
			)
			var knob := p.distance_to(Vector2(32.0, 23.0)) <= 5.0
			var clapper := p.distance_to(Vector2(32.0, 54.0)) <= 6.0
			return trapezoid or knob or clapper,
		UIColors.AI
	)


static func bolt() -> ImageTexture:
	var poly := PackedVector2Array([
		Vector2(36, 8), Vector2(18, 36), Vector2(29, 36), Vector2(24, 58),
		Vector2(46, 28), Vector2(34, 28)
	])
	return _build(func(p: Vector2) -> bool: return _point_in_poly(p, poly), UIColors.PRIMARY)


static func gear() -> ImageTexture:
	return _build(
		func(p: Vector2) -> bool:
			var d: float = p.distance_to(Vector2(32.0, 32.0))
			if d <= 8.0:
				return false
			if d <= 20.0:
				return true
			for i in 8:
				var a: float = deg_to_rad(float(i) * 45.0)
				var tooth := Vector2(32.0, 32.0) + Vector2(cos(a), sin(a)) * 23.0
				if p.distance_to(tooth) <= 6.5:
					return true
			return false,
		UIColors.TEXT_DIM
	)


static func clock() -> ImageTexture:
	return _build(
		func(p: Vector2) -> bool:
			var d: float = p.distance_to(Vector2(32.0, 32.0))
			var ring: bool = d >= 16.0 and d <= 23.0
			var hand_h: bool = _seg_dist(p, Vector2(32, 32), Vector2(46, 32)) <= 3.5
			var hand_v: bool = _seg_dist(p, Vector2(32, 32), Vector2(32, 19)) <= 3.5
			return ring or hand_h or hand_v,
		UIColors.AI
	)


static func check() -> ImageTexture:
	return _build(
		func(p: Vector2) -> bool:
			return _seg_dist(p, Vector2(15, 33), Vector2(27, 46)) <= 6.0 \
				or _seg_dist(p, Vector2(27, 46), Vector2(51, 16)) <= 6.0,
		UIColors.GOOD
	)


static func cross_mark() -> ImageTexture:
	return _build(
		func(p: Vector2) -> bool:
			return _seg_dist(p, Vector2(17, 17), Vector2(47, 47)) <= 6.5 \
				or _seg_dist(p, Vector2(47, 17), Vector2(17, 47)) <= 6.5,
		UIColors.DANGER
	)


static func arrow_up() -> ImageTexture:
	var head := _ngon(Vector2(32.0, 24.0), 17.0, 3, -90.0)
	return _build(
		func(p: Vector2) -> bool:
			return _point_in_poly(p, head) \
				or (absf(p.x - 32.0) <= 6.0 and p.y >= 24.0 and p.y <= 56.0),
		UIColors.TEXT
	)


static func all_icons() -> Dictionary:
	return {
		&"token": token(),
		&"heart": heart(),
		&"star": star(),
		&"square": square(),
		&"triangle": triangle(),
		&"diamond": diamond(),
		&"plus": plus(),
		&"bell": bell(),
		&"bolt": bolt(),
		&"gear": gear(),
		&"clock": clock(),
		&"check": check(),
		&"cross": cross_mark(),
		&"arrow": arrow_up(),
	}
