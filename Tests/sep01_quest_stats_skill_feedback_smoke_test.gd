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
	var quest_log := world.get_node("HUD/QuestLog") as QuestLog
	var inventory := world.get_node("HUD/Inventory") as Control
	assert(quest_log._button_icon.texture.resource_path == "res://Sprites/iconQuest.webp")
	assert(quest_log._button_icon.modulate == Color(1.5, 1.5, 1.5, 1.0), "The quest sprite must be 50% brighter")
	assert((quest_log._button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a == 1.0, "The quest button must have an opaque background")
	assert(quest_log._button.get_global_rect().position == (inventory as InventoryPanel).get_quest_anchor_rect().position, "The Quest Log button must be embedded in the Inventory header")

	var story := world.get_node("StoryManager") as StoryManager
	story._seen_events[&"lio_intro"] = true
	await process_frame
	var lio_quest := story.get_quest_log_entries()[0] as Dictionary
	assert(lio_quest.get("location") == "Tiny Woods")
	assert(quest_log.find_child("QuestUpdateDot", true, false) != null, "A started quest must fly a red dot from Mira")
	quest_log._expanded[&"lio_automation"] = true
	quest_log.open()
	await process_frame
	assert((quest_log.find_child("Quest_lio_automation", true, false) as Button).text.contains("(Tiny Woods)"))
	quest_log.close()
	story._seen_events[&"deru_intro"] = true
	await process_frame
	var deru_quest := story.get_quest_log_entries()[1] as Dictionary
	assert(deru_quest.get("location") == "Snakemouth Expanse")
	await create_timer(0.58).timeout
	assert(quest_log._absorb_tween != null and quest_log._absorb_tween.is_valid(), "The quest button must pulse as it absorbs an update")

	var tooltip := world.get_node("HUD/ItemTooltip") as ItemTooltip
	var damage_grid := world.get_node("HUD/DamageGrid") as DamageGrid
	player.add_color_damage(FoxPlayer.COLOR_RED, 1)
	await process_frame
	_hover_and_assert(damage_grid._color_target_cells[FoxPlayer.COLOR_RED] as Control, "Red Damage", tooltip)
	var vitals := world.get_node("HUD/PlayerVitals") as PlayerVitals
	_hover_and_assert(vitals.find_child("HealthCell", true, false) as Control, "Health", tooltip)
	_hover_and_assert(vitals.find_child("RegenerationCell", true, false) as Control, "Health Regeneration", tooltip)
	_hover_and_assert(vitals.find_child("ManaCell", true, false) as Control, "Mana", tooltip)
	_hover_and_assert(vitals.find_child("ManaRegenerationCell", true, false) as Control, "Mana Regeneration", tooltip)
	player.add_color_defense(FoxPlayer.COLOR_RED, 1)
	await process_frame
	var armor_grid := world.get_node("HUD/ArmorGrid") as ArmorGrid
	_hover_and_assert(armor_grid._grid.get_child(2) as Control, "Red Defense", tooltip)

	player.unlocked_player_skills = [FoxPlayer.SKILL_ROLL_CLOCKWISE]
	player.equipped_player_skills[0] = FoxPlayer.SKILL_ROLL_CLOCKWISE
	player.player_skill_slots_unlocked[0] = true
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 2.0
	assert(not player.cast_player_skill_slot(0))
	var cooldown_popup := player.get_node("ItemStatusPopup") as Label
	assert(cooldown_popup.text == "Cooling Down" and cooldown_popup.get_theme_font_size("font_size") == 28)
	cooldown_popup.free()
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 0.0
	player.mana = 0
	assert(not player.cast_player_skill_slot(0))
	var mana_popup := player.get_node("ItemStatusPopup") as Label
	assert(mana_popup.text == "No Mana" and mana_popup.get_theme_color("font_color") == Color("ef4444"))

	print("PASS: quest update absorption, locations, stat tooltips, and skill failure text")
	world.queue_free()
	await process_frame
	await process_frame
	quit()


func _hover_and_assert(control: Control, expected_title: String, tooltip: ItemTooltip) -> void:
	assert(control != null, "The requested stat control must exist: %s" % expected_title)
	control.mouse_entered.emit()
	assert(tooltip.visible and tooltip._rank.text == expected_title, "Stat tooltip mismatch for %s" % expected_title)
	control.mouse_exited.emit()
