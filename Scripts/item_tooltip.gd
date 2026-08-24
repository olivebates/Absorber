class_name ItemTooltip
extends PanelContainer

var _icon: TextureRect
var _rank: Label
var _stat_icon: TextureRect
var _stat: Label
var _target_position := Vector2.ZERO


func _ready() -> void:
	z_index = 100
	_set_style(Color("777777"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	add_child(content)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(38, 38)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(_icon)
	_rank = Label.new()
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.add_theme_color_override("font_outline_color", Color.BLACK)
	_rank.add_theme_constant_override("outline_size", 2)
	content.add_child(_rank)
	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(stat_row)
	_stat_icon = TextureRect.new()
	_stat_icon.custom_minimum_size = Vector2(16, 16)
	_stat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stat_row.add_child(_stat_icon)
	_stat = Label.new()
	_stat.add_theme_color_override("font_color", Color.WHITE)
	_stat.add_theme_color_override("font_outline_color", Color.BLACK)
	_stat.add_theme_constant_override("outline_size", 2)
	stat_row.add_child(_stat)
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_update_target_position()
	position = position.lerp(_target_position, 1.0 - exp(-18.0 * delta))


func show_item(item: Dictionary) -> void:
	var item_id := str(item.get("item_id", ""))
	if not ItemPickup.ITEM_DATA.has(item_id):
		return
	var is_weapon := ItemPickup.is_weapon(item_id)
	_icon.texture = ItemPickup.ITEM_TEXTURES[item_id]
	_icon.visible = true
	if ItemPickup.is_consumable(item_id):
		_rank.text = str(ItemPickup.ITEM_NAMES.get(item_id, item_id.capitalize()))
		_rank.visible = true
		_rank.add_theme_color_override("font_color", Color.WHITE)
		_stat_icon.texture = preload("res://Sprites/Heart.webp")
		_stat_icon.visible = true
		_stat.text = "Full Heal" if ItemPickup.is_full_heal(item) else "+%d HP" % ItemPickup.get_healing_amount(item)
		_stat.visible = true
		_set_style(Color("777777"))
		visible = true
		reset_size()
		_place_inside_camera()
		return
	var grade := ItemPickup.get_item_grade(item)
	_rank.text = "Grade %d · %s" % [grade, ItemPickup.get_grade_name(grade)]
	_rank.visible = true
	_rank.add_theme_color_override("font_color", ItemPickup.get_grade_color(grade))
	_stat_icon.texture = preload("res://Sprites/DamageIcon.webp") if is_weapon else preload("res://Sprites/ArmorIcon.webp")
	_stat_icon.visible = true
	_stat.text = "+%d" % (ItemPickup.get_damage_bonus(item) if is_weapon else ItemPickup.get_block_amount(item))
	_stat.visible = true
	_set_style(ItemPickup.get_grade_color(grade))
	visible = true
	reset_size()
	_place_inside_camera()


func show_description(icon: Texture2D, title: String, description: String) -> void:
	_icon.texture = icon
	_icon.visible = icon != null
	_rank.text = title
	_rank.visible = not title.is_empty()
	_rank.add_theme_color_override("font_color", Color.WHITE)
	_stat_icon.visible = false
	_stat.text = description
	_stat.visible = not description.is_empty()
	_set_style(Color("777777"))
	visible = true
	reset_size()
	_place_inside_camera()


func hide_item() -> void:
	visible = false


func _place_inside_camera() -> void:
	if not visible:
		return
	_update_target_position()
	position = _target_position


func _update_target_position() -> void:
	var viewport_size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var desired := mouse + Vector2(18, 18)
	if desired.x + size.x > viewport_size.x:
		desired.x = mouse.x - size.x - 18.0
	if desired.y + size.y > viewport_size.y:
		desired.y = mouse.y - size.y - 18.0
	_target_position = Vector2(
		clampf(desired.x, 0.0, maxf(0.0, viewport_size.x - size.x)),
		clampf(desired.y, 0.0, maxf(0.0, viewport_size.y - size.y))
	)


func _set_style(rank_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = rank_color.darkened(0.48)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)
