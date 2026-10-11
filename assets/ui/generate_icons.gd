extends SceneTree
## Generador de assets de UI (scaffold §13.1).
##
## Uso: `godot --headless -s res://assets/ui/generate_icons.gd`
## Materializa los PNG de iconos en assets/ui/ desde UIIconFactory.
## Es idempotente: regenerar sobrescribe con las mismas siluetas.

func _initialize() -> void:
	var icons: Dictionary = UIIconFactory.all_icons()
	for key: StringName in icons:
		var tex: ImageTexture = icons[key]
		var img: Image = tex.get_image()
		if img == null:
			push_error("generate_icons: no image for %s" % key)
			continue
		var path := "res://assets/ui/icon_%s.png" % key
		var err := img.save_png(path)
		if err != OK:
			push_error("generate_icons: save failed %s (%d)" % [path, err])
		else:
			print("generate_icons: wrote %s" % path)
	quit(0)
