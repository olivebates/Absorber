extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var story := world.get_node("StoryManager") as StoryManager
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	var asha := world.get_node("FoxAsha") as FoxAsha
	var lio := world.get_node("FoxLio") as FoxLio
	var deru := world.get_node("FoxDeru") as FoxDeru
	var audio := world.get_node("GameAudio") as GameAudio
	var inventory_panel := world.get_node("HUD/Inventory") as InventoryPanel
	dialogue.cancel()
	var inventory_style := inventory_panel.get_theme_stylebox("panel")
	var expected_inventory_size := inventory_panel._content.get_combined_minimum_size() + inventory_style.get_minimum_size()
	assert(inventory_panel.size.is_equal_approx(expected_inventory_size), "The inventory panel must fit its content")
	# Inventory and equipment signals can refresh this panel more than once in a
	# frame. Old slots must stop participating in layout immediately rather than
	# briefly making the row look like a second, invisible inventory.
	inventory_panel._refresh()
	inventory_panel._refresh()
	inventory_panel._fit_to_content()
	assert(inventory_panel._items.get_child_count() == 6, "Consecutive inventory refreshes must retain exactly the starting six slots")
	assert(inventory_panel.size.is_equal_approx(expected_inventory_size), "Consecutive inventory refreshes must not change the fitted panel size")
	assert(inventory_style.content_margin_left == 8.0 and inventory_style.content_margin_right == 8.0 and inventory_style.content_margin_top == 8.0 and inventory_style.content_margin_bottom == 4.0, "The unified card must split its eight-pixel section gap across the Inventory and Equipment sections")
	var expected_merge_width := InventoryPanel.SLOT_SIZE * InventoryPanel.MERGE_BUTTON_COLUMNS \
		+ InventoryPanel.SLOT_SEPARATION * (InventoryPanel.MERGE_BUTTON_COLUMNS - 1)
	assert(is_equal_approx(inventory_panel._auto_merge_button.size.x, expected_merge_width), "Merge All must occupy the five columns beside the trash slot")
	assert(is_equal_approx(inventory_panel._trash_slot.size.x + InventoryPanel.SLOT_SEPARATION + inventory_panel._auto_merge_button.size.x, inventory_panel._items.size.x), "The trash slot and Merge All must fill one row matching the six-column inventory grid")
	world.player.inventory_slots[0] = ItemPickup.make_item("weathered_sword", 0)
	world.player.equipped_weapons[0] = ItemPickup.make_item("weathered_sword", 0)
	world.player.inventory_changed.emit()
	world.player.equipment_changed.emit()
	await process_frame
	var equipped_pair := world.player.get_next_auto_merge_pair()
	assert(str(equipped_pair.get("source_storage", "")) == "inventory" and str(equipped_pair.get("target_storage", "")) == "weapon", "Merge All must include equipped items and keep the result equipped")
	assert(inventory_panel._auto_merge_button.visible, "Merge All must appear for a match between inventory and equipped items")
	inventory_panel._on_auto_merge_pressed()
	await create_timer(0.35).timeout
	assert(world.player.inventory_slots[0].is_empty() and ItemPickup.get_item_grade(world.player.equipped_weapons[0]) == 1, "Merge All must upgrade matching equipped equipment")
	var player_position := world.player.global_position
	assert(is_equal_approx(audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE), 1.0), "Helper attacks must remain full volume through one tile")
	assert(is_equal_approx(audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 4.0), 4.0 / 7.0), "Helper attacks must fade between one and eight tiles")
	assert(is_zero_approx(audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 8.0)), "Helper attacks must be silent at eight tiles")
	var original_lio_position := lio._original_position
	var original_deru_position := deru._original_position
	var non_helper_save := (world.get_node("SaveSystem") as SaveSystem).create_save_string(900)
	lio.set_hunter_recruited(true)
	deru.set_hunter_recruited(true)
	lio.global_position += Vector2.RIGHT * WorldNavigation.TILE_SIZE * 5.0
	deru.global_position += Vector2.LEFT * WorldNavigation.TILE_SIZE * 5.0
	assert((world.get_node("SaveSystem") as SaveSystem).load_save_string(non_helper_save, 900))
	assert(not lio.is_hunter_recruited() and lio.hunt_state == FoxLio.HuntState.INACTIVE and lio.global_position == original_lio_position, "A non-helper save must reset Lio's role and original position")
	assert(not deru.is_hunter_recruited() and deru.hunt_state == FoxLio.HuntState.INACTIVE and deru.global_position == original_deru_position, "A non-helper save must reset Deru's role and original position")
	story._seen_events[&"asha_recruited"] = true
	story._find_characters()

	assert(asha.is_story_interactable(), "Asha must allow one interaction after joining")
	assert(story.interact_with(&"asha"), "The first post-joining interaction must start dialogue")
	assert(dialogue.get_current_text() == "It's fun being with you :)", "Asha must use her one-time companion line")
	_finish_dialogue(dialogue)
	asha._highlight.visible = true
	asha._process(0.0)
	assert(not asha.is_story_interactable() and not asha._highlight.visible, "Asha must stop highlighting after the companion line")
	assert(world._get_story_character_at_position(asha.global_position) == null, "Asha must no longer intercept movement clicks")
	assert(not world.is_cell_occupied(world.world_to_cell(asha.global_position), world.player), "The player must be able to path onto recruited Asha's tile")

	var encoded := (world.get_node("SaveSystem") as SaveSystem).create_save_string(1000)
	story._seen_events.erase(&"asha_post_recruitment")
	assert((world.get_node("SaveSystem") as SaveSystem).load_save_string(encoded, 1000))
	assert(story.has_seen_event(&"asha_post_recruitment") and not asha.is_story_interactable(), "The one-time Asha interaction must remain consumed after loading")
	print("PASS: inventory fitting/equipped merging, helper reset/audio, and Asha click-through work")
	world.queue_free()
	await process_frame
	await process_frame
	quit()


func _finish_dialogue(dialogue: DialogueBox) -> void:
	while dialogue.is_open():
		dialogue.finish_typing()
		dialogue.advance()
