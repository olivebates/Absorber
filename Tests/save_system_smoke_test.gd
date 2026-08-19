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
	assert(player.collect_item("weathered_sword"), "Save test needs a persistent inventory item")
	resource_manager.add_resource(&"gold_ore", 10.0)
	resource_manager.add_resource(&"jewels", 10.0)
	ore._try_build_mine()
	assert(is_instance_valid(ore._mine), "Save test needs a built mine")

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

	var raw_json := JSON.stringify(save_system._capture_state(1000))
	var encoded := save_system.create_save_string(1000)
	assert(not encoded.is_empty() and encoded.length() < raw_json.length(), "The on-disk save string must be compressed")
	player.health = player.max_health
	player.damage_by_color[FoxPlayer.COLOR_RED][0] = 1
	player.inventory_slots[0] = {}
	gate.set_unlocked(true)
	assert(save_system.load_save_string(encoded, 1600), "A compact save string must decompress and load")
	await process_frame

	assert(player.health == player.max_health, "Ten offline minutes must finish player health recovery")
	assert(player.damage_by_color[FoxPlayer.COLOR_RED][0] == 5, "Damage progression must survive save/load")
	assert(str(player.inventory_slots[0].get("item_id", "")) == "weathered_sword", "Inventory must survive save/load")
	assert(refill_spawn._spawned_enemies.size() == refill_spawn.max_enemies, "Repeated offline respawn intervals must fill a spawn to its cap")
	assert(is_equal_approx(refill_spawn._respawn_time_left, refill_spawn.respawn_time), "A spawn filled offline must restart at its full timer")
	assert(resource_manager.get_amount(&"gold_ore") == resource_manager.get_maximum_amount(&"gold_ore"), "Built mines must produce resources during offline time")
	assert(is_instance_valid(ore._mine), "Built mines must survive save/load")
	assert(not gate.unlocked and gate.visible and gate.is_in_group("gates"), "Loading an older slot must restore a locked gate")

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
	save_system._unhandled_key_input(load_key)
	assert(player.health == player.max_health, "Number without Shift must restore its slot")
	var slot_path := ProjectSettings.globalize_path(save_system.get_save_path(9))
	assert(DirAccess.remove_absolute(slot_path) == OK, "Save test must clean up its temporary slot")
	print("PASS: compact saves, hotkey slots, and offline progression work")
	quit()
