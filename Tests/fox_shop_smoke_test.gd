extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_sprites := ["Snake.webp", "Camel.webp", "Crocodile.webp", "Mouse.webp", "KangarooRat.webp", "MadCoyote.webp"]
	for index in range(expected_sprites.size()):
		var enemy := (load(EnemySpawnPoint.ENEMY_SCENES[index + 8]) as PackedScene).instantiate() as ChickenEnemy
		assert((enemy.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/%s" % expected_sprites[index], "New enemy variants must use their matching sprites")
		enemy.free()

	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue_box := world.get_node("HUD/DialogueBox") as DialogueBox
	while dialogue_box.is_open():
		dialogue_box.finish_typing()
		dialogue_box.advance()
	(world.get_node("StoryManager") as StoryManager).completed_dialogues = 2
	var shopkeeper := get_first_node_in_group("shopkeepers") as FoxAsha
	assert((shopkeeper.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FoxAsha.webp", "The shopkeeper must use FoxAsha")
	assert((shopkeeper.get_node("Sprite2D") as Sprite2D).flip_h, "FoxAsha must face its horizontally flipped default direction")
	assert(world.is_walkable(world.world_to_cell(shopkeeper.global_position)), "FoxAsha must be placed on a walkable tile")
	assert(world.is_npc_cell(world.world_to_cell(shopkeeper.global_position)), "FoxAsha must block its own tile")
	assert(world._get_shopkeeper_at_position(shopkeeper.global_position) == shopkeeper, "World clicks must find FoxAsha")

	# The authored player start can move between world-balance passes. Find a nearby
	# reachable approach cell so this test measures shop routing, not map progression.
	var route_started := shopkeeper.request_interaction(world.player, world)
	if not route_started:
		var shopkeeper_cell := world.world_to_cell(shopkeeper.global_position)
		for candidate in world.floor_layer.get_used_cells():
			var distance := absi(candidate.x - shopkeeper_cell.x) + absi(candidate.y - shopkeeper_cell.y)
			if distance <= 1 or distance > 6 or world.is_cell_occupied(candidate, world.player):
				continue
			world.player.global_position = world.cell_to_world(candidate)
			if shopkeeper.request_interaction(world.player, world):
				route_started = true
				break
	assert(route_started, "Clicking FoxAsha must begin an adjacent route")
	assert(world.player.is_moving(), "The player must walk toward a non-adjacent FoxAsha")
	world.player.global_position = world.cell_to_world(world.world_to_cell(shopkeeper.global_position) + Vector2i.LEFT)
	shopkeeper._process(0.0)
	assert(dialogue_box.is_open() and dialogue_box.get_current_text() == "Oh, there you are! Welcome back :)", "Asha must greet the player on the first interaction")
	while dialogue_box.is_open():
		dialogue_box.finish_typing()
		dialogue_box.advance()
	await process_frame
	var shop := shopkeeper._shop
	assert(shop != null and shop.visible, "The shop must open after Asha's first-interaction dialogue")
	assert((shop.get_panel().find_child("Title", true, false) as Label).text == "Store", "The shop must be named Store")
	assert(shop.get_panel().find_child("BuyFish", true, false) is Button and shop.get_panel().find_child("BuyWood", true, false) is Button, "Fish and Wood purchases must appear at the top of the Store")
	var fish_button := shop.get_panel().find_child("BuyFish", true, false) as Button
	assert(not fish_button.disabled and not shop._rows[0].disabled, "Unaffordable Store buttons must remain hoverable")
	var hover_style := fish_button.get_theme_stylebox("hover") as StyleBoxFlat
	var normal_style := fish_button.get_theme_stylebox("normal") as StyleBoxFlat
	assert(hover_style.bg_color != normal_style.bg_color, "Store buttons must visibly light up on hover")
	shop._show_shop_tooltip(fish_button, "Buy Fish", "Buy 1 Fish for 2 Gold.")
	var instant_tooltip := world.get_node("HUD/ItemTooltip") as ItemTooltip
	assert(instant_tooltip.visible and instant_tooltip._rank.text == "Buy Fish" and not instant_tooltip._stat.visible, "Resource purchase popups must omit their last line")
	shop._show_shop_tooltip(shop._rows[0], "Upgrade", "+1 Armor")
	assert(not instant_tooltip._rank.visible and instant_tooltip._stat.visible, "Stat purchase popups must omit the Upgrade heading but retain their stat description")
	shop._hide_shop_tooltip()
	assert(shop._rows[0] is Button and shop._rows[0].get_child_count() == 1, "Each upgrade row must be one full-width button")
	assert(shop._price_icons[0].texture.resource_path == "res://Sprites/GoldOreResource.webp" and shop._price_labels[0].text == "5", "The row's right side must show the resource icon and price")
	assert(shop._rows[0].find_child("DamageColorDot", true, false) != null, "Red damage must show a red dot between its stat icon and amount")
	assert(shop._price_labels[0].get_theme_color("font_color") == Color("ef5350"), "Unaffordable shop prices must be red")
	assert(shop.is_upgrade_visible(0), "The Gold upgrade must be visible by default")
	assert(not shop.is_upgrade_visible(1) and not shop.is_upgrade_visible(2) and not shop.is_upgrade_visible(3), "Other upgrades must remain hidden until their resource is discovered")
	var style := shop.get_panel().get_theme_stylebox("panel")
	assert(style.content_margin_left == 8.0 and style.content_margin_right == 8.0 and style.content_margin_top == 8.0 and style.content_margin_bottom == 8.0, "The shop box must have exact eight-pixel content margins")

	var manager := world.get_node("ResourceManager") as ResourceManager
	manager.add_resource(&"gold_ore", 4.0)
	assert(shop.buy_resource(&"fish"), "Fish must be purchasable for two Gold")
	assert(shop.visible, "Purchase feedback must play before the first-purchase dialogue closes the shop")
	await create_timer(0.34).timeout
	assert(not shop.visible and dialogue_box.is_open() and dialogue_box.get_current_text() == "Thank you!", "The first purchase must close the shop for the thank-you dialogue")
	while dialogue_box.is_open():
		dialogue_box.finish_typing()
		dialogue_box.advance()
	await process_frame
	assert(shop.visible, "The shop must reopen after the first-purchase dialogue")
	assert(shop.buy_resource(&"wood"), "Wood must be purchasable for two Gold without repeating the dialogue")
	assert(manager.get_amount(&"gold_ore") == 0 and manager.get_amount(&"fish") == 1 and manager.get_amount(&"wood") == 1, "Store resource purchases must charge two Gold and grant one resource")
	manager.add_resource(&"jewels", 1.0)
	assert(shop.is_upgrade_visible(1) and shop.is_upgrade_visible(2) and shop.is_upgrade_visible(3), "Store purchases and resource acquisition must reveal their matching upgrades")
	manager.fill_all_to_maximum()
	assert(shop.is_upgrade_visible(2) and shop.is_upgrade_visible(3), "Fish and Wood upgrades must reveal after discovery")
	var old_red_damage := world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED)
	assert(shop.get_upgrade_price(0) == 5 and shop.buy_upgrade(0), "The first red damage upgrade must cost five Gold")
	assert(world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED) == old_red_damage + 1 and shop.get_upgrade_price(0) == 10, "Gold must grant red damage and raise its price by five")
	var old_max_health := world.player.max_health
	assert(shop.get_upgrade_price(1) == 5 and shop.buy_upgrade(1), "The first Fish health upgrade must cost five Fish")
	assert(world.player.max_health == old_max_health + 20 and shop.get_upgrade_price(1) == 10, "Fish must grant twenty health and raise its price by five")
	assert(shop.get_upgrade_price(2) == 3 and shop.buy_upgrade(2), "The first Wood health upgrade must cost three Wood")
	assert(world.player.max_health == old_max_health + 40 and shop.get_upgrade_price(2) == 6, "Wood must grant twenty health and raise its price by three")
	var old_regeneration := world.player.passive_healing_amount
	assert(shop.get_upgrade_price(3) == 5 and shop.buy_upgrade(3), "The first regeneration upgrade must cost five Jewels")
	assert(world.player.passive_healing_amount == old_regeneration + 1 and shop.get_upgrade_price(3) == 10, "Jewels must grant regeneration and raise its price by five")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var encoded := save_system.create_save_string(1000)
	shopkeeper.purchase_counts = [0, 0, 0, 0]
	assert(save_system.load_save_string(encoded, 1000), "Shop progression must load")
	assert(shopkeeper.purchase_counts == [1, 1, 1, 1] and not shop.visible, "Purchase counts must persist and loading must close the shop")

	shopkeeper.open_shop()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shop._unhandled_key_input(escape)
	assert(not shop.visible, "Escape must close the shop")
	shopkeeper.open_shop()
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	shop._on_overlay_gui_input(outside_click)
	assert(not shop.visible, "Clicking outside the shop panel must close it")
	var close_button := shop.get_panel().find_child("CloseButton", true, false) as Button
	assert(close_button != null, "The shop must provide a top-right X button")

	print("PASS: enemy variants, FoxAsha interaction, shop upgrades, prices, visibility, and persistence work")
	quit()
