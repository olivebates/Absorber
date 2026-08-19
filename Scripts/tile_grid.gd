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
	var used_rect := world.floor_layer.get_used_rect()
	var top_left := world.floor_layer.map_to_local(used_rect.position) - Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	var bottom_right := world.floor_layer.map_to_local(used_rect.end) - Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	for x in range(used_rect.position.x, used_rect.end.x + 1):
		var x_position := top_left.x + (x - used_rect.position.x) * TILE_SIZE
		draw_line(Vector2(x_position, top_left.y), Vector2(x_position, bottom_right.y), Color.BLACK, 2.0, true)
	for y in range(used_rect.position.y, used_rect.end.y + 1):
		var y_position := top_left.y + (y - used_rect.position.y) * TILE_SIZE
		draw_line(Vector2(top_left.x, y_position), Vector2(bottom_right.x, y_position), Color.BLACK, 2.0, true)
