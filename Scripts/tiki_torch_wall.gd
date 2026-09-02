class_name TikiTorchWall
extends StaticBody2D


func _ready() -> void:
	add_to_group("solid_walls")
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			(cursor as WorldNavigation).register_navigation_actor(self)
			return
		cursor = cursor.get_parent()
