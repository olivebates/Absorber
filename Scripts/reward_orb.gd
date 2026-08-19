class_name RewardOrb
extends Node2D

var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _arc_height := 0.0
var _on_arrive: Callable


static func fly(parent: Node, start_position: Vector2, end_position: Vector2, color: Color, on_arrive: Callable) -> RewardOrb:
	var orb := RewardOrb.new()
	orb._start = start_position
	orb._end = end_position
	orb._arc_height = randf_range(46.0, 92.0)
	orb._on_arrive = on_arrive
	orb.global_position = start_position
	orb.z_index = 30
	orb.modulate = color
	orb.add_to_group("reward_orbs")
	parent.add_child(orb)
	orb.queue_redraw()
	var tween := orb.create_tween()
	tween.tween_method(orb._follow_arc, 0.0, 1.0, 0.68).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(orb._finish)
	return orb


func _follow_arc(progress: float) -> void:
	var point := _start.lerp(_end, progress)
	point.y -= sin(progress * PI) * _arc_height
	global_position = point
	rotation = progress * TAU * 1.5


func _finish() -> void:
	if _on_arrive.is_valid():
		_on_arrive.call()
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color.BLACK)
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	draw_circle(Vector2(-1.5, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.85))
