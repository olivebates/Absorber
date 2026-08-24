class_name WorldMapCanvas
extends Control

const CAMPFIRE_ICON := preload("res://Sprites/Campfire.webp")
const FLOOR_COLORS := [
	Color("527f46"), Color("3e716b"), Color("516d91"), Color("795f91"),
	Color("94754d"), Color("6f7945"), Color("7d5252"), Color("4c7280"),
]
const GREEN_FLOOR := Color("4f8a46")
const YELLOW_FLOOR := Color("a69a3f")
const BROWN_FLOOR := Color("795638")
const OBSTACLE_COLOR := Color("303238")
const WATER_COLOR := Color("2d7fc4")
const PATH_COLOR := Color("42a5f5")

var _world: WorldNavigation
var _campfires: Array[Campfire] = []
var _campfire_buttons: Array[Button] = []
var _show_enemies := false
var _show_buildings := true
var _enemies_toggle: CheckButton
var _buildings_toggle: CheckButton


func _ready() -> void:
	custom_minimum_size = Vector2(900, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_position_campfire_buttons)
	_build_layer_toggles()


func setup(world: WorldNavigation) -> void:
	_world = world
	apply_saved_preferences()
	refresh_markers()
	queue_redraw()


func refresh_markers() -> void:
	_rebuild_campfire_buttons()
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.055, 1.0), true)
	if _world == null:
		return
	var cell_size := _get_cell_size()
	for cell in _world.floor_layer.get_used_cells():
		if not _world.is_cell_explored(cell):
			continue
		var center := _cell_to_map(cell)
		draw_rect(Rect2(center - Vector2.ONE * cell_size * 0.5, Vector2.ONE * maxf(1.0, cell_size)), _get_floor_color(cell), true)
	for cell in _world.wall_layer.get_used_cells():
		if _world.is_cell_explored(cell):
			_draw_wall_cell(cell, cell_size)
	for group_name in [&"gates"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D and is_instance_valid(node):
				var cell := _world.world_to_cell(node.global_position)
				if _world.is_cell_explored(cell):
					_draw_obstacle_cell(cell, cell_size)
	if _show_buildings:
		for node in get_tree().get_nodes_in_group("buildings"):
			if node is Node2D and is_instance_valid(node):
				_draw_discovered_node_marker(node)
		for node in get_tree().get_nodes_in_group("gold_ores"):
			if node is GoldOre and is_instance_valid(node) and is_instance_valid(node._mine):
				_draw_discovered_node_marker(node._mine)
	if _show_enemies:
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Node2D and is_instance_valid(node):
				_draw_discovered_node_marker(node)
	for node in get_tree().get_nodes_in_group("gold_ores"):
		if node is Node2D and is_instance_valid(node):
			if _show_buildings and node is GoldOre and is_instance_valid(node._mine):
				continue
			_draw_discovered_node_marker(node)
	for shopkeeper in get_tree().get_nodes_in_group("shopkeepers"):
		if shopkeeper is Node2D and is_instance_valid(shopkeeper):
			_draw_discovered_node_marker(shopkeeper)
	if is_instance_valid(_world.player):
		_draw_player_path()
		var player_position := _cell_to_map(_world.world_to_cell(_world.player.global_position))
		draw_circle(player_position, 5.0, Color.BLACK)
		draw_circle(player_position, 3.0, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, false, 2.0)


func _get_floor_color(cell: Vector2i) -> Color:
	var atlas := _world.floor_layer.get_cell_atlas_coords(cell)
	if atlas.x >= 0 and atlas.x < 3:
		if atlas.y == 0:
			return GREEN_FLOOR
		if atlas.y == 2:
			return YELLOW_FLOOR
		if atlas.y == 4:
			return BROWN_FLOOR
	var source := _world.floor_layer.get_cell_source_id(cell)
	var color_index := absi(source * 31 + atlas.x * 17 + atlas.y * 13) % FLOOR_COLORS.size()
	return FLOOR_COLORS[color_index]


func _draw_obstacle_cell(cell: Vector2i, cell_size: float) -> void:
	var center := _cell_to_map(cell)
	draw_rect(Rect2(center - Vector2.ONE * cell_size * 0.5, Vector2.ONE * maxf(1.0, cell_size)), OBSTACLE_COLOR, true)


func _draw_wall_cell(cell: Vector2i, cell_size: float) -> void:
	var atlas := _world.wall_layer.get_cell_atlas_coords(cell)
	var source := _world.wall_layer.get_cell_source_id(cell)
	var color := WATER_COLOR if source == 3 and atlas.y == 1 and atlas.x >= 3 else OBSTACLE_COLOR
	var center := _cell_to_map(cell)
	draw_rect(Rect2(center - Vector2.ONE * cell_size * 0.5, Vector2.ONE * maxf(1.0, cell_size)), color, true)


func _draw_player_path() -> void:
	var path := _world.player.get_remaining_path_points()
	for index in range(1, path.size()):
		_draw_path_segment(path[index - 1], path[index])


func _draw_path_segment(from_world: Vector2, to_world: Vector2) -> void:
	var from_map := _cell_to_map(_world.world_to_cell(from_world))
	var to_map := _cell_to_map(_world.world_to_cell(to_world))
	var steps := maxi(1, ceili(from_map.distance_to(to_map) / 7.0))
	for step in range(steps + 1):
		var weight := float(step) / float(steps)
		var world_point := from_world.lerp(to_world, weight)
		if _world.is_cell_explored(_world.world_to_cell(world_point)):
			draw_circle(from_map.lerp(to_map, weight), 1.75, PATH_COLOR)


func _build_layer_toggles() -> void:
	var toggles := VBoxContainer.new()
	toggles.name = "MapLayerToggles"
	toggles.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toggles.position = Vector2(8, -62)
	toggles.size = Vector2(170, 54)
	toggles.add_theme_constant_override("separation", 0)
	add_child(toggles)
	_enemies_toggle = CheckButton.new()
	_enemies_toggle.name = "ShowEnemiesToggle"
	_enemies_toggle.text = "Show Enemies"
	_enemies_toggle.button_pressed = false
	_enemies_toggle.toggled.connect(_on_show_enemies_toggled)
	toggles.add_child(_enemies_toggle)
	_buildings_toggle = CheckButton.new()
	_buildings_toggle.name = "ShowBuildingsToggle"
	_buildings_toggle.text = "Show Buildings"
	_buildings_toggle.button_pressed = true
	_buildings_toggle.visible = false
	_buildings_toggle.toggled.connect(_on_show_buildings_toggled)
	toggles.add_child(_buildings_toggle)


func _on_show_enemies_toggled(enabled: bool) -> void:
	_show_enemies = enabled
	if _world:
		_world.map_show_enemies = enabled
	queue_redraw()


func _on_show_buildings_toggled(enabled: bool) -> void:
	_show_buildings = true
	if _world:
		_world.map_show_buildings = true
	if is_instance_valid(_buildings_toggle):
		_buildings_toggle.set_pressed_no_signal(true)
	queue_redraw()


func apply_saved_preferences() -> void:
	if _world == null:
		return
	_show_enemies = _world.map_show_enemies
	_show_buildings = true
	_world.map_show_buildings = true
	if is_instance_valid(_enemies_toggle):
		_enemies_toggle.set_pressed_no_signal(_show_enemies)
	if is_instance_valid(_buildings_toggle):
		_buildings_toggle.set_pressed_no_signal(_show_buildings)
	queue_redraw()


func _draw_discovered_node_marker(node: Node2D) -> void:
	var cell := _world.world_to_cell(node.global_position)
	if not _world.is_cell_explored(cell):
		return
	var sprite := _get_marker_sprite(node)
	if sprite == null or sprite.texture == null:
		return
	var marker_size := clampf(_get_cell_size() * 1.8, 12.0, 24.0)
	var rect := Rect2(_cell_to_map(cell) - Vector2.ONE * marker_size * 0.5, Vector2.ONE * marker_size)
	draw_texture_rect(sprite.texture, rect, false)


func _get_marker_sprite(node: Node2D) -> Sprite2D:
	for candidate in node.find_children("*", "Sprite2D", true, false):
		var sprite := candidate as Sprite2D
		if sprite.texture:
			return sprite
	return null


func _rebuild_campfire_buttons() -> void:
	for button in _campfire_buttons:
		button.queue_free()
	_campfire_buttons.clear()
	_campfires.clear()
	if _world == null:
		return
	for node in get_tree().get_nodes_in_group("campfires"):
		if not node is Campfire or not is_instance_valid(node):
			continue
		var campfire := node as Campfire
		if not _world.is_campfire_visited(campfire):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(28, 28)
		button.size = Vector2(28, 28)
		button.icon = CAMPFIRE_ICON
		button.expand_icon = true
		button.tooltip_text = "Teleport to Campfire"
		button.pressed.connect(_teleport_to_campfire.bind(campfire))
		add_child(button)
		_campfires.append(campfire)
		_campfire_buttons.append(button)
	_position_campfire_buttons()


func _position_campfire_buttons() -> void:
	if _world == null:
		return
	for index in range(_campfire_buttons.size()):
		if is_instance_valid(_campfires[index]):
			_campfire_buttons[index].position = _cell_to_map(_world.world_to_cell(_campfires[index].global_position)) - _campfire_buttons[index].size * 0.5


func _teleport_to_campfire(campfire: Campfire) -> void:
	if _world == null or not is_instance_valid(campfire) or not _world.is_campfire_visited(campfire):
		return
	var was_outside_destination := not campfire.is_player_in_range(_world.player)
	_world.player.stop()
	_world.player.clear_attack_target()
	_world.player.global_position = campfire.global_position
	_world.player.set_respawn_position(campfire.get_respawn_position())
	var map := get_parent().get_parent().get_parent().get_parent() as WorldMap
	if map:
		map.close()
	if was_outside_destination:
		var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
		if story:
			story.on_campfire_teleported()


func _get_cell_size() -> float:
	if _world == null:
		return 1.0
	var region_size := Vector2(_world._navigation_region.size)
	return maxf(1.0, minf((size.x - 20.0) / maxf(1.0, region_size.x), (size.y - 20.0) / maxf(1.0, region_size.y)))


func _cell_to_map(cell: Vector2i) -> Vector2:
	var cell_size := _get_cell_size()
	var region_size := Vector2(_world._navigation_region.size) * cell_size
	var offset := (size - region_size) * 0.5
	return offset + Vector2(cell - _world._navigation_region.position) * cell_size + Vector2.ONE * cell_size * 0.5
