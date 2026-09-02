class_name DungeonLevel
extends WorldNavigation

signal room_changed(previous_room: Vector2i, current_room: Vector2i)

const DEFAULT_ROOM_SIZE_TILES := Vector2i(20, 11)
const FLOOR_COLOR := Color("34313d")
const FLOOR_ALT_COLOR := Color("3c3847")
const GRID_COLOR := Color(0.08, 0.07, 0.10, 0.34)
const LEFT_TRANSITION_INSET := 2
const RIGHT_TRANSITION_INSET := 3
const VERTICAL_TRANSITION_INSET := 1
const LEFT_ENTRY_DEPTH := 3
const RIGHT_ENTRY_DEPTH := 4
const VERTICAL_ENTRY_DEPTH := 2
const ENTRY_SPAWN_OFFSET := Vector2i(3, 0)
const ITEM_PICKUP_SCENE := preload("res://Scenes/item_pickup.tscn")

@export var dungeon_id: StringName = &"test_dungeon"
@export var display_name := "Test Dungeon"
@export var room_size_tiles := DEFAULT_ROOM_SIZE_TILES
@export var entry_cell := Vector2i(2, 5)

var manager: Node
var current_room := Vector2i.ZERO
var previous_room := Vector2i.ZERO
var _previous_room_entry_position := Vector2.ZERO
var _camera: Camera2D
var _camera_tween: Tween
var _room_transitioning := false
var _edge_transition_armed := true
var _blocked_return_direction := Vector2i.ZERO
var _navigation_rooms: Array[Vector2i] = []
var _visited_rooms: Dictionary = {}
var _map_revision := 0
var _map_cache_dirty := true
var _map_cells_cache: Array[Vector2i] = []
var _map_wall_cells_cache: Array[Vector2i] = []
var _map_region_cache := Rect2i()


func _ready() -> void:
	add_to_group("world_navigation")
	add_to_group("dungeon_levels")
	game_audio = get_tree().get_first_node_in_group("game_audio") as GameAudio
	_navigation_rooms.append(cell_to_room(entry_cell))
	_build_dungeon_navigation()
	var safe_entry_cell := _get_entry_spawn_cell()
	current_room = cell_to_room(safe_entry_cell)
	previous_room = current_room
	_previous_room_entry_position = cell_to_world(safe_entry_cell)
	_reveal_room(current_room)
	$FloorTerrain.visible = false
	seed(1)
	queue_redraw()
	_initialize_navigation_runtime()


func attach_player(dungeon_player: FoxPlayer, dungeon_camera: Camera2D, dungeon_manager: Node) -> void:
	player = dungeon_player
	manager = dungeon_manager
	_camera = dungeon_camera
	var safe_entry_cell := _get_entry_spawn_cell()
	player.global_position = cell_to_world(safe_entry_cell)
	current_room = cell_to_room(safe_entry_cell)
	previous_room = current_room
	_previous_room_entry_position = player.global_position
	_edge_transition_armed = true
	_blocked_return_direction = Vector2i.ZERO
	if is_instance_valid(_camera):
		_camera.global_position = get_room_center(current_room)
		_camera.position_smoothing_enabled = false
	_reveal_room(current_room)
	_try_register_navigation_actor(player)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var player_cell := world_to_cell(player.global_position)
	if not _edge_transition_armed:
		if _get_transition_neighbor(player_cell, _blocked_return_direction) == current_room:
			_edge_transition_armed = true
			_blocked_return_direction = Vector2i.ZERO
		_update_room_objects()
		return
	var movement_direction := _get_player_movement_direction()
	var edge_room := _get_transition_neighbor(player_cell, movement_direction)
	if edge_room != current_room and movement_direction == edge_room - current_room:
		_transition_to_room(edge_room, true)
		_update_room_objects()
		return
	var next_room := cell_to_room(player_cell)
	if next_room != current_room:
		_transition_to_room(next_room)
	_update_room_objects()


func _physics_process(_delta: float) -> void:
	_reset_path_request_budget()
	_refresh_actor_cache()
	_ensure_player_flow_field()


func _unhandled_input(event: InputEvent) -> void:
	if gameplay_paused or interaction_locked or _room_transitioning or not is_instance_valid(player):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_position := get_global_mouse_position()
		var interactable := _get_interactable_at(mouse_position)
		if interactable:
			interactable.call("request_interaction", player, self)
			get_viewport().set_input_as_handled()
			return
		var clicked_enemy := _get_enemy_at_position(mouse_position)
		if clicked_enemy:
			player.follow_enemy(clicked_enemy)
			get_viewport().set_input_as_handled()
			return
		player.clear_attack_target()
		var target_cell := world_to_cell(mouse_position)
		if _try_transition_toward(target_cell):
			get_viewport().set_input_as_handled()
			return
		if is_walkable(target_cell) and not is_cell_occupied(target_cell, player):
			player.follow_path(find_path(player.global_position, cell_to_world(target_cell), player))
			get_viewport().set_input_as_handled()


func _get_interactable_at(world_position: Vector2) -> Node2D:
	var closest: Node2D
	var closest_distance := 36.0
	for node in get_tree().get_nodes_in_group("dungeon_interactables"):
		if not is_instance_valid(node) or not node is Node2D or not belongs_to_world(node) \
			or node is CanvasItem and not (node as CanvasItem).visible:
			continue
		var distance := (node as Node2D).global_position.distance_to(world_position)
		if distance <= closest_distance:
			closest = node as Node2D
			closest_distance = distance
	return closest


func _transition_to_room(next_room: Vector2i, move_player_through_edge := false) -> bool:
	var old_room := current_room
	var abandoned_with_enemies := has_room_enemies(old_room)
	_ensure_room_available(next_room)
	var destination_cell := world_to_cell(player.global_position)
	if move_player_through_edge:
		var direction := next_room - old_room
		destination_cell = _get_transition_destination(destination_cell, direction, next_room)
		if cell_to_room(destination_cell) != next_room or not is_walkable(destination_cell):
			player.stop()
			return false
	player.stop()
	previous_room = old_room
	_previous_room_entry_position = _safe_entry_position_for_room(old_room, next_room)
	if move_player_through_edge:
		player.global_position = cell_to_world(destination_cell)
		update_navigation_actor(player)
	current_room = next_room
	if abandoned_with_enemies:
		_respawn_room_enemies(old_room)
	_edge_transition_armed = false
	_blocked_return_direction = old_room - next_room
	_reveal_room(current_room)
	seed(1)
	room_changed.emit(old_room, current_room)
	_room_transitioning = true
	if is_instance_valid(_camera):
		if _camera_tween and _camera_tween.is_valid():
			_camera_tween.kill()
		_camera_tween = create_tween()
		_camera_tween.tween_property(_camera, "global_position", get_room_center(current_room), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_camera_tween.tween_callback(_finish_room_transition)
	else:
		_finish_room_transition()
	return true


func _finish_room_transition() -> void:
	_room_transitioning = false


func _get_transition_neighbor(cell: Vector2i, movement_direction := Vector2i.ZERO) -> Vector2i:
	var local_cell := cell - current_room * room_size_tiles
	var candidate := current_room
	if local_cell.x == LEFT_TRANSITION_INSET and (movement_direction == Vector2i.ZERO or movement_direction == Vector2i.LEFT):
		candidate += Vector2i.LEFT
	elif local_cell.x == room_size_tiles.x - 1 - RIGHT_TRANSITION_INSET and (movement_direction == Vector2i.ZERO or movement_direction == Vector2i.RIGHT):
		candidate += Vector2i.RIGHT
	elif local_cell.y == VERTICAL_TRANSITION_INSET and (movement_direction == Vector2i.ZERO or movement_direction == Vector2i.UP):
		candidate += Vector2i.UP
	elif local_cell.y == room_size_tiles.y - 1 - VERTICAL_TRANSITION_INSET and (movement_direction == Vector2i.ZERO or movement_direction == Vector2i.DOWN):
		candidate += Vector2i.DOWN
	return candidate


func _ensure_room_available(room: Vector2i) -> void:
	if _navigation_rooms.has(room):
		_activate_room_spawns(room)
		return
	_navigation_rooms.append(room)
	_build_dungeon_navigation()
	_activate_room_spawns(room)
	queue_redraw()


func _activate_room_spawns(room: Vector2i) -> void:
	var room_spawns: Array[EnemySpawnPoint] = []
	for child in get_children():
		if child is EnemySpawnPoint and cell_to_room(world_to_cell(child.global_position)) == room:
			room_spawns.append(child as EnemySpawnPoint)
	for spawn in room_spawns:
		spawn.ensure_initial_wave_spawned()


func _get_transition_destination(source_cell: Vector2i, direction: Vector2i, next_room: Vector2i) -> Vector2i:
	var source_local := source_cell - current_room * room_size_tiles
	var destination_local := source_local
	if direction.x > 0:
		destination_local.x = LEFT_ENTRY_DEPTH
	elif direction.x < 0:
		destination_local.x = room_size_tiles.x - 1 - RIGHT_ENTRY_DEPTH
	elif direction.y > 0:
		destination_local.y = VERTICAL_ENTRY_DEPTH
	elif direction.y < 0:
		destination_local.y = room_size_tiles.y - 1 - VERTICAL_ENTRY_DEPTH
	return next_room * room_size_tiles + destination_local


func _get_player_movement_direction() -> Vector2i:
	var movement := player.velocity
	if movement.length_squared() <= 0.01:
		var remaining_path := player.get_remaining_path_points()
		if remaining_path.size() >= 2:
			movement = remaining_path[1] - player.global_position
	if absf(movement.x) > absf(movement.y):
		return Vector2i(signi(roundi(movement.x)), 0)
	if absf(movement.y) > 0.01:
		return Vector2i(0, signi(roundi(movement.y)))
	return Vector2i.ZERO


func _try_transition_toward(target_cell: Vector2i) -> bool:
	if not _edge_transition_armed or _room_transitioning:
		return false
	var player_cell := world_to_cell(player.global_position)
	if not is_walkable(player_cell):
		return false
	var target_offset := target_cell - player_cell
	var target_direction := Vector2i.ZERO
	if absi(target_offset.x) > absi(target_offset.y):
		target_direction = Vector2i(signi(target_offset.x), 0)
	elif target_offset.y != 0:
		target_direction = Vector2i(0, signi(target_offset.y))
	var next_room := _get_transition_neighbor(player_cell, target_direction)
	if next_room == current_room:
		return false
	var direction := next_room - current_room
	if Vector2(target_cell - player_cell).dot(Vector2(direction)) <= 0.0:
		return false
	if not _transition_to_room(next_room, true):
		return false
	_update_room_objects()
	return true


func _get_safe_walkable_cell(preferred_cell: Vector2i) -> Vector2i:
	if is_walkable(preferred_cell):
		return preferred_cell
	var preferred_room := cell_to_room(preferred_cell)
	var closest_cell := preferred_cell
	var closest_distance := 1 << 30
	for raw_cell in _walkable_cells:
		var cell := raw_cell as Vector2i
		if cell_to_room(cell) != preferred_room:
			continue
		var distance := absi(cell.x - preferred_cell.x) + absi(cell.y - preferred_cell.y)
		if distance < closest_distance:
			closest_cell = cell
			closest_distance = distance
	return closest_cell


func _get_entry_spawn_cell() -> Vector2i:
	return _get_safe_walkable_cell(entry_cell + ENTRY_SPAWN_OFFSET)


func _safe_entry_position_for_room(room: Vector2i, toward_room: Vector2i) -> Vector2:
	var center_cell := room * room_size_tiles + room_size_tiles / 2
	var direction := toward_room - room
	center_cell += Vector2i(clampi(direction.x, -1, 1), clampi(direction.y, -1, 1)) * 2
	return cell_to_world(center_cell)


func get_death_respawn_position() -> Vector2:
	return _previous_room_entry_position


func is_actor_in_active_room(actor: Node2D) -> bool:
	return is_instance_valid(actor) and cell_to_room(world_to_cell(actor.global_position)) == current_room


func has_current_room_enemies() -> bool:
	return has_room_enemies(current_room)


func has_room_enemies(room: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node is ChickenEnemy and belongs_to_world(node) \
			and node.health > 0 and cell_to_room(world_to_cell(node.global_position)) == room:
			return true
	return false


func notify_chest_opened() -> void:
	var found_chest := false
	for node in get_tree().get_nodes_in_group("dungeon_chests"):
		if not is_instance_valid(node) or not node is DungeonChest or not belongs_to_world(node):
			continue
		found_chest = true
		if not (node as DungeonChest).opened:
			return
	if found_chest and is_instance_valid(manager) and manager.has_method("request_completed_dungeon_exit"):
		manager.call("request_completed_dungeon_exit")


func _respawn_room_enemies(room: Vector2i) -> void:
	var room_spawns: Array[EnemySpawnPoint] = []
	for child in get_children():
		if child is EnemySpawnPoint and cell_to_room(world_to_cell(child.global_position)) == room:
			room_spawns.append(child as EnemySpawnPoint)
	for spawn in room_spawns:
		spawn.respawn_all_immediately()


func is_current_room_clear() -> bool:
	return not has_current_room_enemies()


func get_room_center(room: Vector2i) -> Vector2:
	return Vector2(room * room_size_tiles * TILE_SIZE) + Vector2(room_size_tiles * TILE_SIZE) * 0.5


func cell_to_room(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(maxi(1, room_size_tiles.x))), floori(float(cell.y) / float(maxi(1, room_size_tiles.y))))


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)
	return Vector2i(floori(local_position.x / TILE_SIZE), floori(local_position.y / TILE_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE * 0.5)


func get_map_cells() -> Array[Vector2i]:
	_rebuild_map_cache()
	return _map_cells_cache


func get_map_wall_cells() -> Array[Vector2i]:
	_rebuild_map_cache()
	return _map_wall_cells_cache


func get_map_region() -> Rect2i:
	_rebuild_map_cache()
	return _map_region_cache


func get_map_revision() -> int:
	return _map_revision


func is_cell_explored(cell: Vector2i) -> bool:
	return _visited_rooms.has(cell_to_room(cell))


func get_map_floor_color(_cell: Vector2i) -> Color:
	return FLOOR_ALT_COLOR if (absi(_cell.x) + absi(_cell.y)) % 2 == 0 else FLOOR_COLOR


func capture_snapshot() -> Dictionary:
	var spawns: Dictionary = {}
	var has_boss := false
	var boss_killed := true
	for child in get_children():
		if is_instance_valid(child) and child is EnemySpawnPoint:
			var spawn := child as EnemySpawnPoint
			spawns[str(spawn.name)] = spawn.get_save_data()
			if spawn.boss:
				has_boss = true
				boss_killed = boss_killed and spawn.emptied_once and spawn.get_active_enemies().is_empty()
	var chests: Dictionary = {}
	var found_chest := false
	var all_chests_open := true
	for node in get_tree().get_nodes_in_group("dungeon_chests"):
		if is_instance_valid(node) and node is DungeonChest and belongs_to_world(node):
			found_chest = true
			chests[str(node.name)] = node.get_save_data()
			all_chests_open = all_chests_open and node.opened
	var locked_doors: Dictionary = {}
	for node in get_tree().get_nodes_in_group("dungeon_locked_doors"):
		if is_instance_valid(node) and node is DungeonDoorLocked and belongs_to_world(node):
			locked_doors[str(node.name)] = node.get_save_data()
	var explored: Array = []
	for cell in explored_cells:
		explored.append([cell.x, cell.y])
	var visited_rooms: Array = []
	for room in _visited_rooms:
		visited_rooms.append([room.x, room.y])
	var pickups: Array = []
	for node in get_tree().get_nodes_in_group("item_pickups"):
		if node is ItemPickup and is_instance_valid(node) and belongs_to_world(node) and not node._collecting:
			var pickup := node as ItemPickup
			pickups.append([roundi(pickup.global_position.x), roundi(pickup.global_position.y), pickup.item_id, pickup.grade])
	return {
		"player_position": [roundi(player.global_position.x), roundi(player.global_position.y)] if is_instance_valid(player) else [],
		"current_room": [current_room.x, current_room.y],
		"previous_room": [previous_room.x, previous_room.y],
		"previous_room_entry_position": [roundi(_previous_room_entry_position.x), roundi(_previous_room_entry_position.y)],
		"spawns": spawns,
		"chests": chests,
		"locked_doors": locked_doors,
		"explored": explored,
		"visited_rooms": visited_rooms,
		"pickups": pickups,
		"boss_killed": has_boss and boss_killed,
		"all_chests_open": found_chest and all_chests_open,
		"cleared": found_chest and all_chests_open,
	}


func load_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	# Rebuild every saved room before restoring its spawns. Previously, enemies
	# outside the entry room were restored while those cells were still absent
	# from navigation, so the spawn lookup failed and left only a huge timer.
	var saved_visited_rooms := snapshot.get("visited_rooms", []) as Array
	var navigation_expanded := false
	for raw_room in saved_visited_rooms:
		if raw_room is Array and raw_room.size() >= 2:
			var room := Vector2i(int(raw_room[0]), int(raw_room[1]))
			_register_visited_room(room)
			if not _navigation_rooms.has(room):
				_navigation_rooms.append(room)
				navigation_expanded = true
	if navigation_expanded:
		_build_dungeon_navigation()
		queue_redraw()
	var saved_spawns := snapshot.get("spawns", {}) as Dictionary
	for child in get_children():
		if not is_instance_valid(child) or not child is EnemySpawnPoint:
			continue
		var spawn := child as EnemySpawnPoint
		if not saved_spawns.has(str(spawn.name)):
			continue
		spawn.clear_for_load()
		var spawn_data := saved_spawns[str(spawn.name)] as Array
		spawn.load_save_data(spawn_data, 0, true)
	var saved_chests := snapshot.get("chests", {}) as Dictionary
	for node in get_tree().get_nodes_in_group("dungeon_chests"):
		if is_instance_valid(node) and node is DungeonChest and belongs_to_world(node) and saved_chests.has(str(node.name)):
			node.load_opened(bool(saved_chests[str(node.name)]))
	var saved_doors := snapshot.get("locked_doors", {}) as Dictionary
	for node in get_tree().get_nodes_in_group("dungeon_locked_doors"):
		if is_instance_valid(node) and node is DungeonDoorLocked and belongs_to_world(node) and saved_doors.has(str(node.name)):
			node.load_opened(bool(saved_doors[str(node.name)]))
	if snapshot.has("pickups"):
		for node in get_tree().get_nodes_in_group("item_pickups"):
			if node is ItemPickup and is_instance_valid(node) and belongs_to_world(node):
				node.free()
		for raw_pickup in snapshot.get("pickups", []) as Array:
			if not raw_pickup is Array or raw_pickup.size() < 4 or not ItemPickup.ITEM_DATA.has(str(raw_pickup[2])):
				continue
			var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
			pickup.setup(str(raw_pickup[2]), int(raw_pickup[3]))
			pickup.global_position = Vector2(float(raw_pickup[0]), float(raw_pickup[1]))
			add_child(pickup)
	_restore_explored_cells(snapshot.get("explored", []) as Array, saved_visited_rooms.is_empty(), not navigation_expanded)
	_restore_player_snapshot(snapshot)
	_update_room_objects()


func _restore_player_snapshot(snapshot: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	var saved_position := snapshot.get("player_position", []) as Array
	if saved_position.size() < 2:
		return
	var candidate := Vector2(float(saved_position[0]), float(saved_position[1]))
	var candidate_cell := world_to_cell(candidate)
	if not is_walkable(candidate_cell) or is_cell_occupied(candidate_cell, player):
		return
	player.global_position = cell_to_world(candidate_cell)
	update_navigation_actor(player)
	current_room = cell_to_room(candidate_cell)
	var saved_current_room := snapshot.get("current_room", []) as Array
	if saved_current_room.size() >= 2:
		current_room = Vector2i(int(saved_current_room[0]), int(saved_current_room[1]))
	previous_room = current_room
	var saved_previous_room := snapshot.get("previous_room", []) as Array
	if saved_previous_room.size() >= 2:
		previous_room = Vector2i(int(saved_previous_room[0]), int(saved_previous_room[1]))
	_previous_room_entry_position = player.global_position
	var saved_respawn_position := snapshot.get("previous_room_entry_position", []) as Array
	if saved_respawn_position.size() >= 2:
		_previous_room_entry_position = Vector2(float(saved_respawn_position[0]), float(saved_respawn_position[1]))
	_edge_transition_armed = true
	_blocked_return_direction = Vector2i.ZERO
	if is_instance_valid(_camera):
		_camera.global_position = get_room_center(current_room)
		_camera.reset_smoothing()


func _restore_explored_cells(explored: Array, infer_visited_rooms := true, rebuild_navigation := true) -> void:
	var navigation_expanded := false
	for raw_cell in explored:
		if raw_cell is Array and raw_cell.size() >= 2:
			var cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
			explored_cells[cell] = true
			var room := cell_to_room(cell)
			if infer_visited_rooms:
				_register_visited_room(room)
			if infer_visited_rooms and not _navigation_rooms.has(room):
				_navigation_rooms.append(room)
				navigation_expanded = true
	if navigation_expanded and rebuild_navigation:
		_build_dungeon_navigation()
		queue_redraw()


func _build_dungeon_navigation() -> void:
	_walkable_cells.clear()
	if _navigation_rooms.is_empty():
		_navigation_rooms.append(cell_to_room(entry_cell))
	var minimum := _navigation_rooms[0] * room_size_tiles
	var maximum := minimum + room_size_tiles
	for room in _navigation_rooms:
		var room_origin := room * room_size_tiles
		minimum.x = mini(minimum.x, room_origin.x)
		minimum.y = mini(minimum.y, room_origin.y)
		maximum.x = maxi(maximum.x, room_origin.x + room_size_tiles.x)
		maximum.y = maxi(maximum.y, room_origin.y + room_size_tiles.y)
		for y in range(room_origin.y, room_origin.y + room_size_tiles.y):
			for x in range(room_origin.x, room_origin.x + room_size_tiles.x):
				var local_cell := Vector2i(x, y) - room_origin
				var cell := Vector2i(x, y)
				var authored_wall := is_instance_valid(wall_layer) and wall_layer.get_cell_source_id(cell) != -1
				if _is_room_cell_walkable(room, local_cell) and not authored_wall:
					_walkable_cells[cell] = true
	_navigation_region = Rect2i(minimum, maximum - minimum)
	_pathfinder = AStarGrid2D.new()
	_pathfinder.region = _navigation_region
	_pathfinder.cell_size = Vector2.ONE * TILE_SIZE
	_pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_pathfinder.jumping_enabled = true
	_pathfinder.update()
	for y in range(_navigation_region.position.y, _navigation_region.end.y):
		for x in range(_navigation_region.position.x, _navigation_region.end.x):
			var cell := Vector2i(x, y)
			_pathfinder.set_point_solid(cell, not _walkable_cells.has(cell))
	_navigation_changed()


func _is_room_cell_walkable(_room: Vector2i, _local_cell: Vector2i) -> bool:
	return true


func _reveal_room(room: Vector2i) -> void:
	_register_visited_room(room)
	var origin := room * room_size_tiles
	for y in range(origin.y, origin.y + room_size_tiles.y):
		for x in range(origin.x, origin.x + room_size_tiles.x):
			explored_cells[Vector2i(x, y)] = true


func _get_visited_rooms() -> Array[Vector2i]:
	var visited_rooms: Array[Vector2i] = []
	for room in _visited_rooms:
		visited_rooms.append(room)
	return visited_rooms


func _register_visited_room(room: Vector2i) -> void:
	if _visited_rooms.has(room):
		return
	_visited_rooms[room] = true
	_map_revision += 1
	_map_cache_dirty = true


func _rebuild_map_cache() -> void:
	if not _map_cache_dirty:
		return
	_map_cells_cache.clear()
	_map_wall_cells_cache.clear()
	var visited_rooms := _get_visited_rooms()
	if visited_rooms.is_empty():
		_map_region_cache = Rect2i(current_room * room_size_tiles, room_size_tiles)
		_map_cache_dirty = false
		return
	var minimum := visited_rooms[0] * room_size_tiles
	var maximum := minimum + room_size_tiles
	for room in visited_rooms:
		var room_origin := room * room_size_tiles
		minimum.x = mini(minimum.x, room_origin.x)
		minimum.y = mini(minimum.y, room_origin.y)
		maximum.x = maxi(maximum.x, room_origin.x + room_size_tiles.x)
		maximum.y = maxi(maximum.y, room_origin.y + room_size_tiles.y)
		for y in range(room_origin.y, room_origin.y + room_size_tiles.y):
			for x in range(room_origin.x, room_origin.x + room_size_tiles.x):
				var cell := Vector2i(x, y)
				_map_cells_cache.append(cell)
				if is_instance_valid(wall_layer) and wall_layer.get_cell_source_id(cell) != -1:
					_map_wall_cells_cache.append(cell)
	_map_region_cache = Rect2i(minimum, maximum - minimum)
	_map_cache_dirty = false


func _update_room_objects() -> void:
	for node in get_tree().get_nodes_in_group("dungeon_room_objects"):
		if is_instance_valid(node) and belongs_to_world(node) and node.has_method("refresh_for_room"):
			node.call("refresh_for_room", self)


func _draw() -> void:
	for room in _navigation_rooms:
		var top_left := Vector2(room * room_size_tiles * TILE_SIZE)
		var room_size := Vector2(room_size_tiles * TILE_SIZE)
		draw_rect(Rect2(top_left, room_size), FLOOR_COLOR, true)
		for y in range(room_size_tiles.y):
			for x in range(room_size_tiles.x):
				if (x + y) % 2 == 0:
					draw_rect(Rect2(top_left + Vector2(x, y) * TILE_SIZE, Vector2.ONE * TILE_SIZE), FLOOR_ALT_COLOR, true)
		for x in range(room_size_tiles.x + 1):
			draw_line(top_left + Vector2(x * TILE_SIZE, 0), top_left + Vector2(x * TILE_SIZE, room_size.y), GRID_COLOR, 1.0)
		for y in range(room_size_tiles.y + 1):
			draw_line(top_left + Vector2(0, y * TILE_SIZE), top_left + Vector2(room_size.x, y * TILE_SIZE), GRID_COLOR, 1.0)
