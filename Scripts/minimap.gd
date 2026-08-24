class_name Minimap
extends Control

const ENEMY_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const VISIBLE_RADIUS_TILES := 8.0
const REDRAW_INTERVAL := 0.1

var _world: WorldNavigation
var _redraw_time_left := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -194.0
	offset_top = 60.0
	offset_right = -12.0
	offset_bottom = 196.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_connect_world")


func _connect_world() -> void:
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation


func _process(delta: float) -> void:
	_redraw_time_left -= delta
	if _redraw_time_left <= 0.0:
		_redraw_time_left = REDRAW_INTERVAL
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.055, 0.9), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, false, 2.0)
	if _world == null or _world._navigation_region.size.x <= 0 or _world._navigation_region.size.y <= 0:
		return
	var map_rect := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	draw_rect(map_rect, Color(0.12, 0.16, 0.13, 1.0), true)
	draw_rect(map_rect, Color(0.0, 0.0, 0.0, 1.0), false, 1.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy):
			var dot_position := _world_to_minimap(enemy.global_position, map_rect)
			draw_circle(dot_position, 4.0, Color.BLACK)
			draw_circle(dot_position, 2.5, ENEMY_COLORS[clampi(enemy.enemy_color, 0, ENEMY_COLORS.size() - 1)])
	for shopkeeper in get_tree().get_nodes_in_group("shopkeepers"):
		if shopkeeper is Node2D and is_instance_valid(shopkeeper):
			var shop_position := _world_to_minimap(shopkeeper.global_position, map_rect)
			draw_circle(shop_position, 4.0, Color.BLACK)
			draw_circle(shop_position, 2.5, Color("ffe082"))
	var player := _world.player if _world else null
	if player:
		var player_position := map_rect.get_center()
		draw_circle(player_position, 3.5, Color.BLACK)
		draw_circle(player_position, 2.0, Color.WHITE)


func _world_to_minimap(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var cell := _world.world_to_cell(world_position)
	var player := _world.player if _world else null
	if player == null:
		return map_rect.get_center()
	var player_cell := _world.world_to_cell(player.global_position)
	var cell_offset := cell - player_cell
	var tile_size := minf(map_rect.size.x, map_rect.size.y) / (VISIBLE_RADIUS_TILES * 2.0 + 1.0)
	var position := map_rect.get_center() + Vector2(cell_offset) * tile_size
	return Vector2(
		clampf(position.x, map_rect.position.x, map_rect.end.x),
		clampf(position.y, map_rect.position.y, map_rect.end.y)
	)
