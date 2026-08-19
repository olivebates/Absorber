class_name Campfire
extends Node2D

const TILE_SIZE := 64.0

@export_range(1.0, 10.0, 0.5, "suffix: tiles") var healing_radius_tiles := 2.0


func _ready() -> void:
	add_to_group("campfires")
	queue_redraw()


func is_player_in_range(player: FoxPlayer) -> bool:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null or player == null:
		return false
	var distance := world.world_to_cell(player.global_position) - world.world_to_cell(global_position)
	var radius := ceili(healing_radius_tiles)
	return absi(distance.x) <= radius and absi(distance.y) <= radius


func _draw() -> void:
	var radius := ceili(healing_radius_tiles)
	var half_extent := (float(radius) + 0.5) * TILE_SIZE
	var healing_area := Rect2(Vector2(-half_extent, -half_extent), Vector2.ONE * half_extent * 2.0)
	draw_rect(healing_area, Color(0.45, 0.48, 0.5, 0.20), true)
	draw_rect(healing_area, Color(0.68, 0.72, 0.74, 0.52), false, 2.0)
