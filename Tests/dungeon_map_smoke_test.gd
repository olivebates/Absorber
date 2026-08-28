extends SceneTree


func _init() -> void:
	assert(WorldMapCanvas.DUNGEON_WALL_COLOR == Color.BLACK and Minimap.DUNGEON_WALL_COLOR == Color.BLACK, "Dungeon walls must render black on both maps")
	var stairs_scene := load("res://Scenes/dungeon_stairs.tscn") as PackedScene
	assert(stairs_scene != null, "The reusable dungeon stairs scene must load")
	var stairs := stairs_scene.instantiate() as Node2D
	assert(stairs != null and stairs.has_method("request_interaction") and (stairs.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/Stairs.webp", "Dungeon stairs must use the Stairs sprite and provide dungeon interaction")
	assert(stairs.is_in_group("dungeon_interactables") and stairs.is_in_group("solid_walls"), "Dungeon stairs must be a blocking dungeon interactable")
	stairs.free()

	var level := DungeonLevel.new()
	for property in level.get_property_list():
		assert(str(property.get("name", "")) != "room_cells", "DungeonLevel must not expose predefined rooms in code or the Inspector")
	level._navigation_rooms = [Vector2i.ZERO]
	level._build_dungeon_navigation()
	level._ensure_room_available(Vector2i.RIGHT)
	level._ensure_room_available(Vector2i(2, 0))
	level._reveal_room(Vector2i.ZERO)
	assert(level.get_map_cells().size() == level.room_size_tiles.x * level.room_size_tiles.y, "Only the visited entry room should be exposed to dungeon maps")
	assert(level.get_map_region() == Rect2i(Vector2i.ZERO, level.room_size_tiles), "Generated but unvisited rooms must not affect dungeon map bounds")
	assert(not level.is_cell_explored(level.room_size_tiles + Vector2i(1, 1)), "Generated rooms must remain hidden from the map and minimap until visited")

	var dynamic_room := Vector2i(-2, 3)
	var saved_exploration: Array = []
	var origin := dynamic_room * level.room_size_tiles
	for y in range(origin.y, origin.y + level.room_size_tiles.y):
		for x in range(origin.x, origin.x + level.room_size_tiles.x):
			saved_exploration.append([x, y])
	level._restore_explored_cells(saved_exploration)
	assert(level._navigation_rooms.has(dynamic_room), "Saved exploration must restore dynamically visited rooms at arbitrary coordinates")
	assert(level._navigation_region.has_point(origin), "Restored dynamic rooms must be rebuilt into dungeon navigation")
	assert(level.get_map_cells().size() == level.room_size_tiles.x * level.room_size_tiles.y * 2, "Restored maps must include exactly the rooms that were visited")
	var expected_region := Rect2i(
		Vector2i(dynamic_room.x * level.room_size_tiles.x, 0),
		Vector2i((1 - dynamic_room.x) * level.room_size_tiles.x, (dynamic_room.y + 1) * level.room_size_tiles.y)
	)
	assert(level.get_map_region() == expected_region, "Dungeon map bounds must expand to dynamically visited room coordinates")

	var canvas := WorldMapCanvas.new()
	canvas._world = level
	canvas.size = Vector2(900, 540)
	assert(canvas._get_map_region() == expected_region, "The full map canvas must use visited dungeon bounds rather than navigation bounds")
	canvas.free()
	var minimap := Minimap.new()
	minimap._world = level
	var map_rect := Rect2(Vector2(5, 5), Vector2(172, 126))
	var fixed_diameter := int(Minimap.VISIBLE_RADIUS_TILES * 2.0 + 1.0)
	var expected_scale := minf(map_rect.size.x / fixed_diameter, map_rect.size.y / fixed_diameter)
	assert(minimap._get_display_region().size == Vector2i.ONE * fixed_diameter and minimap._get_tile_scale(map_rect).is_equal_approx(Vector2.ONE * expected_scale), "The minimap must keep a fixed tile scale instead of zooming out to visited bounds")
	minimap.free()
	level.free()
	print("Dungeon map smoke test passed")
	quit()
