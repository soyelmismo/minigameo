class_name HudThemeFactory
extends RefCounted
## Generates the HUD theme variants per style pack (scaffold §13.2).
##
## The 12 palettes come from §9; every pack references its hud_theme
## (StylePack.hud_theme). The .tres are materialized with
## assets/ui/generate_icons.gd o el comando de themes; esta clase es la
## reproducible source used by StyleDirector when the pack does not bring one.

## Paletas de §9 (top-level: acento del HUD; panel: fondo).
const _PALETTES := {
	&"NEON_DRIFT": [Color(0.15, 0.95, 1.0), Color(1.0, 0.25, 0.85)],
	&"INK_NOIR": [Color(0.96, 0.96, 0.96), Color(0.35, 0.35, 0.35)],
	&"TOON_POP": [Color(1.0, 0.25, 0.25), Color(0.25, 0.5, 1.0)],
	&"VHS_90": [Color(1.0, 0.35, 0.55), Color(0.35, 0.85, 0.9)],
	&"BIT_CRUSH": [Color(0.6, 0.9, 0.3), Color(0.9, 0.4, 0.9)],
	&"CHROME_BEAM": [Color(0.8, 0.85, 0.9), Color(0.45, 0.5, 0.55)],
	&"CANDY_PLASTIC": [Color(1.0, 0.6, 0.8), Color(0.6, 0.9, 1.0)],
	&"KAIJU_SOFVI": [Color(0.95, 0.35, 0.3), Color(0.3, 0.7, 0.4)],
	&"SPRITE_25D": [Color(0.55, 0.35, 1.0), Color(1.0, 0.85, 0.3)],
	&"PAPER_CRAFT": [Color(0.85, 0.7, 0.5), Color(0.6, 0.5, 0.4)],
	&"GOLD_RUSH": [Color(1.0, 0.85, 0.3), Color(0.25, 0.2, 0.1)],
	&"WATERCOLOR": [Color(0.5, 0.65, 0.9), Color(0.95, 0.8, 0.7)],
}


## Theme for a pack. Unknown → base theme (§13.2 degradation).
static func theme_for(pack_id: StringName) -> Theme:
	var pal: PackedColorArray = _PALETTES.get(pack_id, PackedColorArray([UIColors.PRIMARY, UIColors.PANEL]))
	var accent: Color = pal[0]
	var panel: Color = UIColors.PANEL
	panel = panel.lerp(accent, 0.12)

	var theme := Theme.new()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel
	panel_style.border_color = accent
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(14)
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = panel_style.bg_color
	button_style.border_color = UIColors.TEXT
	button_style.set_border_width_all(4)
	button_style.set_corner_radius_all(18)
	theme.set_stylebox("normal", "Button", button_style)
	theme.set_stylebox("hover", "Button", button_style)
	theme.set_stylebox("pressed", "Button", button_style)
	theme.set_color("font_color", "Button", UIColors.TEXT)
	theme.set_color("font_hover_color", "Button", accent)

	theme.set_color("font_color", "Label", UIColors.TEXT)
	theme.set_color("font_outline_color", "Label", UIColors.OUTLINE)
	theme.set_constant("outline_size", "Label", 8)
	theme.set_font_size("font_size", "Label", 28)
	theme.set_font_size("font_size", "Button", 40)
	return theme


static func pack_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k: StringName in _PALETTES:
		ids.append(k)
	return ids
