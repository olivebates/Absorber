class_name FoxLuca
extends FoxAsha

const LUCA_SHOP_SCRIPT := preload("res://Scripts/fox_luca_shop.gd")


func _ready() -> void:
	purchase_counts = [0, 0, 0, 0]
	super._ready()


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story and story.interact_with(&"luca"):
		return
	open_shop()


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = LUCA_SHOP_SCRIPT.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()


func get_save_data() -> Array:
	var data: Array = purchase_counts.duplicate()
	data.append(roundi(global_position.x))
	data.append(roundi(global_position.y))
	return data


func load_save_data(data: Array) -> bool:
	purchase_counts = []
	var old_order := data.size() >= 8
	var count_indices := [3, 5, 1, 2] if old_order else [0, 1, 2, 3]
	for index in count_indices:
		purchase_counts.append(maxi(0, int(data[index])) if index < data.size() else 0)
	var position_index := 6 if old_order else 4
	if data.size() >= position_index + 2 and _world:
		var saved_position := Vector2(float(data[position_index]), float(data[position_index + 1]))
		if _world.is_walkable(_world.world_to_cell(saved_position)):
			global_position = saved_position
	_stop_patrol()
	close_shop()
	return true
