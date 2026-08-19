extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_world: PackedScene = load("res://Scenes/world.tscn")
	assert(packed_world != null, "World scene must load")
	var world := packed_world.instantiate()
	root.add_child(world)
	await process_frame
	var initial_damage_grid := world.get_node("HUD/DamageGrid") as DamageGrid
	assert(not initial_damage_grid.visible, "Damage types must stay hidden until a weapon slot has been equipped")
	assert(initial_damage_grid._grid.get_child_count() == 0, "The hidden damage HUD must not show a header without any damage above one")
	var resource_panel := world.get_node("HUD/ResourcePanel") as ResourcePanel
	assert(not resource_panel.visible, "Resources must stay hidden until first acquisition")
	var inventory_panel := world.get_node("HUD/Inventory") as InventoryPanel
	assert(not inventory_panel._auto_merge_button.visible, "Auto Merge must be hidden when the inventory has no valid merge")
	var tile_grid := world.get_node("GridOverlay/TileGrid") as TileGrid
	assert(tile_grid != null and is_equal_approx(tile_grid.modulate.a, 0.2), "The tile grid overlay must be 20% opaque")
	assert(world.get_node("HUD/Minimap") is Minimap, "The HUD must contain a minimap")
	var fox: FoxPlayer = world.get_node("Fox")
	for index in range(4):
		assert(fox.get_slot_item("inventory", index).is_empty(), "Inventory should begin with four empty slots")
		assert(fox.get_slot_item("weapon", index).is_empty() and fox.get_slot_item("armor", index).is_empty(), "Toolbar should begin empty")
	var floor_cells: Array[Vector2i] = world.floor_layer.get_used_cells()
	assert(floor_cells.size() > 1, "Manual floor tilemap must have walkable cells")
	var target_cell: Vector2i = floor_cells[0]
	for cell in floor_cells:
		if world.is_walkable(cell) and cell != world.world_to_cell(fox.global_position):
			target_cell = cell
			break
	fox.follow_path(world.find_path(fox.global_position, world.cell_to_world(target_cell)))
	assert(fox.is_moving(), "Fox should receive a route across the manual floor tilemap")
	fox.stop()
	fox.follow_path(PackedVector2Array([fox.global_position + Vector2(64, 0)]))
	fox._physics_process(1.0 / 60.0)
	assert(fox.fox_sprite.flip_h, "Fox sprite should flip while moving right")
	var spawn: EnemySpawnPoint = world.get_node("ChickenSpawn2")
	spawn.stat_reward_amount = 5
	var expected_sprite_paths: Array[String] = ["res://Sprites/Mole.webp", "res://Sprites/Mole2.webp", "res://Sprites/Goat.webp"]
	for index in range(3):
		var variant_enemy := EnemySpawnPoint.ENEMY_SCENES[index + 3].instantiate() as ChickenEnemy
		var variant_sprite := variant_enemy.get_node("ChickenSprite") as Sprite2D
		var expected_sprite_path: String = expected_sprite_paths[index]
		assert(variant_sprite.texture.resource_path == expected_sprite_path, "Each new enemy type must use its matching sprite")
		variant_enemy.free()
	var gate := load("res://Scenes/gate.tscn").instantiate() as Gate
	var gate_cell := target_cell
	for cell in floor_cells:
		if cell != world.world_to_cell(fox.global_position) and cell != world.world_to_cell(spawn.global_position):
			gate_cell = cell
			break
	gate.unlock_enemy_spawn = spawn
	gate.global_position = world.cell_to_world(gate_cell)
	world.add_child(gate)
	await process_frame
	assert(world.is_cell_occupied(gate_cell), "A gate must block its grid cell like a wall")
	spawn._spawn_enemy()
	assert(get_nodes_in_group("enemies").size() > 0, "Spawn point should create chickens")
	var enemy := spawn._spawned_enemies.back() as ChickenEnemy
	enemy.damage_reward = spawn.stat_reward_amount
	enemy._update_reward_visual()
	assert(enemy.enemy_color == FoxPlayer.COLOR_RED, "Spawned enemies must retain their configured color")
	assert(enemy.max_health == spawn.enemy_health and enemy.attack_damage == spawn.enemy_damage, "Spawn points must provide health and damage to each enemy")
	assert(enemy.damage_reward == spawn.stat_reward_amount, "Spawn points must export and provide stat reward amounts")
	assert(enemy.reward_type == ChickenEnemy.REWARD_RESOURCE and enemy.reward_resource_id == &"gold_ore", "Spawners must be able to select a resource reward")
	assert(enemy.reward_icon.texture.resource_path == "res://Sprites/GoldOreResource.webp", "Resource rewards must use the gold reward icon above the health bar")
	assert(is_equal_approx(enemy.reward_icon.texture.get_size().x * enemy.reward_icon.scale.x, 16.0), "Enemy reward icons must render at 16x16")
	assert(enemy.reward_label.get_theme_font_size("font_size") == 16, "Enemy reward text must use the compact font size")
	assert(enemy.reward_label.text == "+%d" % enemy.damage_reward, "Every reward must show a plus-prefixed amount")
	assert(enemy.chicken_sprite.texture.resource_path == "res://Sprites/Cow.webp", "Cow must be selectable from an enemy spawn point")
	assert(enemy.health_label.text == str(enemy.health), "Enemy HP must show current health only")
	assert(fox.health_label.text == str(fox.health), "Player HP must show current health only")
	var adjacent_cell: Vector2i = world.world_to_cell(fox.global_position) + Vector2i.LEFT
	assert(world.is_walkable(adjacent_cell), "Smoke-test map must have a tile beside the fox")
	enemy.global_position = world.cell_to_world(adjacent_cell)
	assert(world.find_path(fox.global_position, enemy.global_position, fox).is_empty(), "Actors must not path onto occupied tiles")
	var health_before: int = fox.health
	enemy._attack_time_left = 0.0
	enemy._attack_player()
	assert(fox.health == health_before - enemy.attack_damage, "An adjacent enemy must automatically attack the player")
	for entry in enemy.drop_table:
		var item_id := str(entry.get("item_id", ""))
		assert(item_id == "weathered_armor" or item_id == "weathered_sword", "Chickens may only drop weathered equipment")
	enemy.take_damage(enemy.health)
	assert(get_nodes_in_group("reward_orbs").size() == 1, "Resource rewards should travel as an orb before they are granted")
	await create_timer(1.0).timeout
	assert(not is_instance_valid(gate), "A gate must disappear when an enemy from its linked spawn is killed")
	var resource_manager := world.get_node("ResourceManager") as ResourceManager
	assert(resource_manager.get_amount(&"gold_ore") == 5, "Gold Ore resource rewards must enter the resource manager after their orb arrives")
	assert(resource_manager.has_ever_owned(&"gold_ore"), "Resources must become discovered when first obtained")
	assert(resource_panel.visible, "First resource acquisition must reveal the resource HUD")
	var gold_row := resource_panel._rows.get_child(0) as HBoxContainer
	assert((gold_row.get_child(1) as Label).text == "5/10", "Resource HUD should show the capped amount")
	assert(gold_row.get_child_count() == 2, "Resource HUD should hide gain text while no resource is being gained")
	var bull_spawn := world.get_node("ChickenSpawn3") as EnemySpawnPoint
	bull_spawn._spawn_enemy()
	var bull := bull_spawn._spawned_enemies.back() as ChickenEnemy
	var bull_variant := EnemySpawnPoint.ENEMY_SCENES[2].instantiate() as ChickenEnemy
	assert((bull_variant.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/Bull.webp", "Bull must be selectable from an enemy spawn point")
	bull_variant.free()
	bull.damage_reward = 2
	bull.reward_type = ChickenEnemy.REWARD_RESOURCE
	bull.reward_resource_id = &"jewels"
	bull._update_reward_visual()
	bull.take_damage(bull.health)
	await create_timer(1.0).timeout
	assert(resource_manager.get_amount(&"jewels") == 2, "Spawner-selected Jewel rewards must be granted after their orb arrives")
	resource_manager.add_resource(&"jewels", 100.0)
	assert(resource_manager.get_amount(&"jewels") == 10, "Jewels must stop at a maximum of ten")
	var ore := world.get_node("GoldOre") as GoldOre
	ore.show_build_button()
	assert(ore.build_button.visible, "Clicking an ore should reveal a build-mine button instead of moving the player")
	ore._show_build_tooltip()
	var mine_tooltip := world.get_node("HUD/BuildMineTooltip") as BuildMineTooltip
	assert(not ore.build_button.disabled and mine_tooltip.visible and mine_tooltip._content.get_child_count() == 3, "Affordable mine controls must instantly show a vertical icon cost tooltip")
	assert(ore.build_button.get_parent() == world.get_node("HUD"), "The mine control must render in the HUD above the grid")
	ore._try_build_mine()
	await process_frame
	assert(ore.get_node_or_null("MinerStructure") is MinerStructure, "A mine should be built on gold ore when its cost is affordable")
	assert(is_equal_approx(resource_manager.get_production_speed(&"gold_ore"), 1.0 / 60.0), "Each mine must produce one gold ore every 60 seconds")
	gold_row = resource_panel._rows.get_child(0) as HBoxContainer
	assert((gold_row.get_child(1) as Label).text == "0/10", "Resource HUD must refresh the capped amount")
	assert(gold_row.get_child_count() == 3 and (gold_row.get_child(2) as Label).text == "+0.02/s", "Resource HUD must show active gain speed separately")
	assert((gold_row.get_child(2) as Label).get_theme_color("font_color") == Color("65d76e"), "Active resource gain must be green")
	var mine := ore.get_node("MinerStructure") as MinerStructure
	mine._process(60.0)
	assert(resource_manager.get_amount(&"gold_ore") == 1, "Mine production should add gold ore to the capped resource amount")
	assert(mine.get_child_count() > 1, "On-screen mines must create green +1 production feedback")
	resource_manager.add_resource(&"gold_ore", 100.0)
	assert(resource_manager.get_amount(&"gold_ore") == 10, "Gold must stop at a maximum of ten")
	gold_row = resource_panel._rows.get_child(0) as HBoxContainer
	assert(gold_row.get_child_count() == 2, "Resource gain text must hide once the resource is full")
	var damage_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	damage_enemy.global_position = world.cell_to_world(adjacent_cell)
	damage_enemy.setup(adjacent_cell, 2, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_YELLOW, 50, 0)
	world.add_child(damage_enemy)
	await process_frame
	assert(damage_enemy.reward_icon.visible and damage_enemy.reward_icon.texture.resource_path == "res://Sprites/DamageIcon.webp" and damage_enemy.reward_label.text == "+2", "Damage rewards must use DamageIcon beside a colored +amount")
	damage_enemy.take_damage(damage_enemy.health)
	await create_timer(1.0).timeout
	assert(fox.get_base_damage_for_color(FoxPlayer.COLOR_YELLOW) == 3, "Damage reward color must be selected independently by the spawner")
	assert(fox.collect_item("weathered_sword"), "Picked-up sword should occupy inventory")
	assert(fox.collect_item("weathered_armor"), "Picked-up armor should occupy inventory")
	assert(fox.get_slot_item("weapon", 0).is_empty() and fox.get_slot_item("armor", 0).is_empty(), "Picking up equipment must not auto-equip it")
	assert(fox.move_or_merge("inventory", 0, "weapon", 0), "Inventory sword should move into a weapon slot")
	assert(fox.move_or_merge("inventory", 1, "armor", 0), "Inventory armor should move into an armor slot")
	assert(fox.get_damage_for_color(FoxPlayer.COLOR_RED) == fox.get_base_damage_for_color(FoxPlayer.COLOR_RED) + ItemPickup.get_damage_bonus(fox.get_slot_item("weapon", 0)), "Weapon damage should be added to the base color damage")
	assert(fox.collect_item("weathered_sword"), "A second sword should use an empty inventory slot")
	assert(fox.move_or_merge("inventory", 0, "weapon", 0), "Matching items should merge")
	assert(fox.get_slot_item("weapon", 0).get("grade", -1) == 1, "Merging two grade-zero swords should create grade one")
	assert(fox.get_damage_for_color(FoxPlayer.COLOR_RED) == fox.get_base_damage_for_color(FoxPlayer.COLOR_RED) + ItemPickup.get_damage_bonus(fox.get_slot_item("weapon", 0)), "Grade one sword damage should use the 2.1x grade multiplier")
	var armored_health := fox.health
	fox.take_damage(2)
	assert(fox.health == armored_health - 1, "Weathered armor should block one damage")
	var grid := world.get_node("HUD/DamageGrid") as DamageGrid
	assert(grid._grid.columns == 2 and grid._grid.get_child_count() == 8, "Damage HUD should show the equipped weapon and every color with a summed value above one")
	assert(is_equal_approx(grid.get_anchor(SIDE_LEFT), 0.0), "Damage HUD must be anchored to the top left")
	assert(grid._grid.get_child(2).get_child(0) is Polygon2D, "Damage color dots must remain in the first grid column")
	fox.add_color_damage(FoxPlayer.COLOR_RED, 1)
	assert(grid.visible, "The damage table should always be visible")
	fox.add_color_damage(FoxPlayer.COLOR_YELLOW, 1)
	assert(grid.visible, "Damage table remains visible after color upgrades")
	assert((grid._grid.get_child(0).get_child(0) as Label).text.is_empty(), "The first damage-grid square must stay empty")
	assert(grid._grid.get_child(1).get_child_count() == 1 and grid._grid.get_child(1).get_child(0) is CenterContainer, "The second damage-grid square must contain only the damage icon")
	assert(fox.collect_item("weathered_armor") and fox.collect_item("weathered_armor"), "Matching inventory items should be collectible")
	assert(inventory_panel._auto_merge_button.visible, "Auto Merge must appear when the inventory has matching items")
	inventory_panel._on_auto_merge_pressed()
	assert(fox.get_slot_item("inventory", 0).get("grade", -1) == 0, "The auto-merge animation must begin before the item state changes")
	await create_timer(0.35).timeout
	assert(fox.get_slot_item("inventory", 0).get("grade", -1) == 1, "Auto merge should upgrade the surviving item")
	assert(not inventory_panel._auto_merge_button.visible, "Auto Merge must hide after all valid merges are consumed")
	var starting_position := fox._spawn_position
	fox.global_position += Vector2(64, 0)
	fox.take_damage(fox.health + fox.get_total_block())
	assert(fox.health == fox.max_health and fox.global_position == starting_position, "Death should restore the fox at the original spawn with full health")
	fox.health = fox.max_health - 1
	fox._heal_time_left = 0.01
	fox._physics_process(0.02)
	assert(fox.health == fox.max_health, "Fox should regenerate one health every three seconds")
	var campfire := world.get_node("Campfire") as Campfire
	assert(world.is_walkable(world.world_to_cell(campfire.global_position)), "Campfire must be placed on a walkable tile")
	fox.global_position = world.cell_to_world(world.world_to_cell(campfire.global_position))
	fox.health = fox.max_health - 2
	fox.health_bar.value = fox.health
	fox._heal_time_left = 3.0
	fox._physics_process(0.61)
	assert(fox.health == fox.max_health - 1, "Campfires must make regeneration five times faster within two tiles")
	var health_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	health_enemy.global_position = world.cell_to_world(adjacent_cell)
	health_enemy.setup(adjacent_cell, 3, ChickenEnemy.REWARD_HEALTH, [], &"gold_ore", FoxPlayer.COLOR_RED, 1, 0)
	world.add_child(health_enemy)
	await process_frame
	var max_health_before := fox.max_health
	health_enemy.take_damage(health_enemy.health)
	await create_timer(1.0).timeout
	assert(fox.max_health == max_health_before + 3, "Health rewards must raise maximum health by their reward amount")
	print("PASS: navigation, enemies, resources, mining, inventory, respawn, HUD, and movement work")
	quit()
