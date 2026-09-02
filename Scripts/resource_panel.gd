class_name ResourcePanel
extends PanelContainer

const SIDEBAR_MARGIN := 12.0
const SIDEBAR_CONTENT_WIDTH := 296.0
const ICON_SIZE := 32.0
const VALUE_FONT_SIZE := 24
const VALUE_GAP := 32

var _resource_manager: ResourceManager
var _rows: VBoxContainer
var _resource_rows: Dictionary = {}


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_style()
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)
	call_deferred("_connect_resource_manager")


func _connect_resource_manager() -> void:
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if _resource_manager:
		_resource_manager.resource_changed.connect(_on_resource_changed)
		_resource_manager.resource_discovered.connect(_on_resource_discovered)
		_resource_manager.production_changed.connect(_on_production_changed)
		_refresh()


func _on_resource_changed(_resource_id: StringName, _amount: int, _maximum_amount: int) -> void:
	_refresh()


func _on_resource_discovered(_resource_id: StringName) -> void:
	_refresh()


func _on_production_changed(_resource_id: StringName, _production_speed: float) -> void:
	_refresh()


func _refresh() -> void:
	if _resource_manager == null or _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_resource_rows.clear()
	var has_visible_resource := false
	for definition in _resource_manager.get_definitions():
		if not _resource_manager.has_ever_owned(definition.resource_id):
			continue
		has_visible_resource = true
		var row := _make_resource_row(definition)
		_resource_rows[definition.resource_id] = row
		_rows.add_child(row)
	if has_visible_resource:
		show()
		call_deferred("_fit_to_content")
	else:
		hide()


func get_resource_target_screen_position(resource_id: StringName) -> Vector2:
	var row := _resource_rows.get(resource_id) as Control
	if row and is_instance_valid(row):
		return row.get_global_rect().get_center()
	return Vector2(58.0, get_viewport_rect().size.y - 42.0)


func _fit_to_content() -> void:
	if not visible:
		return
	var content_size := _rows.get_combined_minimum_size()
	var panel_style := get_theme_stylebox("panel")
	var fitted_size := Vector2(SIDEBAR_CONTENT_WIDTH, content_size.y + panel_style.get_minimum_size().y)
	size = fitted_size
	set_offset(SIDE_LEFT, SIDEBAR_MARGIN)
	set_offset(SIDE_TOP, -SIDEBAR_MARGIN - fitted_size.y)
	set_offset(SIDE_RIGHT, SIDEBAR_MARGIN + fitted_size.x)
	set_offset(SIDE_BOTTOM, -SIDEBAR_MARGIN)


func _make_resource_row(definition: GameResourceDefinition) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	var icon := TextureRect.new()
	icon.texture = definition.icon
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var values := HBoxContainer.new()
	values.name = "Values"
	values.add_theme_constant_override("separation", VALUE_GAP)
	row.add_child(values)
	var amount := Label.new()
	amount.name = "ResourceAmount"
	amount.text = "%d/%d" % [
		_resource_manager.get_amount(definition.resource_id),
		_resource_manager.get_maximum_amount(definition.resource_id),
	]
	amount.add_theme_color_override("font_color", Color.WHITE)
	amount.add_theme_color_override("font_outline_color", Color.BLACK)
	amount.add_theme_constant_override("outline_size", 2)
	amount.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	values.add_child(amount)
	var production_speed := _resource_manager.get_production_speed(definition.resource_id)
	if production_speed > 0.0 and _resource_manager.get_amount(definition.resource_id) < _resource_manager.get_maximum_amount(definition.resource_id):
		var production := Label.new()
		production.name = "ResourceProduction"
		production.text = "+%s/m" % _format_speed(production_speed * 60.0)
		production.add_theme_color_override("font_color", Color("65d76e"))
		production.add_theme_color_override("font_outline_color", Color.BLACK)
		production.add_theme_constant_override("outline_size", 2)
		production.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
		production.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		values.add_child(production)
	return row


func _format_speed(speed: float) -> String:
	if is_zero_approx(speed):
		return "0"
	var formatted := "%.3f" % speed if speed < 0.01 else "%.2f" % speed
	while formatted.contains(".") and formatted.ends_with("0"):
		formatted = formatted.trim_suffix("0")
	return formatted.trim_suffix(".")


func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.83)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
