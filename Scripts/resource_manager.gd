class_name ResourceManager
extends Node

signal resource_changed(resource_id: StringName, amount: int, maximum_amount: int)
signal resource_discovered(resource_id: StringName)
signal production_changed(resource_id: StringName, production_speed: float)

@export var resources: Array[GameResourceDefinition] = [
	preload("res://Resources/gold_ore.tres"),
	preload("res://Resources/jewels.tres"),
	preload("res://Resources/fish.tres"),
	preload("res://Resources/wood.tres"),
	preload("res://Resources/cave_moss.tres"),
]

var _definitions: Dictionary = {}
var _amounts: Dictionary = {}
var _ever_owned: Dictionary = {}
var _producer_speeds: Dictionary = {}
var _capacity_bonuses: Dictionary = {}


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
	if definition == null:
		return 0
	var maximum := definition.maximum_amount
	for bonus in _capacity_bonuses.values():
		if bonus is Dictionary and StringName(bonus.get("resource_id", &"")) == resource_id:
			maximum += int(bonus.get("amount", 0))
	return maximum


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
	var maximum_amount := get_maximum_amount(resource_id)
	_amounts[resource_id] = minf(float(maximum_amount), float(_amounts.get(resource_id, 0.0)) + amount)
	var new_amount := get_amount(resource_id)
	if new_amount > 0:
		_ever_owned[resource_id] = true
	if not was_discovered and has_ever_owned(resource_id):
		resource_discovered.emit(resource_id)
	if old_amount != new_amount:
		resource_changed.emit(resource_id, new_amount, maximum_amount)
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
			resource_changed.emit(resource_id, new_amount, get_maximum_amount(resource_id))
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


func register_capacity_bonus(source: Node, resource_id: StringName, amount: int) -> void:
	if source == null or get_definition(resource_id) == null:
		return
	_capacity_bonuses[source.get_instance_id()] = {"resource_id": resource_id, "amount": maxi(0, amount)}
	var definition := get_definition(resource_id)
	resource_changed.emit(resource_id, get_amount(resource_id), get_maximum_amount(resource_id))
	if definition and get_amount(resource_id) > 0:
		_ever_owned[resource_id] = true


func unregister_capacity_bonus(source: Node) -> void:
	if source == null:
		return
	var bonus := _capacity_bonuses.get(source.get_instance_id()) as Dictionary
	_capacity_bonuses.erase(source.get_instance_id())
	if bonus.is_empty():
		return
	var resource_id := StringName(bonus.get("resource_id", &""))
	var maximum_amount := get_maximum_amount(resource_id)
	_amounts[resource_id] = minf(float(_amounts.get(resource_id, 0.0)), float(maximum_amount))
	resource_changed.emit(resource_id, get_amount(resource_id), maximum_amount)


func fill_all_to_maximum() -> void:
	for resource_id in _definitions:
		var maximum_amount := get_maximum_amount(resource_id)
		var was_discovered := has_ever_owned(resource_id)
		_amounts[resource_id] = float(maximum_amount)
		_ever_owned[resource_id] = true
		if not was_discovered:
			resource_discovered.emit(resource_id)
		resource_changed.emit(resource_id, maximum_amount, maximum_amount)


func get_save_data() -> Array:
	var result: Array = [0]
	var discovery_mask := 0
	for index in range(resources.size()):
		var definition := resources[index]
		if definition == null:
			result.append(0)
			continue
		result.append(roundi(float(_amounts.get(definition.resource_id, 0.0)) * 1000.0))
		if has_ever_owned(definition.resource_id):
			discovery_mask |= 1 << index
	result[0] = discovery_mask
	result.append("production_v1")
	var production_speeds: Array[int] = []
	for definition in resources:
		production_speeds.append(maxi(0, roundi(definition.production_speed * 1000000000.0)) if definition else 0)
	result.append(production_speeds)
	return result


func load_save_data(data: Array) -> bool:
	if data.is_empty():
		return false
	var discovery_mask := int(data[0])
	var production_marker_index := data.find("production_v1")
	if production_marker_index < 0:
		production_marker_index = resources.size() + 1
	var saved_production_speeds: Array = []
	if data.size() > production_marker_index + 1 and str(data[production_marker_index]) == "production_v1" and data[production_marker_index + 1] is Array:
		saved_production_speeds = data[production_marker_index + 1] as Array
	for index in range(resources.size()):
		var definition := resources[index]
		if definition == null:
			continue
		var amount_milliseconds := int(data[index + 1]) if index + 1 < mini(data.size(), production_marker_index) else 0
		if index < saved_production_speeds.size():
			definition.production_speed = maxf(0.0, float(saved_production_speeds[index]) / 1000000000.0)
		var maximum_amount := get_maximum_amount(definition.resource_id)
		_amounts[definition.resource_id] = clampf(float(amount_milliseconds) / 1000.0, 0.0, float(maximum_amount))
		_ever_owned[definition.resource_id] = (discovery_mask & (1 << index)) != 0
		if has_ever_owned(definition.resource_id):
			resource_discovered.emit(definition.resource_id)
		resource_changed.emit(definition.resource_id, get_amount(definition.resource_id), maximum_amount)
		production_changed.emit(definition.resource_id, get_production_speed(definition.resource_id))
	return true
