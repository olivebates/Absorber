class_name GoldOre
extends Node2D

const MINER_STRUCTURE_SCENE := preload("res://Scenes/miner_structure.tscn")
const GOLD_SHACK_SCENE := preload("res://Scenes/gold_shack.tscn")
const GOLD_SHACK_ICON := preload("res://Sprites/GoldShack.webp")
const MINER_STRUCTURE_ICON := preload("res://Sprites/MinerStructure.webp")
const SHACK_COST := {"gold_ore": 10}
const ADJACENT_OFFSETS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@export var build_cost: Dictionary = {"gold_ore": 5, "jewels": 2}
@export var mined_resource_id: StringName = &"gold_ore"
@export var mine_production_speed := 1.0 / 300.0
@export var shack_build_cost: Dictionary = SHACK_COST
@export var shack_scene: PackedScene = GOLD_SHACK_SCENE
@export var shack_icon: Texture2D = GOLD_SHACK_ICON
@export var mine_icon: Texture2D = MINER_STRUCTURE_ICON
@export var mine_build_label := "Build Mine"
@export var capacity_build_label := "Build Shack"

var _mine: MinerStructure
var _resource_manager: ResourceManager
var _button_is_in_hud := false
var _build_tooltip: BuildMineTooltip
var _shack_buttons: Array[Button] = []
var _tile_highlight: Line2D
var _build_hover_label: Label
var _mine_selected := false

@onready var build_button: Button = $BuildMineButton


func _ready() -> void:
	add_to_group("gold_ores")
	_register_with_navigation()
	_tile_highlight = _create_tile_highlight()
	add_child(_tile_highlight)
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	build_button.pressed.connect(_on_build_button_pressed)
	build_button.mouse_entered.connect(_show_build_tooltip)
	build_button.mouse_exited.connect(_hide_build_tooltip.bind(build_button))
	build_button.visible = false
	build_button.tooltip_text = ""
	_set_button_style()
	if _resource_manager:
		_resource_manager.resource_changed.connect(_on_resource_changed)
	call_deferred("_move_build_button_to_hud")


func _register_with_navigation() -> void:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			(cursor as WorldNavigation).register_navigation_actor(self)
			return
		cursor = cursor.get_parent()


func show_build_button() -> void:
	if is_instance_valid(_mine):
		_mine_selected = true
		if _build_hover_label:
			_build_hover_label.hide()
		_show_shack_buttons()
	else:
		_clear_shack_buttons()
		build_button.text = mine_build_label
		_update_build_availability()
		build_button.visible = true
		_update_build_button_position()


func hide_build_button() -> void:
	build_button.visible = false
	_mine_selected = false
	if _build_hover_label:
		_build_hover_label.hide()
	_clear_shack_buttons()
	_hide_build_tooltip()


func _try_build_mine() -> void:
	if _mine != null or _resource_manager == null:
		return
	if not _resource_manager.spend_resources(get_current_build_cost()):
		_update_build_availability()
		return
	_create_mine()
	_play_building_sfx()
	build_button.visible = false
	_clear_shack_buttons()
	_hide_build_tooltip()
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.on_structure_built(mined_resource_id, self)


func _on_build_button_pressed() -> void:
	if is_instance_valid(_mine):
		_show_shack_buttons()
	else:
		_try_build_mine()


func get_save_data() -> Array:
	return [0] if _mine == null else [1, _mine.get_save_data()]


func load_save_data(data: Array, offline_seconds: int) -> bool:
	if data.is_empty():
		return false
	var should_have_mine := int(data[0]) != 0
	if not should_have_mine:
		if is_instance_valid(_mine):
			_mine.free()
		_mine = null
		return true
	if not is_instance_valid(_mine):
		_create_mine()
	_mine.load_save_data(data[1] if data.size() > 1 else 0, offline_seconds)
	build_button.visible = false
	_hide_build_tooltip()
	return true


func _cost_text() -> String:
	var entries: Array[String] = []
	var current_cost := get_current_build_cost()
	for resource_id in current_cost:
		var definition := _resource_manager.get_definition(StringName(resource_id)) if _resource_manager else null
		entries.append("%d %s" % [int(current_cost[resource_id]), definition.display_name if definition else str(resource_id)])
	return ", ".join(entries)


func get_current_build_cost() -> Dictionary:
	var built_count := 0
	for node in get_tree().get_nodes_in_group("gold_ores"):
		if node is GoldOre and node.mined_resource_id == mined_resource_id and is_instance_valid(node._mine):
			built_count += 1
	return _scale_cost(build_cost, built_count)


func get_current_shack_cost() -> Dictionary:
	var built_count := 0
	for node in get_tree().get_nodes_in_group("buildings"):
		if node is GoldShack and is_instance_valid(node) and node.resource_id == mined_resource_id:
			built_count += 1
	return _scale_cost(shack_build_cost, built_count)


func _scale_cost(base_cost: Dictionary, built_count: int) -> Dictionary:
	var result := base_cost.duplicate()
	for resource_id in result:
		var price := maxi(0, int(result[resource_id]))
		for _built in range(maxi(0, built_count)):
			price = ceili(float(price) * 1.25)
		result[resource_id] = price
	return result


func _process(_delta: float) -> void:
	_update_hover_highlight(get_global_mouse_position())
	_update_mine_build_hover_label(get_global_mouse_position())
	if build_button.visible:
		_update_build_button_position()
	if _build_hover_label and _build_hover_label.visible:
		_update_build_hover_label_position()
	_update_shack_button_positions()


func _update_mine_build_hover_label(world_mouse_position: Vector2) -> void:
	if _build_hover_label == null:
		return
	var hovered := Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(world_mouse_position))
	_build_hover_label.visible = is_instance_valid(_mine) and not _mine_selected and hovered and _has_permanent_shack_cell()


func _on_resource_changed(_resource_id: StringName, _amount: int, _maximum_amount: int) -> void:
	if _mine == null:
		_update_build_availability()
	for button in _shack_buttons:
		if is_instance_valid(button):
			var cell := Vector2i(button.get_meta("build_cell", Vector2i.ZERO))
			var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
			button.disabled = _resource_manager == null or not _resource_manager.can_afford(get_current_shack_cost()) or world == null or not world.can_build_at_cell(cell)


func _update_build_availability() -> void:
	build_button.disabled = _resource_manager == null or not _resource_manager.can_afford(get_current_build_cost())


func _move_build_button_to_hud() -> void:
	if _button_is_in_hud:
		return
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	var hud: CanvasLayer
	if world:
		hud = world.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	build_button.reparent(hud, false)
	_button_is_in_hud = true
	_build_hover_label = Label.new()
	_build_hover_label.name = "MineBuildHoverLabel"
	_build_hover_label.text = "Build\nMore"
	_build_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_hover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_hover_label.size = Vector2(72, 48)
	_build_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hover_label.add_theme_color_override("font_color", Color.WHITE)
	_build_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_build_hover_label.add_theme_constant_override("outline_size", 3)
	_build_hover_label.z_index = 25
	_build_hover_label.hide()
	hud.add_child(_build_hover_label)
	_build_tooltip = hud.get_node_or_null("BuildMineTooltip") as BuildMineTooltip
	_update_build_button_position()


func _update_build_button_position() -> void:
	if not _button_is_in_hud:
		return
	var screen_position := get_global_transform_with_canvas().origin
	build_button.position = screen_position - build_button.size * 0.5


func _update_build_hover_label_position() -> void:
	if _build_hover_label == null:
		return
	var screen_position := get_global_transform_with_canvas().origin
	_build_hover_label.position = screen_position - _build_hover_label.size * 0.5


func _set_button_style() -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4d3d12") if state == "normal" else Color("715b19") if state == "hover" else Color("2f260a") if state == "pressed" else Color("25272d")
		style.border_color = Color("e9c64d") if state != "disabled" else Color("626975")
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		build_button.add_theme_stylebox_override(state, style)
	build_button.add_theme_color_override("font_color", Color("fff2bd"))
	build_button.add_theme_color_override("font_outline_color", Color.BLACK)
	build_button.add_theme_constant_override("outline_size", 2)


func _show_build_tooltip() -> void:
	if _mine == null and build_button.visible and _build_tooltip:
		_build_tooltip.show_cost(get_current_build_cost(), _resource_manager, build_button, mine_icon)


func _hide_build_tooltip(requester: Variant = null) -> void:
	if _build_tooltip:
		_build_tooltip.hide_tooltip(requester)


func _create_mine() -> void:
	_mine = MINER_STRUCTURE_SCENE.instantiate() as MinerStructure
	_mine.resource_id = mined_resource_id
	_mine.production_speed = mine_production_speed
	var sprite := _mine.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and mine_icon:
		sprite.texture = mine_icon
		sprite.position.y = -8.0
	var deposit_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if deposit_sprite:
		deposit_sprite.position.y = 14.0
		deposit_sprite.z_index = 0
	add_child(_mine)


func _show_shack_buttons() -> void:
	_clear_shack_buttons()
	build_button.visible = false
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null or not _button_is_in_hud:
		return
	var ore_cell := world.world_to_cell(global_position)
	for offset in ADJACENT_OFFSETS:
		var candidate: Vector2i = ore_cell + Vector2i(offset)
		if not world.is_permanently_buildable_cell(candidate):
			continue
		var button := Button.new()
		button.text = capacity_build_label
		button.custom_minimum_size = Vector2(96, 30)
		button.set_meta("build_cell", candidate)
		button.disabled = _resource_manager == null or not _resource_manager.can_afford(get_current_shack_cost()) or not world.can_build_at_cell(candidate)
		_set_action_button_style(button)
		button.pressed.connect(_try_build_shack.bind(candidate))
		button.mouse_entered.connect(_show_shack_tooltip.bind(button))
		button.mouse_exited.connect(_hide_build_tooltip.bind(button))
		build_button.get_parent().add_child(button)
		_shack_buttons.append(button)
	_update_shack_button_positions()


func _try_build_shack(cell: Vector2i) -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null or _resource_manager == null or not world.can_build_at_cell(cell):
		_show_shack_buttons()
		return
	if not _resource_manager.spend_resources(get_current_shack_cost()):
		return
	var shack := shack_scene.instantiate() as GoldShack
	shack.global_position = world.cell_to_world(cell)
	world.add_child(shack)
	_play_building_sfx()
	_clear_shack_buttons()
	_hide_build_tooltip()


func _play_building_sfx() -> void:
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_building()


func _show_shack_tooltip(button: Button) -> void:
	if _build_tooltip and is_instance_valid(button):
		_build_tooltip.show_cost(get_current_shack_cost(), _resource_manager, button, shack_icon)


func _clear_shack_buttons() -> void:
	for button in _shack_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_shack_buttons.clear()


func _update_shack_button_positions() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return
	for button in _shack_buttons:
		if not is_instance_valid(button):
			continue
		var cell := Vector2i(button.get_meta("build_cell", Vector2i.ZERO))
		var screen_position := world.get_canvas_transform() * world.cell_to_world(cell)
		button.position = screen_position - button.size * 0.5


func _update_hover_highlight(world_mouse_position: Vector2) -> void:
	if _tile_highlight:
		var can_offer_shack := _mine == null or _has_permanent_shack_cell()
		_tile_highlight.visible = can_offer_shack and Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(world_mouse_position))


func _has_permanent_shack_cell() -> bool:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return false
	var ore_cell := world.world_to_cell(global_position)
	for offset in ADJACENT_OFFSETS:
		if world.is_permanently_buildable_cell(ore_cell + Vector2i(offset)):
			return true
	return false


func _create_tile_highlight() -> Line2D:
	var highlight := Line2D.new()
	highlight.width = 2.0
	highlight.default_color = Color.YELLOW
	highlight.antialiased = false
	highlight.z_index = 20
	for point in [Vector2(-31, -31), Vector2(31, -31), Vector2(31, 31), Vector2(-31, 31), Vector2(-31, -31)]:
		highlight.add_point(point)
	highlight.visible = false
	return highlight


func _set_action_button_style(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4d3d12") if state == "normal" else Color("715b19") if state == "hover" else Color("2f260a") if state == "pressed" else Color("25272d")
		style.border_color = Color("e9c64d") if state != "disabled" else Color("626975")
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("fff2bd"))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 2)
