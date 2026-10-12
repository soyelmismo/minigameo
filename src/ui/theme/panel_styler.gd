extends Node
class_name PanelStyler
## Shared Nintendo-arcade style (scaffold §13.2): rounded corners,
## thick dark outline, semi-opaque panel. Applied by the HUD and the screens.

static func panel_style(border_color: Color = UIColors.PRIMARY, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.PANEL
	sb.border_color = border_color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(radius)
	return sb


static func apply(panel: Panel, border_color: Color = UIColors.PRIMARY, radius: int = 14) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(border_color, radius))
