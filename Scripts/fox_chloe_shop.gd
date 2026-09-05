class_name FoxChloeShop
extends FoxShop

const CHLOE_UPGRADES := [
	{
		"resource_id": &"cave_moss", "base_price": 5, "visible_by_default": true,
		"purchase_slot": 0, "amount": 4, "stat_icon": DAMAGE_ICON, "stat": &"damage",
		"color": FoxPlayer.COLOR_BLUE, "name": "Blue Damage",
		"description": "Increase blue damage by 4.",
	},
	{
		"resource_id": &"cave_moss", "base_price": 15, "visible_by_default": true,
		"one_time": true, "purchase_slot": 1, "amount": 1,
		"stat_icon": preload("res://Sprites/ChestClosed.webp"), "stat": &"inventory_slot",
		"name": "Inventory Slot", "description": "Add one extra inventory slot.",
	},
]


func _get_upgrades() -> Array:
	return CHLOE_UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	return [
		{"resource_id": &"herbs", "cost_resource_id": &"cave_moss", "price": 2},
		{"resource_id": &"cave_moss", "cost_resource_id": &"wood", "price": 2},
	]


func _get_shop_title() -> String:
	return "Chloe's Shop"


func _notify_story_purchase(_upgrade_index := -1) -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.on_chloe_purchase()
