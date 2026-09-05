extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame

	var resources := world.get_node("ResourceManager") as ResourceManager
	var herbs_definition := resources.get_definition(&"herbs")
	assert(herbs_definition != null and herbs_definition.display_name == "Herbs" and herbs_definition.maximum_amount == 10)
	assert(herbs_definition.icon.resource_path == "res://Sprites/iconHerbs.webp")
	var herbs := world.get_node("Herbs") as GoldOre
	assert((herbs.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/Herbs.webp")
	assert(herbs.build_cost == {"cave_moss": 2, "herbs": 5} and herbs.shack_build_cost == {"herbs": 10})
	assert(herbs.mine_build_label == "Build Garden" and herbs.capacity_build_label == "Build Rack")
	assert(is_equal_approx(herbs.mine_production_speed, 1.0 / 420.0) and herbs.capacity_bonus == 10)
	resources.fill_all_to_maximum()
	herbs._try_build_mine()
	assert(resources.get_amount(&"herbs") == 5 and resources.get_amount(&"cave_moss") == 8)
	assert(is_instance_valid(herbs._mine) and (herbs._mine.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/herbGarden.webp")
	assert(is_equal_approx(resources.get_production_speed(&"herbs"), 1.0 / 420.0))

	resources.fill_all_to_maximum()
	var herbs_cell := world.world_to_cell(herbs.global_position)
	var rack_cell := Vector2i(-999, -999)
	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = herbs_cell + Vector2i(offset)
		if world.is_permanently_buildable_cell(candidate):
			rack_cell = candidate
			break
	assert(rack_cell != Vector2i(-999, -999))
	herbs._try_build_shack(rack_cell)
	assert(resources.get_maximum_amount(&"herbs") == 20)
	var rack := get_nodes_in_group("buildings").filter(func(node: Node) -> bool: return node is GoldShack and node.resource_id == &"herbs")[0] as GoldShack
	assert((rack.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/herbDryingrack.webp")
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var captured_state := save_system._capture_state(1000)
	assert((captured_state[8] as Array).any(func(saved_building: Array) -> bool: return saved_building.size() > 2 and int(saved_building[2]) == 4), "Racks must be included in save data")

	var reward_property: Dictionary
	for property in EnemySpawnPoint.new().get_property_list():
		if property.name == &"reward_resource_id":
			reward_property = property
			break
	assert(int(reward_property.get("hint", 0)) == PROPERTY_HINT_ENUM and "herbs" in str(reward_property.get("hint_string", "")))
	for spawn_name in ["ChickenSpawn30", "ChickenSpawn32", "ChickenSpawn33", "ChickenSpawn9", "ChickenSpawn10", "ChickenSpawn11"]:
		var spawn := world.get_node(spawn_name) as EnemySpawnPoint
		assert(spawn.reward_type == ChickenEnemy.REWARD_RESOURCE and not spawn.reward_resource_id.is_empty())
	assert(world.get_node("ChickenSpawn10").reward_resource_id == &"gold_ore")

	var player := world.player
	player.max_health = 100
	player.health = 100
	player.thorn = 4
	var saved_player := player.get_save_data()
	player.thorn = 0
	assert(player.load_save_data(saved_player, 0) and player.thorn == 4, "Player thorn must persist in saves")
	var enemy := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	enemy.setup(Vector2i.ZERO, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 50, 1, FoxPlayer.COLOR_YELLOW, 2, FoxPlayer.COLOR_RED, false, [], false, 3)
	world.add_child(enemy)
	assert(enemy.armor == 2 and enemy.thorn == 3)
	assert(enemy.find_child("ArmorStat", true, false).visible and enemy.find_child("ThornStat", true, false).visible)
	assert((enemy.find_child("ArmorIcon", true, false) as TextureRect).texture.resource_path == "res://Sprites/ShieldIcon.webp")
	assert((enemy.find_child("ThornIcon", true, false) as TextureRect).texture.resource_path == "res://Sprites/iconThorn.webp")
	var player_health := player.health
	enemy.take_damage(5, false, player)
	assert(enemy.health == 47 and player.health == player_health - 3, "Enemy thorn must return same-color damage to its attacker")
	var enemy_health := enemy.health
	player.take_damage(1, FoxPlayer.COLOR_YELLOW, enemy)
	assert(enemy.health == enemy_health - 2, "Player thorn must be reduced by enemy armor like normal colored damage")

	assert(FoxPlayer.format_large_number(1499) == "1499")
	assert(FoxPlayer.format_large_number(1500) == "1.5k")
	assert(FoxPlayer.format_large_number(1200000) == "1.2m")
	player.max_health = FoxPlayer.MAX_HEALTH
	player.health = 1501
	player._update_health_label()
	assert(player.health_label.text == "1.5k")
	player.add_max_health(1)
	assert(player.max_health == 100000000)
	var max_spawn := EnemySpawnPoint.new()
	var health_property: Dictionary
	for property in max_spawn.get_property_list():
		if property.name == &"enemy_health":
			health_property = property
			break
	assert("100000000" in str(health_property.get("hint_string", "")))

	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: Herbs buildings, thorn reflection, compact health, and resource dropdown work")
	quit()
