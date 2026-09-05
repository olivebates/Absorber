class_name FoxChloe
extends FoxAsha

const CHLOE_SHOP_SCRIPT := preload("res://Scripts/fox_chloe_shop.gd")
const CHLOE_SAVE_FORMAT := "chloe_shop_v1"


func _ready() -> void:
	purchase_counts = [0, 0]
	super._ready()


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story and story.interact_with(&"chloe"):
		return
	open_shop()


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = CHLOE_SHOP_SCRIPT.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()


func get_save_data() -> Array:
	return [CHLOE_SAVE_FORMAT, purchase_counts.duplicate()]


func load_save_data(data: Array) -> bool:
	purchase_counts = [0, 0]
	if data.size() >= 2 and str(data[0]) == CHLOE_SAVE_FORMAT and data[1] is Array:
		var saved_counts := data[1] as Array
		for index in range(purchase_counts.size()):
			purchase_counts[index] = maxi(0, int(saved_counts[index])) if index < saved_counts.size() else 0
	_stop_patrol()
	close_shop()
	return true
