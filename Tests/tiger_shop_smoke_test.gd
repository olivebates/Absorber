extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_sprites := ["Snake.webp", "Camel.webp", "Crocodile.webp", "Mouse.webp", "KangarooRat.webp", "MadCoyote.webp"]
	for index in range(expected_sprites.size()):
		var enemy := EnemySpawnPoint.ENEMY_SCENES[index + 8].instantiate() as ChickenEnemy
		assert((enemy.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/%s" % expected_sprites[index], "New enemy variants must use their matching sprites")
		enemy.free()

	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var tiger := get_first_node_in_group("shopkeepers") as WhiteTiger
	assert((tiger.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/WhiteTiger.webp", "The shopkeeper must use WhiteTiger")
	assert((tiger.get_node("Sprite2D") as Sprite2D).flip_h, "The White Tiger must face its horizontally flipped default direction")
	assert(world.is_walkable(world.world_to_cell(tiger.global_position)), "The White Tiger must be placed on a walkable tile")
	assert(world.is_npc_cell(world.world_to_cell(tiger.global_position)), "The White Tiger must block its own tile")
	assert(world._get_shopkeeper_at_position(tiger.global_position) == tiger, "World clicks must find the White Tiger")

	assert(tiger.request_interaction(world.player, world), "Clicking the White Tiger must begin an adjacent route")
	assert(world.player.is_moving(), "The player must walk toward a non-adjacent White Tiger")
	world.player.global_position = world.cell_to_world(world.world_to_cell(tiger.global_position) + Vector2i.LEFT)
	tiger._process(0.0)
	var shop := tiger._shop
	assert(shop != null and shop.visible, "The shop must open once the player is adjacent")
	assert((shop.get_panel().find_child("Title", true, false) as Label).text == "Stats Shop", "The shop must be named Stats Shop")
	assert(shop._rows[0] is Button and shop._rows[0].get_child_count() == 1, "Each upgrade row must be one full-width button")
	assert(shop._price_icons[0].texture.resource_path == "res://Sprites/GoldOreResource.webp" and shop._price_labels[0].text == "5", "The row's right side must show the resource icon and price")
	assert(shop._rows[0].find_child("DamageColorDot", true, false) != null, "Red damage must show a red dot between its stat icon and amount")
	assert(shop._price_labels[0].get_theme_color("font_color") == Color("ef5350"), "Unaffordable shop prices must be red")
	assert(shop.is_upgrade_visible(0), "The Gold upgrade must be visible by default")
	assert(not shop.is_upgrade_visible(1) and not shop.is_upgrade_visible(2) and not shop.is_upgrade_visible(3), "Other upgrades must remain hidden until their resource is discovered")
	var style := shop.get_panel().get_theme_stylebox("panel")
	assert(style.content_margin_left == 8.0 and style.content_margin_right == 8.0 and style.content_margin_top == 8.0 and style.content_margin_bottom == 8.0, "The shop box must have exact eight-pixel content margins")

	var manager := world.get_node("ResourceManager") as ResourceManager
	manager.add_resource(&"jewels", 1.0)
	assert(shop.is_upgrade_visible(1) and not shop.is_upgrade_visible(2), "An upgrade must reveal when its price resource is first acquired")
	manager.fill_all_to_maximum()
	assert(shop.is_upgrade_visible(2) and shop.is_upgrade_visible(3), "Fish and Wood upgrades must reveal after discovery")
	var old_red_damage := world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED)
	assert(shop.get_upgrade_price(0) == 5 and shop.buy_upgrade(0), "The first red damage upgrade must cost five Gold")
	assert(world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED) == old_red_damage + 1 and shop.get_upgrade_price(0) == 10, "Gold must grant red damage and raise its price by five")
	var old_regeneration := world.player.passive_healing_amount
	assert(shop.get_upgrade_price(1) == 5 and shop.buy_upgrade(1), "The first regeneration upgrade must cost five Jewels")
	assert(world.player.passive_healing_amount == old_regeneration + 1 and shop.get_upgrade_price(1) == 10, "Jewels must grant regeneration and raise its price by five")
	var old_max_health := world.player.max_health
	assert(shop.get_upgrade_price(2) == 5 and shop.buy_upgrade(2), "The first Fish health upgrade must cost five Fish")
	assert(world.player.max_health == old_max_health + 20 and shop.get_upgrade_price(2) == 10, "Fish must grant twenty health and raise its price by five")
	assert(shop.get_upgrade_price(3) == 3 and shop.buy_upgrade(3), "The first Wood health upgrade must cost three Wood")
	assert(world.player.max_health == old_max_health + 40 and shop.get_upgrade_price(3) == 6, "Wood must grant twenty health and raise its price by three")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var encoded := save_system.create_save_string(1000)
	tiger.purchase_counts = [0, 0, 0, 0]
	assert(save_system.load_save_string(encoded, 1000), "Shop progression must load")
	assert(tiger.purchase_counts == [1, 1, 1, 1] and not shop.visible, "Purchase counts must persist and loading must close the shop")

	tiger.open_shop()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	shop._unhandled_key_input(escape)
	assert(not shop.visible, "Escape must close the shop")
	tiger.open_shop()
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	shop._on_overlay_gui_input(outside_click)
	assert(not shop.visible, "Clicking outside the shop panel must close it")
	var close_button := shop.get_panel().find_child("CloseButton", true, false) as Button
	assert(close_button != null, "The shop must provide a top-right X button")

	print("PASS: enemy variants, White Tiger interaction, shop upgrades, prices, visibility, and persistence work")
	quit()
