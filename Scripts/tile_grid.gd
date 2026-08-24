class_name TileGrid
extends Node2D

const TILE_SIZE := 64.0
const OVERLAY_OPACITY := 0.2


func _ready() -> void:
	z_index = -1
	modulate = Color(1.0, 1.0, 1.0, OVERLAY_OPACITY)
	queue_redraw()


func _process(_delta: float) -> void:
	pass


func _draw() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return
	var obstacle_cells: Dictionary = {}
	for obstacle in get_tree().get_nodes_in_group("solid_walls"):
		if obstacle is Node2D and is_instance_valid(obstacle):
			for cell in world._get_actor_cells(obstacle):
				obstacle_cells[cell] = true
	for cell in world.floor_layer.get_used_cells():
		if obstacle_cells.has(cell):
			continue
		var center := world.floor_layer.map_to_local(cell)
		var half := TILE_SIZE * 0.5
		var top_left := center - Vector2(half, half)
		var top_right := center + Vector2(half, -half)
		var bottom_left := center + Vector2(-half, half)
		var bottom_right := center + Vector2(half, half)
		if not obstacle_cells.has(cell + Vector2i.UP):
			draw_line(top_left, top_right, Color.BLACK, 2.0, true)
		if not obstacle_cells.has(cell + Vector2i.LEFT):
			draw_line(top_left, bottom_left, Color.BLACK, 2.0, true)
		if not obstacle_cells.has(cell + Vector2i.DOWN):
			draw_line(bottom_left, bottom_right, Color.BLACK, 2.0, true)
		if not obstacle_cells.has(cell + Vector2i.RIGHT):
			draw_line(top_right, bottom_right, Color.BLACK, 2.0, true)
	# Obstacles hide their internal grid, but their combined outer silhouette
	# remains outlined against the surrounding walkable tiles.
	for cell in obstacle_cells:
		var center := world.floor_layer.map_to_local(cell)
		var half := TILE_SIZE * 0.5
		var top_left := center - Vector2(half, half)
		var top_right := center + Vector2(half, -half)
		var bottom_left := center + Vector2(-half, half)
		var bottom_right := center + Vector2(half, half)
		if not obstacle_cells.has(cell + Vector2i.UP):
			draw_line(top_left, top_right, Color.BLACK, 2.0, true)
		if not obstacle_cells.has(cell + Vector2i.LEFT):
			draw_line(top_left, bottom_left, Color.BLACK, 2.0, true)
		if not obstacle_cells.has(cell + Vector2i.DOWN):
			draw_line(bottom_left, bottom_right, Color.BLACK, 2.0, true)
		if not obstacle_cells.has(cell + Vector2i.RIGHT):
			draw_line(top_right, bottom_right, Color.BLACK, 2.0, true)
