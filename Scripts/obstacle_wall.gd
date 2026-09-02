class_name ObstacleWall
extends StaticBody2D

@export var footprint_tiles := Vector2i.ONE


func _ready() -> void:
	add_to_group("solid_walls")
	_register_with_navigation()


func _register_with_navigation() -> void:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			(cursor as WorldNavigation).register_navigation_actor(self)
			return
		cursor = cursor.get_parent()


func get_blocked_cells(world: WorldNavigation) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := world.world_to_cell(global_position)
	for y in range(maxi(1, footprint_tiles.y)):
		for x in range(maxi(1, footprint_tiles.x)):
			result.append(origin + Vector2i(x, y))
	return result
