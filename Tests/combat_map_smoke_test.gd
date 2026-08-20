extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame

	var spawn := EnemySpawnPoint.new()
	spawn.enemy_damage = 7
	spawn.enemy_damage_color = FoxPlayer.COLOR_YELLOW
	spawn.enemy_armor = 3
	world.add_child(spawn)
	var enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	enemy.setup(Vector2i.ZERO, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 10, spawn.enemy_damage, spawn.enemy_damage_color, spawn.enemy_armor)
	world.add_child(enemy)
	await process_frame
	assert(enemy.enemy_color == FoxPlayer.COLOR_YELLOW and enemy.armor == 3, "One spawn color must configure both enemy damage and damage resistance")
	assert(enemy.get_node_or_null("CombatStats") == null and enemy.color_dot.color == Color("fbc02d"), "Enemy health bars must use the original compact color-dot row")
	var enemy_health := enemy.health
	enemy.take_damage(3)
	assert(enemy.health == enemy_health - 1, "Enemy armor may reduce damage, but never below one")
	world.player.defense = 999
	var player_health := world.player.health
	world.player.take_damage(2)
	assert(world.player.health == player_health - 1, "Hidden player defense may reduce damage, but never below one")
	var player_save := world.player.get_save_data()
	world.player.defense = 0
	assert(world.player.load_save_data(player_save, 0) and world.player.defense == 999, "The hidden player defense stat must persist")

	var ore := world.get_tree().get_nodes_in_group("gold_ores")[0] as GoldOre
	var ore_cell := world.world_to_cell(ore.global_position)
	assert(world.find_path(world.player.global_position, ore.global_position, world.player).is_empty(), "Players must pathfind around deposits instead of onto them")
	world.player.global_position = ore.global_position
	var escape_cell := Vector2i(-999, -999)
	for offset in GoldOre.ADJACENT_OFFSETS:
		var candidate: Vector2i = ore_cell + Vector2i(offset)
		if world.is_walkable(candidate) and not world.is_cell_occupied(candidate):
			escape_cell = candidate
			break
	assert(escape_cell != Vector2i(-999, -999), "The tested ore must have an escape tile")
	assert(world.can_enter_position(world.player, world.player.global_position + Vector2(4, 0)), "An actor already overlapping a deposit must be allowed to leave")
	assert(not world.find_path(world.player.global_position, world.cell_to_world(escape_cell), world.player).is_empty(), "An actor overlapping a deposit must ignore its current deposit as a wall")

	var tiger := get_first_node_in_group("shopkeepers") as WhiteTiger
	assert(tiger._highlight.default_color == Color.YELLOW, "White Tiger hover must use a yellow tile border")
	var home_cell := tiger._home_cell
	tiger._pause_time_left = 0.0
	tiger._choose_patrol_path()
	if tiger._path.size() > 1:
		var patrol_target := world.world_to_cell(tiger._path[-1])
		assert((patrol_target - home_cell).length_squared() <= 4, "White Tiger patrols must remain within two tiles")

	var map := world.get_node("HUD/WorldMap") as WorldMap
	var campfire := get_first_node_in_group("campfires") as Campfire
	world.load_exploration_save_data([])
	world.player.global_position = campfire.global_position
	world._update_exploration()
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	map._unhandled_key_input(tab)
	assert(map.visible and map._canvas._campfire_buttons.size() == 1, "The map must only show visited campfires")
	var other_campfire: Campfire
	for node in get_nodes_in_group("campfires"):
		if node != campfire:
			other_campfire = node as Campfire
	assert(other_campfire != null and not world.is_campfire_visited(other_campfire), "Unvisited campfires must remain behind fog of war")
	world.player.global_position = Vector2.ZERO
	map._canvas._teleport_to_campfire(campfire)
	assert(world.player.global_position == campfire.global_position and not map.visible, "Selecting a campfire must teleport the player and close the map")

	assert(map._canvas._get_floor_color(Vector2i.ZERO) is Color, "Map floor types must resolve to terrain colors")
	print("PASS: merged combat color, armor, navigation blockers, tiger patrol, and fogged campfire map work")
	quit()
