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

var _world: WorldNavigation
var _campfires: Array[Campfire] = []
var _campfire_buttons: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(900, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_position_campfire_buttons)


func setup(world: WorldNavigation) -> void:
	_world = world
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
			_draw_obstacle_cell(cell, cell_size)
	for group_name in [&"buildings", &"gates"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D and is_instance_valid(node):
				var cell := _world.world_to_cell(node.global_position)
				if _world.is_cell_explored(cell):
					_draw_obstacle_cell(cell, cell_size)
	for node in get_tree().get_nodes_in_group("gold_ores"):
		if node is Node2D and is_instance_valid(node):
			_draw_discovered_node_marker(node)
	var tiger := get_tree().get_first_node_in_group("shopkeepers") as WhiteTiger
	if tiger and is_instance_valid(tiger):
		_draw_discovered_node_marker(tiger)
	if is_instance_valid(_world.player):
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


func _draw_discovered_node_marker(node: Node2D) -> void:
	var cell := _world.world_to_cell(node.global_position)
	if not _world.is_cell_explored(cell):
		return
	var sprite := node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var marker_size := clampf(_get_cell_size() * 1.8, 12.0, 24.0)
	var rect := Rect2(_cell_to_map(cell) - Vector2.ONE * marker_size * 0.5, Vector2.ONE * marker_size)
	draw_texture_rect(sprite.texture, rect, false)


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
	_world.player.stop()
	_world.player.clear_attack_target()
	_world.player.global_position = campfire.global_position
	var map := get_parent().get_parent().get_parent().get_parent() as WorldMap
	if map:
		map.close()


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
