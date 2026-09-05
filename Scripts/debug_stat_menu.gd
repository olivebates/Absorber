class_name DebugStatMenu
extends PanelContainer

const COLOR_NAMES := ["Red Damage", "Yellow Damage", "Blue Damage"]
const DEFENSE_NAMES := ["Red Defense", "Yellow Defense", "Blue Defense"]
const SIDEBAR_MARGIN := 12.0

var _player: FoxPlayer
var _damage_grid: DamageGrid
var _vitals: Control
var _values: Array[Label] = []


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	_set_panel_style()
	_build_menu()
	call_deferred("_connect_player")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_O and key_event.shift_pressed and not key_event.ctrl_pressed and not key_event.alt_pressed and not key_event.meta_pressed:
		visible = not visible
		if visible:
			_refresh_values()
			_fit_below_damage_grid()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_fit_below_damage_grid()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_damage_grid = get_parent().get_node_or_null("DamageGrid") as DamageGrid
	_vitals = get_parent().get_node_or_null("PlayerVitals") as Control
	if _player:
		_player.damage_matrix_changed.connect(_refresh_values)
	_refresh_values()


func _build_menu() -> void:
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	add_child(rows)
	var title := Label.new()
	title.text = "Debug Stats"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffe082"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	rows.add_child(title)
	_add_stat_row(rows, "Max Health", 0)
	_add_stat_row(rows, "Regeneration", 1)
	for color_index in range(COLOR_NAMES.size()):
		_add_stat_row(rows, COLOR_NAMES[color_index], color_index + 2)
	for color_index in range(DEFENSE_NAMES.size()):
		_add_stat_row(rows, DEFENSE_NAMES[color_index], color_index + 5)
	_add_stat_row(rows, "Thorn", 8)


func _add_stat_row(parent: VBoxContainer, label_text: String, stat_index: int) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(94, 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(26, 24)
	minus_button.pressed.connect(_adjust_stat.bind(stat_index, -1))
	row.add_child(minus_button)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(30, 24)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	_values.append(value_label)
	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(26, 24)
	plus_button.pressed.connect(_adjust_stat.bind(stat_index, 1))
	row.add_child(plus_button)


func _adjust_stat(stat_index: int, amount: int) -> void:
	if _player == null:
		return
	match stat_index:
		0:
			_player.add_max_health(amount)
		1:
			_player.add_passive_healing(amount)
		2, 3, 4:
			_player.add_color_damage(stat_index - 2, amount)
		5, 6, 7:
			_player.add_color_defense(stat_index - 5, amount)
		8:
			_player.add_thorn(amount)
	_refresh_values()


func _refresh_values() -> void:
	if _player == null or _values.size() < 9:
		return
	_values[0].text = str(_player.max_health)
	_values[1].text = str(_player.passive_healing_amount)
	for color_index in range(3):
		_values[color_index + 2].text = str(_player.get_base_damage_for_color(color_index))
		_values[color_index + 5].text = str(_player.get_base_defense_for_color(color_index))
	_values[8].text = str(_player.thorn)


func _fit_below_damage_grid() -> void:
	var minimum_size := get_combined_minimum_size()
	size = minimum_size
	var top := 12.0
	if is_instance_valid(_damage_grid) and _damage_grid.visible:
		top = _damage_grid.position.y + _damage_grid.size.y + 8.0
	if is_instance_valid(_vitals):
		top = maxf(top, _vitals.position.y + _vitals.size.y + 8.0)
	set_offset(SIDE_LEFT, SIDEBAR_MARGIN)
	set_offset(SIDE_TOP, top)
	set_offset(SIDE_RIGHT, SIDEBAR_MARGIN + minimum_size.x)
	set_offset(SIDE_BOTTOM, top + minimum_size.y)


func _set_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.94)
	style.border_color = Color("e9c64d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", style)
