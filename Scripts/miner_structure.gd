class_name MinerStructure
extends Node2D

@export var resource_id: StringName = &"gold_ore"
@export_range(0.001, 9999.0, 0.001, "suffix:/sec") var production_speed := 1.0 / 60.0

var _resource_manager: ResourceManager
var _production_time := 0.0


func _ready() -> void:
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if _resource_manager:
		_resource_manager.register_producer(self, resource_id, production_speed)


func _process(delta: float) -> void:
	if _resource_manager == null or production_speed <= 0.0:
		return
	_production_time += delta
	var interval := 1.0 / production_speed
	while _production_time >= interval:
		_production_time -= interval
		var previous_amount := _resource_manager.get_amount(resource_id)
		var new_amount := _resource_manager.add_resource(resource_id, 1.0)
		if new_amount > previous_amount and _is_on_screen():
			_show_production_feedback()


func _exit_tree() -> void:
	if _resource_manager:
		_resource_manager.unregister_producer(self)


func _is_on_screen() -> bool:
	var screen_position := get_global_transform_with_canvas().origin
	return Rect2(Vector2.ZERO, get_viewport_rect().size).has_point(screen_position)


func _show_production_feedback() -> void:
	var label := Label.new()
	label.text = "+1"
	label.position = Vector2(-10, -46)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("60e870"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 20
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -74.0, 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.70).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
