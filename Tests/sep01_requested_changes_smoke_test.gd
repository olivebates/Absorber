extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	if dialogue.is_open():
		dialogue.cancel()
	var player := world.player
	assert(ItemPickup.ITEM_NAMES["weathered_sword"] == "Yellow Sword")
	assert(ItemPickup.ITEM_NAMES["weathered_armor"] == "Orange Shield")
	assert(ItemPickup.get_damage_bonus(ItemPickup.make_item("weathered_sword")) == 5)
	assert(ItemPickup.get_block_colors(ItemPickup.make_item("weathered_armor")) == [FoxPlayer.COLOR_RED, FoxPlayer.COLOR_YELLOW])
	var crude := ItemPickup.make_item("weathered_sword")
	var superior := ItemPickup.make_item("weathered_sword", 2)
	player.inventory_slots = [crude, superior, {}, {}]
	assert(player.can_merge(crude, superior) and player.merge_inventory_pair(0, 1))
	assert(ItemPickup.get_merge_amount(player.inventory_slots[1]) == 5 and ItemPickup.get_item_grade(player.inventory_slots[1]) == 2)
	var saved_player := player.get_save_data()
	player.inventory_slots = [{}, {}, {}, {}]
	assert(player.load_save_data(saved_player, 0) and ItemPickup.get_merge_amount(player.inventory_slots[1]) == 5)
	var tooltip := world.get_node("HUD/ItemTooltip") as ItemTooltip
	tooltip.show_item(ItemPickup.make_item("weathered_sword"))
	assert(tooltip._rank.text == "Crude Yellow Sword")
	tooltip.show_item(ItemPickup.make_item("weathered_armor"))
	assert(tooltip._stat_icon.texture.resource_path == "res://Sprites/ShieldIcon.webp" and tooltip._secondary_stat.visible)
	player.health = player.max_health
	player.inventory_slots[0] = ItemPickup.make_item("potion_basic")
	var failure_state := {"failed": false}
	player.item_use_failed.connect(func(_index: int, message: String) -> void: failure_state["failed"] = message == "Full Health")
	assert(not player.consume_inventory_item(0) and bool(failure_state["failed"]) and not player.inventory_slots[0].is_empty())
	assert((world.get_node("HUD/QuestLog") as QuestLog)._button_icon.texture.resource_path == "res://Sprites/iconQuest.webp")
	var story := world.get_node("StoryManager") as StoryManager
	story._seen_events[&"lio_intro"] = true
	assert(story.get_quest_log_entries().size() == 1)
	story._seen_events[&"deru_intro"] = true
	assert(story.get_quest_log_entries().size() == 2)
	var lio_shop := FoxLioShop.new()
	var lucie_shop := FoxLucaShop.new()
	assert(lio_shop._get_shop_title() == "Lios Shop")
	assert(lucie_shop._get_shop_title() == "Lucie's Store")
	assert(lucie_shop._get_resource_offers()[0].price == 2)
	lio_shop.free()
	lucie_shop.free()
	assert(world.map_show_enemies)
	var lio := world.get_node("FoxLio") as FoxLio
	lio.set_hunter_recruited(true, false)
	lio.collect_enemy_item(ItemPickup.make_item("weathered_sword", 1))
	assert(lio._collected_items.size() == 1 and (lio.get_save_data()[-1] as Array).size() == 1)
	player.inventory_slots = [
		ItemPickup.make_item("potion_basic"), ItemPickup.make_item("potion_basic"),
		ItemPickup.make_item("potion_basic"), ItemPickup.make_item("potion_basic"),
	]
	player.equipped_weapons[0] = ItemPickup.make_item("weathered_sword")
	lio.hunt_state = FoxLio.HuntState.WAITING_AT_CAMPFIRE
	lio.authorize_free_reward_handoff()
	lio.begin_reward_delivery()
	var transfer := world.get_node("HUD").get_child(-1) as HelperInventoryTransfer
	assert(transfer != null and transfer._helper_items.size() == 1)
	var helper_slot := transfer._helper_grid.get_child(0) as ItemSlot
	var player_slot := transfer._player_grid.get_child(0) as ItemSlot
	transfer.drop_in_slot(helper_slot, player_slot)
	transfer._confirm()
	assert(lio._collected_items.is_empty() and str(player.inventory_slots[0].get("item_id", "")) == "weathered_sword")
	await create_timer(0.7).timeout
	print("PASS: Sep 1 requested item, quest, shop, potion, and helper state changes")
	world.queue_free()
	await process_frame
	await process_frame
	quit()
