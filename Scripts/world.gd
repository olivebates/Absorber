class_name WorldNavigation
extends Node2D

const TILE_SIZE := 64
const EXPLORATION_RADIUS_TILES := 3

@onready var floor_layer: TileMapLayer = $FloorTerrain
@onready var wall_layer: TileMapLayer = $WallTerrain
@onready var player: FoxPlayer = $Fox

var _pathfinder := AStarGrid2D.new()
var _walkable_cells: Dictionary = {}
var _navigation_region := Rect2i()
var explored_cells: Dictionary = {}
var visited_campfires: Dictionary = {}


func _ready() -> void:
	add_to_group("world_navigation")
	_build_navigation_grid_from_tilemaps()
	_update_exploration()


func _process(_delta: float) -> void:
	_update_exploration()


func _update_exploration() -> void:
	if not is_instance_valid(player):
		return
	var player_cell := world_to_cell(player.global_position)
	for y in range(player_cell.y - EXPLORATION_RADIUS_TILES, player_cell.y + EXPLORATION_RADIUS_TILES + 1):
		for x in range(player_cell.x - EXPLORATION_RADIUS_TILES, player_cell.x + EXPLORATION_RADIUS_TILES + 1):
			var cell := Vector2i(x, y)
			if (cell - player_cell).length_squared() <= EXPLORATION_RADIUS_TILES * EXPLORATION_RADIUS_TILES and _navigation_region.has_point(cell):
				explored_cells[cell] = true
	for node in get_tree().get_nodes_in_group("campfires"):
		if node is Campfire and is_instance_valid(node) and node.is_player_in_range(player):
			visited_campfires[world_to_cell(node.global_position)] = true


func is_cell_explored(cell: Vector2i) -> bool:
	return explored_cells.has(cell)


func is_campfire_visited(campfire: Campfire) -> bool:
	return is_instance_valid(campfire) and visited_campfires.has(world_to_cell(campfire.global_position))


func get_exploration_save_data() -> Array:
	_update_exploration()
	var explored: Array = []
	for cell in explored_cells:
		explored.append([cell.x, cell.y])
	var campfires: Array = []
	for cell in visited_campfires:
		campfires.append([cell.x, cell.y])
	return [explored, campfires]


func load_exploration_save_data(data: Array) -> void:
	explored_cells.clear()
	visited_campfires.clear()
	if data.size() > 0 and data[0] is Array:
		for raw_cell in data[0]:
			if raw_cell is Array and raw_cell.size() >= 2:
				explored_cells[Vector2i(int(raw_cell[0]), int(raw_cell[1]))] = true
	if data.size() > 1 and data[1] is Array:
		for raw_cell in data[1]:
			if raw_cell is Array and raw_cell.size() >= 2:
				visited_campfires[Vector2i(int(raw_cell[0]), int(raw_cell[1]))] = true
	_update_exploration()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_shopkeeper := _get_shopkeeper_at_position(get_global_mouse_position())
		if clicked_shopkeeper:
			_hide_ore_build_buttons()
			clicked_shopkeeper.request_interaction(player, self)
			return
		var clicked_ore := _get_gold_ore_at_position(get_global_mouse_position())
		if clicked_ore:
			_show_ore_build_button(clicked_ore)
			return
		_hide_ore_build_buttons()
		var clicked_enemy := _get_enemy_at_position(get_global_mouse_position())
		if clicked_enemy:
			player.follow_enemy(clicked_enemy)
			return
		player.clear_attack_target()
		var target_cell := world_to_cell(get_global_mouse_position())
		if is_walkable(target_cell) and not is_cell_occupied(target_cell, player):
			player.follow_path(find_path(player.global_position, cell_to_world(target_cell), player))


func _get_shopkeeper_at_position(world_position: Vector2) -> WhiteTiger:
	for shopkeeper in get_tree().get_nodes_in_group("shopkeepers"):
		if shopkeeper is WhiteTiger and is_instance_valid(shopkeeper) and shopkeeper.global_position.distance_to(world_position) <= 30.0:
			return shopkeeper
	return null


func _get_enemy_at_position(world_position: Vector2) -> ChickenEnemy:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy) and enemy.global_position.distance_to(world_position) <= 28.0:
			return enemy
	return null


func _get_gold_ore_at_position(world_position: Vector2) -> GoldOre:
	for ore in get_tree().get_nodes_in_group("gold_ores"):
		if ore is GoldOre and is_instance_valid(ore) and ore.global_position.distance_to(world_position) <= 30.0:
			return ore
	return null


func _show_ore_build_button(selected_ore: GoldOre) -> void:
	for ore in get_tree().get_nodes_in_group("gold_ores"):
		if ore is GoldOre and is_instance_valid(ore):
			if ore == selected_ore:
				ore.show_build_button()
			else:
				ore.hide_build_button()


func _hide_ore_build_buttons() -> void:
	for ore in get_tree().get_nodes_in_group("gold_ores"):
		if ore is GoldOre and is_instance_valid(ore):
			ore.hide_build_button()


func find_path(from_world: Vector2, to_world: Vector2, moving_actor: Node2D = null) -> PackedVector2Array:
	var start := world_to_cell(from_world)
	var goal := world_to_cell(to_world)
	if not is_walkable(start) or not is_walkable(goal):
		return PackedVector2Array()
	var occupied := get_occupied_cells(moving_actor)
	for ore in get_tree().get_nodes_in_group("gold_ores"):
		if ore is GoldOre and is_instance_valid(ore):
			var ore_cell := world_to_cell(ore.global_position)
			if ore_cell != start:
				occupied[ore_cell] = true
	# The caller may omit moving_actor; its own starting tile must remain usable.
	occupied.erase(start)
	if occupied.has(goal):
		return PackedVector2Array()
	for cell in occupied:
		_pathfinder.set_point_solid(cell, true)
	var result := _center_and_compress(_pathfinder.get_id_path(start, goal))
	for cell in occupied:
		_pathfinder.set_point_solid(cell, false)
	return result


func get_patrol_path(from_world: Vector2, to_cell: Vector2i, home_cell: Vector2i, radius_tiles: int, moving_actor: Node2D = null) -> PackedVector2Array:
	var path := find_path(from_world, cell_to_world(to_cell), moving_actor)
	for point in path:
		var cell := world_to_cell(point)
		var offset := cell - home_cell
		if offset.length_squared() > radius_tiles * radius_tiles:
			return PackedVector2Array()
	return path


func get_patrol_destination(home_cell: Vector2i, radius_tiles: int, moving_actor: Node2D = null) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for y in range(home_cell.y - radius_tiles, home_cell.y + radius_tiles + 1):
		for x in range(home_cell.x - radius_tiles, home_cell.x + radius_tiles + 1):
			var candidate := Vector2i(x, y)
			var offset := candidate - home_cell
			if offset.length_squared() <= radius_tiles * radius_tiles and is_walkable(candidate) and not is_gold_ore_cell(candidate):
				candidates.append(candidate)
	if candidates.is_empty():
		return home_cell
	return candidates.pick_random()


func is_walkable(cell: Vector2i) -> bool:
	return _walkable_cells.has(cell) and not _pathfinder.is_point_solid(cell)


func is_cell_occupied(cell: Vector2i, except_actor: Node2D = null) -> bool:
	return get_occupied_cells(except_actor).has(cell)


func get_occupied_cells(except_actor: Node2D = null) -> Dictionary:
	var occupied := {}
	var actors := get_tree().get_nodes_in_group("enemies")
	actors.append_array(get_tree().get_nodes_in_group("player"))
	actors.append_array(get_tree().get_nodes_in_group("gates"))
	actors.append_array(get_tree().get_nodes_in_group("buildings"))
	actors.append_array(get_tree().get_nodes_in_group("npcs"))
	for actor in actors:
		if actor != except_actor and actor is Node2D and is_instance_valid(actor):
			occupied[world_to_cell(actor.global_position)] = true
	return occupied


func can_enter_position(actor: Node2D, world_position: Vector2) -> bool:
	var cell := world_to_cell(world_position)
	var current_cell := world_to_cell(actor.global_position)
	if cell == current_cell:
		# A structure may be built beneath an actor. Let it cross its current tile
		# so it can reach the unoccupied destination chosen by pathfinding.
		return is_walkable(cell)
	return is_walkable(cell) and not is_cell_occupied(cell, actor) and not is_gold_ore_cell(cell)


func is_gold_ore_cell(cell: Vector2i) -> bool:
	for ore in get_tree().get_nodes_in_group("gold_ores"):
		if ore is GoldOre and is_instance_valid(ore) and world_to_cell(ore.global_position) == cell:
			return true
	return false


func is_building_cell(cell: Vector2i) -> bool:
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is Node2D and is_instance_valid(building) and world_to_cell(building.global_position) == cell:
			return true
	return false


func can_build_at_cell(cell: Vector2i) -> bool:
	# Actors are temporary occupants and may step away after construction.
	return is_permanently_buildable_cell(cell)


func is_permanently_buildable_cell(cell: Vector2i) -> bool:
	return is_walkable(cell) \
		and wall_layer.get_cell_source_id(cell) == -1 \
		and not is_gold_ore_cell(cell) \
		and not is_building_cell(cell) \
		and not is_npc_cell(cell) \
		and not is_gate_cell(cell)


func is_npc_cell(cell: Vector2i) -> bool:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc is Node2D and is_instance_valid(npc) and world_to_cell(npc.global_position) == cell:
			return true
	return false


func is_gate_cell(cell: Vector2i) -> bool:
	for gate in get_tree().get_nodes_in_group("gates"):
		if gate is Node2D and is_instance_valid(gate) and world_to_cell(gate.global_position) == cell:
			return true
	return false


func is_enemy_target_conflicted(actor: ChickenEnemy, target_cell: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == actor or not node is ChickenEnemy or not is_instance_valid(node):
			continue
		var other := node as ChickenEnemy
		if world_to_cell(other.global_position) == target_cell:
			return true
		if other.get_movement_target_cell(self) == target_cell and other.get_instance_id() < actor.get_instance_id():
			return true
	return false


func are_adjacent(first: Node2D, second: Node2D) -> bool:
	var offset := world_to_cell(first.global_position) - world_to_cell(second.global_position)
	return absi(offset.x) + absi(offset.y) == 1


func world_to_cell(world_position: Vector2) -> Vector2i:
	return floor_layer.local_to_map(floor_layer.to_local(world_position))


func cell_to_world(cell: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(cell))


func _build_navigation_grid_from_tilemaps() -> void:
	for cell in floor_layer.get_used_cells():
		_walkable_cells[cell] = true

	_navigation_region = floor_layer.get_used_rect().merge(wall_layer.get_used_rect()).grow(1)
	_pathfinder.region = _navigation_region
	_pathfinder.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	_pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Jump Point Search keeps long routes fast on the fixed, uniform grid.
	_pathfinder.jumping_enabled = true
	_pathfinder.update()

	for y in range(_navigation_region.position.y, _navigation_region.end.y):
		for x in range(_navigation_region.position.x, _navigation_region.end.x):
			var cell := Vector2i(x, y)
			_pathfinder.set_point_solid(cell, not _walkable_cells.has(cell) or wall_layer.get_cell_source_id(cell) != -1)


func _center_and_compress(cell_path: Array[Vector2i]) -> PackedVector2Array:
	var result := PackedVector2Array()
	if cell_path.is_empty():
		return result
	result.append(cell_to_world(cell_path[0]))
	var previous_direction := Vector2i.ZERO
	for index in range(1, cell_path.size()):
		var direction: Vector2i = cell_path[index] - cell_path[index - 1]
		if index > 1 and direction != previous_direction:
			result.append(cell_to_world(cell_path[index - 1]))
		previous_direction = direction
	result.append(cell_to_world(cell_path[-1]))
	return result
