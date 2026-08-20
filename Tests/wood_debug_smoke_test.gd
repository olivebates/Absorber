extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame

	var manager := world.get_node("ResourceManager") as ResourceManager
	var wood := manager.get_definition(&"wood")
	assert(wood != null and wood.icon.resource_path == "res://Sprites/WoodResource.webp", "Wood must use WoodResource")
	assert(wood.maximum_amount == 10, "Wood must start with ten capacity")

	var oak := world.get_node("OakTree") as GoldOre
	var palm := world.get_node("PalmTree") as GoldOre
	assert(world.is_walkable(world.world_to_cell(oak.global_position)), "The oak must be placed on a walkable tile")
	assert(world.is_walkable(world.world_to_cell(palm.global_position)), "The palm must be placed on a walkable tile")
	assert(is_equal_approx(oak.mine_production_speed, 1.0 / 300.0), "Oak lodges must produce one wood every five minutes")
	assert(is_equal_approx(palm.mine_production_speed, 1.0 / 180.0), "Palm lodges must produce one wood every three minutes")

	var fishing_spot := world.get_node("FishingSpot") as GoldOre
	fishing_spot.show_build_button()
	assert(fishing_spot.build_button.text == "Build Hut", "Fishing spots must offer a Hut")
	fishing_spot.hide_build_button()

	manager.fill_all_to_maximum()
	oak._try_build_mine()
	palm._try_build_mine()
	assert((oak._mine.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/WoodCuttingLodge.webp", "Oak mines must use the woodcutting lodge")
	assert((palm._mine.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/WoodCuttingLodge.webp", "Palm mines must use the woodcutting lodge")
	manager.spend_resources({"wood": 10})

	var saved := (world.get_node("SaveSystem") as SaveSystem).create_save_string(1000)
	assert((world.get_node("SaveSystem") as SaveSystem).load_save_string(saved, 1301), "Wood production save must load")
	assert(manager.get_amount(&"wood") == 2, "Both wood lodges must produce during offline time")

	manager.fill_all_to_maximum()
	var crate_cell := Vector2i.ZERO
	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = world.world_to_cell(oak.global_position) + Vector2i(offset)
		if world.can_build_at_cell(candidate):
			crate_cell = candidate
			break
	assert(crate_cell != Vector2i.ZERO, "Oak must have room for a wood crate")
	oak._try_build_shack(crate_cell)
	assert(manager.get_maximum_amount(&"wood") == 25, "Wood Crates must add fifteen capacity")

	var debug_menu := world.get_node("HUD/DebugMenu") as DebugStatMenu
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_O
	toggle.shift_pressed = true
	toggle.pressed = true
	debug_menu._unhandled_key_input(toggle)
	assert(debug_menu.visible, "Shift+O must show the debug stat menu")
	var old_max_health := world.player.max_health
	debug_menu._adjust_stat(0, 1)
	assert(world.player.max_health == old_max_health + 1, "Debug controls must increase stats")
	debug_menu._adjust_stat(0, -1)
	assert(world.player.max_health == old_max_health, "Debug controls must decrease stats")

	world.player.passive_healing_amount = 3
	world.player.health = world.player.max_health - 3
	world.player._heal_time_left = 1.0
	world.player._physics_process(1.0)
	assert(world.player.health == world.player.max_health - 2, "Higher regeneration must heal one point at a time")
	world.player._physics_process(1.0)
	assert(world.player.health == world.player.max_health - 1, "Higher regeneration must continue at evenly spaced intervals")

	var drop := EnemyDropEntry.new()
	drop.item_type = EnemyDropEntry.ItemType.WEATHERED_SWORD
	drop.chance = 0.25
	drop.grade = 2
	var spawn := EnemySpawnPoint.new()
	spawn.item_drops = [drop]
	var drop_data := spawn._get_drop_table()
	assert(drop_data.size() == 1 and drop_data[0]["item_id"] == "weathered_sword" and drop_data[0]["grade"] == 2, "Typed spawner drops must convert to enemy drop data")
	spawn.free()

	print("PASS: wood production, debug stats, continuous regeneration, and simple drops work")
	quit()
