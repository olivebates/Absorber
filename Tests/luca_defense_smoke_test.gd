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
		dialogue.close()
	var luca := world.get_node("FoxLuca") as FoxLuca
	assert(luca != null and (luca.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FoxLuca.webp", "Luca must use the FoxLuca WebP sprite")
	assert((luca.get_node("Sprite2D") as Sprite2D).scale == Vector2.ONE, "Luca must use the regular fox sprite scale")
	assert(world.is_walkable(world.world_to_cell(luca.global_position)) and world.is_npc_cell(world.world_to_cell(luca.global_position)), "Luca must stand on and block a walkable tile")

	luca.open_shop()
	var shop := luca._shop
	assert(shop is FoxLucaShop and shop.visible and shop._rows.size() == 8, "Luca must open a separate expanded store")
	assert(shop.get_upgrade_price(0) == 7 and shop.get_upgrade_price(1) == 3 and shop.get_upgrade_price(2) == 10 and shop.get_upgrade_price(3) == 8, "Luca's upgrades must be ordered damage, armor, health, regeneration")
	assert(shop.get_panel().find_child("BuyFish", true, false) and shop.get_panel().find_child("BuyJewels", true, false), "Luca must trade both Fish and Gems")

	var resources := world.get_node("ResourceManager") as ResourceManager
	resources.fill_all_to_maximum()
	assert(resources.spend_resources({&"fish": 1}), "The trade test must make room for a Fish")
	var gems_before_fish := resources.get_amount(&"jewels")
	var fish_before := resources.get_amount(&"fish")
	assert(shop.buy_resource(&"fish") and resources.get_amount(&"fish") == fish_before + 1 and resources.get_amount(&"jewels") == gems_before_fish - 1, "One Fish must cost one Gem")
	assert(resources.spend_resources({&"jewels": 1}), "The trade test must make room for a Gem")
	var gold_before_gem := resources.get_amount(&"gold_ore")
	var gems_before := resources.get_amount(&"jewels")
	assert(shop.buy_resource(&"jewels") and resources.get_amount(&"jewels") == gems_before + 1 and resources.get_amount(&"gold_ore") == gold_before_gem - 5, "One Gem must cost five Gold")
	var old_values := [world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED), world.player.get_base_defense_for_color(FoxPlayer.COLOR_RED), world.player.max_health, world.player.passive_healing_amount]
	for index in range(4):
		resources.fill_all_to_maximum()
		assert(shop.buy_upgrade(index), "Every Luca upgrade must be purchasable for its listed currency")
	assert(world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED) == old_values[0] + 1, "Seven Wood must grant one red damage")
	assert(world.player.get_base_defense_for_color(FoxPlayer.COLOR_RED) == old_values[1] + 1 and world.get_node("HUD/ArmorGrid").visible, "Three Gold must grant red defense and reveal the armor grid")
	assert(world.player.max_health == old_values[2] + 40, "Ten Fish must grant forty max health")
	assert(world.player.passive_healing_amount == old_values[3] + 1, "Eight Gems must grant one regeneration")
	assert(shop.get_upgrade_price(0) == 7 and shop.get_upgrade_price(3) == 8, "Luca's listed prices must remain fixed")
	var saved_counts := luca.purchase_counts.duplicate()
	var encoded := (world.get_node("SaveSystem") as SaveSystem).create_save_string(1000)
	luca.purchase_counts = [0, 0, 0, 0]
	assert((world.get_node("SaveSystem") as SaveSystem).load_save_string(encoded, 1000) and luca.purchase_counts == saved_counts, "Luca's separate shop progression must survive save/load")

	var enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	enemy.setup(Vector2i.ZERO, 2, ChickenEnemy.REWARD_DEFENSE, [], &"gold_ore", FoxPlayer.COLOR_RED, 3, 1, FoxPlayer.COLOR_RED, 0, FoxPlayer.COLOR_BLUE)
	world.add_child(enemy)
	await process_frame
	assert(enemy.reward_icon.texture.resource_path == "res://Sprites/ShieldIcon.webp", "Defense rewards must display the shield icon")
	var blue_defense := world.player.get_base_defense_for_color(FoxPlayer.COLOR_BLUE)
	enemy._grant_kill_reward()
	await create_timer(0.7).timeout
	assert(world.player.get_base_defense_for_color(FoxPlayer.COLOR_BLUE) == blue_defense + 2, "A blue defense spawn reward must grant blue defense on arrival")

	dialogue.play([{"speaker": "Luca", "text": "Left to right.", "portrait": (luca.get_node("Sprite2D") as Sprite2D).texture}])
	assert(dialogue._text_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and dialogue._continue_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "NPC dialogue must type left-to-right")
	var dialogue_style := (dialogue._bottom.get_child(0) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert(dialogue_style.content_margin_left >= 26.0 and dialogue_style.content_margin_right >= 26.0, "Dialogue must retain generous horizontal content margins")
	print("PASS: Luca shop, defense rewards, armor visibility, and NPC dialogue direction work")
	quit()
