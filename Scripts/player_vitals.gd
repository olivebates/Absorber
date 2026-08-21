class_name PlayerVitals
extends HBoxContainer

const HEART_ICON := preload("res://Sprites/Heart.webp")
const REGEN_ICON := preload("res://Sprites/RecoveryHeart.webp")

var _player: FoxPlayer
var _damage_grid: DamageGrid
var _armor_grid: Control
var _health_label: Label
var _regen_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_theme_constant_override("separation", 4)
	_health_label = _add_stat_cell("Health", HEART_ICON)
	_regen_label = _add_stat_cell("Regeneration", REGEN_ICON)
	call_deferred("_connect_player")


func _process(_delta: float) -> void:
	_fit_below_grids()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_damage_grid = get_parent().get_node_or_null("DamageGrid") as DamageGrid
	_armor_grid = get_parent().get_node_or_null("ArmorGrid") as Control
	if _player:
		_player.vitals_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _player == null:
		return
	_health_label.text = "%d/%d" % [_player.health, _player.max_health]
	_regen_label.text = str(_player.passive_healing_amount)
	call_deferred("_fit_below_grids")


func get_stat_target_screen_position(stat: StringName) -> Vector2:
	var cell_name := "RegenerationCell" if stat == &"regeneration" else "HealthCell"
	var cell := find_child(cell_name, true, false) as Control
	return cell.get_global_rect().get_center() if cell else get_global_rect().get_center()


func _fit_below_grids() -> void:
	var top := 12.0
	if is_instance_valid(_damage_grid) and _damage_grid.visible:
		top = maxf(top, _damage_grid.position.y + _damage_grid.size.y + 4.0)
	if is_instance_valid(_armor_grid) and _armor_grid.visible:
		top = maxf(top, _armor_grid.position.y + _armor_grid.size.y + 4.0)
	var minimum_size := get_combined_minimum_size()
	size = minimum_size
	set_offset(SIDE_LEFT, 12.0)
	set_offset(SIDE_TOP, top)
	set_offset(SIDE_RIGHT, 12.0 + minimum_size.x)
	set_offset(SIDE_BOTTOM, top + minimum_size.y)


func _add_stat_cell(cell_name: String, texture: Texture2D) -> Label:
	var cell := PanelContainer.new()
	cell.name = "%sCell" % cell_name
	cell.custom_minimum_size = Vector2(74, 29)
	cell.add_theme_stylebox_override("panel", _make_cell_style())
	add_child(cell)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	var icon := TextureRect.new()
	icon.name = "%sIcon" % cell_name
	icon.texture = texture
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "%sValue" % cell_name
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


func _make_cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.15, 0.95)
	style.border_color = Color(0.28, 0.33, 0.42, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style
