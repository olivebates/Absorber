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
	var shader_code := floor_material.shader.code
	assert(shader_code.contains("MODEL_MATRIX * vec4(VERTEX"), "Floor noise cell coordinates must remain locked to the continuous world")
	assert(source_floor.map_to_local(Vector2i.ZERO) == Vector2(32.0, 32.0), "The floor atlas origin must keep its first cell inside the zero-to-sixty-four pixel square")
	assert(shader_code.contains("floor(world_position / tile_size)"), "Color boundaries must match the actual sixty-four-pixel TileMap boundaries")
	assert(not shader_code.contains("floor((world_position - color_grid_offset)"), "The Perlin offset must not split individual floor tiles")
	assert(shader_code.contains("tile_cell + vec2(0.5) + color_grid_offset / tile_size"), "The requested noise offset must be applied only after selecting the whole floor tile")
	assert(not shader_code.contains("floor((local_position"), "Floor noise must not reset at TileMap render-chunk boundaries")
	assert(shader_code.count("perlin_noise(noise_cell") == 2, "Hue and brightness must sample both Perlin fields once per world cell")
	assert(shader_code.contains("noise_cell * 0.06055"), "Hue Perlin scale must be reduced by thirty percent")
	assert(shader_code.contains("noise_cell * 0.04095"), "Brightness Perlin scale must be reduced by thirty percent")
	assert(shader_code.contains("hue_noise * hue_shift_degrees, -15.0, 15.0"), "Hue noise must be clamped between negative and positive fifteen")
	assert(shader_code.contains("brightness_noise * brightness_shift_points, -15.0, 15.0"), "Brightness noise must be clamped between negative and positive fifteen")
	world.free()

	print("PASS: floor tiles use seamless, tile-locked Perlin hue and brightness variation")
	quit()
