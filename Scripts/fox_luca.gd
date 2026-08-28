class_name FoxLuca
extends FoxAsha

const LUCA_SHOP_SCRIPT := preload("res://Scripts/fox_luca_shop.gd")
const LUCA_SAVE_FORMAT := "luca_shop_v2"


func _ready() -> void:
	purchase_counts = [0, 0, 0, 0, 0, 0, 0, 0]
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
	return [LUCA_SAVE_FORMAT, purchase_counts.duplicate()]


func load_save_data(data: Array) -> bool:
	purchase_counts = []
	if data.size() >= 2 and str(data[0]) == LUCA_SAVE_FORMAT and data[1] is Array:
		var saved_counts := data[1] as Array
		for index in range(FoxLucaShop.LUCA_UPGRADES.size()):
			purchase_counts.append(maxi(0, int(saved_counts[index])) if index < saved_counts.size() else 0)
	else:
		var old_order := data.size() >= 8
		var count_indices := [3, 5, 1, 2, -1] if old_order else [0, 1, 2, 3, 4]
		for index in count_indices:
			purchase_counts.append(maxi(0, int(data[index])) if index >= 0 and index < data.size() else 0)
		while purchase_counts.size() < FoxLucaShop.LUCA_UPGRADES.size():
			purchase_counts.append(0)
	# Keep Luca at the position authored in the current scene. Saved coordinates
	# are deliberately ignored so map edits take effect for existing saves.
	_stop_patrol()
	close_shop()
	return true
