extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var manager := world.get_node("ResourceManager") as ResourceManager
	var gem_ore := world.get_node("GemOre2") as GoldOre
	assert(gem_ore.build_cost == {"gold_ore": 2, "jewels": 5}, "Gem mines must cost two gold and five jewels")
	assert(gem_ore.mined_resource_id == &"jewels" and is_equal_approx(gem_ore.mine_production_speed, 1.0 / 180.0), "Gem mines must produce one jewel every three minutes")
	manager.fill_all_to_maximum()
	gem_ore._try_build_mine()
	assert(is_instance_valid(gem_ore._mine) and gem_ore._mine.resource_id == &"jewels", "The gem deposit must build a jewel-producing mine")

	var ore_cell := world.world_to_cell(gem_ore.global_position)
	var actor_cell := Vector2i.ZERO
	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = ore_cell + Vector2i(offset)
		if world.is_permanently_buildable_cell(candidate):
			actor_cell = candidate
			break
	assert(actor_cell != Vector2i.ZERO, "The placed gem deposit needs an adjacent shack tile")
	world.player.global_position = world.cell_to_world(actor_cell)
	gem_ore.show_build_button()
	var actor_button_found := false
	for button in gem_ore._shack_buttons:
		if Vector2i(button.get_meta("build_cell")) == actor_cell:
			actor_button_found = true
	assert(actor_button_found, "Build Shack must remain visible on a player-occupied tile")
	manager.fill_all_to_maximum()
	gem_ore._try_build_shack(actor_cell)
	assert(manager.get_maximum_amount(&"jewels") == 20, "A Gem Shack must add ten jewel capacity")

	var tooltip := world.get_node("HUD/BuildMineTooltip") as BuildMineTooltip
	var definition := manager.get_definition(&"jewels")
	tooltip.show_stat(definition.icon, "Capacity", "+10", gem_ore)
	await process_frame
	assert((tooltip._content.get_child(0) as TextureRect).texture == definition.icon, "Building stats must put the resource icon on the left")
	assert((tooltip._content.get_child(1) as Label).text == "Capacity: +10", "Shack hover stats must show capacity")
	tooltip.show_stat(definition.icon, "Production", "+0.006/s", gem_ore)
	await process_frame
	assert((tooltip._content.get_child(1) as Label).text == "Production: +0.006/s", "Mine hover stats must show per-second production")
	var resource_panel := world.get_node("HUD/ResourcePanel") as ResourcePanel
	await process_frame
	await process_frame
	var panel_style := resource_panel.get_theme_stylebox("panel")
	var expected_panel_size := resource_panel._rows.get_combined_minimum_size() + panel_style.get_minimum_size()
	assert(resource_panel.size.is_equal_approx(expected_panel_size), "The resource panel must fit only its visible rows and eight-pixel margins")

	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = ore_cell + Vector2i(offset)
		if world.is_permanently_buildable_cell(candidate):
			var blocker := load("res://Scenes/gem_shack.tscn").instantiate() as GoldShack
			blocker.global_position = world.cell_to_world(candidate)
			world.add_child(blocker)
	gem_ore._update_hover_highlight(gem_ore.global_position)
	assert(not gem_ore._tile_highlight.visible, "A mine with no remaining shack tiles must not light up yellow")

	var first_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	var second_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	first_enemy.global_position = world.cell_to_world(Vector2i(1, 2))
	second_enemy.global_position = world.cell_to_world(Vector2i(3, 2))
	world.add_child(first_enemy)
	world.add_child(second_enemy)
	await process_frame
	var shared_target := world.cell_to_world(Vector2i(2, 2))
	first_enemy._path = PackedVector2Array([shared_target])
	second_enemy._path = PackedVector2Array([shared_target])
	assert(world.is_enemy_target_conflicted(second_enemy, Vector2i(2, 2)), "A later enemy must yield a shared target tile")
	second_enemy._patrol(0.01)
	assert(second_enemy.get_movement_target_cell(world) == world.world_to_cell(second_enemy.global_position), "A yielding enemy must target its own tile")
	print("PASS: gem buildings, occupied shack tiles, hover stats, and enemy target yielding work")
	quit()
