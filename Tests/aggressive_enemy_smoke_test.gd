extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_world: PackedScene = load("res://Scenes/world.tscn")
	assert(packed_world != null, "World scene must load")
	var world := packed_world.instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED

	var fox := world.player
	var corridor_start := _find_open_corridor(world, 7)
	assert(corridor_start != Vector2i(-999999, -999999), "Test map must contain a seven-tile open corridor")
	fox.global_position = world.cell_to_world(corridor_start) + Vector2(3.0 * WorldNavigation.TILE_SIZE, 0.0)

	var spawn := world.get_node("ChickenSpawn2") as EnemySpawnPoint
	spawn.aggressive = true
	var enemy := spawn._create_enemy(world, world.cell_to_world(corridor_start), corridor_start)
	assert(enemy.aggressive, "A spawn point must pass its exported aggressive toggle to new enemies")

	enemy._movement_mode = ChickenEnemy.MovementMode.PATROL
	enemy._was_in_combat = false
	enemy._update_behavior_state(false)
	assert(enemy._movement_mode == ChickenEnemy.MovementMode.CHASE, "An aggressive enemy must notice a player at the edge of its three-tile radius")
	enemy._choose_player_adjacent_path(world.world_to_cell(fox.global_position))
	assert(not enemy._path.is_empty(), "An aggressive enemy must find a route beside the player")
	var route_end := world.world_to_cell(enemy._path[-1])
	var route_offset := route_end - world.world_to_cell(fox.global_position)
	assert(absi(route_offset.x) + absi(route_offset.y) == 1, "Aggressive routes must end on a cardinally adjacent player tile")

	enemy.global_position = world.cell_to_world(corridor_start + Vector2i(2, 0))
	enemy._update_behavior_state(true)
	enemy._was_in_combat = true
	fox.global_position = world.cell_to_world(corridor_start + Vector2i(6, 0))
	enemy._update_behavior_state(false)
	assert(enemy._pursuit_is_limited and enemy._pursuit_tiles_left == 3, "Disengaging must begin a three-tile pursuit")
	enemy.global_position = world.cell_to_world(corridor_start + Vector2i(4, 0))
	enemy._record_pursuit_progress(3.0 * WorldNavigation.TILE_SIZE)
	assert(enemy._movement_mode == ChickenEnemy.MovementMode.RETURN_HOME, "The enemy must return home after following for three tiles")

	enemy.aggressive = false
	enemy._movement_mode = ChickenEnemy.MovementMode.PATROL
	enemy._was_in_combat = true
	enemy._update_behavior_state(false)
	assert(enemy._movement_mode == ChickenEnemy.MovementMode.CHASE, "Non-aggressive enemies must also follow after combat disengages")
	assert(enemy._pursuit_is_limited and enemy._pursuit_tiles_left == 3, "Every enemy must receive the three-tile disengagement allowance")

	enemy._pursuit_tiles_left = 0
	enemy._pursuit_distance_left = 0.0
	enemy.take_damage(1)
	assert(enemy._movement_mode == ChickenEnemy.MovementMode.CHASE, "Taking damage must restart pursuit for every enemy")
	assert(enemy._pursuit_is_limited and enemy._pursuit_tiles_left == 3, "Taking damage must reset every enemy's three-tile allowance")

	print("PASS: aggressive detection and universal enemy pursuit, reset, and return work")
	world.queue_free()
	await process_frame
	quit()


func _find_open_corridor(world: WorldNavigation, length: int) -> Vector2i:
	for start in world.floor_layer.get_used_cells():
		var is_open := true
		for offset in range(length):
			var cell := start + Vector2i(offset, 0)
			if not world.is_walkable(cell) or world.is_cell_occupied(cell) or world.is_gold_ore_cell(cell):
				is_open = false
				break
		if is_open:
			return start
	return Vector2i(-999999, -999999)
