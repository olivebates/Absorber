class_name ArmorGrid
extends PanelContainer

const DEFENSE_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const DEFENSE_NAMES := ["Red Defense", "Yellow Defense", "Blue Defense"]
const SHIELD_ICON := preload("res://Sprites/ShieldIcon.webp")

var _player: FoxPlayer
var _damage_grid: DamageGrid
var _grid: GridContainer
var _dungeon_visibility_reference: Array = []
var _dungeon_force_visible := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	_set_panel_style()
	call_deferred("_connect_player")


func _process(_delta: float) -> void:
	_fit_beside_damage_grid()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_damage_grid = get_parent().get_node_or_null("DamageGrid") as DamageGrid
	if _player:
		_player.damage_matrix_changed.connect(_refresh)
		_player.equipment_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _player == null:
		return
	if _grid:
		remove_child(_grid)
		_grid.queue_free()
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 3)
	add_child(_grid)
	visible = _dungeon_force_visible or _player.armor_ever_equipped or _player.has_equipped_armor() or _has_color_defense()
	if not visible:
		return
	_add_blank_header()
	_add_shield_header()
	for color_index in range(3):
		var reference_defense := int(_dungeon_visibility_reference[color_index]) if color_index < _dungeon_visibility_reference.size() else 0
		if color_index != FoxPlayer.COLOR_RED and _player.get_base_defense_for_color(color_index) < 1 and reference_defense < 1:
			continue
		_add_color_header(color_index)
		_add_number_cell(_player.get_defense_for_color(color_index), color_index)
	call_deferred("_fit_beside_damage_grid")


func set_dungeon_visibility_reference(defense_values: Array, was_visible: bool) -> void:
	_dungeon_visibility_reference = defense_values.duplicate()
	_dungeon_force_visible = was_visible
	_refresh()


func clear_dungeon_visibility_reference() -> void:
	_dungeon_visibility_reference.clear()
	_dungeon_force_visible = false
	_refresh()


func _has_color_defense() -> bool:
	for color_index in range(3):
		if _player.get_base_defense_for_color(color_index) > 0:
			return true
	return false


func get_color_target_screen_position(color_index: int) -> Vector2:
	if is_instance_valid(_grid):
		var visible_row := 0
		for candidate in range(3):
			var reference_defense := int(_dungeon_visibility_reference[candidate]) if candidate < _dungeon_visibility_reference.size() else 0
			if candidate != FoxPlayer.COLOR_RED and _player.get_base_defense_for_color(candidate) < 1 and reference_defense < 1:
				continue
			if candidate == color_index:
				var cell_index := 2 + visible_row * 2
				if cell_index < _grid.get_child_count():
					return (_grid.get_child(cell_index) as Control).get_global_rect().get_center()
			visible_row += 1
	return get_global_rect().get_center()


func _fit_beside_damage_grid() -> void:
	if not visible:
		return
	var minimum_size := get_combined_minimum_size()
	size = minimum_size
	var left := 12.0
	if is_instance_valid(_damage_grid) and _damage_grid.visible:
		left = _damage_grid.position.x + _damage_grid.size.x + 6.0
	set_offset(SIDE_LEFT, left)
	set_offset(SIDE_TOP, 12.0)
	set_offset(SIDE_RIGHT, left + minimum_size.x)
	set_offset(SIDE_BOTTOM, 12.0 + minimum_size.y)


func _add_blank_header() -> void:
	_add_cell(Control.new(), Vector2(32, 25))


func _add_shield_header() -> void:
	var center := CenterContainer.new()
	var icon := TextureRect.new()
	icon.name = "ShieldIcon"
	icon.texture = SHIELD_ICON
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(icon)
	var cell := _add_cell(center, Vector2(34, 25))
	_connect_stat_tooltip(cell, "Defense")


func _add_color_header(color_index: int) -> void:
	var center := CenterContainer.new()
	var dot := Panel.new()
	dot.name = "DefenseColor%d" % color_index
	dot.custom_minimum_size = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = DEFENSE_COLORS[color_index]
	style.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", style)
	center.add_child(dot)
	var cell := _add_cell(center, Vector2(32, 25))
	_connect_stat_tooltip(cell, DEFENSE_NAMES[color_index])


func _add_number_cell(value: int, color_index: int) -> void:
	var label := Label.new()
	label.name = "DefenseValue"
	label.text = str(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	var cell := _add_cell(label, Vector2(34, 25))
	_connect_stat_tooltip(cell, DEFENSE_NAMES[color_index])


func _add_cell(content: Control, minimum_size: Vector2) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = minimum_size
	cell.add_theme_stylebox_override("panel", _make_cell_style())
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(content)
	_grid.add_child(cell)
	return cell


func _connect_stat_tooltip(control: Control, title: String) -> void:
	control.mouse_entered.connect(func() -> void:
		var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
		if tooltip:
			tooltip.show_description(null, title, "")
	)
	control.mouse_exited.connect(func() -> void:
		var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
		if tooltip:
			tooltip.hide_item()
	)


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
