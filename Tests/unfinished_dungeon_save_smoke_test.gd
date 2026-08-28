extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := await _make_world()
	var manager := world.get_node("DungeonManager") as DungeonManager
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var entrance := world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	var overworld_position := world.player.global_position
	var overworld_max_health := world.player.max_health
	manager.tutorial_seen = true
	await manager._begin_entry(entrance)
	var level := manager.get_active_level()
	world.player.add_max_health(2)
	manager.add_key(2)
	var chest := level.get_node("KeyChest") as DungeonChest
	chest.load_opened(true)
	var spawn := level.get_node("EntryGuard") as EnemySpawnPoint
	var enemy := spawn.get_active_enemies()[0]
	enemy.health = 1
	var saved_dungeon_position := world.player.global_position
	for candidate in level.floor_layer.get_used_cells():
		if level.cell_to_room(candidate) == level.current_room and level.is_walkable(candidate) \
				and not level.is_cell_occupied(candidate, world.player) \
				and candidate.distance_squared_to(level.world_to_cell(world.player.global_position)) >= 4:
			saved_dungeon_position = level.cell_to_world(candidate)
			break
	world.player.global_position = saved_dungeon_position
	var pickup := load("res://Scenes/item_pickup.tscn").instantiate() as ItemPickup
	pickup.setup("weathered_sword", 2)
	pickup.global_position = level.cell_to_world(level._get_entry_spawn_cell() + Vector2i.DOWN)
	level.add_child(pickup)
	await process_frame
	saved_dungeon_position = world.player.global_position

	var encoded := save_system.create_save_string(1000)
	var decoded := save_system._decode_state(encoded)
	var saved_player := decoded[2] as Array
	assert(Vector2(float(saved_player[0]), float(saved_player[1])) == overworld_position and int(saved_player[3]) == overworld_max_health, "A live dungeon save must load Mira back into the overworld with her overworld stats")
	var saved_dungeons := (decoded[15] as Array)[1] as Dictionary
	var saved_state := saved_dungeons[str(entrance.dungeon_id)] as Dictionary
	var saved_level := saved_state.get("level", {}) as Dictionary
	var saved_position_data := saved_level.get("player_position", []) as Array
	assert(saved_position_data.size() >= 2 and Vector2(float(saved_position_data[0]), float(saved_position_data[1])) == saved_dungeon_position, "A live dungeon snapshot must include Mira's dungeon position")
	assert(int((saved_state.get("stats", {}) as Dictionary).get("max_health", 0)) == 12 and int(saved_state.get("keys", 0)) == 2, "A live dungeon save must retain temporary stats and keys")
	assert(bool((saved_level.get("chests", {}) as Dictionary).get("KeyChest", false)) and (saved_level.get("pickups", []) as Array).size() == 1, "A live dungeon save must retain opened chests and ground equipment")
	assert(str((decoded[15] as Array)[4]) == str(entrance.dungeon_id), "A dungeon save must identify the active dungeon for direct loading")

	manager.add_key()
	world.player.add_max_health(5)
	assert(save_system.load_save_string(encoded, 1000), "A save slot must be loadable while its dungeon is active")
	await create_timer(0.7).timeout
	assert(manager.is_dungeon_active() and manager.get_active_dungeon_id() == entrance.dungeon_id, "Loading inside a dungeon must reopen the dungeon saved in that slot")
	assert(world.player.max_health == 12 and manager.get_key_count() == 2, "An in-dungeon load must restore temporary stats and keys")
	assert(world.player.global_position == saved_dungeon_position, "An in-dungeon load must restore Mira's saved dungeon position")
	level = manager.get_active_level()
	assert((level.get_node("KeyChest") as DungeonChest).opened, "An in-dungeon load must restore opened chests")
	var in_place_enemies := (level.get_node("EntryGuard") as EnemySpawnPoint).get_active_enemies()
	assert(in_place_enemies.size() == 1 and in_place_enemies[0].health == 1, "An in-dungeon load must restore enemy health")

	world.queue_free()
	await process_frame
	await process_frame
	world = await _make_world()
	manager = world.get_node("DungeonManager") as DungeonManager
	save_system = world.get_node("SaveSystem") as SaveSystem
	entrance = world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	assert(save_system.load_save_string(encoded, 1000), "The unfinished dungeon save file must load")
	await create_timer(0.7).timeout
	assert(manager.is_dungeon_active() and manager.get_active_dungeon_id() == entrance.dungeon_id, "Loading an unfinished dungeon save must resume that dungeon directly")
	level = manager.get_active_level()
	assert(world.player.max_health == 12 and manager.get_key_count() == 2, "Resuming must restore saved temporary stats and keys")
	assert(world.player.global_position == saved_dungeon_position, "Resuming in a new session must restore Mira's saved dungeon position")
	assert((level.get_node("KeyChest") as DungeonChest).opened, "Resuming must restore saved chest state")
	assert(level.get_tree().get_nodes_in_group("item_pickups").any(func(node: Node) -> bool: return node is ItemPickup and level.belongs_to_world(node) and (node as ItemPickup).grade == 2), "Resuming must restore saved dungeon pickups")
	var restored_enemies := (level.get_node("EntryGuard") as EnemySpawnPoint).get_active_enemies()
	assert(restored_enemies.size() == 1 and restored_enemies[0].health == 1, "Resuming must restore unfinished enemy health")

	print("PASS: live unfinished dungeon state saves and loads directly inside dungeons")
	world.queue_free()
	await process_frame
	await process_frame
	quit()


func _make_world() -> WorldNavigation:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	if dialogue.is_open():
		dialogue.cancel()
	return world
