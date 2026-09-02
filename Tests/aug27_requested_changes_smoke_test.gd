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
	player.skill_swap_tutorial_seen = true
	for skill_id in FoxPlayer.PLAYER_SKILL_IDS:
		player.unlock_player_skill(skill_id)
	var toolbar := world.get_node("HUD/SkillToolbar") as SkillToolbar
	toolbar._open_picker()
	await process_frame
	assert(toolbar._picker_list.columns == 5 and toolbar._picker_list.get_child_count() == 4, "The icon-only skill picker must use a five-column grid")
	assert(toolbar._picker.find_children("*", "Button", true, false).is_empty(), "The skill picker must not contain a Done button")
	for label in toolbar._picker.find_children("*", "Label", true, false):
		assert((label as Label).text.is_empty(), "The skill picker must not draw text")
	assert(toolbar._picker.find_children("MovementDiagram", "Control", true, false).is_empty(), "Movement diagrams must be removed from the picker")
	var compact_slot := toolbar._get_player_slot(0)
	assert(compact_slot.size == Vector2(42, 42) and compact_slot._icon.size == Vector2(32, 32) and compact_slot._icon.position == Vector2(3, 3) and compact_slot._hotkey_label.position == compact_slot.size - Vector2(14, 17), "Center-bar skill slots must remain compact while their icons stay 32 pixels and shifted up-left")
	toolbar._close_picker()
	await process_frame
	compact_slot = toolbar._get_player_slot(0)
	assert(compact_slot.size == Vector2(42, 42) and compact_slot._icon.size == Vector2(32, 32) and compact_slot._icon.position == Vector2(3, 3), "Closing the picker must not resize skill slots or icons")

	var enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	var enemy_cell := _find_attack_fixture(world, player)
	player.global_position = world.cell_to_world(enemy_cell + Vector2i.RIGHT)
	enemy.global_position = world.cell_to_world(enemy_cell)
	enemy.setup(enemy_cell, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 20, 2, FoxPlayer.COLOR_RED, 0, FoxPlayer.COLOR_RED, false, [{
		"skill_id": ChickenEnemy.SKILL_CASCADING_SWEEP, "damage": 10, "damage_type": FoxPlayer.COLOR_RED, "cooldown": 0.0, "initial_offset": 0.0,
	}])
	world.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	player.enemy_skill_move_tutorial_seen = true
	player.cascading_sweep_skill_tutorial_seen = true
	player.follow_enemy(enemy)
	enemy._begin_enemy_skill(0)
	var snare_ring := player.get_node("SnareRing") as Line2D
	assert(player.is_snared() and snare_ring.visible and player.get_node("SnaredLabel").visible \
		and is_equal_approx(snare_ring.width, 3.0) and snare_ring.position == Vector2.ZERO \
		and is_equal_approx(snare_ring.points[0].length(), 31.0), "Cascading attacks must snare Mira with a three-pixel white circle around her sprite")
	player.follow_path(PackedVector2Array([player.global_position + Vector2(64, 0)]))
	assert(not player.is_moving() and player._snare_shake_tween != null, "Trying to move while snared must reject the path and start a 0.2-second shake")
	player.mana = 10
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 0.0
	assert(player.cast_player_skill_slot(0) and not player.is_snared(), "A movement skill must be allowed to cast and break every active snare")
	enemy._reset_enemy_skills()
	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: requested skill picker and cascading snare changes")
	quit()


func _find_attack_fixture(world: WorldNavigation, player: FoxPlayer) -> Vector2i:
	for raw_cell in world._walkable_cells.keys():
		var cell := raw_cell as Vector2i
		var required := [cell, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT]
		var valid := true
		for candidate in required:
			if not world.is_walkable(candidate) or world.is_cell_occupied(candidate, player):
				valid = false
				break
		if valid:
			return cell
	assert(false, "The world fixture must contain room for a cascading snare")
	return Vector2i.ZERO
