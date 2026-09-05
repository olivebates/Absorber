class_name MinerStructure
extends Node2D

@export var resource_id: StringName = &"gold_ore"
@export_range(0.001, 9999.0, 0.001, "suffix:/sec") var production_speed := 1.0 / 60.0
@export var produces_resources := true

var _resource_manager: ResourceManager
var _production_time := 0.0
var _hovered := false


func _ready() -> void:
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if _resource_manager and produces_resources:
		_resource_manager.register_producer(self, resource_id, production_speed)


func _process(delta: float) -> void:
	if not produces_resources:
		return
	_update_tooltip()
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


func _update_tooltip() -> void:
	var hovered := Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(get_global_mouse_position()))
	if hovered == _hovered:
		return
	_hovered = hovered
	var tooltip := _get_building_tooltip()
	if tooltip == null:
		return
	if hovered:
		var definition := _resource_manager.get_definition(resource_id) if _resource_manager else null
		tooltip.show_stat(definition.icon if definition else null, "Production", _get_production_tooltip_value(), self)
	else:
		tooltip.hide_tooltip(self)


func _get_production_tooltip_value() -> String:
	return ResourceManager.format_production_rate(production_speed)


func _get_building_tooltip() -> BuildMineTooltip:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	return world.get_node_or_null("HUD/BuildMineTooltip") as BuildMineTooltip if world else null


func get_save_data() -> Array:
	return [maxi(0, roundi(_production_time * 1000.0)), maxi(0, roundi(production_speed * 1000000000.0))]


func load_save_data(data: Variant, offline_seconds: int) -> void:
	var production_milliseconds := 0
	if data is Array:
		var saved := data as Array
		production_milliseconds = maxi(0, int(saved[0])) if not saved.is_empty() else 0
		if saved.size() > 1:
			production_speed = maxf(0.0, float(saved[1]) / 1000000000.0)
	else:
		production_milliseconds = maxi(0, int(data))
	if _resource_manager and produces_resources:
		_resource_manager.register_producer(self, resource_id, production_speed)
	if not produces_resources:
		return
	if _resource_manager == null or production_speed <= 0.0:
		return
	var interval := 1.0 / production_speed
	var total_time := maxf(0.0, float(production_milliseconds) / 1000.0 + maxi(0, offline_seconds))
	var produced_amount := floori(total_time / interval)
	_production_time = fmod(total_time, interval)
	if produced_amount > 0:
		_resource_manager.add_resource(resource_id, float(produced_amount))


func _exit_tree() -> void:
	if _resource_manager and produces_resources:
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
