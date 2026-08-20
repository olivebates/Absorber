class_name BuildMineTooltip
extends PanelContainer

const MINE_ICON := preload("res://Sprites/MinerStructure.webp")

var _content: HBoxContainer
var _anchor: Control
var _world_anchor: Node2D


func _ready() -> void:
	_set_style()
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content = HBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	visible = false


func show_cost(cost: Dictionary, resource_manager: ResourceManager, anchor: Control, building_icon: Texture2D = MINE_ICON) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_anchor = anchor
	_world_anchor = null
	var cost_column := VBoxContainer.new()
	cost_column.add_theme_constant_override("separation", 3)
	var title := Label.new()
	title.text = "Costs:"
	title.add_theme_color_override("font_color", Color("fff2bd"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	cost_column.add_child(title)
	for raw_resource_id in cost:
		var resource_id := StringName(raw_resource_id)
		var definition := resource_manager.get_definition(resource_id) if resource_manager else null
		if definition:
			cost_column.add_child(_make_cost_row(definition.icon, int(cost[raw_resource_id])))
	_content.add_child(cost_column)
	var mine_icon := TextureRect.new()
	mine_icon.texture = building_icon
	mine_icon.custom_minimum_size = building_icon.get_size() if building_icon else Vector2(64, 64)
	mine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mine_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(mine_icon)
	visible = true
	call_deferred("_fit_and_place")


func hide_tooltip(requester: Variant = null) -> void:
	if requester != null and requester != _anchor and requester != _world_anchor:
		return
	visible = false
	_anchor = null
	_world_anchor = null


func show_stat(icon_texture: Texture2D, stat_name: String, stat_value: String, world_anchor: Node2D) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_anchor = null
	_world_anchor = world_anchor
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(icon)
	var text := Label.new()
	text.text = "%s: %s" % [stat_name, stat_value]
	text.add_theme_color_override("font_color", Color.WHITE)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 2)
	_content.add_child(text)
	visible = true
	call_deferred("_fit_and_place")


func _process(_delta: float) -> void:
	if visible:
		_fit_and_place()


func _make_cost_row(icon_texture: Texture2D, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var value := Label.new()
	value.text = str(amount)
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_color_override("font_outline_color", Color.BLACK)
	value.add_theme_constant_override("outline_size", 2)
	row.add_child(value)
	return row


func _fit_and_place() -> void:
	if not visible or (not is_instance_valid(_anchor) and not is_instance_valid(_world_anchor)):
		return
	size = get_combined_minimum_size()
	var viewport_size := get_viewport_rect().size
	var anchor_rect: Rect2
	if is_instance_valid(_anchor):
		anchor_rect = _anchor.get_global_rect()
	else:
		var screen_position := _world_anchor.get_global_transform_with_canvas().origin
		anchor_rect = Rect2(screen_position - Vector2(32, 32), Vector2(64, 64))
	var desired := Vector2(anchor_rect.get_center().x - size.x * 0.5, anchor_rect.position.y - size.y - 8.0)
	position = Vector2(
		clampf(desired.x, 0.0, maxf(0.0, viewport_size.x - size.x)),
		clampf(desired.y, 0.0, maxf(0.0, viewport_size.y - size.y))
	)


func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4d3d12")
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
