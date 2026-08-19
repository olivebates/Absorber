class_name DamageGrid
extends PanelContainer

const DAMAGE_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")

var _player: FoxPlayer
var _grid: GridContainer
var _color_target_cells: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	_set_panel_style()
	call_deferred("_connect_player")


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _player:
		_player.damage_matrix_changed.connect(_refresh)
		_refresh()


func get_color_target_screen_position(color_index: int) -> Vector2:
	var clamped_color_index := clampi(color_index, 0, DAMAGE_COLORS.size() - 1)
	var target_cell := _color_target_cells.get(clamped_color_index) as Control
	if is_instance_valid(target_cell):
		return target_cell.get_global_rect().get_center()
	var header := _grid.get_child(0) as Control if _grid and _grid.get_child_count() > 0 else null
	if header:
		var header_rect := header.get_global_rect()
		return Vector2(header_rect.get_center().x, header_rect.end.y + 15.5 + clamped_color_index * 28.0)
	return get_global_rect().position + Vector2(22.0, 49.5 + clamped_color_index * 28.0)


func _refresh() -> void:
	if _player == null:
		return
	if _grid:
		remove_child(_grid)
		_grid.queue_free()
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 3)
	add_child(_grid)
	_color_target_cells.clear()

	var weapon_count: int = _player.damage_by_color[0].size() if not _player.damage_by_color.is_empty() else 0
	var damage_values: Array = []
	for color_index in range(DAMAGE_COLORS.size()):
		var values_for_color: Array[int] = []
		for weapon_index in range(weapon_count):
			values_for_color.append(_player.get_damage_for_weapon_color(color_index, weapon_index))
		damage_values.append(values_for_color)

	var shown_weapon_indices: Array[int] = []
	for weapon_index in range(weapon_count):
		for color_index in range(DAMAGE_COLORS.size()):
			if int(damage_values[color_index][weapon_index]) > 1:
				shown_weapon_indices.append(weapon_index)
				break

	var shown_color_indices: Array[int] = []
	for color_index in range(DAMAGE_COLORS.size()):
		for weapon_index in range(weapon_count):
			if int(damage_values[color_index][weapon_index]) > 1:
				shown_color_indices.append(color_index)
				break

	visible = not shown_weapon_indices.is_empty() and not shown_color_indices.is_empty()
	if not visible:
		call_deferred("_fit_to_top_left")
		return

	_grid.columns = shown_weapon_indices.size() + 1
	_add_blank_header()
	for weapon_index in shown_weapon_indices:
		_add_weapon_header(weapon_index)
	for color_index in shown_color_indices:
		var color_cell := _add_color_header(color_index)
		_color_target_cells[color_index] = color_cell
		for weapon_index in shown_weapon_indices:
			var damage := int(damage_values[color_index][weapon_index])
			if damage > 1:
				_add_number_cell(damage)
			else:
				_add_hidden_damage_cell()
	call_deferred("_fit_to_top_left")


func _fit_to_top_left() -> void:
	var minimum_size := get_combined_minimum_size()
	size = minimum_size
	set_offset(SIDE_LEFT, 12.0)
	set_offset(SIDE_TOP, 12.0)
	set_offset(SIDE_RIGHT, 12.0 + minimum_size.x)
	set_offset(SIDE_BOTTOM, 12.0 + minimum_size.y)


func _add_blank_header() -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(32, 25)
	cell.add_theme_stylebox_override("panel", _make_cell_style())
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	_grid.add_child(cell)


func _add_color_header(color_index: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(32, 25)
	cell.add_theme_stylebox_override("panel", _make_cell_style())
	var dot := Polygon2D.new()
	dot.polygon = PackedVector2Array([-6, 0, -4, -4, 0, -6, 4, -4, 6, 0, 4, 4, 0, 6, -4, 4])
	dot.color = DAMAGE_COLORS[color_index]
	dot.position = cell.custom_minimum_size * 0.5
	cell.add_child(dot)
	_grid.add_child(cell)
	return cell


func _add_number_cell(value: int) -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(34, 25)
	cell.add_theme_stylebox_override("panel", _make_cell_style())
	var label := Label.new()
	label.text = str(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	cell.add_child(label)
	_grid.add_child(cell)


func _add_hidden_damage_cell() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(34, 25)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(spacer)


func _add_weapon_header(weapon_index: int) -> void:
	var damage_type_cell := PanelContainer.new()
	damage_type_cell.custom_minimum_size = Vector2(34, 25)
	damage_type_cell.add_theme_stylebox_override("panel", _make_cell_style())
	var content := CenterContainer.new()
	damage_type_cell.add_child(content)
	var icon := TextureRect.new()
	var weapon := _player.get_slot_item("weapon", weapon_index)
	icon.texture = ItemPickup.ITEM_TEXTURES.get(str(weapon.get("item_id", "")), DAMAGE_ICON)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	_grid.add_child(damage_type_cell)


func _make_cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.15, 0.95)
	style.border_color = Color(0.28, 0.33, 0.42, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _set_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.9)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
