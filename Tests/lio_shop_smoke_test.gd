extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var story := world.get_node("StoryManager") as StoryManager
	var box := world.get_node("HUD/DialogueBox") as DialogueBox
	while box.is_open():
		box.finish_typing()
		box.advance()
	var lio := world.get_node("FoxLio") as FoxLio
	assert(lio != null and not story._has_seen(&"lio_intro"), "Lio must begin with an unseen introduction")
	world.player.global_position = lio.global_position + Vector2(64, 0)
	story._process(0.0)
	assert(not box.is_open(), "Lio must not speak merely because the player is nearby")
	lio.interact()
	assert(_finish_dialogue(box) == " You wouldn’t believe how much work it takes to dig up this gold! What I wouldn’t do for some fish right now, haha!", "Lio's first interaction must use the requested dialogue")
	await process_frame
	var shop := lio._shop as FoxLioShop
	assert(shop != null and shop.visible and shop._rows.size() == 2, "Lio must open his three-offer shop")
	assert(shop.get_panel().find_child("BuyGoldOre", true, false) is Button, "Lio must offer one Gold")
	assert(shop.is_upgrade_visible(0) and not shop.is_upgrade_visible(1), "Lio's Jewel health offer must stay hidden until Jewels have been discovered")
	var resources := world.get_node("ResourceManager") as ResourceManager
	resources.fill_all_to_maximum()
	assert(shop.is_upgrade_visible(1), "Lio's Jewel health offer must appear after obtaining a Jewel")
	var damage_before := world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED)
	assert(shop.get_upgrade_price(0) == 5 and shop.buy_upgrade(0), "Lio's +4 red damage must cost five Fish")
	assert(world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED) == damage_before + 4, "Lio must grant four red damage")
	await create_timer(0.34).timeout
	assert(_finish_dialogue(box) == " Oh man, I'm so hungry, thank you!", "Lio's first purchase must use the requested thank-you line")
	await process_frame
	assert(shop.visible, "Lio's shop must reopen after his first-purchase dialogue")
	var health_before := world.player.max_health
	assert(shop.get_upgrade_price(1) == 5 and shop.buy_upgrade(1), "Lio's health upgrade must cost five Jewels")
	assert(world.player.max_health == health_before + 20, "Lio must grant twenty maximum health")
	resources.spend_resources({&"gold_ore": resources.get_amount(&"gold_ore")})
	var fish_before := resources.get_amount(&"fish")
	assert(shop.buy_resource(&"gold_ore"), "Lio must sell one Gold for two Fish")
	assert(resources.get_amount(&"gold_ore") == 1 and resources.get_amount(&"fish") == fish_before - 2, "Lio's Gold trade must charge exactly two Fish")
	print("PASS: Lio interaction, shop offers, prices, upgrades, and first-purchase dialogue work")
	quit()


func _finish_dialogue(box: DialogueBox) -> String:
	var copy := ""
	while box.is_open():
		box.finish_typing()
		copy += " " + box.get_current_text()
		box.advance()
	return copy
