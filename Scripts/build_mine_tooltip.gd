class_name BuildMineTooltip
extends PanelContainer

const MINE_ICON := preload("res://Sprites/MinerStructure.webp")

var _content: VBoxContainer


func _ready() -> void:
	_set_style()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 3)
	add_child(_content)
	visible = false


func show_cost(cost: Dictionary, resource_manager: ResourceManager) -> void:
	for child in _content.get_children():
		child.queue_free()
	var mine_icon := TextureRect.new()
	mine_icon.texture = MINE_ICON
	mine_icon.custom_minimum_size = Vector2(28, 28)
	mine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mine_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(mine_icon)
	for raw_resource_id in cost:
		var resource_id := StringName(raw_resource_id)
		var definition := resource_manager.get_definition(resource_id) if resource_manager else null
		if definition == null:
			continue
		_content.add_child(_make_cost_row(definition.icon, int(cost[raw_resource_id])))
	visible = true
	call_deferred("_place_inside_camera")


func hide_tooltip() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_place_inside_camera()


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


func _place_inside_camera() -> void:
	if not visible:
		return
	var viewport_size := get_viewport_rect().size
	var desired := get_viewport().get_mouse_position() + Vector2(18, 18)
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
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)
