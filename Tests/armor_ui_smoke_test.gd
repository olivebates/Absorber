extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var player := world.player
	var armor_grid := world.get_node("HUD/ArmorGrid")
	var vitals := world.get_node("HUD/PlayerVitals")
	assert(not armor_grid.visible, "The armor grid must remain hidden until a shield has been equipped")
	assert((vitals.find_child("HealthIcon", true, false) as TextureRect).texture.resource_path == "res://Sprites/Heart.webp", "Vitals must use the Heart icon")
	assert((vitals.find_child("HealthValue", true, false) as Label).text == "%d/%d" % [player.health, player.max_health], "Vitals must show current and maximum health")
	assert((vitals.find_child("RegenerationIcon", true, false) as TextureRect).texture.resource_path == "res://Sprites/RecoveryHeart.webp" and (vitals.find_child("RegenerationValue", true, false) as Label).text == str(player.passive_healing_amount), "Vitals must show the regeneration icon and amount")

	assert(player.collect_item("weathered_armor") and not player.get_slot_item("armor", 0).is_empty(), "A collected shield must auto-equip into an empty slot")
	assert(armor_grid.visible and armor_grid._grid.get_child_count() == 4, "Equipping the first shield must reveal the initial two-by-two armor grid")
	assert((armor_grid.find_child("ShieldIcon", true, false) as TextureRect).texture.resource_path == "res://Sprites/ShieldIcon.webp", "The armor header must use ShieldIcon")
	assert((armor_grid.find_children("DefenseValue", "Label", true, false)[0] as Label).text == "2", "Armor values must not include a leading minus")
	player.add_color_damage(FoxPlayer.COLOR_RED, 1)
	await process_frame
	var damage_grid := world.get_node("HUD/DamageGrid") as DamageGrid
	armor_grid._process(0.0)
	vitals._process(0.0)
	assert(damage_grid.visible and armor_grid.position.x >= damage_grid.position.x + damage_grid.size.x + 5.0, "The armor grid must sit to the right of the damage grid")
	assert(vitals.position.y >= maxf(damage_grid.position.y + damage_grid.size.y, armor_grid.position.y + armor_grid.size.y), "The vital cells must sit beneath the combat grids")

	player.add_color_defense(FoxPlayer.COLOR_YELLOW, 1)
	assert(armor_grid._grid.get_child_count() == 6, "Yellow armor must appear after its first color-defense increase")
	player.add_color_defense(FoxPlayer.COLOR_BLUE, 1)
	assert(armor_grid._grid.get_child_count() == 8, "Blue armor must appear after its first color-defense increase")

	player.health = 10
	player.take_damage(5, FoxPlayer.COLOR_YELLOW)
	assert(player.health == 8, "Yellow damage must be reduced by yellow defense plus shield block")
	player.health = 10
	player.add_color_defense(FoxPlayer.COLOR_BLUE, 99)
	player.take_damage(5, FoxPlayer.COLOR_BLUE)
	assert(player.health == 9, "Color defense must never reduce incoming damage below one")

	var saved := player.get_save_data()
	player.defense_by_color = [0, 0, 0]
	player.armor_ever_equipped = false
	assert(player.load_save_data(saved, 0), "Player armor state must load")
	assert(player.get_base_defense_for_color(FoxPlayer.COLOR_YELLOW) == 1 and player.get_base_defense_for_color(FoxPlayer.COLOR_BLUE) == 100 and player.armor_ever_equipped, "Color defense and armor-grid discovery must persist")
	print("PASS: player vitals, progressive armor grid, color defense, and persistence work")
	quit()
