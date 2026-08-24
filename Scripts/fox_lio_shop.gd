class_name FoxLioShop
extends FoxShop

const LIO_UPGRADES := [
	{"resource_id": &"fish", "base_price": 5, "fixed_price": true, "visible_by_default": true, "amount": 4, "stat_icon": DAMAGE_ICON, "stat": &"damage", "color": FoxPlayer.COLOR_RED, "name": "Red Damage", "description": "Increase red damage by 4."},
	{"resource_id": &"jewels", "base_price": 5, "fixed_price": true, "amount": 20, "stat_icon": HEALTH_ICON, "stat": &"health", "name": "Max Health", "description": "Increase maximum health by 20."},
]


func _get_upgrades() -> Array:
	return LIO_UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	return [{"resource_id": &"gold_ore", "cost_resource_id": &"fish", "price": 2}]


func _notify_story_purchase(_upgrade_index := -1) -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.on_lio_purchase()
