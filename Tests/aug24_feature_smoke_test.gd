extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(FoxPlayer.format_health_per_second(5.0) == "5/s")
	assert(ItemPickup.get_healing_amount(ItemPickup.make_item("potion_basic")) == 40)
	assert(ItemPickup.get_healing_amount(ItemPickup.make_item("potion_rope")) == 100)
	assert(ItemPickup.is_full_heal(ItemPickup.make_item("potion_holy")))
	assert(FoxShop.UPGRADES[-1]["item_id"] == "potion_basic" and FoxShop.UPGRADES[-1]["base_price"] == 2)
	assert(FoxLucaShop.LUCA_UPGRADES[0]["amount"] == 2 and FoxLucaShop.LUCA_UPGRADES[0]["base_price"] == 10)
	assert(FoxLucaShop.LUCA_UPGRADES[1]["amount"] == 3 and FoxLucaShop.LUCA_UPGRADES[1]["resource_id"] == &"fish")
	assert(FoxLucaShop.LUCA_UPGRADES[2]["amount"] == 60 and FoxLucaShop.LUCA_UPGRADES[2]["resource_id"] == &"wood")
	assert(FoxLucaShop.LUCA_UPGRADES[3]["item_id"] == "potion_rope" and FoxLucaShop.LUCA_UPGRADES[3]["base_price"] == 7)

	var fox := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(fox)
	await process_frame
	fox.max_health = 100
	fox.health = 1
	assert(fox.collect_item("potion_basic"))
	assert(fox.consume_inventory_item(0) and fox.health == 41)
	assert(fox.collect_item("weathered_sword") and fox.collect_item("weathered_sword"))
	assert(fox.duplicate_equipment_tutorial_seen and fox.get_tutorial_merge_locations().size() == 2)
	fox.inventory_slots = [ItemPickup.make_item("weathered_sword"), ItemPickup.make_item("weathered_sword"), {}, {}]
	fox.duplicate_equipment_tutorial_seen = true
	assert(fox.merge_inventory_pair(1, 0) and fox.merge_count == 1)
	assert(not fox.can_merge(ItemPickup.make_item("potion_basic"), ItemPickup.make_item("potion_basic")))

	var enemy_paths := ["squirrel", "deer", "porcupine", "bunny", "evil_raccoon", "evil_owl"]
	for enemy_name in enemy_paths:
		assert(ResourceLoader.exists("res://Scenes/%s_enemy.tscn" % enemy_name))
	var obstacle_sizes := {
		"obstacle_jaw": Vector2i(2, 2),
		"obstacle_skull": Vector2i(3, 2),
		"obstacle_treehouse": Vector2i(2, 2),
		"obstacle_fox_skull": Vector2i.ONE,
		"obstacle_fox_skull_stack": Vector2i.ONE,
		"obstacle_skull_on_spear": Vector2i.ONE,
	}
	for obstacle_name in obstacle_sizes:
		var obstacle := (load("res://Scenes/%s.tscn" % obstacle_name) as PackedScene).instantiate() as ObstacleWall
		assert(obstacle.footprint_tiles == obstacle_sizes[obstacle_name])
		obstacle.free()

	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var map := world.get_node("HUD/WorldMap") as WorldMap
	assert(map._canvas._show_buildings and not map._canvas._buildings_toggle.visible)
	map._canvas._on_show_buildings_toggled(false)
	assert(map._canvas._show_buildings and world.map_show_buildings)
	var jaw := (load("res://Scenes/obstacle_jaw.tscn") as PackedScene).instantiate() as ObstacleWall
	jaw.global_position = world.player.global_position
	world.add_child(jaw)
	var jaw_origin := world.world_to_cell(jaw.global_position)
	var occupied := world.get_occupied_cells(world.player)
	assert(occupied.has(jaw_origin) and occupied.has(jaw_origin + Vector2i(1, 1)))
	var auto_fight := world.get_node("HUD/AutoFight") as AutoFightControl
	assert(not auto_fight.visible)
	auto_fight._on_first_boss_killed(null)
	await create_timer(0.8).timeout
	assert(world.player.auto_fight_unlocked and auto_fight.visible)
	auto_fight._toggle.button_pressed = true
	assert(world.player.auto_fight_enabled and world.player._auto_fight_range_fill.visible)

	var popup := load("res://Scenes/damage_popup.tscn").instantiate() as DamagePopup
	root.add_child(popup)
	popup.show_damage(9, FoxPlayer.COLOR_RED, 4)
	assert((popup.get_child(0).get_child(1) as Label).text == "-9")

	print("PASS: August 24 feature set works")
	quit()
