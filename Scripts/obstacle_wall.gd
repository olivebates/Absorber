class_name ObstacleWall
extends StaticBody2D

@export var footprint_tiles := Vector2i.ONE


func _ready() -> void:
	add_to_group("solid_walls")


func get_blocked_cells(world: WorldNavigation) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := world.world_to_cell(global_position)
	for y in range(maxi(1, footprint_tiles.y)):
		for x in range(maxi(1, footprint_tiles.x)):
			result.append(origin + Vector2i(x, y))
	return result
