class_name FoxLio
extends FoxAsha


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story and story.interact_with(&"lio"):
		return
	open_shop()


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = FoxLioShop.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()
