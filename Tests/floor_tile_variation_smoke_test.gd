extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_world: PackedScene = load("res://Scenes/world.tscn")
	assert(packed_world != null, "World scene must load")
	var world := packed_world.instantiate()
	var source_floor := world.get_node("FloorTerrain") as TileMapLayer
	var floor_material := source_floor.material as ShaderMaterial
	assert(floor_material != null and floor_material.shader != null, "Floor tiles must have a variation shader")
	assert(floor_material.get_shader_parameter("color_grid_offset") == Vector2(-32.0, -32.0), "Both color grids must use the requested negative thirty-two pixel offset")
	assert(is_equal_approx(floor_material.get_shader_parameter("hue_shift_degrees"), 15.0), "Hue variation must be limited to fifteen degrees")
	assert(is_equal_approx(floor_material.get_shader_parameter("brightness_shift_points"), 15.0), "Brightness variation must be limited to fifteen percentage points")
	assert(is_equal_approx(floor_material.get_shader_parameter("seam_blend_pixels"), 8.0), "Tile-color seams must be feathered across eight pixels")
	var shader_code := floor_material.shader.code
	assert(shader_code.contains("MODEL_MATRIX * vec4(VERTEX"), "Floor noise cell coordinates must remain locked to the continuous world")
	assert(source_floor.map_to_local(Vector2i.ZERO) == Vector2(32.0, 32.0), "The floor atlas origin must keep its first cell inside the zero-to-sixty-four pixel square")
	assert(shader_code.contains("world_cell_position = world_position / tile_size"), "Color coordinates must use the actual sixty-four-pixel TileMap grid")
	assert(shader_code.contains("floor(world_cell_position)"), "Tile-center colors must remain locked to whole world cells")
	assert(not shader_code.contains("floor((world_position - color_grid_offset)"), "The Perlin offset must not split individual floor tiles")
	assert(shader_code.contains("tile_cell + vec2(0.5) + color_grid_offset / tile_size"), "The requested noise offset must be applied only after selecting the whole floor tile")
	assert(not shader_code.contains("floor((local_position"), "Floor noise must not reset at TileMap render-chunk boundaries")
	assert(shader_code.count("perlin_noise(noise_cell") == 2, "Hue and brightness must each retain one flat Perlin sample per world cell")
	assert(shader_code.count("perlin_noise(continuous_noise_position") == 2, "Hue and brightness must each rejoin a continuous Perlin field at tile edges")
	assert(shader_code.count("* 0.06055") == 2, "Both hue samples must keep the reduced Perlin scale")
	assert(shader_code.count("* 0.04095") == 2, "Both brightness samples must keep the reduced Perlin scale")
	assert(shader_code.contains("distance_to_edge = min(position_in_tile, vec2(1.0) - position_in_tile)"), "Seam blending must be symmetric on every tile edge")
	assert(shader_code.contains("mix(continuous_hue_noise, tile_hue_noise, interior_weight)"), "Hue must become continuous exactly at tile borders")
	assert(shader_code.contains("mix(continuous_brightness_noise, tile_brightness_noise, interior_weight)"), "Brightness must become continuous exactly at tile borders")
	var half_pixel_from_seam := 0.5 / floor_material.get_shader_parameter("tile_size") as float
	var blend_width := floor_material.get_shader_parameter("seam_blend_pixels") / floor_material.get_shader_parameter("tile_size") as float
	var nearest_pixel_interior_weight := smoothstep(0.0, blend_width, half_pixel_from_seam)
	assert(nearest_pixel_interior_weight < 0.02, "The nearest pixel on either side of a seam must use at least ninety-eight percent continuous noise")
	assert(shader_code.contains("hue_noise * hue_shift_degrees, -15.0, 15.0"), "Hue noise must be clamped between negative and positive fifteen")
	assert(shader_code.contains("brightness_noise * brightness_shift_points, -15.0, 15.0"), "Brightness noise must be clamped between negative and positive fifteen")
	world.free()

	print("PASS: floor tiles use world-locked Perlin variation with continuous color across tile seams")
	quit()
