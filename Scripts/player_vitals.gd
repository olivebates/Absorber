class_name PlayerVitals
extends VBoxContainer

const HEART_ICON := preload("res://Sprites/Heart.webp")
const REGEN_ICON := preload("res://Sprites/RecoveryHeart.webp")
const MANA_ICON := preload("res://Sprites/IconMana.webp")
const MANA_REGEN_ICON := preload("res://Sprites/iconManaRegen.webp")
const THORN_ICON := preload("res://Sprites/iconThorn.webp")
const SIDEBAR_MARGIN := 12.0
const STAT_MARGIN := 8.0
const CELL_HEIGHT := 48.0
const ICON_SIZE := 32.0
const VALUE_FONT_SIZE := 22

var _player: FoxPlayer
var _damage_grid: DamageGrid
var _armor_grid: Control
var _health_label: Label
var _regen_label: Label
var _thorn_label: Label
var _regen_cell: PanelContainer
var _regen_icon: TextureRect
var _regen_block_line: Line2D
var _mana_label: Label
var _mana_regen_label: Label
var _mana_row: HBoxContainer
var _mana_regen_cell: PanelContainer
var _mana_regen_icon: TextureRect
var _mana_regen_block_line: Line2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_theme_constant_override("separation", int(STAT_MARGIN))
	var health_row := HBoxContainer.new()
	health_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_theme_constant_override("separation", int(STAT_MARGIN))
	add_child(health_row)
	_health_label = _add_stat_cell(health_row, "Health", HEART_ICON)
	_regen_label = _add_stat_cell(health_row, "Regeneration", REGEN_ICON)
	_thorn_label = _add_stat_cell(health_row, "Thorn", THORN_ICON)
	_mana_row = HBoxContainer.new()
	_mana_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mana_row.add_theme_constant_override("separation", int(STAT_MARGIN))
	add_child(_mana_row)
	_mana_label = _add_stat_cell(_mana_row, "Mana", MANA_ICON)
	_mana_regen_label = _add_stat_cell(_mana_row, "ManaRegeneration", MANA_REGEN_ICON)
	_mana_label.add_theme_color_override("font_color", Color("67e8f9"))
	_mana_regen_label.add_theme_color_override("font_color", Color("67e8f9"))
	_regen_cell = find_child("RegenerationCell", true, false) as PanelContainer
	_regen_icon = find_child("RegenerationIcon", true, false) as TextureRect
	_mana_regen_cell = find_child("ManaRegenerationCell", true, false) as PanelContainer
	_mana_regen_icon = find_child("ManaRegenerationIcon", true, false) as TextureRect
	_regen_block_line = _build_block_line(_regen_cell, "DungeonRegenerationBlocked")
	_mana_regen_block_line = _build_block_line(_mana_regen_cell, "DungeonManaRegenerationBlocked")
	call_deferred("_connect_player")


func _process(_delta: float) -> void:
	_refresh_regeneration()
	_refresh_mana()
	_fit_below_grids()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_damage_grid = get_parent().get_node_or_null("DamageGrid") as DamageGrid
	_armor_grid = get_parent().get_node_or_null("ArmorGrid") as Control
	if _player:
		_player.vitals_changed.connect(_refresh)
		_player.equipment_changed.connect(_refresh)
		_player.skills_changed.connect(_refresh)
		_player.mana_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _player == null:
		return
	_health_label.text = "%s/%s" % [FoxPlayer.format_large_number(_player.health), FoxPlayer.format_large_number(_player.max_health)]
	_thorn_label.text = str(_player.get_thorn())
	_refresh_regeneration()
	_refresh_mana()
	call_deferred("_fit_below_grids")


func _refresh_regeneration() -> void:
	if is_instance_valid(_player) and is_instance_valid(_regen_label):
		_regen_label.text = FoxPlayer.format_health_per_second(_player.get_effective_passive_healing_per_second())
		var blocked := false
		var manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
		if manager and manager.is_dungeon_active():
			var level := manager.get_active_level()
			blocked = level != null and level.has_current_room_enemies()
		_regen_label.add_theme_color_override("font_color", Color("777982") if blocked else Color("65d76e") if _player.is_near_campfire() else Color.WHITE)
		if is_instance_valid(_regen_icon):
			_regen_icon.modulate = Color("777982") if blocked else Color.WHITE
		if is_instance_valid(_regen_block_line):
			_regen_block_line.visible = blocked


func _refresh_mana() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_mana_row):
		return
	_mana_row.visible = _player.has_unlocked_player_skill()
	if not _mana_row.visible:
		return
	_mana_label.text = "%d/%d" % [_player.mana, _player.max_mana]
	_mana_regen_label.text = FoxPlayer.format_health_per_second(_player.get_effective_passive_mana_regeneration_per_second())
	var blocked := false
	var manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
	if manager and manager.is_dungeon_active():
		var level := manager.get_active_level()
		blocked = level != null and level.has_current_room_enemies()
	_mana_regen_label.add_theme_color_override("font_color", Color("777982") if blocked else Color("67e8f9"))
	if is_instance_valid(_mana_regen_icon):
		_mana_regen_icon.modulate = Color("777982") if blocked else Color.WHITE
	if is_instance_valid(_mana_regen_block_line):
		_mana_regen_block_line.visible = blocked


func get_stat_target_screen_position(stat: StringName) -> Vector2:
	var cell_name := "ManaRegenerationCell" if stat == &"mana_regeneration" else "ManaCell" if stat == &"mana" else "ThornCell" if stat == &"thorn" else "RegenerationCell" if stat == &"regeneration" else "HealthCell"
	var cell := find_child(cell_name, true, false) as Control
	return cell.get_global_rect().get_center() if cell else get_global_rect().get_center()


func _fit_below_grids() -> void:
	var top := 12.0
	if is_instance_valid(_damage_grid) and _damage_grid.visible:
		top = maxf(top, _damage_grid.position.y + _damage_grid.size.y + STAT_MARGIN)
	if is_instance_valid(_armor_grid) and _armor_grid.visible:
		top = maxf(top, _armor_grid.position.y + _armor_grid.size.y + STAT_MARGIN)
	var minimum_size := get_combined_minimum_size()
	size = minimum_size
	set_offset(SIDE_LEFT, SIDEBAR_MARGIN)
	set_offset(SIDE_TOP, top)
	set_offset(SIDE_RIGHT, SIDEBAR_MARGIN + minimum_size.x)
	set_offset(SIDE_BOTTOM, top + minimum_size.y)
	_update_block_line(_regen_block_line, _regen_cell)
	_update_block_line(_mana_regen_block_line, _mana_regen_cell)


func _add_stat_cell(parent_row: HBoxContainer, cell_name: String, texture: Texture2D) -> Label:
	var cell := PanelContainer.new()
	cell.name = "%sCell" % cell_name
	cell.custom_minimum_size = Vector2(74, CELL_HEIGHT)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_stylebox_override("panel", _make_cell_style(cell_name == "Health" or cell_name == "Mana"))
	var tooltip_titles := {
		"Health": "Health",
		"Regeneration": "Health Regeneration",
		"Mana": "Mana",
		"ManaRegeneration": "Mana Regeneration",
		"Thorn": "Thorn",
	}
	_connect_stat_tooltip(cell, str(tooltip_titles.get(cell_name, cell_name)))
	parent_row.add_child(cell)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	var icon := TextureRect.new()
	icon.name = "%sIcon" % cell_name
	icon.texture = texture
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "%sValue" % cell_name
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


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


func _make_cell_style(primary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.135, 0.19, 0.98) if primary else Color(0.065, 0.075, 0.095, 0.94)
	style.border_color = Color(0.34, 0.41, 0.54, 1.0) if primary else Color(0.22, 0.25, 0.31, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = STAT_MARGIN
	style.content_margin_right = STAT_MARGIN
	style.content_margin_top = STAT_MARGIN
	style.content_margin_bottom = STAT_MARGIN
	return style


func _build_block_line(cell: PanelContainer, line_name: String) -> Line2D:
	if not is_instance_valid(cell):
		return null
	var line := Line2D.new()
	line.name = line_name
	line.points = PackedVector2Array([Vector2(0, CELL_HEIGHT), Vector2(74, 0)])
	line.width = 3.0
	line.default_color = Color("dc2626")
	line.antialiased = true
	line.z_index = 5
	line.hide()
	cell.add_child(line)
	return line


func _update_block_line(line: Line2D, cell: Control) -> void:
	if is_instance_valid(line) and is_instance_valid(cell):
		line.points = PackedVector2Array([Vector2(0, cell.size.y), Vector2(cell.size.x, 0)])
