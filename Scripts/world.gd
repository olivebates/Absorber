class_name WorldNavigation
extends Node2D

const TILE_SIZE := 64
const EXPLORATION_RADIUS_TILES := 6
const COMBAT_TILE_LERP_DURATION := 0.20
const COMBAT_ALIGNMENT_TWEEN_META := &"combat_alignment_tween"
const COMBAT_ALIGNMENT_TARGET_META := &"combat_alignment_target"
const PATH_REQUEST_BUDGET_PER_FRAME := 2
const FLOW_FIELD_RADIUS_TILES := 12
const ACTOR_RECONCILE_INTERVAL_FRAMES := 3600
const NAVIGATION_ACTOR_GROUPS := [&"enemies", &"player", &"gates", &"buildings", &"npcs", &"solid_walls", &"gold_ores"]
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@export var version_number := 1

@onready var floor_layer: TileMapLayer = get_node_or_null("FloorTerrain") as TileMapLayer
@onready var wall_layer: TileMapLayer = get_node_or_null("WallTerrain") as TileMapLayer
@onready var player: FoxPlayer = get_node_or_null("Fox") as FoxPlayer

var _pathfinder := AStarGrid2D.new()
var _walkable_cells: Dictionary = {}
var _navigation_region := Rect2i()
var explored_cells: Dictionary = {}
var _exploration_map_revision := 0
var visited_campfires: Dictionary = {}
var second_campfire_tab_prompt_dismissed := false
var map_show_enemies := true
var map_show_buildings := true
var interaction_locked := false
var gameplay_paused := false
var _tab_prompt: Label
var _actor_cache_frame := -1
var _cached_actor_counts: Dictionary = {}
var _cached_actor_single_ids: Dictionary = {}
var _cached_enemy_target_min_ids: Dictionary = {}
var _cached_enemies_by_cell: Dictionary = {}
var _cached_actors_by_cell: Dictionary = {}
var _cached_all_occupied_cells: Dictionary = {}
var _occupied_snapshots_by_actor: Dictionary = {}
var _occupied_snapshot_frame := -1
var _navigation_actors: Dictionary = {}
var _navigation_enemies: Dictionary = {}
var _actor_cells_by_id: Dictionary = {}
var _overlap_navigation_actors: Dictionary = {}
var _actor_reconcile_frame := -ACTOR_RECONCILE_INTERVAL_FRAMES
var _patrol_destination_cache: Dictionary = {}
var _path_budget_frame := -1
var _path_requests_used := 0
var _player_flow_goal_cell := Vector2i(2147483647, 2147483647)
var _player_flow_navigation_revision := -1
var _player_flow_distances: Dictionary = {}
var _navigation_revision := 0
var _visible_world_rect_frame := -1
var _visible_world_rect := Rect2()
var game_audio: GameAudio


func _ready() -> void:
	add_to_group("world_navigation")
	game_audio = GameAudio.new()
	game_audio.name = "GameAudio"
	game_audio.setup(self)
	add_child(game_audio)
	_build_navigation_grid_from_tilemaps()
	_create_tab_prompt()
	_update_exploration()
	_initialize_navigation_runtime()


func _input(event: InputEvent) -> void:
	_consume_tab_navigation(event)


func _unhandled_key_input(event: InputEvent) -> void:
	_consume_tab_navigation(event)


func _consume_tab_navigation(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_TAB:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()


func _process(_delta: float) -> void:
	_update_exploration()


func _physics_process(_delta: float) -> void:
	_reset_path_request_budget()
	_refresh_actor_cache()
	_ensure_player_flow_field()


func _update_exploration() -> void:
	if not is_instance_valid(player):
		return
	var dungeon_manager := get_node_or_null("DungeonManager") as DungeonManager
	if dungeon_manager and dungeon_manager.is_dungeon_active():
		return
	var player_cell := world_to_cell(player.global_position)
	var changed := false
	for y in range(player_cell.y - EXPLORATION_RADIUS_TILES, player_cell.y + EXPLORATION_RADIUS_TILES + 1):
		for x in range(player_cell.x - EXPLORATION_RADIUS_TILES, player_cell.x + EXPLORATION_RADIUS_TILES + 1):
			var cell := Vector2i(x, y)
			if (cell - player_cell).length_squared() <= EXPLORATION_RADIUS_TILES * EXPLORATION_RADIUS_TILES and _navigation_region.has_point(cell):
				if not explored_cells.has(cell):
					explored_cells[cell] = true
					changed = true
	if changed:
		_exploration_map_revision += 1
	for node in get_tree().get_nodes_in_group("campfires"):
		if node is Campfire and is_instance_valid(node) and node.is_player_in_range(player):
			visited_campfires[world_to_cell(node.global_position)] = true
			player.set_respawn_position((node as Campfire).get_respawn_position())
			if node.name == &"Campfire2" and not second_campfire_tab_prompt_dismissed:
				_tab_prompt.visible = true


func is_cell_explored(cell: Vector2i) -> bool:
	return explored_cells.has(cell)


func get_map_region() -> Rect2i:
	if explored_cells.is_empty():
		return Rect2i(world_to_cell(player.global_position), Vector2i.ONE) if is_instance_valid(player) else _navigation_region
	var cells := explored_cells.keys()
	var minimum: Vector2i = cells[0]
	var maximum := minimum
	for cell_value in cells:
		var cell: Vector2i = cell_value
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func get_map_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell_value in explored_cells:
		cells.append(cell_value as Vector2i)
	return cells


func get_map_wall_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell_value in explored_cells:
		var cell := cell_value as Vector2i
		if wall_layer.get_cell_source_id(cell) != -1:
			cells.append(cell)
	return cells


func get_map_revision() -> int:
	return _exploration_map_revision


func get_visible_world_rect() -> Rect2:
	var physics_frame := Engine.get_physics_frames()
	if _visible_world_rect_frame == physics_frame:
		return _visible_world_rect
	_visible_world_rect_frame = physics_frame
	var viewport := get_viewport()
	if viewport == null:
		_visible_world_rect = Rect2()
		return _visible_world_rect
	var viewport_rect := viewport.get_visible_rect()
	var inverse_canvas := viewport.get_canvas_transform().affine_inverse()
	var corners := PackedVector2Array([
		inverse_canvas * viewport_rect.position,
		inverse_canvas * Vector2(viewport_rect.end.x, viewport_rect.position.y),
		inverse_canvas * viewport_rect.end,
		inverse_canvas * Vector2(viewport_rect.position.x, viewport_rect.end.y),
	])
	var minimum := corners[0]
	var maximum := corners[0]
	for corner in corners:
		minimum.x = minf(minimum.x, corner.x)
		minimum.y = minf(minimum.y, corner.y)
		maximum.x = maxf(maximum.x, corner.x)
		maximum.y = maxf(maximum.y, corner.y)
	_visible_world_rect = Rect2(minimum, maximum - minimum)
	return _visible_world_rect


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
	return [explored, campfires, second_campfire_tab_prompt_dismissed, map_show_enemies, map_show_buildings]


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
	_exploration_map_revision += 1
	second_campfire_tab_prompt_dismissed = bool(data[2]) if data.size() > 2 else false
	map_show_enemies = bool(data[3]) if data.size() > 3 else true
	map_show_buildings = true
	if is_instance_valid(_tab_prompt):
		_tab_prompt.visible = false
	_update_exploration()
	var map := get_node_or_null("HUD/WorldMap") as WorldMap
	if map and is_instance_valid(map._canvas):
		map._canvas.apply_saved_preferences()


func dismiss_second_campfire_tab_prompt() -> void:
	if not is_instance_valid(_tab_prompt) or not _tab_prompt.visible:
		return
	second_campfire_tab_prompt_dismissed = true
	_tab_prompt.hide()


func _create_tab_prompt() -> void:
	_tab_prompt = Label.new()
	_tab_prompt.name = "CampfireTabPrompt"
	_tab_prompt.text = "M/TAB to Teleport"
	_tab_prompt.position = Vector2(-24, -82)
	_tab_prompt.size = Vector2(48, 28)
	_tab_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_prompt.add_theme_font_size_override("font_size", 20)
	_tab_prompt.add_theme_color_override("font_color", Color("ffe082"))
	_tab_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_tab_prompt.add_theme_constant_override("outline_size", 4)
	_tab_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_prompt.z_index = 30
	_tab_prompt.visible = false
	player.add_child(_tab_prompt)


func _unhandled_input(event: InputEvent) -> void:
	var dungeon_manager := get_node_or_null("DungeonManager") as DungeonManager
	if dungeon_manager and dungeon_manager.is_dungeon_active():
		return
	if interaction_locked:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_interactable := _get_world_interactable_at(get_global_mouse_position())
		if clicked_interactable:
			_hide_ore_build_buttons()
			clicked_interactable.call("request_interaction", player, self)
			return
		var clicked_character := _get_story_character_at_position(get_global_mouse_position())
		if clicked_character:
			_hide_ore_build_buttons()
			clicked_character.request_interaction(player, self)
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


func _get_world_interactable_at(world_position: Vector2) -> Node2D:
	var closest: Node2D
	var closest_distance := 38.0
	for node in get_tree().get_nodes_in_group("world_interactables"):
		if not node is Node2D or not is_instance_valid(node) or not belongs_to_world(node):
			continue
		var distance := (node as Node2D).global_position.distance_to(world_position)
		if distance <= closest_distance:
			closest = node as Node2D
			closest_distance = distance
	return closest


func _get_shopkeeper_at_position(world_position: Vector2) -> FoxAsha:
	for shopkeeper in get_tree().get_nodes_in_group("shopkeepers"):
		if shopkeeper is FoxAsha and is_instance_valid(shopkeeper) and shopkeeper.global_position.distance_to(world_position) <= 30.0:
			return shopkeeper
	return null


func _get_story_character_at_position(world_position: Vector2) -> Node2D:
	for character in get_tree().get_nodes_in_group("story_characters"):
		if character is Node2D and is_instance_valid(character) \
			and (not character.has_method("is_story_interactable") or bool(character.call("is_story_interactable"))) \
			and character.global_position.distance_to(world_position) <= 32.0:
			return character
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
		if ore is GoldOre and is_instance_valid(ore) and belongs_to_world(ore):
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
	var occupied := get_occupied_cells(moving_actor)
	return _center_and_compress(_find_cell_path(start, goal, occupied))


func find_path_to_actor_adjacent(from_world: Vector2, target_actor: Node2D, moving_actor: Node2D = null, occupied_snapshot: Variant = null) -> PackedVector2Array:
	if not is_instance_valid(target_actor) or not belongs_to_world(target_actor):
		return PackedVector2Array()
	var start := world_to_cell(from_world)
	var goal := world_to_cell(target_actor.global_position)
	var occupied: Dictionary = occupied_snapshot if occupied_snapshot is Dictionary else get_occupied_cells(moving_actor)
	var cell_path := _find_cell_path(start, goal, occupied, true)
	if cell_path.size() <= 1:
		return PackedVector2Array()
	cell_path.remove_at(cell_path.size() - 1)
	return _center_and_compress(cell_path)


func try_consume_path_request() -> bool:
	_reset_path_request_budget()
	if _path_requests_used >= PATH_REQUEST_BUDGET_PER_FRAME:
		return false
	_path_requests_used += 1
	return true


func get_path_requests_used() -> int:
	_reset_path_request_budget()
	return _path_requests_used


func _reset_path_request_budget() -> void:
	var physics_frame := Engine.get_physics_frames()
	if _path_budget_frame == physics_frame:
		return
	_path_budget_frame = physics_frame
	_path_requests_used = 0


func _find_cell_path(start: Vector2i, goal: Vector2i, occupied: Dictionary, allow_occupied_goal := false) -> Array[Vector2i]:
	if not is_walkable(start) or not is_walkable(goal):
		return []
	# The mover's starting tile must remain usable even if a structure was built
	# under it. Actor-approach routes may likewise permit the occupied goal, then
	# remove that final cell before returning their movement path.
	if occupied.has(goal) and goal != start and not allow_occupied_goal:
		return []
	var blocked_pathfinder_cells: Array[Vector2i] = []
	for raw_cell in occupied:
		var cell := raw_cell as Vector2i
		if cell == start or allow_occupied_goal and cell == goal:
			continue
		# Dungeon snapshots can restore enemies in rooms that are not part of the
		# currently active navigation rectangle. They still count as occupied in
		# the world, but must not be submitted to this room's AStar grid.
		if not _pathfinder.region.has_point(cell):
			continue
		_pathfinder.set_point_solid(cell, true)
		blocked_pathfinder_cells.append(cell)
	var result := _pathfinder.get_id_path(start, goal)
	for cell in blocked_pathfinder_cells:
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
	var candidates := get_patrol_destinations(home_cell, radius_tiles, moving_actor)
	return candidates[0] if not candidates.is_empty() else home_cell


func get_patrol_destinations(home_cell: Vector2i, radius_tiles: int, moving_actor: Node2D = null) -> Array[Vector2i]:
	var cache_key := Vector3i(home_cell.x, home_cell.y, radius_tiles)
	if not _patrol_destination_cache.has(cache_key):
		var cached_candidates: Array[Vector2i] = []
		for y in range(home_cell.y - radius_tiles, home_cell.y + radius_tiles + 1):
			for x in range(home_cell.x - radius_tiles, home_cell.x + radius_tiles + 1):
				var candidate := Vector2i(x, y)
				var offset := candidate - home_cell
				if offset.length_squared() <= radius_tiles * radius_tiles and is_walkable(candidate) and not is_gold_ore_cell(candidate):
					cached_candidates.append(candidate)
		_patrol_destination_cache[cache_key] = cached_candidates
	var candidates: Array[Vector2i] = []
	for candidate: Vector2i in _patrol_destination_cache[cache_key]:
		if moving_actor != null and _is_cached_actor_cell_occupied(candidate, moving_actor):
			continue
		if moving_actor is ChickenEnemy and is_enemy_target_conflicted(moving_actor as ChickenEnemy, candidate):
			continue
		candidates.append(candidate)
	candidates.shuffle()
	return candidates


func is_walkable(cell: Vector2i) -> bool:
	return _walkable_cells.has(cell) and not _pathfinder.is_point_solid(cell)


func is_cell_occupied(cell: Vector2i, except_actor: Node2D = null) -> bool:
	if except_actor == null:
		return _is_cached_actor_cell_occupied(cell)
	return _is_actor_cell_occupied(cell, except_actor)


func get_occupied_cells(except_actor: Node2D = null) -> Dictionary:
	if is_instance_valid(except_actor):
		sync_navigation_actor(except_actor)
	_refresh_actor_cache()
	var physics_frame := Engine.get_physics_frames()
	if _occupied_snapshot_frame != physics_frame:
		_occupied_snapshot_frame = physics_frame
		_occupied_snapshots_by_actor.clear()
	var snapshot_key := except_actor.get_instance_id() if is_instance_valid(except_actor) else 0
	if _occupied_snapshots_by_actor.has(snapshot_key):
		return _occupied_snapshots_by_actor[snapshot_key] as Dictionary
	var occupied := _cached_all_occupied_cells.duplicate()
	if except_actor == null:
		_occupied_snapshots_by_actor[snapshot_key] = occupied
		return occupied
	var excluded_ids := {except_actor.get_instance_id(): true}
	for actor_value in _overlap_navigation_actors.values():
		var actor := actor_value as Node2D
		if is_instance_valid(actor) and _actors_can_overlap(except_actor, actor):
			excluded_ids[actor.get_instance_id()] = true
	var affected_cells := {}
	for actor_id_value in excluded_ids:
		var actor_id := int(actor_id_value)
		for cell_value in _actor_cells_by_id.get(actor_id, []):
			affected_cells[cell_value as Vector2i] = true
	for cell_value in affected_cells:
		var cell := cell_value as Vector2i
		var remains_blocked := false
		for actor_value in _cached_actors_by_cell.get(cell, []):
			var actor := actor_value as Node2D
			if is_instance_valid(actor) and not excluded_ids.has(actor.get_instance_id()):
				remains_blocked = true
				break
		if not remains_blocked:
			occupied.erase(cell)
	_occupied_snapshots_by_actor[snapshot_key] = occupied
	return occupied


func _get_actor_cells(actor: Node2D) -> Array[Vector2i]:
	if actor.has_method("get_blocked_cells"):
		return actor.call("get_blocked_cells", self) as Array[Vector2i]
	return [world_to_cell(actor.global_position)]


func can_enter_position(actor: Node2D, world_position: Vector2) -> bool:
	var cell := world_to_cell(world_position)
	var current_cell := world_to_cell(actor.global_position)
	if cell == current_cell:
		# A structure may be built beneath an actor. Let it cross its current tile
		# so it can reach the unoccupied destination chosen by pathfinding.
		return is_walkable(cell)
	return is_walkable(cell) and not _is_actor_cell_occupied(cell, actor) and not is_gold_ore_cell(cell)


func _is_actor_cell_occupied(cell: Vector2i, moving_actor: Node2D) -> bool:
	_refresh_actor_cache()
	for actor_value in _cached_actors_by_cell.get(cell, []):
		var other := actor_value as Node2D
		if other != moving_actor and is_instance_valid(other) and not _actors_can_overlap(moving_actor, other):
			return true
	return false


func _actors_can_overlap(first: Node2D, second: Node2D) -> bool:
	if not is_instance_valid(first) or not is_instance_valid(second):
		return false
	return first.has_method("can_overlap_navigation_actor") \
		and bool(first.call("can_overlap_navigation_actor", second)) \
		or second.has_method("can_overlap_navigation_actor") \
		and bool(second.call("can_overlap_navigation_actor", first))


func is_gold_ore_cell(cell: Vector2i) -> bool:
	return _cell_has_navigation_group(cell, &"gold_ores")


func is_building_cell(cell: Vector2i) -> bool:
	return _cell_has_navigation_group(cell, &"buildings")


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
	return _cell_has_navigation_group(cell, &"npcs")


func is_gate_cell(cell: Vector2i) -> bool:
	return _cell_has_navigation_group(cell, &"gates")


func _cell_has_navigation_group(cell: Vector2i, group_name: StringName) -> bool:
	_refresh_actor_cache()
	for actor_value in _cached_actors_by_cell.get(cell, []):
		var actor := actor_value as Node2D
		if is_instance_valid(actor) and actor.is_in_group(group_name):
			return true
	return false


func is_enemy_target_conflicted(actor: ChickenEnemy, target_cell: Vector2i) -> bool:
	_refresh_actor_cache()
	var actor_id := actor.get_instance_id()
	var occupied_count := int(_cached_actor_counts.get(target_cell, 0))
	if occupied_count > 1:
		return true
	if occupied_count == 1 and int(_cached_actor_single_ids.get(target_cell, -1)) != actor_id:
		return true
	return int(_cached_enemy_target_min_ids.get(target_cell, actor_id)) < actor_id


func get_cached_adjacent_enemy(actor: Node2D) -> ChickenEnemy:
	_refresh_actor_cache()
	var actor_cell := world_to_cell(actor.global_position)
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var enemies_at_cell: Array = _cached_enemies_by_cell.get(actor_cell + offset, [])
		for enemy_value in enemies_at_cell:
			var enemy := enemy_value as ChickenEnemy
			if is_instance_valid(enemy) and enemy.health > 0:
				return enemy
	return null


func _is_cached_actor_cell_occupied(cell: Vector2i, except_actor: Node2D = null) -> bool:
	_refresh_actor_cache()
	var count := int(_cached_actor_counts.get(cell, 0))
	if count <= 0:
		return false
	if except_actor == null:
		return true
	return _is_actor_cell_occupied(cell, except_actor)


func _refresh_actor_cache() -> void:
	var physics_frame := Engine.get_physics_frames()
	if _actor_cache_frame == physics_frame:
		return
	_actor_cache_frame = physics_frame
	_cached_enemy_target_min_ids.clear()
	if _navigation_actors.is_empty() or physics_frame - _actor_reconcile_frame >= ACTOR_RECONCILE_INTERVAL_FRAMES:
		_reconcile_navigation_actors()
	for actor_id_value in _navigation_enemies.keys():
		var actor_id := int(actor_id_value)
		var actor := _navigation_enemies.get(actor_id) as ChickenEnemy
		if not is_instance_valid(actor):
			_unregister_navigation_actor_id(actor_id)
			continue
		var actor_cells: Array = _actor_cells_by_id.get(actor_id, [])
		if actor_cells.is_empty():
			continue
		var enemy_cell := actor_cells[0] as Vector2i
		var target_cell := actor.get_movement_target_cell(self, enemy_cell)
		var previous_id := int(_cached_enemy_target_min_ids.get(target_cell, actor_id))
		_cached_enemy_target_min_ids[target_cell] = mini(previous_id, actor_id)


func _initialize_navigation_runtime() -> void:
	var added_callable := Callable(self, "_on_tree_node_added")
	if not get_tree().node_added.is_connected(added_callable):
		get_tree().node_added.connect(added_callable)
	var removed_callable := Callable(self, "_on_tree_node_removed")
	if not get_tree().node_removed.is_connected(removed_callable):
		get_tree().node_removed.connect(removed_callable)
	_reconcile_navigation_actors()


func _on_tree_node_added(node: Node) -> void:
	# Groups are commonly assigned during a Node2D's _ready(), after node_added.
	# Register authored groups immediately, then defer once for scripts that add
	# their group in _ready(). Restricting this to Node2D keeps UI construction
	# from producing a large deferred-call queue.
	if node is Node2D:
		_try_register_navigation_actor(node)
		call_deferred("_try_register_navigation_actor_id", node.get_instance_id())


func _on_tree_node_removed(node: Node) -> void:
	if node is Node2D:
		_unregister_navigation_actor_id(node.get_instance_id())


func _try_register_navigation_actor(node: Node) -> void:
	if node is Node2D and is_instance_valid(node) and belongs_to_world(node) and _is_navigation_actor(node):
		_register_navigation_actor(node as Node2D)


func _try_register_navigation_actor_id(actor_id: int) -> void:
	var node := instance_from_id(actor_id)
	if node is Node2D:
		_try_register_navigation_actor(node)


func register_navigation_actor(actor: Node2D) -> void:
	if not is_instance_valid(floor_layer):
		call_deferred("register_navigation_actor", actor)
		return
	if is_instance_valid(actor) and belongs_to_world(actor) and _is_navigation_actor(actor):
		_register_navigation_actor(actor)


func unregister_navigation_actor(actor: Node2D) -> void:
	if actor != null:
		_unregister_navigation_actor_id(actor.get_instance_id())


func refresh_navigation_actor_membership(actor: Node2D) -> void:
	if not is_instance_valid(floor_layer):
		call_deferred("refresh_navigation_actor_membership", actor)
		return
	if is_instance_valid(actor) and belongs_to_world(actor) and _is_navigation_actor(actor):
		_register_navigation_actor(actor)
	elif actor != null:
		_unregister_navigation_actor_id(actor.get_instance_id())


func update_navigation_actor(actor: Node2D) -> void:
	if not is_instance_valid(floor_layer):
		call_deferred("update_navigation_actor", actor)
		return
	if not is_instance_valid(actor):
		return
	if not _navigation_actors.has(actor.get_instance_id()):
		register_navigation_actor(actor)
	else:
		_update_navigation_actor_cells(actor)


func sync_navigation_actor(actor: Node2D) -> void:
	if not is_instance_valid(floor_layer):
		call_deferred("sync_navigation_actor", actor)
		return
	if not is_instance_valid(actor):
		return
	var actor_id := actor.get_instance_id()
	if not _navigation_actors.has(actor_id):
		register_navigation_actor(actor)
		return
	# Continuously moving navigation actors occupy one tile. Compare that tile
	# first so walking within it does not rebuild their occupied-cell list.
	if not actor.has_method("get_blocked_cells"):
		var old_cells: Array = _actor_cells_by_id.get(actor_id, [])
		if old_cells.size() == 1 and old_cells[0] == world_to_cell(actor.global_position):
			return
	_update_navigation_actor_cells(actor)


func _reconcile_navigation_actors() -> void:
	_actor_reconcile_frame = Engine.get_physics_frames()
	var discovered_ids := {}
	for group_name in NAVIGATION_ACTOR_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			if node is Node2D and is_instance_valid(node) and belongs_to_world(node):
				discovered_ids[node.get_instance_id()] = true
				_register_navigation_actor(node as Node2D)
	for actor_id_value in _navigation_actors.keys():
		if not discovered_ids.has(actor_id_value):
			_unregister_navigation_actor_id(int(actor_id_value))


func _is_navigation_actor(actor: Node2D) -> bool:
	for group_name in NAVIGATION_ACTOR_GROUPS:
		if actor.is_in_group(group_name):
			return true
	return false


func _register_navigation_actor(actor: Node2D) -> void:
	var actor_id := actor.get_instance_id()
	_navigation_actors[actor_id] = actor
	if actor is ChickenEnemy:
		_navigation_enemies[actor_id] = actor
	if actor.has_method("can_overlap_navigation_actor"):
		_overlap_navigation_actors[actor_id] = actor
	_update_navigation_actor_cells(actor)


func _unregister_navigation_actor_id(actor_id: int) -> void:
	if not _navigation_actors.has(actor_id):
		return
	_occupied_snapshots_by_actor.clear()
	var actor := _navigation_actors.get(actor_id) as Node2D
	for cell_value in _actor_cells_by_id.get(actor_id, []):
		_remove_navigation_actor_from_cell(actor, actor_id, cell_value as Vector2i)
	_navigation_actors.erase(actor_id)
	_navigation_enemies.erase(actor_id)
	_actor_cells_by_id.erase(actor_id)
	_overlap_navigation_actors.erase(actor_id)


func _update_navigation_actor_cells(actor: Node2D) -> void:
	var actor_id := actor.get_instance_id()
	var new_cells := _get_actor_cells(actor)
	var old_cells: Array = _actor_cells_by_id.get(actor_id, [])
	if old_cells == new_cells:
		return
	_occupied_snapshots_by_actor.clear()
	for cell_value in old_cells:
		_remove_navigation_actor_from_cell(actor, actor_id, cell_value as Vector2i)
	_actor_cells_by_id[actor_id] = new_cells
	for cell in new_cells:
		_add_navigation_actor_to_cell(actor, cell)


func _add_navigation_actor_to_cell(actor: Node2D, cell: Vector2i) -> void:
	var actors_at_cell: Array = _cached_actors_by_cell.get(cell, [])
	if not actors_at_cell.has(actor):
		actors_at_cell.append(actor)
	_cached_actors_by_cell[cell] = actors_at_cell
	_rebuild_navigation_cell_summary(cell, actors_at_cell)


func _remove_navigation_actor_from_cell(actor: Node2D, actor_id: int, cell: Vector2i) -> void:
	var actors_at_cell: Array = _cached_actors_by_cell.get(cell, [])
	for index in range(actors_at_cell.size() - 1, -1, -1):
		var existing := actors_at_cell[index] as Node2D
		if not is_instance_valid(existing) or existing == actor or existing.get_instance_id() == actor_id:
			actors_at_cell.remove_at(index)
	if actors_at_cell.is_empty():
		_cached_actors_by_cell.erase(cell)
		_cached_actor_counts.erase(cell)
		_cached_actor_single_ids.erase(cell)
		_cached_enemies_by_cell.erase(cell)
		_cached_all_occupied_cells.erase(cell)
	else:
		_cached_actors_by_cell[cell] = actors_at_cell
		_rebuild_navigation_cell_summary(cell, actors_at_cell)


func _rebuild_navigation_cell_summary(cell: Vector2i, actors_at_cell: Array) -> void:
	_cached_actor_counts[cell] = actors_at_cell.size()
	_cached_actor_single_ids[cell] = (actors_at_cell[0] as Node2D).get_instance_id() if actors_at_cell.size() == 1 else -1
	_cached_all_occupied_cells[cell] = true
	var enemies: Array = []
	for actor_value in actors_at_cell:
		if actor_value is ChickenEnemy:
			enemies.append(actor_value)
	if enemies.is_empty():
		_cached_enemies_by_cell.erase(cell)
	else:
		_cached_enemies_by_cell[cell] = enemies


func _ensure_player_flow_field() -> void:
	if not is_instance_valid(player) or not belongs_to_world(player):
		_player_flow_distances.clear()
		return
	var goal := world_to_cell(player.global_position)
	if goal == _player_flow_goal_cell and _player_flow_navigation_revision == _navigation_revision:
		return
	_player_flow_goal_cell = goal
	_player_flow_navigation_revision = _navigation_revision
	_player_flow_distances.clear()
	if not is_walkable(goal):
		return
	var frontier: Array[Vector2i] = [goal]
	var frontier_index := 0
	_player_flow_distances[goal] = 0
	while frontier_index < frontier.size():
		var cell := frontier[frontier_index]
		frontier_index += 1
		var distance := int(_player_flow_distances[cell])
		if distance >= FLOW_FIELD_RADIUS_TILES:
			continue
		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if _player_flow_distances.has(neighbor) or not _is_static_walkable(neighbor):
				continue
			_player_flow_distances[neighbor] = distance + 1
			frontier.append(neighbor)


func get_flow_path_to_player_adjacent(from_world: Vector2, moving_actor: Node2D = null, occupied_snapshot: Variant = null) -> PackedVector2Array:
	_ensure_player_flow_field()
	var start := world_to_cell(from_world)
	if not _player_flow_distances.has(start):
		return PackedVector2Array()
	var occupied: Dictionary = occupied_snapshot if occupied_snapshot is Dictionary else get_occupied_cells(moving_actor)
	var cell_path: Array[Vector2i] = [start]
	var current := start
	while int(_player_flow_distances.get(current, FLOW_FIELD_RADIUS_TILES + 1)) > 1:
		var current_distance := int(_player_flow_distances[current])
		var next_cell := current
		for direction in CARDINAL_DIRECTIONS:
			var candidate: Vector2i = current + direction
			if int(_player_flow_distances.get(candidate, current_distance + 1)) >= current_distance:
				continue
			if occupied.has(candidate):
				continue
			if cell_path.size() == 1 and moving_actor is ChickenEnemy and is_enemy_target_conflicted(moving_actor as ChickenEnemy, candidate):
				continue
			next_cell = candidate
			break
		if next_cell == current:
			return PackedVector2Array()
		cell_path.append(next_cell)
		current = next_cell
	return _center_cell_path(cell_path)


func _center_cell_path(cell_path: Array[Vector2i]) -> PackedVector2Array:
	var result := PackedVector2Array()
	for cell in cell_path:
		result.append(cell_to_world(cell))
	return result


func _is_static_walkable(cell: Vector2i) -> bool:
	return _walkable_cells.has(cell) and (not is_instance_valid(wall_layer) or wall_layer.get_cell_source_id(cell) == -1)


func _navigation_changed() -> void:
	_navigation_revision += 1
	_patrol_destination_cache.clear()
	_player_flow_navigation_revision = -1


func are_adjacent(first: Node2D, second: Node2D) -> bool:
	var offset := world_to_cell(first.global_position) - world_to_cell(second.global_position)
	return absi(offset.x) + absi(offset.y) == 1


func belongs_to_world(actor: Node) -> bool:
	if actor == null:
		return false
	var cursor := actor.get_parent()
	while cursor:
		if cursor is WorldNavigation:
			return cursor == self
		cursor = cursor.get_parent()
	return self == get_tree().current_scene


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := floor_layer.to_local(world_position)
	return Vector2i(floori(local_position.x / TILE_SIZE), floori(local_position.y / TILE_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return floor_layer.to_global(Vector2(cell * TILE_SIZE) + Vector2.ONE * (TILE_SIZE * 0.5))


func center_stationary_combatants(first: Node2D, second: Node2D) -> bool:
	var first_ready := _center_actor_if_stationary(first)
	var second_ready := _center_actor_if_stationary(second)
	return first_ready and second_ready


func center_stationary_actor(actor: Node2D) -> bool:
	return _center_actor_if_stationary(actor)


func cancel_combatant_tile_lerps(first: Node2D, second: Node2D) -> void:
	_cancel_actor_tile_lerp(first)
	_cancel_actor_tile_lerp(second)


func _center_actor_if_stationary(actor: Node2D) -> bool:
	if not _is_actor_stationary(actor):
		_cancel_actor_tile_lerp(actor)
		return true
	return _lerp_actor_to_intended_tile(actor)


func _is_actor_stationary(actor: Node2D) -> bool:
	if not is_instance_valid(actor):
		return false
	if actor.has_method("is_moving") and bool(actor.call("is_moving")):
		return false
	return not actor is CharacterBody2D or (actor as CharacterBody2D).velocity.length_squared() <= 1.0


func _lerp_actor_to_intended_tile(actor: Node2D) -> bool:
	if not is_instance_valid(actor):
		return false
	var intended_position := cell_to_world(world_to_cell(actor.global_position))
	if actor.global_position.distance_squared_to(intended_position) <= 0.25:
		actor.global_position = intended_position
		sync_navigation_actor(actor)
		_clear_combat_alignment(actor)
		return true
	if actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity = Vector2.ZERO
	var existing_tween := actor.get_meta(COMBAT_ALIGNMENT_TWEEN_META) as Tween \
		if actor.has_meta(COMBAT_ALIGNMENT_TWEEN_META) else null
	var existing_target: Vector2 = actor.get_meta(COMBAT_ALIGNMENT_TARGET_META) \
		if actor.has_meta(COMBAT_ALIGNMENT_TARGET_META) else Vector2(INF, INF)
	if existing_tween and existing_tween.is_valid() and existing_tween.is_running() \
		and existing_target.is_equal_approx(intended_position):
		return false
	if existing_tween and existing_tween.is_valid():
		existing_tween.kill()
	var alignment_tween := actor.create_tween()
	alignment_tween.tween_property(actor, "global_position", intended_position, COMBAT_TILE_LERP_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	alignment_tween.tween_callback(Callable(self, "sync_navigation_actor").bind(actor))
	actor.set_meta(COMBAT_ALIGNMENT_TWEEN_META, alignment_tween)
	actor.set_meta(COMBAT_ALIGNMENT_TARGET_META, intended_position)
	return false


func _cancel_actor_tile_lerp(actor: Node2D) -> void:
	if not is_instance_valid(actor) or not actor.has_meta(COMBAT_ALIGNMENT_TWEEN_META):
		return
	var existing_tween := actor.get_meta(COMBAT_ALIGNMENT_TWEEN_META) as Tween
	if existing_tween and existing_tween.is_valid() and existing_tween.is_running():
		existing_tween.kill()
	actor.remove_meta(COMBAT_ALIGNMENT_TWEEN_META)
	if actor.has_meta(COMBAT_ALIGNMENT_TARGET_META):
		actor.remove_meta(COMBAT_ALIGNMENT_TARGET_META)


func _clear_combat_alignment(actor: Node2D) -> void:
	var existing_tween := actor.get_meta(COMBAT_ALIGNMENT_TWEEN_META) as Tween \
		if actor.has_meta(COMBAT_ALIGNMENT_TWEEN_META) else null
	if existing_tween and existing_tween.is_valid() and existing_tween.is_running():
		existing_tween.kill()
	if actor.has_meta(COMBAT_ALIGNMENT_TWEEN_META):
		actor.remove_meta(COMBAT_ALIGNMENT_TWEEN_META)
	if actor.has_meta(COMBAT_ALIGNMENT_TARGET_META):
		actor.remove_meta(COMBAT_ALIGNMENT_TARGET_META)


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
	_navigation_changed()


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
