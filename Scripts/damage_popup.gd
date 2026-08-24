class_name DamagePopup
extends Control

const DAMAGE_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const SHIELD_ICON := preload("res://Sprites/ShieldIcon.webp")


func show_damage(amount: int, color_index := 0, blocked_damage := 0) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	row.add_child(_make_icon(DAMAGE_ICON))
	row.add_child(_make_label("-%d" % amount, DAMAGE_COLORS[clampi(color_index, 0, DAMAGE_COLORS.size() - 1)]))
	if blocked_damage > 0:
		row.add_child(_make_icon(SHIELD_ICON))
		row.add_child(_make_label(str(blocked_damage), DAMAGE_COLORS[2]))
	modulate.a = 1.0
	scale = Vector2(0.7, 0.7)
	var animation := create_tween().set_parallel()
	animation.tween_property(self, "position:y", position.y - 30.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animation.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.43)
	animation.finished.connect(queue_free)


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _make_label(copy: String, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1f0605"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
