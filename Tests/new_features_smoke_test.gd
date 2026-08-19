extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resource_manager := ResourceManager.new()
	root.add_child(resource_manager)
	var resource_panel := ResourcePanel.new()
	root.add_child(resource_panel)
	await process_frame
	resource_manager.add_resource(&"gold_ore", 1.0)
	var producer := Node.new()
	root.add_child(producer)
	resource_manager.register_producer(producer, &"gold_ore", 1.0)
	await process_frame
	var gold_row := resource_panel._rows.get_child(0) as HBoxContainer
	assert((gold_row.get_child(1) as Label).text == "1/10", "Gold must use a maximum of ten")
	assert(gold_row.get_child_count() == 3, "Gaining resources must show a gain label")
	assert((gold_row.get_child(2) as Label).get_theme_color("font_color") == Color("65d76e"), "Gain labels must be green")
	resource_manager.add_resource(&"gold_ore", 100.0)
	resource_manager.add_resource(&"jewels", 100.0)
	assert(resource_manager.get_amount(&"gold_ore") == 10 and resource_manager.get_amount(&"jewels") == 10, "Gold and jewels must cap at ten")
	await process_frame
	gold_row = resource_panel._rows.get_child(0) as HBoxContainer
	assert(gold_row.get_child_count() == 2, "Full resources are not currently gaining and must hide gain text")

	var fox := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(fox)
	var damage_grid := DamageGrid.new()
	root.add_child(damage_grid)
	await process_frame
	assert(not damage_grid.visible and damage_grid._grid.get_child_count() == 0, "Damage table must stay hidden while every matrix value is one")
	fox.add_color_damage(FoxPlayer.COLOR_RED, 1)
	await process_frame
	assert(is_equal_approx(damage_grid.get_anchor(SIDE_LEFT), 0.0), "Damage grid must remain top-left anchored")
	assert(damage_grid.visible and damage_grid._grid.columns == 2 and damage_grid._grid.get_child_count() == 4, "Only the upgraded color and weapon column must appear")
	assert((damage_grid._grid.get_child(0).get_child(0) as Label).text.is_empty(), "The table's first header cell must be blank")
	assert(damage_grid._grid.get_child(1).get_child(0) is CenterContainer, "The weapon header must contain its damage-type icon")
	assert(damage_grid._grid.get_child(2).get_child(0) is Polygon2D, "Color dots must occupy the first grid column")
	assert((damage_grid._grid.get_child(3).get_child(0) as Label).text == "2", "Damage cells must sum the color and weapon damage")
	var color_dot_cell := damage_grid._grid.get_child(2) as Control
	assert(damage_grid.get_color_target_screen_position(FoxPlayer.COLOR_RED).distance_to(color_dot_cell.get_global_rect().get_center()) < 0.1, "Damage rewards must fly to the color dot")
	fox.damage_by_color[FoxPlayer.COLOR_YELLOW][1] = 2
	fox.damage_matrix_changed.emit()
	await process_frame
	assert(damage_grid._grid.columns == 3 and damage_grid._grid.get_child_count() == 9, "A second active weapon type and color must add a table column and row")
	assert(damage_grid._grid.get_child(5) is Control and not (damage_grid._grid.get_child(5) is PanelContainer), "A value of one must leave its matrix cell hidden")
	assert((damage_grid._grid.get_child(8).get_child(0) as Label).text == "2", "The matching color and weapon cell must retain its summed damage")
	fox.damage_by_color[FoxPlayer.COLOR_BLUE][0] = 2
	fox.damage_matrix_changed.emit()
	await process_frame
	assert((damage_grid._grid.get_child(3).get_child(0) as Polygon2D).color == Color("e53935"), "The first damage row must have the red dot")
	assert((damage_grid._grid.get_child(6).get_child(0) as Polygon2D).color == Color("fbc02d"), "The second damage row must have the yellow dot")
	assert((damage_grid._grid.get_child(9).get_child(0) as Polygon2D).color == Color("1976d2"), "The third damage row must have the blue dot")
	var equipment_toolbar := EquipmentToolbar.new()
	root.add_child(equipment_toolbar)
	await process_frame
	var armor_slot := equipment_toolbar._armor_row.get_child(0) as ItemSlot
	var locked_armor_slot := equipment_toolbar._armor_row.get_child(1) as ItemSlot
	var weapon_slot := equipment_toolbar._weapon_row.get_child(0) as ItemSlot
	assert(not armor_slot.locked, "The first armor slot must start unlocked")
	assert(locked_armor_slot.locked, "Later armor slots must remain locked")
	assert(armor_slot._empty_icon.visible and armor_slot._empty_icon.texture.resource_path == "res://Sprites/HelmetIcon.webp", "Empty armor slots must show HelmetIcon")
	assert(weapon_slot._empty_icon.visible and weapon_slot._empty_icon.texture.resource_path == "res://Sprites/SwordIcon.webp", "Empty weapon slots must show SwordIcon")
	assert(locked_armor_slot._empty_icon.z_index < locked_armor_slot._lock_icon.z_index, "Empty slot icons must render beneath locks")

	var reward_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	reward_enemy.setup(Vector2i.ZERO, 1)
	root.add_child(reward_enemy)
	await process_frame
	assert(is_equal_approx(reward_enemy.reward_icon.texture.get_size().x * reward_enemy.reward_icon.scale.x, 16.0), "Reward icons must be 16x16")
	reward_enemy._pause_time_left = 999.0
	reward_enemy.take_damage(1)
	reward_enemy._physics_process(2.99)
	assert(reward_enemy.health == reward_enemy.max_health - 1, "Enemies must wait three seconds before regenerating")
	reward_enemy._physics_process(0.01)
	reward_enemy._physics_process(0.1)
	assert(reward_enemy.health == reward_enemy.max_health, "Enemies must regenerate rapidly after the delay")

	var expected_sprite_paths: Array[String] = ["res://Sprites/Mole.webp", "res://Sprites/Mole2.webp", "res://Sprites/Goat.webp"]
	for index in range(expected_sprite_paths.size()):
		var variant_enemy := EnemySpawnPoint.ENEMY_SCENES[index + 3].instantiate() as ChickenEnemy
		assert((variant_enemy.get_node("ChickenSprite") as Sprite2D).texture.resource_path == expected_sprite_paths[index], "New enemy types must use their matching sprites")
		variant_enemy.free()

	var spawn := EnemySpawnPoint.new()
	root.add_child(spawn)
	assert(spawn._format_respawn_time(65.0) == "1:05" and spawn._format_respawn_time(420.0) == "7:00", "Respawn timers must use minutes and seconds")
	var gate := Gate.new()
	gate.unlock_enemy_spawn = spawn
	root.add_child(gate)
	await process_frame
	assert(gate.is_in_group("gates"), "Gates must register as path blockers")
	var linked_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	linked_enemy.setup(Vector2i.ZERO, 1)
	linked_enemy.died.connect(spawn._on_spawned_enemy_died)
	root.add_child(linked_enemy)
	await process_frame
	linked_enemy.take_damage(linked_enemy.health)
	await process_frame
	assert(gate.unlocked and not gate.visible and not gate.is_in_group("gates"), "Killing an enemy from the selected spawn must unlock and hide its gate")

	var empty_drop_tooltip := EnemyDropTooltip.new()
	root.add_child(empty_drop_tooltip)
	await process_frame
	assert(empty_drop_tooltip._get_visible_drops([]).is_empty(), "Enemies without drops must not show a drop tooltip")

	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	for child in world.get_children():
		if child is EnemySpawnPoint:
			var enemy_spawn := child as EnemySpawnPoint
			assert(enemy_spawn._spawned_enemies.size() == enemy_spawn.max_enemies, "Spawns must begin with their full enemy count")
	var ore_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	var ore := world.get_node("GoldOre") as GoldOre
	ore_enemy.global_position = ore.global_position + Vector2(64, 0)
	world.add_child(ore_enemy)
	await process_frame
	assert(not world.can_enter_position(ore_enemy, ore.global_position), "Enemies must not enter gold-ore cells")
	var campfire := world.get_node("Campfire") as Campfire
	world.player.global_position = campfire.global_position + Vector2(128, 128)
	assert(campfire.is_player_in_range(world.player), "Campfires must heal throughout their two-tile square")
	world.player.health = world.player.max_health - 2
	world.player.health_bar.value = world.player.health
	world.player._heal_time_left = 3.0
	world.player._physics_process(0.61)
	assert(world.player.health == world.player.max_health - 1, "Campfire healing must apply inside the square")
	assert(world.player._healing_particles.emitting, "Green healing particles must activate near campfires")
	world.player.global_position = campfire.global_position + Vector2(192, 0)
	assert(not campfire.is_player_in_range(world.player), "Campfire healing must end outside the square")

	var regeneration_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	regeneration_enemy.setup(Vector2i.ZERO, 2, ChickenEnemy.REWARD_REGENERATE)
	root.add_child(regeneration_enemy)
	await process_frame
	assert(regeneration_enemy.reward_icon.texture.resource_path == "res://Sprites/GreenHeart.png", "Regeneration rewards must use the green heart sprite")
	var passive_healing_before := fox.passive_healing_amount
	regeneration_enemy._grant_kill_reward()
	await create_timer(0.8).timeout
	assert(fox.passive_healing_amount == passive_healing_before + 2, "Regeneration rewards must increase passive healing")
	var minimap := world.get_node("HUD/Minimap") as Minimap
	var map_rect := Rect2(Vector2(5, 5), minimap.size - Vector2(10, 10))
	assert(minimap._world_to_minimap(world.player.global_position, map_rect).distance_to(map_rect.get_center()) < 0.1, "The player must remain centered on the minimap")
	print("PASS: requested feature changes work")
	quit()
