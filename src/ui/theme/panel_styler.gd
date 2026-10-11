extends Node
class_name PanelStyler
## Estilo Nintendo-arcade compartido (scaffold §13.2): esquinas redondeadas,
## outline grueso oscuro, panel semiopaco. Lo aplican HUD y pantallas.

static func panel_style(border_color: Color = UIColors.PRIMARY, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.PANEL
	sb.border_color = border_color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(radius)
	return sb


static func apply(panel: Panel, border_color: Color = UIColors.PRIMARY, radius: int = 14) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(border_color, radius))
