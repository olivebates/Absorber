class_name EnemyDropTooltip
extends PanelContainer

var _content: VBoxContainer
var _shown_enemy: ChickenEnemy
var _last_mouse_position := Vector2.ZERO


func _ready() -> void:
	_set_style()
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	add_child(_content)
	visible = false


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	_last_mouse_position = mouse
	var hovered: ChickenEnemy
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy) and enemy.get_global_transform_with_canvas().origin.distance_to(mouse) <= 30.0:
			hovered = enemy
			break
	var visible_drops: Array[Dictionary] = []
	if hovered:
		visible_drops = _get_visible_drops(hovered.drop_table)
	if hovered and not visible_drops.is_empty():
		if hovered != _shown_enemy:
			_shown_enemy = hovered
			_refresh(visible_drops)
		visible = true
		_place_inside_camera(mouse)
	else:
		_shown_enemy = null
		visible = false


func _place_inside_camera(mouse_position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var desired := mouse_position + Vector2(18, 18)
	if desired.x + size.x > viewport_size.x:
		desired.x = mouse_position.x - size.x - 18.0
	if desired.y + size.y > viewport_size.y:
		desired.y = mouse_position.y - size.y - 18.0
	position = Vector2(
		clampf(desired.x, 0.0, maxf(0.0, viewport_size.x - size.x)),
		clampf(desired.y, 0.0, maxf(0.0, viewport_size.y - size.y))
	)


func _get_visible_drops(drop_table: Array[Dictionary]) -> Array[Dictionary]:
	var visible_drops: Array[Dictionary] = []
	for entry in drop_table:
		var item_id := str(entry.get("item_id", ""))
		if ItemPickup.ITEM_DATA.has(item_id) and float(entry.get("chance", 0.0)) > 0.0:
			visible_drops.append(entry)
	return visible_drops


func _refresh(drop_table: Array[Dictionary]) -> void:
	for child in _content.get_children():
		child.free()
	var title := Label.new()
	title.text = "Possible drops"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	_content.add_child(title)
	for entry in drop_table:
		var item_id := str(entry.get("item_id", ""))
		if not ItemPickup.ITEM_DATA.has(item_id):
			continue
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		var item := ItemPickup.make_item(item_id, int(entry.get("grade", 0)))
		card_style.bg_color = ItemPickup.get_grade_color(ItemPickup.get_item_grade(item))
		card_style.border_color = Color.BLACK
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(3)
		card_style.content_margin_left = 3
		card_style.content_margin_right = 3
		card_style.content_margin_top = 2
		card_style.content_margin_bottom = 2
		card.add_theme_stylebox_override("panel", card_style)
		var row := HBoxContainer.new()
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = ItemPickup.ITEM_TEXTURES[item_id]
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var chance := Label.new()
		chance.text = "%d%%" % roundi(float(entry.get("chance", 0.0)) * 100.0)
		chance.add_theme_color_override("font_color", Color.WHITE)
		chance.add_theme_color_override("font_outline_color", Color.BLACK)
		chance.add_theme_constant_override("outline_size", 2)
		row.add_child(chance)
		_content.add_child(card)
	call_deferred("_fit_to_content")


func _fit_to_content() -> void:
	size = get_combined_minimum_size()
	_place_inside_camera(_last_mouse_position)


func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.96)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)
