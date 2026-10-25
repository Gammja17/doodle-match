class_name WordRow
extends HBoxContainer


const GLYPH: = preload("res://scenes/board/fx/glyph.tscn")



func show_glyphs(glyphs: Array[Texture2D], height: float, color: = Color.WHITE) -> void :
	while get_child_count() < glyphs.size():
		add_child(GLYPH.instantiate())
	for i in get_child_count():
		var r: TextureRect = get_child(i)
		r.visible = i < glyphs.size()
		if r.visible:
			var t: = glyphs[i]
			r.texture = t
			r.custom_minimum_size = Vector2(height * t.get_width() / t.get_height(), height)
			r.self_modulate = color
	add_theme_constant_override("separation", roundi( - height * 0.08))
	size = get_combined_minimum_size()
