extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var player := world.player
	var damage_grid := world.get_node("HUD/DamageGrid") as DamageGrid
	for color_index in [FoxPlayer.COLOR_RED, FoxPlayer.COLOR_YELLOW, FoxPlayer.COLOR_BLUE]:
		player.damage_by_color[color_index][0] = 2
	player.damage_matrix_changed.emit()
	await process_frame
	var red_dot := damage_grid._grid.get_child(2).get_child(0) as Polygon2D
	var yellow_dot := damage_grid._grid.get_child(4).get_child(0) as Polygon2D
	var blue_dot := damage_grid._grid.get_child(6).get_child(0) as Polygon2D
	assert(red_dot.color == Color("e53935") and yellow_dot.color == Color("fbc02d") and blue_dot.color == Color("1976d2"), "Damage rows must show red, yellow, then blue dots")
	assert(red_dot.z_index > 0 and yellow_dot.z_index > 0 and blue_dot.z_index > 0, "Damage dots must draw above their table cells")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var fill_key := InputEventKey.new()
	fill_key.pressed = true
	fill_key.physical_keycode = KEY_P
	fill_key.shift_pressed = true
	save_system._unhandled_key_input(fill_key)
	var resource_manager := world.get_node("ResourceManager") as ResourceManager
	assert(resource_manager.get_amount(&"gold_ore") == 10 and resource_manager.get_amount(&"jewels") == 10, "Shift+P must fill every resource to capacity")

	var ore := world.get_node("GoldOre") as GoldOre
	assert(ore.get_current_build_cost() == {"gold_ore": 5, "jewels": 2}, "The first Gold mine must use its base price")
	ore._update_hover_highlight(ore.global_position)
	assert(ore._tile_highlight.visible and is_equal_approx(ore._tile_highlight.width, 2.0) and ore._tile_highlight.default_color == Color.YELLOW, "Hovering an unbuilt ore must show a yellow two-pixel tile outline")
	ore.show_build_button()
	ore._show_build_tooltip()
	await process_frame
	await process_frame
	var tooltip := world.get_node("HUD/BuildMineTooltip") as BuildMineTooltip
	var cost_column := tooltip._content.get_child(0) as VBoxContainer
	var building_icon := tooltip._content.get_child(1) as TextureRect
	var tooltip_style := tooltip.get_theme_stylebox("panel") as StyleBoxFlat
	assert((cost_column.get_child(0) as Label).text == "Costs:" and cost_column.get_child_count() == 3, "Mine tooltip must put Costs and both resource rows on the left")
	assert(building_icon.texture.resource_path == "res://Sprites/MinerStructure.webp" and building_icon.custom_minimum_size == building_icon.texture.get_size(), "Mine tooltip must show its building sprite at full size")
	assert(tooltip_style.content_margin_left == 8.0 and tooltip_style.content_margin_right == 8.0 and tooltip_style.content_margin_top == 8.0 and tooltip_style.content_margin_bottom == 8.0, "Mine tooltip must have an eight-pixel content margin")
	assert(tooltip.get_global_rect().end.y <= ore.build_button.get_global_rect().position.y, "Mine tooltip must appear above the build button")

	ore._try_build_mine()
	assert(is_instance_valid(ore._mine), "The mine must build before shack placement becomes available")
	ore._update_mine_build_hover_label(ore.global_position)
	assert(ore._build_hover_label.visible and ore._build_hover_label is Label and ore._build_hover_label.mouse_filter == Control.MOUSE_FILTER_IGNORE and ore._build_hover_label.get_theme_color("font_color") == Color.WHITE, "A built mine must show a plain white Build label on hover")
	ore.show_build_button()
	assert(not ore._build_hover_label.visible, "The Build hover label must disappear when the mine is clicked")
	var world_map := world.get_node("HUD/WorldMap") as WorldMap
	assert(world_map._canvas._get_marker_sprite(ore._mine).texture.resource_path == "res://Sprites/MinerStructure.webp", "Built producers must expose their sprite to the map overlay")
	var second_ore := world.get_node("GoldOre2") as GoldOre
	assert(second_ore.get_current_build_cost() == {"gold_ore": 7, "jewels": 3}, "A second Gold mine must cost 25 percent more, rounded up per resource")
	ore._update_hover_highlight(ore.global_position)
	assert(ore._tile_highlight.visible, "Hovering a built mine must show the yellow tile outline")
	resource_manager.fill_all_to_maximum()
	ore.show_build_button()
	assert(not ore._shack_buttons.is_empty(), "Clicking a mine must show Build Shack buttons on valid adjacent tiles")
	assert(ore.get_current_shack_cost() == {"gold_ore": 10}, "The first capacity building must cost ten of its stored resource")
	for button in ore._shack_buttons:
		assert(button.text == "Build Shack" and world.can_build_at_cell(Vector2i(button.get_meta("build_cell"))), "Shack buttons must only occupy valid adjacent tiles")
	var first_cell := Vector2i(ore._shack_buttons[0].get_meta("build_cell"))
	ore._try_build_shack(first_cell)
	assert(world.get_tree().get_nodes_in_group("buildings").size() == 1, "Build Shack must create a Gold Shack")
	assert(resource_manager.get_maximum_amount(&"gold_ore") == 25, "Each Gold Shack must add fifteen gold capacity")
	assert(world.is_building_cell(first_cell) and not world.can_build_at_cell(first_cell), "A Gold Shack tile must become occupied for navigation and placement")
	assert(ore.get_current_shack_cost() == {"gold_ore": 13}, "The next capacity building price must rise by 25 percent from the previous rounded price")

	resource_manager.fill_all_to_maximum()
	ore.show_build_button()
	assert(not ore._shack_buttons.is_empty(), "A mine must continue offering other valid adjacent shack tiles")
	var second_cell := Vector2i(ore._shack_buttons[0].get_meta("build_cell"))
	ore._try_build_shack(second_cell)
	assert(resource_manager.get_maximum_amount(&"gold_ore") == 40, "Gold Shack capacity bonuses must stack")
	resource_manager.fill_all_to_maximum()
	assert(resource_manager.get_amount(&"gold_ore") == 40, "Shift+P behavior must respect capacity bonuses")

	var encoded := save_system.create_save_string(1000)
	for shack in get_nodes_in_group("buildings"):
		shack.free()
	assert(resource_manager.get_maximum_amount(&"gold_ore") == 10, "Removing shacks must remove their capacity bonuses")
	assert(save_system.load_save_string(encoded, 1000), "Saves must restore Gold Shacks")
	assert(get_nodes_in_group("buildings").size() == 2 and resource_manager.get_maximum_amount(&"gold_ore") == 40, "Loaded Gold Shacks must restore stacked capacity")
	print("PASS: damage dots, mine interactions, Gold Shacks, and Shift+P work")
	quit()
