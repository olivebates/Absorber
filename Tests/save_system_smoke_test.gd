extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var player := world.player
	var resource_manager := world.get_node("ResourceManager") as ResourceManager
	var ore := world.get_node("GoldOre") as GoldOre
	var gate := world.get_node("Gate") as Gate
	assert(save_system != null, "The world must own the save system")

	player.health = 1
	player.health_bar.value = player.health
	player._heal_time_left = 3.0
	player.add_color_damage(FoxPlayer.COLOR_RED, 4)
	assert(player.collect_item("weathered_sword"), "Save test needs a persistent equipment item")
	resource_manager.add_resource(&"gold_ore", 10.0)
	resource_manager.add_resource(&"jewels", 10.0)
	ore._try_build_mine()
	assert(is_instance_valid(ore._mine), "Save test needs a built mine")
	ore._mine.production_speed = 0.125
	resource_manager.register_producer(ore._mine, ore._mine.resource_id, ore._mine.production_speed)
	resource_manager.get_definition(&"wood").production_speed = 0.25

	var refill_spawn: EnemySpawnPoint
	for child in world.get_children():
		if child is EnemySpawnPoint and child.max_enemies >= 3:
			refill_spawn = child
			break
	assert(refill_spawn != null, "Save test needs a multi-enemy spawn")
	refill_spawn.clear_for_load()
	refill_spawn.respawn_time = 60.0
	refill_spawn._respawn_time_left = 60.0
	gate.set_unlocked(false)
	var campfire := world.get_node("Campfire") as Campfire
	player.global_position = campfire.global_position
	world._update_exploration()
	world.map_show_enemies = true
	world.map_show_buildings = true
	assert(world.is_campfire_visited(campfire), "The save test must begin with a visited campfire")
	var asha := world.get_node("FoxAsha") as FoxAsha
	var saved_asha_position := asha.global_position
	var location_spawn := world.get_node("ChickenSpawn2") as EnemySpawnPoint
	var location_enemy := location_spawn.get_active_enemies()[0]
	var saved_enemy_position := location_enemy.global_position
	for candidate in world.floor_layer.get_used_cells():
		if world.is_walkable(candidate) and not world.is_cell_occupied(candidate, location_enemy) \
			and Vector2(candidate - world.world_to_cell(location_spawn.global_position)).length() > 8.0:
			saved_enemy_position = world.cell_to_world(candidate)
			break
	location_enemy.global_position = saved_enemy_position

	var raw_json := JSON.stringify(save_system._capture_state(1000))
	var encoded := save_system.create_save_string(1000)
	assert(not encoded.is_empty() and encoded.length() < raw_json.length(), "The on-disk save string must be compressed")
	player.health = player.max_health
	player.damage_by_color[FoxPlayer.COLOR_RED][0] = 1
	player.equipped_weapons[0] = {}
	ore._mine.production_speed = 0.5
	resource_manager.register_producer(ore._mine, ore._mine.resource_id, ore._mine.production_speed)
	resource_manager.get_definition(&"wood").production_speed = 0.5
	world.explored_cells.clear()
	world.visited_campfires.clear()
	world.map_show_enemies = false
	world.map_show_buildings = false
	gate.set_unlocked(true)
	asha.global_position = saved_asha_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE
	var current_asha_position := asha.global_position
	assert(save_system.load_save_string(encoded, 1600), "A compact save string must decompress and load")
	await process_frame

	assert(player.health == player.max_health, "Ten offline minutes must finish player health recovery")
	assert(player.damage_by_color[FoxPlayer.COLOR_RED][0] == 5, "Damage progression must survive save/load")
	assert(str(player.equipped_weapons[0].get("item_id", "")) == "weathered_sword", "Equipment must survive save/load")
	assert(refill_spawn._spawned_enemies.size() == refill_spawn.max_enemies, "Repeated offline respawn intervals must fill a spawn to its cap")
	assert(is_equal_approx(refill_spawn._respawn_time_left, refill_spawn.respawn_time), "A spawn filled offline must restart at its full timer")
	assert(resource_manager.get_amount(&"gold_ore") >= 2, "Five-minute mines must produce resources during ten offline minutes")
	assert(is_instance_valid(ore._mine), "Built mines must survive save/load")
	assert(is_equal_approx(ore._mine.production_speed, 0.125), "A built producer's speed must survive save/load")
	assert(is_equal_approx(resource_manager.get_definition(&"wood").production_speed, 0.25), "Base resource production speeds must survive save/load")
	assert(not gate.unlocked and gate.visible and gate.is_in_group("gates"), "Loading an older slot must restore a locked gate")
	assert(world.is_campfire_visited(campfire), "Explored areas and visited campfires must survive save/load")
	assert(world.map_show_enemies and world.map_show_buildings, "Map overlay toggles must survive save/load")
	assert(asha.global_position == current_asha_position, "NPCs must remain at their current scene locations instead of loading saved coordinates")
	var loaded_location_enemies := location_spawn.get_active_enemies()
	assert(not loaded_location_enemies.is_empty(), "The saved enemy must be rebuilt at its current spawn")
	var loaded_enemy := loaded_location_enemies[0]
	var loaded_offset := world.world_to_cell(loaded_enemy.global_position) - world.world_to_cell(location_spawn.global_position)
	assert(loaded_enemy.global_position != saved_enemy_position and maxi(absi(loaded_offset.x), absi(loaded_offset.y)) <= EnemySpawnPoint.SPAWN_RADIUS_TILES, "Enemies must ignore saved coordinates and use the current spawn marker")
	var captured_spawns := save_system._capture_state(1000)[4] as Array
	assert(captured_spawns[0] is Array and captured_spawns[0][0] is String, "Enemy spawn saves must be keyed by stable spawn names")

	var save_key := InputEventKey.new()
	save_key.pressed = true
	save_key.physical_keycode = KEY_9
	save_key.shift_pressed = true
	save_system._unhandled_key_input(save_key)
	assert(FileAccess.file_exists(save_system.get_save_path(9)), "Shift-number must write its save slot")
	player.health = 1
	var load_key := InputEventKey.new()
	load_key.pressed = true
	load_key.physical_keycode = KEY_9
	load_key.ctrl_pressed = true
	save_system._unhandled_key_input(load_key)
	assert(player.health == player.max_health, "Ctrl-number must restore its slot")
	var slot_path := ProjectSettings.globalize_path(save_system.get_save_path(9))
	assert(DirAccess.remove_absolute(slot_path) == OK, "Save test must clean up its temporary slot")
	print("PASS: compact saves, hotkey slots, and offline progression work")
	quit()
