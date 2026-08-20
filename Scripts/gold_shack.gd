class_name GoldShack
extends Node2D

const GOLD_CAPACITY_BONUS := 15

@export var resource_id: StringName = &"gold_ore"
@export var capacity_bonus := GOLD_CAPACITY_BONUS
@export var building_type := 0

var _resource_manager: ResourceManager
var _hovered := false


func _ready() -> void:
	add_to_group("buildings")
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if _resource_manager:
		_resource_manager.register_capacity_bonus(self, resource_id, capacity_bonus)


func _process(_delta: float) -> void:
	var hovered := Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(get_global_mouse_position()))
	if hovered == _hovered:
		return
	_hovered = hovered
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	var tooltip := world.get_node_or_null("HUD/BuildMineTooltip") as BuildMineTooltip if world else null
	if tooltip == null:
		return
	if hovered:
		var definition := _resource_manager.get_definition(resource_id) if _resource_manager else null
		tooltip.show_stat(definition.icon if definition else null, "Capacity", "+%d" % capacity_bonus, self)
	else:
		tooltip.hide_tooltip(self)


func _exit_tree() -> void:
	if _resource_manager:
		_resource_manager.unregister_capacity_bonus(self)
