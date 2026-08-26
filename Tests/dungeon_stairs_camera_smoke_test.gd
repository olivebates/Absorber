extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_world := load("res://Scenes/world.tscn") as PackedScene
	assert(packed_world != null, "The world must load for the dungeon stairs and camera test")
	var world := packed_world.instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var manager := world.get_node("DungeonManager") as DungeonManager
	var entrance := world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	var original_camera := world.player.get_node("Camera2D") as Camera2D
	var original_parent := world.player.get_parent()
	manager.tutorial_seen = true
	await manager._begin_entry(entrance)
	assert(manager.is_dungeon_active(), "The configured dungeon must open")
	var level := manager.get_active_level()
	assert(original_camera.get_parent() == world, "The overworld camera must stay in the overworld while the dungeon is open")
	assert(original_camera.global_position != Vector2.ZERO, "The overworld camera must not fall back to the world origin")
	assert(level._camera != original_camera and level._camera.get_parent() == level, "The dungeon must use a separate fixed camera")
	var map_cells := level.get_map_cells()
	var map_walls := level.get_map_wall_cells()
	assert(map_cells.size() == level.room_size_tiles.x * level.room_size_tiles.y, "Only the current room may be visible on first dungeon entry")
	assert(not map_walls.is_empty(), "Authored walls in the visited room must be supplied to both dungeon maps")
	for wall_cell in map_walls:
		assert(level.cell_to_room(wall_cell) == level.current_room and level.wall_layer.get_cell_source_id(wall_cell) != -1, "Map wall data must contain only authored walls from visited rooms")
	var world_map := world.get_node("HUD/WorldMap") as WorldMap
	world_map.open()
	assert(world_map._canvas._floor_cells_cache.size() == map_cells.size() and world_map._canvas._terrain_revision == level.get_map_revision(), "Opening the dungeon map must reuse its visited-room terrain cache")
	var terrain_rebuilds := world_map._canvas._terrain_cache_rebuild_count
	world_map.close()
	world_map.open()
	assert(world_map._canvas._terrain_cache_rebuild_count == terrain_rebuilds, "Reopening an unchanged map must not rebuild its terrain cache")
	world_map.close()

	var stairs_scene := load("res://Scenes/dungeon_stairs.tscn") as PackedScene
	var stairs := stairs_scene.instantiate() as Node2D
	level.add_child(stairs)
	var player_cell := level.world_to_cell(world.player.global_position)
	var stairs_cell := player_cell + Vector2i.RIGHT
	for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var candidate := player_cell + offset
		if level.is_walkable(candidate):
			stairs_cell = candidate
			break
	stairs.global_position = level.cell_to_world(stairs_cell)
	var stairs_position := stairs.global_position
	var return_position := manager._overworld_position
	var original_sprite_scale := world.player.fox_sprite.scale
	assert(is_equal_approx(DungeonStairs.EXIT_TRANSITION_DELAY, 0.8) and is_equal_approx(DungeonStairs.TRAVERSE_DURATION, 1.2), "Stairs must start the exit transition after 0.8 seconds while walking upward for 1.2 seconds")
	stairs.call("request_interaction", world.player, level)
	stairs.call("_process", 0.0)
	assert(world.player.global_position.is_equal_approx(stairs_position + Vector2(22, 2)), "The stairs exit animation must begin twenty pixels above the sprite's bottom-right corner")
	await create_timer(0.55).timeout
	var halfway_position := world.player.global_position
	assert(manager.is_dungeon_active() and not manager.is_transitioning() and halfway_position.x < stairs_position.x + 22.0 and halfway_position.y < stairs_position.y + 2.0, "Mira must still be walking diagonally before the 0.8-second transition delay elapses")
	await create_timer(0.32).timeout
	assert(manager.is_dungeon_active() and manager.is_transitioning(), "The dungeon exit transition must begin after 0.8 seconds while the 1.2-second walk continues")
	var camera_reached_entrance := false
	for _poll in range(75):
		await create_timer(0.02).timeout
		if original_camera.global_position.distance_to(entrance.global_position) < 1.0:
			camera_reached_entrance = true
			break
	assert(camera_reached_entrance, "The hidden overworld camera must be positioned at the entrance before the dungeon transition reveals it")
	await create_timer(1.55).timeout
	assert(not manager.is_dungeon_active(), "Interacting with dungeon stairs must leave through the same manager flow as the map button")
	assert(world.player.get_parent() == original_parent and original_camera.get_parent() == world.player, "Leaving by stairs must restore Mira and her camera to the overworld")
	assert(world.player.global_position.is_equal_approx(return_position) and world.player.fox_sprite.scale.is_equal_approx(original_sprite_scale), "The reverse entrance animation must finish at the saved cave-adjacent position and restore Mira's scale")
	world_map.open()
	assert(world_map._canvas._terrain_cache_rebuild_count == terrain_rebuilds, "Returning to the overworld map must reuse its earlier terrain cache instead of causing another opening spike")
	world_map.close()
	world.queue_free()
	await process_frame
	await process_frame
	print("Dungeon stairs and camera smoke test passed")
	quit()
