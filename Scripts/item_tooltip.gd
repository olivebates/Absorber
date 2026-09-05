class_name ItemTooltip
extends PanelContainer

var _icon: TextureRect
var _icon_row: HBoxContainer
var _stone_slot: PanelContainer
var _stone_icon: TextureRect
var _rank: Label
var _instruction: Label
var _stat_dot: Control
var _stat_icon: TextureRect
var _stat: Label
var _stat_bonus: Label
var _secondary_stat_dot: Control
var _secondary_stat_icon: TextureRect
var _secondary_stat: Label
var _secondary_stat_bonus: Label
var _extra_rows: VBoxContainer
var _target_position := Vector2.ZERO
var _displayed_grade := -1
var _panel_style: StyleBoxFlat


func _ready() -> void:
	z_index = 2000
	_set_style(Color("777777"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	add_child(content)
	_icon_row = HBoxContainer.new()
	_icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_icon_row.add_theme_constant_override("separation", 6)
	content.add_child(_icon_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(38, 38)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_row.add_child(_icon)
	_stone_slot = PanelContainer.new()
	_stone_slot.name = "EquipmentStoneSlot"
	_stone_slot.custom_minimum_size = Vector2(38, 38)
	var stone_slot_style := StyleBoxFlat.new()
	stone_slot_style.bg_color = Color("192236")
	stone_slot_style.border_color = Color.BLACK
	stone_slot_style.set_border_width_all(2)
	stone_slot_style.set_corner_radius_all(4)
	_stone_slot.add_theme_stylebox_override("panel", stone_slot_style)
	_icon_row.add_child(_stone_slot)
	_stone_icon = TextureRect.new()
	_stone_icon.name = "StoneIcon"
	_stone_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stone_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stone_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stone_slot.add_child(_stone_icon)
	_rank = Label.new()
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.add_theme_color_override("font_outline_color", Color.BLACK)
	_rank.add_theme_constant_override("outline_size", 2)
	content.add_child(_rank)
	_instruction = Label.new()
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.add_theme_color_override("font_color", Color.WHITE)
	_instruction.add_theme_color_override("font_outline_color", Color.BLACK)
	_instruction.add_theme_constant_override("outline_size", 2)
	_instruction.hide()
	content.add_child(_instruction)
	var stat_row := _make_stat_row(content)
	_stat_dot = stat_row[0] as Control
	_stat_icon = stat_row[1] as TextureRect
	_stat = stat_row[2] as Label
	_stat_bonus = stat_row[3] as Label
	var secondary_row := _make_stat_row(content)
	_secondary_stat_dot = secondary_row[0] as Control
	_secondary_stat_icon = secondary_row[1] as TextureRect
	_secondary_stat = secondary_row[2] as Label
	_secondary_stat_bonus = secondary_row[3] as Label
	_secondary_stat_icon.get_parent().hide()
	_extra_rows = VBoxContainer.new()
	_extra_rows.add_theme_constant_override("separation", 2)
	content.add_child(_extra_rows)
	visible = false
	set_process(true)


func _make_stat_row(parent: VBoxContainer) -> Array:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var dot := Panel.new()
	dot.name = "StatColorDot"
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.hide()
	row.add_child(dot)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	row.add_child(label)
	var bonus := Label.new()
	bonus.name = "StackedStoneBonus"
	bonus.add_theme_color_override("font_color", Color("63d471"))
	bonus.add_theme_color_override("font_outline_color", Color.BLACK)
	bonus.add_theme_constant_override("outline_size", 2)
	bonus.hide()
	row.add_child(bonus)
	return [dot, icon, label, bonus]

func _process(delta: float) -> void:
	if not visible:
		return
	if ItemPickup.is_animated_grade(_displayed_grade):
		var grade_color := ItemPickup.get_grade_color(_displayed_grade)
		_rank.add_theme_color_override("font_color", grade_color)
		_update_style_color(grade_color)
	_update_target_position()
	position = position.lerp(_target_position, 1.0 - exp(-18.0 * delta))


func show_item(item: Dictionary) -> void:
	_displayed_grade = -1
	_hide_secondary_stat()
	_clear_extra_rows()
	_instruction.hide()
	_stat_bonus.hide()
	_secondary_stat_bonus.hide()
	var item_id := str(item.get("item_id", ""))
	if not ItemPickup.ITEM_DATA.has(item_id):
		return
	var is_weapon := ItemPickup.is_weapon(item_id)
	_icon.texture = ItemPickup.ITEM_TEXTURES[item_id]
	_icon.modulate = ItemPickup.get_icon_modulate(item_id)
	_icon.visible = true
	_stone_slot.visible = ItemPickup.is_equipment(item_id)
	var equipped_stone := ItemPickup.get_equipped_stone(item)
	_stone_icon.texture = ItemPickup.ITEM_TEXTURES.get(str(equipped_stone.get("item_id", ""))) if not equipped_stone.is_empty() else null
	_stone_icon.modulate = ItemPickup.get_icon_modulate(str(equipped_stone.get("item_id", "")))
	var description := ItemPickup.get_description(item_id)
	if not description.is_empty():
		_rank.text = str(ItemPickup.ITEM_NAMES.get(item_id, item_id.capitalize()))
		_rank.visible = true
		_rank.add_theme_color_override("font_color", Color.WHITE)
		_stat_icon.visible = false
		_stat.text = description
		_stat.add_theme_color_override("font_color", Color.WHITE)
		_stat.visible = true
		_set_style(Color("b71c1c") if ItemPickup.is_protected(item_id) else Color("777777"))
		_show_and_place()
		return
	var grade := ItemPickup.get_item_grade(item)
	var full_name := "%s %s" % [ItemPickup.get_grade_name(grade), str(ItemPickup.ITEM_NAMES.get(item_id, item_id.capitalize()))]
	if ItemPickup.is_consumable(item_id):
		_rank.text = full_name
		_rank.visible = true
		_rank.add_theme_color_override("font_color", Color.WHITE)
		_stat_icon.texture = preload("res://Sprites/Heart.webp")
		_stat_icon.visible = true
		_stat.text = "Full Heal" if ItemPickup.is_full_heal(item) else "+%d HP" % ItemPickup.get_healing_amount(item)
		_stat.add_theme_color_override("font_color", Color.WHITE)
		_stat.visible = true
		_set_style(Color("777777"))
		_show_and_place()
		return
	if ItemPickup.is_stone(item_id):
		var stone_grade := ItemPickup.get_item_grade(item)
		var stone_stat := ItemPickup.get_stone_stat(item)
		_displayed_grade = stone_grade
		_rank.text = "%s %s" % [ItemPickup.get_grade_name(stone_grade), str(ItemPickup.ITEM_NAMES[item_id])]
		_rank.visible = true
		_rank.add_theme_color_override("font_color", ItemPickup.get_grade_color(stone_grade))
		_instruction.text = "Drag onto equipment to activate."
		_instruction.show()
		_stat_icon.texture = preload("res://Sprites/DamageIcon.webp") if stone_stat == &"damage" else preload("res://Sprites/iconThorn.webp") if stone_stat == &"thorn" else preload("res://Sprites/ShieldIcon.webp")
		_stat_icon.visible = true
		_stat.text = "+%d" % ItemPickup.get_stone_bonus(item)
		var stone_colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
		_stat.add_theme_color_override("font_color", Color("63d471") if stone_stat == &"thorn" else stone_colors[ItemPickup.get_stat_color(item)])
		_stat.visible = true
		_set_style(ItemPickup.get_grade_color(stone_grade))
		_show_and_place()
		return
	_displayed_grade = grade
	_rank.text = full_name
	_rank.visible = true
	_rank.add_theme_color_override("font_color", ItemPickup.get_grade_color(grade))
	var stat_colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
	var primary_color := ItemPickup.get_stat_color(item) if is_weapon else FoxPlayer.COLOR_RED
	_stat_icon.texture = preload("res://Sprites/DamageIcon.webp") if is_weapon else preload("res://Sprites/ShieldIcon.webp")
	_stat_icon.visible = true
	_stat.text = "+%d" % (ItemPickup.get_damage_bonus(item) if is_weapon else ItemPickup.get_block_amount(item))
	_stat.add_theme_color_override("font_color", stat_colors[primary_color])
	_stat.visible = true
	_set_dot_color(_stat_dot, stat_colors[primary_color])
	if not is_weapon:
		_secondary_stat_icon.texture = preload("res://Sprites/ShieldIcon.webp")
		_secondary_stat_icon.visible = true
		_secondary_stat.text = "+%d" % ItemPickup.get_block_amount(item)
		_secondary_stat.add_theme_color_override("font_color", stat_colors[FoxPlayer.COLOR_YELLOW])
		_secondary_stat.visible = true
		_set_dot_color(_secondary_stat_dot, stat_colors[FoxPlayer.COLOR_YELLOW])
		_secondary_stat_icon.get_parent().show()
	_show_equipped_stone_stat(item, is_weapon, primary_color, equipped_stone, stat_colors)
	var thorn_amount := ItemPickup.get_thorn_amount(item)
	if thorn_amount > 0:
		_add_extra_stat_row(preload("res://Sprites/iconThorn.webp"), "+%d Thorn" % thorn_amount, Color("63d471"))
	_set_style(ItemPickup.get_grade_color(grade))
	_show_and_place()


func show_description(icon: Texture2D, title: String, description: String, icon_modulate: Color = Color.WHITE) -> void:
	_displayed_grade = -1
	_hide_secondary_stat()
	_clear_extra_rows()
	_instruction.hide()
	_icon.texture = icon
	_icon.visible = icon != null
	_icon.modulate = icon_modulate
	_stone_slot.hide()
	_rank.text = title
	_rank.visible = not title.is_empty()
	_rank.add_theme_color_override("font_color", Color.WHITE)
	_stat_icon.visible = false
	_stat.text = description
	_stat.add_theme_color_override("font_color", Color.WHITE)
	_stat.visible = not description.is_empty()
	_set_style(Color("777777"))
	_show_and_place()


func show_catalog(icon: Texture2D, title: String, rows: Array[Dictionary], icon_modulate: Color = Color.WHITE) -> void:
	_displayed_grade = -1
	_hide_secondary_stat()
	_clear_extra_rows()
	_instruction.hide()
	_icon.texture = icon
	_icon.visible = icon != null
	_icon.modulate = icon_modulate
	_stone_slot.hide()
	_rank.text = title
	_rank.visible = not title.is_empty()
	_rank.add_theme_color_override("font_color", Color.WHITE)
	_stat_icon.get_parent().hide()
	for row_data in rows:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		_extra_rows.add_child(row)
		var row_icon := TextureRect.new()
		row_icon.custom_minimum_size = Vector2(16, 16)
		row_icon.texture = row_data.get("icon") as Texture2D
		row_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_icon.modulate = row_data.get("icon_modulate", Color.WHITE) as Color
		row.add_child(row_icon)
		var label := Label.new()
		label.text = str(row_data.get("text", ""))
		label.add_theme_color_override("font_color", row_data.get("color", Color.WHITE) as Color)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		row.add_child(label)
	_set_style(Color("777777"))
	_show_and_place()


func _show_and_place() -> void:
	visible = true
	reset_size()
	_place_inside_camera()


func _hide_secondary_stat() -> void:
	if is_instance_valid(_stat_icon):
		_stat_icon.get_parent().show()
	if is_instance_valid(_secondary_stat_icon):
		_secondary_stat_icon.visible = false
		_secondary_stat_icon.get_parent().hide()
	if is_instance_valid(_secondary_stat):
		_secondary_stat.visible = false
	if is_instance_valid(_stat_dot):
		_stat_dot.hide()
	if is_instance_valid(_secondary_stat_dot):
		_secondary_stat_dot.hide()
	if is_instance_valid(_stat_bonus):
		_stat_bonus.hide()
	if is_instance_valid(_secondary_stat_bonus):
		_secondary_stat_bonus.hide()


func _show_equipped_stone_stat(item: Dictionary, is_weapon: bool, primary_color: int, stone: Dictionary, stat_colors: Array) -> void:
	if stone.is_empty():
		return
	var stone_stat := ItemPickup.get_stone_stat(stone)
	var stone_color := ItemPickup.get_stat_color(stone)
	var bonus := ItemPickup.get_stone_bonus(stone)
	var stacks_primary := stone_color == primary_color and ((is_weapon and stone_stat == &"damage") or (not is_weapon and stone_stat == &"defense"))
	var stacks_secondary := not is_weapon and stone_stat == &"defense" and stone_color == FoxPlayer.COLOR_YELLOW
	if stacks_primary or stacks_secondary:
		var bonus_label := _stat_bonus if stacks_primary else _secondary_stat_bonus
		bonus_label.text = "+%d" % bonus
		bonus_label.show()
		return
	var row_data := _make_stat_row(_extra_rows)
	var dot := row_data[0] as Control
	var icon := row_data[1] as TextureRect
	var label := row_data[2] as Label
	icon.texture = preload("res://Sprites/DamageIcon.webp") if stone_stat == &"damage" else preload("res://Sprites/iconThorn.webp") if stone_stat == &"thorn" else preload("res://Sprites/ShieldIcon.webp")
	label.text = "+%d Thorn" % bonus if stone_stat == &"thorn" else "+%d %s %s" % [bonus, ["Red", "Yellow", "Blue"][stone_color], "Damage" if stone_stat == &"damage" else "Defence"]
	label.add_theme_color_override("font_color", Color("63d471"))
	_set_dot_color(dot, stat_colors[stone_color])


func _add_extra_stat_row(texture: Texture2D, copy: String, color: Color) -> void:
	var row_data := _make_stat_row(_extra_rows)
	var dot := row_data[0] as Control
	var icon := row_data[1] as TextureRect
	var label := row_data[2] as Label
	dot.hide()
	icon.texture = texture
	label.text = copy
	label.add_theme_color_override("font_color", color)


func _set_dot_color(dot: Control, color: Color) -> void:
	if not is_instance_valid(dot):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", style)
	dot.show()


func _clear_extra_rows() -> void:
	if not is_instance_valid(_extra_rows):
		return
	for child in _extra_rows.get_children():
		_extra_rows.remove_child(child)
		child.queue_free()


func hide_item() -> void:
	visible = false
	_displayed_grade = -1


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
	_panel_style = style
	add_theme_stylebox_override("panel", style)


func _update_style_color(rank_color: Color) -> void:
	if _panel_style:
		_panel_style.bg_color = rank_color.darkened(0.48)
