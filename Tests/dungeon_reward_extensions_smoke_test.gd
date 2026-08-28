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
	var chest := load("res://Scenes/dungeon_chest.tscn").instantiate() as DungeonChest
	world.add_child(chest)

	var inventory_before := player.inventory_slots.size()
	chest.reward_type = DungeonChest.RewardType.INVENTORY_SLOT
	chest.reward_amount = 2
	chest._grant_reward(player)
	assert(player.inventory_slots.size() == inventory_before + 2, "Inventory-slot chest rewards must add visible inventory slots")
	var inventory_panel := world.get_node("HUD/Inventory") as InventoryPanel
	inventory_panel._refresh()
	assert(inventory_panel._items.get_child_count() == player.inventory_slots.size(), "The inventory panel must render every rewarded slot")

	chest.reward_type = DungeonChest.RewardType.EQUIPMENT_SLOT
	chest.reward_amount = 1
	chest._grant_reward(player)
	assert(player.equipment_slots_unlocked == 2 and player.is_equipment_slot_unlocked(1), "Equipment-slot chest rewards must unlock the next weapon and armor positions")

	chest.reward_type = DungeonChest.RewardType.SKILL_SLOT
	chest._grant_reward(player)
	assert(bool(player.player_skill_slots_unlocked[1]), "Skill-slot chest rewards must unlock the next skill-bar position")
	var saved_player := player.get_save_data()
	assert(int(saved_player[34]) == inventory_before + 2 and int(saved_player[35]) == 2, "Rewarded inventory and equipment slot counts must be saved")

	var scorpion := load("res://Scenes/evil_scorpion_enemy.tscn").instantiate() as ChickenEnemy
	assert((scorpion.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/EvilScorpion.webp", "The Evil Scorpion enemy must use the supplied sprite")
	scorpion.free()
	var spawn := EnemySpawnPoint.new()
	spawn.enemy_type = 22
	spawn.enemy_skill_1 = ChickenEnemy.SKILL_CASCADING_SURROUND
	assert(spawn._get_enemy_scene().resource_path == "res://Scenes/evil_scorpion_enemy.tscn", "Enemy spawn points must expose Evil Scorpion as a selectable enemy")
	assert(int(spawn._get_enemy_skills()[0].skill_id) == ChickenEnemy.SKILL_CASCADING_SURROUND, "Enemy spawn points must expose Cascading Surround as a selectable skill")
	var added_enemy_sprites := ["Toad", "DungBeetle", "Spider", "Salamander"]
	for index in range(added_enemy_sprites.size()):
		spawn.enemy_type = 23 + index
		var added_enemy := spawn._get_enemy_scene().instantiate() as ChickenEnemy
		assert((added_enemy.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/%s.webp" % added_enemy_sprites[index], "%s must use its supplied sprite" % added_enemy_sprites[index])
		added_enemy.free()
	spawn.free()

	var enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	var enemy_cell := _find_attack_fixture(world, player)
	player.global_position = world.cell_to_world(enemy_cell + Vector2i.RIGHT)
	enemy.global_position = world.cell_to_world(enemy_cell)
	enemy.setup(enemy_cell, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 20, 2, FoxPlayer.COLOR_RED, 0, FoxPlayer.COLOR_RED, false, [{
		"skill_id": ChickenEnemy.SKILL_CASCADING_SURROUND, "damage": 10, "damage_type": FoxPlayer.COLOR_RED, "cooldown": 0.0, "initial_offset": 0.0,
	}])
	world.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy._begin_enemy_skill(0)
	assert(enemy._active_skill_targets.size() == 6, "Cascading Surround must include Cascading Sweep's four tiles plus both tiles beside its caster")
	var side_cells := [enemy_cell + Vector2i.UP, enemy_cell + Vector2i.DOWN]
	for side_cell in side_cells:
		var found := false
		for target in enemy._active_skill_targets:
			if target.cell == side_cell and is_equal_approx(float(target.delay), 0.4):
				found = true
				break
		assert(found, "Each tile beside a Cascading Surround caster must strike after 0.4 seconds")
	enemy._reset_enemy_skills()
	var current_player_cell := world.world_to_cell(player.global_position)
	var patterned_skills := [
		[ChickenEnemy.SKILL_FAN_STRIKE_QUICK, 0.8, [world.cell_to_world(current_player_cell), world.cell_to_world(current_player_cell + Vector2i.UP), world.cell_to_world(current_player_cell + Vector2i.DOWN)]],
		[ChickenEnemy.SKILL_FAN_STRIKE_CHARGED, 1.5, [world.cell_to_world(current_player_cell), world.cell_to_world(current_player_cell + Vector2i.UP), world.cell_to_world(current_player_cell + Vector2i.DOWN)]],
		[ChickenEnemy.SKILL_DRIVING_STRIKE_QUICK, 0.8, [world.cell_to_world(current_player_cell), world.cell_to_world(current_player_cell + Vector2i.RIGHT)]],
		[ChickenEnemy.SKILL_DRIVING_STRIKE_CHARGED, 1.5, [world.cell_to_world(current_player_cell), world.cell_to_world(current_player_cell + Vector2i.RIGHT)]],
	]
	for skill_test in patterned_skills:
		enemy.enemy_skills = [{"skill_id": int(skill_test[0]), "damage": 10, "damage_type": FoxPlayer.COLOR_RED, "cooldown": 0.0, "initial_offset": 0.0}]
		enemy._skill_cooldowns = [0.0]
		enemy._begin_enemy_skill(0)
		var expected_positions := skill_test[2] as Array
		assert(is_equal_approx(enemy._active_skill_windup, float(skill_test[1])) and enemy._active_skill_targets.size() == expected_positions.size(), "Each new enemy-skill version must use its authored pattern and windup")
		for target_index in range(enemy._active_skill_targets.size()):
			var target := enemy._active_skill_targets[target_index] as Dictionary
			assert(expected_positions.has((target.telegraph as Node2D).global_position) and is_equal_approx(float(target.delay), 0.0 if target_index == 0 else 0.2), "New enemy-skill secondary tiles must resolve 0.2 seconds after the player tile")
		enemy._reset_enemy_skills()
	spawn = EnemySpawnPoint.new()
	spawn.enemy_skill_1 = ChickenEnemy.SKILL_DRIVING_STRIKE_CHARGED
	assert(int(spawn._get_enemy_skills()[0].skill_id) == ChickenEnemy.SKILL_DRIVING_STRIKE_CHARGED, "Spawn inspectors must expose all new enemy-skill variants")
	spawn.free()

	var toolbar := world.get_node("HUD/SkillToolbar") as SkillToolbar
	assert(dialogue.play([{"speaker": "Mira", "text": "A skill reward", "portrait": SkillToolbar.PLAYER_PORTRAIT}]), "The tutorial regression needs an open reward dialogue")
	assert(player.unlock_player_skill(FoxPlayer.SKILL_ROLL_CLOCKWISE), "The first tutorial skill must unlock")
	assert(player.unlock_player_skill(FoxPlayer.SKILL_ROLL_BACK), "Back Roll must unlock for the swap tutorial")
	await process_frame
	assert(toolbar._swap_tutorial_pending and not toolbar._swap_tutorial_active, "The swap tutorial must wait until the reward dialogue is dismissed")
	dialogue.close()
	await create_timer(2.05).timeout
	assert(dialogue.is_open() and dialogue.get_current_speaker() == "Mira" and dialogue.get_current_text() == SkillToolbar.SKILL_SWAP_TUTORIAL_TEXT, "Two seconds after dismissing the second-skill reward, Mira must explain the swap button")
	assert(toolbar._swap_tutorial_active and toolbar._picker_button.has_theme_stylebox_override("normal") and dialogue.mouse_filter == Control.MOUSE_FILTER_IGNORE and dialogue._continue_label.text == "Click the yellow button to continue.", "The swap button must glow and the dialogue hint must direct the player to it")
	assert(world.gameplay_paused, "The player must not move during the swap dialogue")
	toolbar._toggle_picker()
	assert(not dialogue.is_open() and not player.skill_swap_tutorial_seen and toolbar._picker.visible, "Clicking the swap button must open the picker without completing the drag tutorial")
	assert(absf(toolbar._picker.get_global_rect().get_center().x - toolbar._player_row.get_global_rect().get_center().x) < 1.0 \
		and toolbar._picker.get_global_rect().end.y <= toolbar._player_row.get_global_rect().position.y, "The skill picker must be centered above the player skill bar")
	var back_roll := toolbar._get_picker_slot(FoxPlayer.SKILL_ROLL_BACK)
	assert(back_roll != null and back_roll.tutorial_glowing, "Back Roll must glow until the player starts dragging it")
	toolbar.begin_skill_drag(FoxPlayer.SKILL_ROLL_BACK, back_roll)
	assert(not back_roll.tutorial_glowing and (toolbar._get_player_slot(toolbar._tutorial_target_slot) as SkillSlot).tutorial_glowing, "Dragging Back Roll must move the yellow glow to its target skill slot")
	toolbar.end_skill_drag()
	assert(back_roll.tutorial_glowing, "Releasing Back Roll before placing it must restore its glow")
	toolbar.begin_skill_drag(FoxPlayer.SKILL_ROLL_BACK, back_roll)
	toolbar.drop_skill({"source_kind": "picker", "source_index": -1, "skill_id": FoxPlayer.SKILL_ROLL_BACK}, toolbar._get_player_slot(toolbar._tutorial_target_slot))
	toolbar.end_skill_drag()
	assert(player.skill_swap_tutorial_seen and toolbar._picker.visible and not world.gameplay_paused, "Dropping Back Roll into the highlighted slot must complete the tutorial, resume play, and keep arranging open")
	assert((toolbar._get_player_slot(0) as SkillSlot).size == Vector2(42, 42) and (toolbar._get_player_slot(0) as SkillSlot)._icon.size == Vector2(32, 32) and toolbar._picker_status.contains("Back Roll equipped"), "Skill slots must match equipment slots without enlarging their icons")
	assert(toolbar._picker_list.columns == 5 and toolbar._picker.find_children("*", "Button", true, false).is_empty(), "The picker must be an icon-only five-column grid without a Done button")
	for label in toolbar._picker.find_children("*", "Label", true, false):
		assert((label as Label).text.is_empty(), "The picker must not show skill names, instructions, or a diagram legend")
	var quick_roll := toolbar._get_picker_slot(FoxPlayer.SKILL_ROLL_CLOCKWISE)
	var cursor_point := Vector2(300, 280)
	toolbar.start_cursor_skill_drag(FoxPlayer.SKILL_ROLL_CLOCKWISE, quick_roll)
	toolbar._update_cursor_skill_drag(cursor_point)
	assert(toolbar._drag_active and toolbar._cursor_drag_preview.get_global_rect().get_center() == cursor_point, "Clicking a picker skill must immediately center it beneath the cursor")
	var snap_target := toolbar._get_player_slot(0)
	toolbar._finish_cursor_skill_drag(snap_target.get_global_rect().get_center() + Vector2(23, 0))
	assert(player.equipped_player_skills[0] == FoxPlayer.SKILL_ROLL_CLOCKWISE and toolbar._picker.visible and toolbar._picker_status.contains("Quick Roll equipped"), "Releasing within 24 pixels must snap the dragged skill into an unlocked slot")
	assert(not toolbar.has_method("select_skill_for_click") and not toolbar.has_method("click_player_slot"), "Click-select-then-click-slot assignment must be removed")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	toolbar._input(escape)
	assert(not toolbar._picker.visible and (toolbar._get_player_slot(0) as SkillSlot).size == Vector2(42, 42), "Escape must close arranging mode without resizing its inventory-sized slots")
	toolbar._toggle_picker()
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2.ZERO
	toolbar._input(outside_click)
	assert(not toolbar._picker.visible, "Clicking outside the picker and skill bar must close arranging mode")
	toolbar._toggle_picker()
	assert(toolbar._picker.visible and toolbar._picker.find_children("*", "Button", true, false).is_empty(), "Reopened arranging mode must remain free of a Done button")
	toolbar._close_picker()

	chest.queue_free()
	enemy.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: chest slot rewards persist, Evil Scorpion/Cascading Surround are configured, and the swap tutorial is enforced")
	quit()


func _find_attack_fixture(world: WorldNavigation, player: FoxPlayer) -> Vector2i:
	for raw_cell in world._walkable_cells.keys():
		var cell := raw_cell as Vector2i
		var required := [cell, cell + Vector2i.RIGHT, cell + Vector2i.RIGHT * 2, cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.RIGHT + Vector2i.UP, cell + Vector2i.RIGHT + Vector2i.DOWN]
		var valid := true
		for candidate in required:
			if not world.is_walkable(candidate) or world.is_cell_occupied(candidate, player):
				valid = false
				break
		if valid:
			return cell
	assert(false, "The world fixture must contain room for Cascading Surround")
	return Vector2i.ZERO
