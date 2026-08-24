class_name Minimap
extends Control

const ENEMY_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const NPC_COLOR := Color("43a047")
const PATH_COLOR := Color("42a5f5")
const VISIBLE_RADIUS_TILES := 20.0
const CLICK_SEARCH_LIMIT := 30
const REDRAW_INTERVAL := 0.1
const GREEN_FLOOR := Color("4f8a46")
const YELLOW_FLOOR := Color("a69a3f")
const BROWN_FLOOR := Color("795638")
const OBSTACLE_COLOR := Color("303238")
const WATER_COLOR := Color("2d7fc4")
const FLOOR_COLORS := [
	Color("527f46"), Color("3e716b"), Color("516d91"), Color("795f91"),
	Color("94754d"), Color("6f7945"), Color("7d5252"), Color("4c7280"),
]

var _world: WorldNavigation
var _redraw_time_left := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -194.0
	offset_top = 60.0
	offset_right = -12.0
	offset_bottom = 196.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	call_deferred("_connect_world")


func _connect_world() -> void:
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation


func _process(delta: float) -> void:
	_redraw_time_left -= delta
	if _redraw_time_left <= 0.0:
		_redraw_time_left = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.055, 0.9), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, false, 2.0)
	if _world == null or _world._navigation_region.size.x <= 0 or _world._navigation_region.size.y <= 0:
		return
	var map_rect := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	var player := _world.player if _world else null
	if player == null:
		return
	var player_cell := _world.world_to_cell(player.global_position)
	var tile_scale := _get_tile_scale(map_rect)
	draw_rect(map_rect, Color(0.055, 0.07, 0.065, 1.0), true)
	_draw_terrain(map_rect, player_cell, tile_scale)
	_draw_player_path(map_rect)
	draw_rect(map_rect, Color(0.0, 0.0, 0.0, 1.0), false, 1.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy) and _is_visible_marker(enemy, player_cell):
			var dot_position := _world_to_minimap(enemy.global_position, map_rect)
			draw_circle(dot_position, 4.0, Color.BLACK)
			draw_circle(dot_position, 2.5, ENEMY_COLORS[clampi(enemy.enemy_color, 0, ENEMY_COLORS.size() - 1)])
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc is Node2D and is_instance_valid(npc) and _is_visible_marker(npc, player_cell):
			var npc_position := _world_to_minimap(npc.global_position, map_rect)
			draw_circle(npc_position, 4.0, Color.BLACK)
			draw_circle(npc_position, 2.5, NPC_COLOR)
	var player_position := map_rect.get_center()
	draw_circle(player_position, 3.5, Color.BLACK)
	draw_circle(player_position, 2.0, Color.WHITE)


func _draw_terrain(map_rect: Rect2, player_cell: Vector2i, tile_scale: Vector2) -> void:
	var radius := int(VISIBLE_RADIUS_TILES)
	for y in range(player_cell.y - radius, player_cell.y + radius + 1):
		for x in range(player_cell.x - radius, player_cell.x + radius + 1):
			var cell := Vector2i(x, y)
			if not _world._navigation_region.has_point(cell) or not _world.is_cell_explored(cell):
				continue
			var center := map_rect.get_center() + Vector2(cell - player_cell) * tile_scale
			var drawn_size := Vector2(maxf(1.0, tile_scale.x), maxf(1.0, tile_scale.y))
			var cell_rect := Rect2(center - tile_scale * 0.5, drawn_size)
			if _world.floor_layer.get_cell_source_id(cell) != -1:
				draw_rect(cell_rect, _get_floor_color(cell), true)
			if _world.wall_layer.get_cell_source_id(cell) != -1:
				draw_rect(cell_rect, _get_wall_color(cell), true)


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


func _get_wall_color(cell: Vector2i) -> Color:
	var atlas := _world.wall_layer.get_cell_atlas_coords(cell)
	var source := _world.wall_layer.get_cell_source_id(cell)
	return WATER_COLOR if source == 3 and atlas.y == 1 and atlas.x >= 3 else OBSTACLE_COLOR


func _is_within_visible_range(world_position: Vector2, player_cell: Vector2i) -> bool:
	var offset := _world.world_to_cell(world_position) - player_cell
	return offset.length_squared() <= VISIBLE_RADIUS_TILES * VISIBLE_RADIUS_TILES


func _is_visible_marker(node: Node2D, player_cell: Vector2i) -> bool:
	var cell := _world.world_to_cell(node.global_position)
	return _world.is_cell_explored(cell) and _is_within_visible_range(node.global_position, player_cell)


func _get_tile_scale(map_rect: Rect2) -> Vector2:
	return map_rect.size / (VISIBLE_RADIUS_TILES * 2.0 + 1.0)


func _draw_player_path(map_rect: Rect2) -> void:
	var path := _world.player.get_remaining_path_points()
	for index in range(1, path.size()):
		_draw_path_segment(path[index - 1], path[index], map_rect)


func _draw_path_segment(from_world: Vector2, to_world: Vector2, map_rect: Rect2) -> void:
	var from_map := _world_to_minimap_unclamped(from_world, map_rect)
	var to_map := _world_to_minimap_unclamped(to_world, map_rect)
	var steps := maxi(1, ceili(from_map.distance_to(to_map) / 5.0))
	for step in range(steps + 1):
		var weight := float(step) / float(steps)
		var map_point := from_map.lerp(to_map, weight)
		var world_point := from_world.lerp(to_world, weight)
		if map_rect.has_point(map_point) and _world.is_cell_explored(_world.world_to_cell(world_point)):
			draw_circle(map_point, 1.25, PATH_COLOR)


func _world_to_minimap(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var position := _world_to_minimap_unclamped(world_position, map_rect)
	return Vector2(
		clampf(position.x, map_rect.position.x, map_rect.end.x),
		clampf(position.y, map_rect.position.y, map_rect.end.y)
	)


func _world_to_minimap_unclamped(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var cell := _world.world_to_cell(world_position)
	var player := _world.player if _world else null
	if player == null:
		return map_rect.get_center()
	var player_cell := _world.world_to_cell(player.global_position)
	var cell_offset := cell - player_cell
	var tile_scale := _get_tile_scale(map_rect)
	return map_rect.get_center() + Vector2(cell_offset) * tile_scale


func _minimap_to_cell(local_position: Vector2, map_rect: Rect2) -> Vector2i:
	var player_cell := _world.world_to_cell(_world.player.global_position)
	var tile_scale := _get_tile_scale(map_rect)
	var offset := local_position - map_rect.get_center()
	return player_cell + Vector2i(roundi(offset.x / tile_scale.x), roundi(offset.y / tile_scale.y))


func _on_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var map_rect := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	if _world == null or not is_instance_valid(_world.player) or not map_rect.has_point(event.position):
		return
	var path := _find_click_path(_minimap_to_cell(event.position, map_rect))
	if not path.is_empty():
		_world.player.clear_attack_target()
		_world.player.follow_path(path)
	accept_event()


func _find_click_path(clicked_cell: Vector2i) -> PackedVector2Array:
	if _world == null or not is_instance_valid(_world.player):
		return PackedVector2Array()
	for distance in range(CLICK_SEARCH_LIMIT + 1):
		var best_path := PackedVector2Array()
		var best_length := INF
		for candidate in _get_cell_ring(clicked_cell, distance):
			if not _world.is_cell_explored(candidate) or not _world.is_walkable(candidate) or _world.is_cell_occupied(candidate, _world.player):
				continue
			var path := _world.find_path(_world.player.global_position, _world.cell_to_world(candidate), _world.player)
			if path.is_empty():
				continue
			var path_length := _get_path_length(path)
			if path_length < best_length:
				best_length = path_length
				best_path = path
		if not best_path.is_empty():
			return best_path
	return PackedVector2Array()


func _get_cell_ring(center: Vector2i, distance: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if distance == 0:
		cells.append(center)
		return cells
	for x_offset in range(-distance, distance + 1):
		var y_offset := distance - absi(x_offset)
		cells.append(center + Vector2i(x_offset, y_offset))
		if y_offset != 0:
			cells.append(center + Vector2i(x_offset, -y_offset))
	return cells


func _get_path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	var previous := _world.player.global_position
	for point in path:
		length += previous.distance_to(point)
		previous = point
	return length
