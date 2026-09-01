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

	var world_map := world.get_node("HUD/WorldMap") as WorldMap
	var canvas := world_map._canvas
	var minimap := world.get_node("HUD/Minimap") as Minimap
	var matching_cell := Vector2i(2147483647, 2147483647)
	for cell in world.floor_layer.get_used_cells():
		var atlas := world.floor_layer.get_cell_atlas_coords(cell)
		if atlas.y == 1 and atlas.x >= 0 and atlas.x < 3:
			matching_cell = cell
			break
	assert(matching_cell.x != 2147483647, "The painted world must contain a first-three/second-row FloorTiles cell")
	assert(canvas._get_floor_color(matching_cell) == Color("44442b"), "The full map must color that FloorTiles row #44442B")
	assert(minimap._get_floor_color(matching_cell) == Color("44442b"), "The minimap must color that FloorTiles row #44442B")

	var missing_cell := world.world_to_cell(world.player.global_position)
	var search_region := world._navigation_region
	for y in range(search_region.position.y, search_region.end.y):
		for x in range(search_region.position.x, search_region.end.x):
			var candidate := Vector2i(x, y)
			if world.floor_layer.get_cell_source_id(candidate) == -1:
				missing_cell = candidate
				break
		if world.floor_layer.get_cell_source_id(missing_cell) == -1:
			break
	assert(world.floor_layer.get_cell_source_id(missing_cell) == -1, "The test world must expose an unpainted map coordinate")
	assert(not canvas._should_draw_floor_cell(missing_cell), "Unpainted coordinates must leave the full map's black background visible")

	var story := world.get_node("StoryManager") as StoryManager
	story._seen_events[&"lio_intro"] = true
	var quest_log := world.get_node("HUD/QuestLog") as QuestLog
	quest_log._expanded[&"lio_automation"] = true
	quest_log.open()
	await process_frame
	await process_frame
	var line := quest_log.find_child("CompletedCrossout", true, false) as Line2D
	assert(line != null and line.get_parent() is Label, "A completed quest step must have a cross-out line")
	var label := line.get_parent() as Label
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var expected_start := font.get_string_size(str(label.get_meta("step_prefix")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var expected_width := font.get_string_size(str(label.get_meta("step_text")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	assert(is_equal_approx(line.points[0].x, expected_start), "The cross-out must begin at the first objective character")
	assert(is_equal_approx(line.points[1].x - line.points[0].x, expected_width), "The cross-out must be exactly as wide as the objective text")
	assert(line.points[0].y > 0.0 and line.points[0].y < font.get_height(font_size), "The cross-out must overlap the rendered font height")

	print("PASS: quest cross-outs and map tile/background colors use exact visual bounds")
	world.queue_free()
	await process_frame
	await process_frame
	quit()
