class_name ResourceManager
extends Node

signal resource_changed(resource_id: StringName, amount: int, maximum_amount: int)
signal resource_discovered(resource_id: StringName)
signal production_changed(resource_id: StringName, production_speed: float)

@export var resources: Array[GameResourceDefinition] = [
	preload("res://Resources/gold_ore.tres"),
	preload("res://Resources/jewels.tres"),
]

var _definitions: Dictionary = {}
var _amounts: Dictionary = {}
var _ever_owned: Dictionary = {}
var _producer_speeds: Dictionary = {}


func _ready() -> void:
	add_to_group("resource_manager")
	for definition in resources:
		if definition == null or definition.resource_id.is_empty():
			continue
		_definitions[definition.resource_id] = definition
		_amounts[definition.resource_id] = float(clampi(definition.starting_amount, 0, definition.maximum_amount))
		_ever_owned[definition.resource_id] = definition.starting_amount > 0


func _process(delta: float) -> void:
	for resource_id in _definitions:
		var definition := get_definition(resource_id)
		var production := definition.production_speed if definition else 0.0
		if production > 0.0:
			add_resource(resource_id, production * delta)


func get_definitions() -> Array[GameResourceDefinition]:
	var result: Array[GameResourceDefinition] = []
	for definition in resources:
		if definition != null:
			result.append(definition)
	return result


func get_definition(resource_id: StringName) -> GameResourceDefinition:
	return _definitions.get(resource_id) as GameResourceDefinition


func get_amount(resource_id: StringName) -> int:
	return floori(float(_amounts.get(resource_id, 0.0)))


func get_maximum_amount(resource_id: StringName) -> int:
	var definition := get_definition(resource_id)
	return definition.maximum_amount if definition else 0


func has_ever_owned(resource_id: StringName) -> bool:
	return bool(_ever_owned.get(resource_id, false))


func get_production_speed(resource_id: StringName) -> float:
	var definition := get_definition(resource_id)
	var speed := definition.production_speed if definition else 0.0
	for producer in _producer_speeds.values():
		if producer is Dictionary and StringName(producer.get("resource_id", &"")) == resource_id:
			speed += float(producer.get("speed", 0.0))
	return speed


func add_resource(resource_id: StringName, amount: float) -> int:
	var definition := get_definition(resource_id)
	if definition == null or amount <= 0.0:
		return get_amount(resource_id)
	var was_discovered := has_ever_owned(resource_id)
	var old_amount := get_amount(resource_id)
	_amounts[resource_id] = minf(float(definition.maximum_amount), float(_amounts.get(resource_id, 0.0)) + amount)
	var new_amount := get_amount(resource_id)
	if new_amount > 0:
		_ever_owned[resource_id] = true
	if not was_discovered and has_ever_owned(resource_id):
		resource_discovered.emit(resource_id)
	if old_amount != new_amount:
		resource_changed.emit(resource_id, new_amount, definition.maximum_amount)
	return new_amount


func can_afford(cost: Dictionary) -> bool:
	for raw_resource_id in cost:
		if get_amount(StringName(raw_resource_id)) < int(cost[raw_resource_id]):
			return false
	return true


func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for raw_resource_id in cost:
		var resource_id := StringName(raw_resource_id)
		var definition := get_definition(resource_id)
		if definition == null:
			continue
		var old_amount := get_amount(resource_id)
		_amounts[resource_id] = maxf(0.0, float(_amounts.get(resource_id, 0.0)) - float(cost[raw_resource_id]))
		var new_amount := get_amount(resource_id)
		if old_amount != new_amount:
			resource_changed.emit(resource_id, new_amount, definition.maximum_amount)
	return true


func register_producer(source: Node, resource_id: StringName, production_speed: float) -> void:
	if source == null or get_definition(resource_id) == null:
		return
	_producer_speeds[source.get_instance_id()] = {"resource_id": resource_id, "speed": maxf(0.0, production_speed)}
	production_changed.emit(resource_id, get_production_speed(resource_id))


func unregister_producer(source: Node) -> void:
	if source:
		var producer := _producer_speeds.get(source.get_instance_id()) as Dictionary
		_producer_speeds.erase(source.get_instance_id())
		if not producer.is_empty():
			var resource_id := StringName(producer.get("resource_id", &""))
			production_changed.emit(resource_id, get_production_speed(resource_id))
