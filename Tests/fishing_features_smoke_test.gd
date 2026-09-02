extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame

	var manager := world.get_node("ResourceManager") as ResourceManager
	var fishing_spot := world.get_node("FishingSpot") as GoldOre
	var fish_definition := manager.get_definition(&"fish")
	assert(fish_definition != null and fish_definition.maximum_amount == 20, "Fish must have a default capacity of twenty")
	assert(fish_definition.icon.resource_path == "res://Sprites/FishResource.webp", "Fish must use FishResource as its icon")
	assert((fishing_spot.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FishSillouhettes.webp", "The fishing spot must use FishSillouhettes")
	assert(world.is_walkable(world.world_to_cell(fishing_spot.global_position)), "The fishing spot must be placed on authored floor")
	assert(fishing_spot.build_cost == {"fish": 5, "gold_ore": 2} and fishing_spot.shack_build_cost == {"fish": 10}, "Fishing huts must use their resource cost and Fish storage must start at ten Fish")

	for index in [6, 7]:
		var enemy := (load(EnemySpawnPoint.ENEMY_SCENES[index]) as PackedScene).instantiate() as ChickenEnemy
		var expected := "res://Sprites/EvilGoat.webp" if index == 6 else "res://Sprites/Crab.webp"
		assert((enemy.get_node("ChickenSprite") as Sprite2D).texture.resource_path == expected, "Each new enemy must use its requested sprite")
		enemy.free()

	manager.fill_all_to_maximum()
	fishing_spot._try_build_mine()
	assert(is_instance_valid(fishing_spot._mine), "The fishing spot must build a mine")
	assert(fishing_spot._mine.resource_id == &"fish" and is_equal_approx(fishing_spot._mine.production_speed, 1.0 / 60.0), "The fishing mine must produce one fish per minute")
	assert((fishing_spot._mine.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FishingMine.webp", "The built fishing mine must use FishingMine")
	assert(fishing_spot._mine._get_production_tooltip_value() == "+1.00/m", "Production rates must be converted to a per-minute value")

	var tooltip := world.get_node("HUD/BuildMineTooltip") as BuildMineTooltip
	tooltip.show_stat(fish_definition.icon, "Production", fishing_spot._mine._get_production_tooltip_value(), fishing_spot._mine)
	var production_label := tooltip._content.get_child(1) as Label
	assert(production_label.text == "Production: +1.00/m", "Mine hover must show production per minute")
	var unrelated_shack := load("res://Scenes/gold_shack.tscn").instantiate() as GoldShack
	world.add_child(unrelated_shack)
	tooltip.hide_tooltip(unrelated_shack)
	assert(tooltip.visible and (tooltip._content.get_child(1) as Label).text == "Production: +1.00/m", "Leaving a previously hovered shack must not hide the mine popup")

	var fishing_cell := world.world_to_cell(fishing_spot.global_position)
	var crate_cell := Vector2i(-999, -999)
	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = fishing_cell + Vector2i(offset)
		if world.is_permanently_buildable_cell(candidate):
			crate_cell = candidate
			break
	assert(crate_cell != Vector2i(-999, -999), "The fishing spot must have an adjacent crate tile")
	fishing_spot._try_build_shack(crate_cell)
	assert(manager.get_maximum_amount(&"fish") == 25, "A Fish Crate must add five fish capacity")
	var crate := world.get_tree().get_nodes_in_group("buildings").filter(func(node: Node) -> bool: return node is GoldShack and node.building_type == 2)[0] as GoldShack
	assert((crate.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FishCrate.webp", "Fish storage must use FishCrate")

	var escape_cell := Vector2i(-999, -999)
	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = crate_cell + Vector2i(offset)
		if world.is_walkable(candidate) and not world.is_cell_occupied(candidate):
			escape_cell = candidate
			break
	assert(escape_cell != Vector2i(-999, -999), "The crate tile must have an unoccupied escape tile")
	world.player.global_position = world.cell_to_world(crate_cell)
	assert(world.can_enter_position(world.player, world.player.global_position + Vector2(4, 0)), "A player on a building must be able to start leaving its tile")
	assert(not world.find_path(world.player.global_position, world.cell_to_world(escape_cell), world.player).is_empty(), "A player on a building must path to an unoccupied tile")

	var enemy := load("res://Scenes/crab_enemy.tscn").instantiate() as ChickenEnemy
	enemy.global_position = world.cell_to_world(crate_cell)
	world.add_child(enemy)
	await process_frame
	assert(world.can_enter_position(enemy, enemy.global_position + Vector2(4, 0)), "An enemy on a building must be able to start leaving its tile")
	assert(not world.find_path(enemy.global_position, world.cell_to_world(escape_cell), enemy).is_empty(), "An enemy on a building must path to an unoccupied tile")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var encoded := save_system.create_save_string(1000)
	crate.free()
	assert(manager.get_maximum_amount(&"fish") == 20, "Removing a Fish Crate must remove its capacity")
	assert(save_system.load_save_string(encoded, 1000), "Saves must restore Fish Crates")
	assert(manager.get_maximum_amount(&"fish") == 25, "A restored Fish Crate must restore fish capacity")
	print("PASS: building escape, tooltip ownership, new enemies, and fishing economy work")
	quit()
