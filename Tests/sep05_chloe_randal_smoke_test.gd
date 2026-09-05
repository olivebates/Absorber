extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _finish_dialogue(box: DialogueBox) -> String:
	var copy := ""
	while box.is_open():
		copy += " " + box.get_current_text()
		box.finish_typing()
		box.advance()
	return copy


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var box := world.get_node("HUD/DialogueBox") as DialogueBox
	_finish_dialogue(box)
	var story := world.get_node("StoryManager") as StoryManager
	var player := world.player
	var resources := world.get_node("ResourceManager") as ResourceManager
	var chloe := world.get_node("FoxChloe") as FoxChloe
	var randal := world.get_node("FoxRandal") as FoxRandal
	var deru := world.get_node("FoxDeru") as FoxDeru
	var ball := world.get_node("randalsBallPickup") as RandalsBallPickup

	assert(chloe != null and randal != null and deru != null and ball != null)
	assert(world.is_walkable(world.world_to_cell(chloe.global_position)), "Chloe must stand on authored floor")
	assert(world.is_walkable(world.world_to_cell(randal.global_position)), "Randal must stand on authored floor")
	assert(world.is_walkable(world.world_to_cell(ball.global_position)), "Randal's ball must sit on authored floor")
	assert((chloe.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FoxChloe.webp")
	assert((randal.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/foxRandal.webp")
	assert((ball.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/randalsBallPickup.webp")
	assert(not ball.visible and not ball.is_in_group("world_interactables"), "The ball pickup must stay unavailable until Randal starts the quest")

	assert(story.interact_with(&"chloe"))
	assert(_finish_dialogue(box).contains("useful things"))
	await process_frame
	var chloe_shop := chloe._shop as FoxChloeShop
	assert(chloe_shop != null and chloe_shop.visible and chloe_shop._get_upgrades().size() == 2)
	var offers := chloe_shop._get_resource_offers()
	assert(offers[0] == {"resource_id": &"herbs", "cost_resource_id": &"cave_moss", "price": 2})
	assert(offers[1] == {"resource_id": &"cave_moss", "cost_resource_id": &"wood", "price": 2})
	assert(chloe_shop.get_upgrade_price(0) == 5 and chloe_shop.get_upgrade_price(1) == 15)
	assert(StringName(chloe_shop._get_upgrades()[0]["stat"]) == &"damage" and int(chloe_shop._get_upgrades()[0]["amount"]) == 4 \
		and int(chloe_shop._get_upgrades()[0]["color"]) == FoxPlayer.COLOR_BLUE)
	assert(StringName(chloe_shop._get_upgrades()[1]["stat"]) == &"inventory_slot" and bool(chloe_shop._get_upgrades()[1]["one_time"]))
	assert(FoxLucaShop.LUCA_UPGRADES.all(func(upgrade: Dictionary) -> bool:
		return not [&"inventory_slot", &"equipment_slot", &"skill_slot"].has(StringName(upgrade.get("stat", &"")))
	), "Other shops must no longer sell inventory, equipment, or skill slots")

	resources._amounts[&"cave_moss"] = 5.0
	resources._ever_owned[&"cave_moss"] = true
	var blue_damage_before := player.get_base_damage_for_color(FoxPlayer.COLOR_BLUE)
	assert(chloe_shop.buy_upgrade(0))
	assert(player.get_base_damage_for_color(FoxPlayer.COLOR_BLUE) == blue_damage_before + 4)
	await create_timer(0.35).timeout
	_finish_dialogue(box)
	var moss_capacity := Node.new()
	world.add_child(moss_capacity)
	resources.register_capacity_bonus(moss_capacity, &"cave_moss", 10)
	resources._amounts[&"cave_moss"] = 15.0
	var inventory_size_before := player.inventory_slots.size()
	assert(chloe_shop.buy_upgrade(1))
	assert(player.inventory_slots.size() == inventory_size_before + 1 and not chloe_shop._rows[1].visible)

	assert(story.interact_with(&"randal"))
	var quest_intro := _finish_dialogue(box)
	assert(quest_intro.contains("can't find my ball") and quest_intro.contains("keep an eye out"))
	assert(story.is_randal_quest_started() and ball.visible and ball.is_in_group("world_interactables"))
	assert(story.interact_with(&"randal"))
	assert(_finish_dialogue(box).contains("has to be around here"), "Randal needs a reminder interaction before the ball is found")
	assert(story.interact_with(&"randals_ball"))
	assert(_finish_dialogue(box).contains("bring Randal's ball back"))
	assert(story.is_randals_ball_collected() and player.has_inventory_item("randals_ball"))
	assert(not ball.visible and not ball.is_in_group("world_interactables"))
	var ball_item := ItemPickup.make_item("randals_ball")
	assert(ItemPickup.ITEM_TEXTURES["randals_ball"].resource_path == "res://Sprites/RandalsBall.webp")
	assert(ItemPickup.is_protected("randals_ball") and not ball_item.is_empty())
	assert(story.interact_with(&"randal"))
	var return_dialogue := _finish_dialogue(box)
	assert(return_dialogue.contains("What can I do to return the favor?") \
		and return_dialogue.contains("I could use some help clearing the creatures out of these woods") \
		and return_dialogue.contains("Leave a few of them to me"), \
		"Randal must ask how to return the favor before Mira suggests clearing the forest")
	assert(story.is_randal_quest_completed() and not player.has_inventory_item("randals_ball"))
	assert(randal.is_hunter_recruited() and randal._get_hunt_area_id() == 5)
	assert(randal._get_area_campfire() != null and randal._get_area_campfire().area_id == 5)
	randal.set_process(false)
	var area_five_spawn: EnemySpawnPoint
	for spawn_node in get_nodes_in_group("enemy_spawns"):
		var candidate_spawn := spawn_node as EnemySpawnPoint
		if candidate_spawn.area_id == 5 and not FoxLio.EXCLUDED_ENEMY_TYPES.has(candidate_spawn.enemy_type):
			area_five_spawn = candidate_spawn
			break
	assert(area_five_spawn != null, "Randal needs an eligible AreaID 5 enemy spawn")
	var randal_target := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	randal_target.setup(Vector2i.ZERO, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 60, 1)
	randal_target.spawn_point = area_five_spawn
	world.add_child(randal_target)
	var horizontal_start := Vector2i(-999999, -999999)
	for cell in world.floor_layer.get_used_cells():
		if world.is_walkable(cell) and world.is_walkable(cell + Vector2i.RIGHT) \
				and world.is_walkable(cell + Vector2i.RIGHT * 2) and world.is_walkable(cell + Vector2i.RIGHT * 3):
			horizontal_start = cell
			break
	assert(horizontal_start != Vector2i(-999999, -999999), "The helper test needs four horizontal floor tiles")
	randal.global_position = world.cell_to_world(horizontal_start)
	randal_target.global_position = world.cell_to_world(horizontal_start + Vector2i.RIGHT * 3)
	world.sync_navigation_actor(randal)
	world.sync_navigation_actor(randal_target)
	var horizontal_path := randal._best_adjacent_path(randal_target)
	assert(horizontal_path.size() > 1 and world.world_to_cell(horizontal_path[-1]) == horizontal_start + Vector2i.RIGHT * 2, \
		"A straight Jump Point Search route must retain the horizontal approach tile beside an enemy")
	randal._path = horizontal_path
	randal._path_index = 1
	var randal_before_move := randal.global_position
	randal._follow_hunt_path(0.1)
	assert(randal.global_position.x > randal_before_move.x and is_equal_approx(randal.global_position.y, randal_before_move.y), \
		"Randal must move horizontally toward an enemy on the same row")
	randal_target.take_hunter_damage(deru)
	assert(randal_target.health == 53, "Deru must deal 7 damage per helper hit")
	randal_target.take_hunter_damage(randal)
	assert(randal_target.health == 36, "Randal must deal 17 damage per helper hit")
	randal_target.take_hunter_damage(randal)
	assert(randal_target.health == 19, "Randal's second helper hit must deal another 17 damage")
	randal_target.queue_free()
	var entries := story.get_quest_log_entries()
	var randal_quest := entries.filter(func(entry: Dictionary) -> bool: return entry.get("id") == &"randals_ball")
	assert(randal_quest.size() == 1 and bool(randal_quest[0]["completed"]))

	story._seen_events.erase(&"fish_hut")
	story._seen_events.erase(&"first_structure_build_tip")
	story.on_structure_built(&"fish")
	var build_dialogue := _finish_dialogue(box)
	assert(build_dialogue.contains("That'll do.") and build_dialogue.contains("if I click it again, I can build even more things"))
	story.on_structure_built(&"jewels")
	assert(not _finish_dialogue(box).contains("click it again"), "The extra construction hint must only play once")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var save_string := save_system.create_save_string(1000)
	assert(save_system.load_save_string(save_string, 1000))
	assert((world.get_node("FoxChloe") as FoxChloe).purchase_counts[1] == 1)
	assert((world.get_node("FoxRandal") as FoxRandal).is_hunter_recruited())
	assert((world.get_node("StoryManager") as StoryManager).is_randal_quest_completed())

	print("PASS: Chloe shop, Randal ball quest/helper damage and movement, slot catalog, and build hint work")
	world.queue_free()
	quit()
