extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var player := world.player
	var banners = world.get_node("HUD/MergeUpgradeBanners")
	player.inventory_slots = [
		ItemPickup.make_item("weathered_sword"),
		ItemPickup.make_item("weathered_sword"),
		ItemPickup.make_item("weathered_armor"),
		ItemPickup.make_item("weathered_armor"),
		{}, {},
	]
	assert(player.merge_inventory_pair(0, 1), "Matching weapons must merge")
	assert(banners._active_banners.size() == 1, "The first merge banner must appear immediately")
	var weapon_banner: Control = banners._active_banners[0]
	var weapon_text := weapon_banner.find_child("BannerText", true, false) as Label
	var weapon_icon := weapon_banner.find_child("ItemIcon", true, false) as TextureRect
	assert(weapon_text.text == "Damage 5 -> 10", "Weapon merge banners must show the old and new damage")
	assert(weapon_text.get_theme_color("font_color") == Color.WHITE, "Merge banner text must always be white")
	assert(weapon_icon.texture == ItemPickup.ITEM_TEXTURES["weathered_sword"], "Merge banners must use the merged item's icon")
	var weapon_strip := weapon_banner.get_node("BannerStrip") as Panel
	var weapon_style := weapon_strip.get_theme_stylebox("panel") as StyleBoxFlat
	assert(weapon_style.bg_color == ItemPickup.get_grade_color(1), "Merge banners must use the new item's grade color")
	var weapon_shadow := weapon_banner.get_node("BannerShadow") as Panel
	var shadow_style := weapon_shadow.get_theme_stylebox("panel") as StyleBoxFlat
	assert(shadow_style.bg_color.a > 0.0 and weapon_shadow.position.y > weapon_strip.position.y, "The full-width banner must have a visible offset shadow")
	assert(weapon_text.get_theme_color("font_shadow_color").a > 0.0, "The upgrade text must have a visible shadow")
	assert(is_equal_approx(weapon_banner.position.y + weapon_banner.size.y * 0.5, banners.size.y * 0.25), "The first banner must be centered one quarter from the top")
	assert(is_equal_approx(weapon_strip.size.x, banners.size.x), "The grade banner must span the entire screen width")
	assert(player.merge_inventory_pair(2, 3), "Matching armor must merge")
	assert(banners._active_banners.size() == 1, "Simultaneous merge banners must be staggered")
	await create_timer(0.25).timeout
	assert(banners._active_banners.size() == 2, "The next merge banner must appear after the 0.2 second stagger")
	var armor_banner: Control = banners._active_banners[1]
	assert((armor_banner.find_child("BannerText", true, false) as Label).text == "Armor 2 -> 4", "Armor merge banners must report armor upgrades")
	assert(armor_banner.position.y > weapon_banner.position.y, "Concurrent banners must stack below the first")
	await create_timer(0.35).timeout
	var weapon_content := weapon_banner.get_node("BannerContent") as HBoxContainer
	assert(is_equal_approx(weapon_strip.position.x, 0.0), "The grade strip must finish entering from the right")
	assert(is_equal_approx(weapon_content.position.x, (banners.size.x - weapon_content.size.x) * 0.5), "The icon and text must finish entering from the left at screen center")
	assert(is_equal_approx(weapon_content.modulate.a, 1.0), "The icon and text must be fully visible during the three-second hold")
	assert(is_equal_approx(banners.HOLD_SECONDS, 3.0), "The completed banner must hold for exactly three seconds")
	await create_timer(3.0).timeout
	assert(weapon_strip.position.x < 0.0, "After its three-second hold, the grade strip must leave through the left side")
	assert(weapon_content.modulate.a < 1.0, "The centered icon and text must fade while the strip exits left")
	await create_timer(0.5).timeout
	assert(not is_instance_valid(weapon_banner), "The banner must clean itself up after leaving the screen")
	print("PASS: Merge upgrade banners show actual stats, full-width opposing motion, shadows, stacking, and timing")
	world.queue_free()
	await process_frame
	quit()
