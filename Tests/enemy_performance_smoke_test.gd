extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	while dialogue.is_open():
		dialogue.finish_typing()
		dialogue.advance()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var enemies: Array[ChickenEnemy] = []
	for node in get_nodes_in_group("enemies"):
		if node is ChickenEnemy:
			enemies.append(node)
	assert(enemies.size() >= 2, "The performance world must contain at least two enemies")
	var occupied := world.get_occupied_cells()
	var reserved := {}
	for enemy in enemies:
		reserved[enemy.get_movement_target_cell(world)] = true
	var target_cell := Vector2i(-999999, -999999)
	for cell in world.floor_layer.get_used_cells():
		if world.is_walkable(cell) and not occupied.has(cell) and not reserved.has(cell):
			target_cell = cell
			break
	assert(target_cell.x > -999999, "The performance test needs one unreserved floor tile")
	var first := enemies[0]
	var second := enemies[1]
	var lower := first if first.get_instance_id() < second.get_instance_id() else second
	var higher := second if lower == first else first
	lower._path = PackedVector2Array([world.cell_to_world(target_cell)])
	lower._path_index = 0
	higher._path = PackedVector2Array([world.cell_to_world(target_cell)])
	higher._path_index = 0
	world._actor_cache_frame = -1
	world._refresh_actor_cache()
	assert(not world.is_enemy_target_conflicted(lower, target_cell), "The lowest-id enemy must retain a shared reserved target")
	assert(world.is_enemy_target_conflicted(higher, target_cell), "The higher-id enemy must yield a shared reserved target")
	assert(not world.can_enter_position(first, second.global_position), "Cached occupancy must still prevent enemies from entering one another's cells")
	var player_cell := world.world_to_cell(world.player.global_position)
	first.global_position = world.cell_to_world(player_cell + Vector2i.RIGHT)
	world.update_navigation_actor(first)
	world._actor_cache_frame = -1
	assert(world.get_cached_adjacent_enemy(world.player) == first, "The per-frame enemy-cell cache must resolve player adjacency without a full enemy scan")
	var old_first_cell := world.world_to_cell(first.global_position)
	var moved_first_cell := target_cell
	if moved_first_cell == old_first_cell:
		for cell in world.floor_layer.get_used_cells():
			if cell != old_first_cell and world.is_walkable(cell) and not world.is_cell_occupied(cell):
				moved_first_cell = cell
				break
	assert(moved_first_cell != old_first_cell, "The performance test needs a second free cell for incremental movement")
	first.global_position = world.cell_to_world(moved_first_cell)
	world.update_navigation_actor(first)
	assert(not (world._cached_actors_by_cell.get(old_first_cell, []) as Array).has(first), "Incremental occupancy must release an actor's previous cell")
	assert((world._cached_actors_by_cell.get(moved_first_cell, []) as Array).has(first), "Incremental occupancy must index an actor's new cell without rebuilding every actor")
	var gate := world.get_tree().get_first_node_in_group("gates") as Gate
	assert(gate != null, "The performance world must contain a navigation gate")
	var gate_cell := world.world_to_cell(gate.global_position)
	assert((world._cached_actors_by_cell.get(gate_cell, []) as Array).has(gate), "A closed gate must be registered as a blocker")
	gate.set_unlocked(true)
	assert(not (world._cached_actors_by_cell.get(gate_cell, []) as Array).has(gate), "Opening a gate must remove its blocker immediately")
	gate.set_unlocked(false)
	assert((world._cached_actors_by_cell.get(gate_cell, []) as Array).has(gate), "Closing a gate must restore its blocker immediately")
	world._path_budget_frame = -1
	assert(world.try_consume_path_request(), "The first path request in a physics frame must be admitted")
	assert(world.try_consume_path_request(), "The second path request in a physics frame must be admitted")
	assert(not world.try_consume_path_request(), "The shared scheduler must cap expensive path requests per physics frame")
	assert(world.get_path_requests_used() == WorldNavigation.PATH_REQUEST_BUDGET_PER_FRAME, "The path budget counter must stop at its configured cap")
	world._ensure_player_flow_field()
	var flow_path := PackedVector2Array()
	var flow_start := Vector2i.ZERO
	var occupied_after_move := world.get_occupied_cells(first)
	for cell_value in world._player_flow_distances.keys():
		var cell := cell_value as Vector2i
		if int(world._player_flow_distances[cell]) < 3 or occupied_after_move.has(cell):
			continue
		var candidate := world.get_flow_path_to_player_adjacent(world.cell_to_world(cell), first)
		if candidate.size() > 1:
			flow_start = cell
			flow_path = candidate
			break
	assert(not flow_path.is_empty(), "Nearby enemies must be able to reuse the player's shared flow field")
	var flow_end := world.world_to_cell(flow_path[-1])
	assert(absi(flow_end.x - player_cell.x) + absi(flow_end.y - player_cell.y) == 1, "A shared flow route must stop beside the player")
	var direct_path := world.find_path_to_actor_adjacent(world.cell_to_world(flow_start), world.player, first)
	assert(not direct_path.is_empty(), "The single-search actor route must find a reachable adjacent endpoint")
	var direct_end := world.world_to_cell(direct_path[-1])
	assert(absi(direct_end.x - player_cell.x) + absi(direct_end.y - player_cell.y) == 1, "The single-search actor route must truncate before the occupied target cell")
	assert(ChickenEnemy.REPATH_DELAY_MIN >= 0.10 and ChickenEnemy.REPATH_DELAY_MAX <= 0.20, "Enemy replans must be staggered within the requested 100-200ms window")
	var distant_lod_enemy: ChickenEnemy = null
	for enemy in enemies:
		if is_instance_valid(enemy.spawn_point) and enemy.spawn_point.boss:
			continue
		distant_lod_enemy = enemy
		break
	assert(distant_lod_enemy != null, "The performance world must contain a non-boss enemy for screen-distance checks")
	distant_lod_enemy._movement_mode = ChickenEnemy.MovementMode.PATROL
	distant_lod_enemy._active_skill_slot = -1
	distant_lod_enemy._hunter_target = null
	var visible_world_rect := world.get_visible_world_rect()
	assert(visible_world_rect.size.x > 0.0 and visible_world_rect.size.y > 0.0, "The overworld viewport must provide a visible world rectangle")
	var screen_center := visible_world_rect.get_center()
	distant_lod_enemy.global_position = screen_center
	assert(not distant_lod_enemy._should_use_distant_ai_lod(), "An on-screen patrol enemy must retain full-rate movement")
	var full_rate_margin := ChickenEnemy.FULL_RATE_SCREEN_MARGIN_TILES * WorldNavigation.TILE_SIZE
	distant_lod_enemy.global_position = Vector2(visible_world_rect.position.x - full_rate_margin, screen_center.y)
	assert(not distant_lod_enemy._should_use_distant_ai_lod(), "A patrol enemy exactly six tiles beyond the screen must retain full-rate movement")
	distant_lod_enemy.global_position = Vector2(visible_world_rect.position.x - full_rate_margin - WorldNavigation.TILE_SIZE, screen_center.y)
	assert(distant_lod_enemy._should_use_distant_ai_lod(), "A patrol enemy beyond the six-tile screen margin must use batched AI updates")
	var started := Time.get_ticks_usec()
	for _index in range(20000):
		world.is_enemy_target_conflicted(higher, target_cell)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert(elapsed_ms < 250.0, "Cached conflict lookups must remain constant-time under a large enemy population")
	started = Time.get_ticks_usec()
	for _index in range(20000):
		world.get_cached_adjacent_enemy(world.player)
	var adjacency_elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert(adjacency_elapsed_ms < 250.0, "Cached adjacent-enemy lookups must remain constant-time under a large enemy population")
	started = Time.get_ticks_usec()
	for _index in range(1000):
		world.get_occupied_cells(first)
	var occupancy_elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert(occupancy_elapsed_ms < 250.0, "Occupied-cell snapshots must reuse the incremental spatial index")
	assert(Minimap.REDRAW_INTERVAL >= 0.1, "The minimap must not redraw every rendered frame")
	var minimap := world.get_node("HUD/Minimap") as Minimap
	minimap._world = world
	var map_rect := Rect2(Vector2(5, 5), minimap.size - Vector2(10, 10))
	minimap._update_map_transform(map_rect)
	var display_region := minimap._get_display_region()
	minimap._update_terrain_texture(display_region, world.world_to_cell(world.player.global_position))
	var terrain_texture := minimap._terrain_texture
	assert(terrain_texture != null and terrain_texture.get_size() == Vector2(display_region.size), "The minimap must collapse local terrain into one cell-sized cached texture")
	started = Time.get_ticks_usec()
	for _index in range(20000):
		minimap._update_terrain_texture(display_region, world.world_to_cell(world.player.global_position))
	var minimap_elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert(minimap._terrain_texture == terrain_texture, "Unchanged minimap terrain must reuse its existing texture")
	assert(minimap_elapsed_ms < 250.0, "Unchanged minimap redraws must skip rebuilding terrain")
	print("PASS: incremental occupancy, path budgets, shared flow routes, distant AI, and minimap caching work; conflict/adjacency/occupancy/terrain timings were %.2f/%.2f/%.2f/%.2f ms across %d enemies" % [elapsed_ms, adjacency_elapsed_ms, occupancy_elapsed_ms, minimap_elapsed_ms, enemies.size()])
	world.queue_free()
	await process_frame
	await process_frame
	quit()
