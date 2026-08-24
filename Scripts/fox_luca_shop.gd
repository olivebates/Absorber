class_name FoxLucaShop
extends FoxShop

const LUCA_UPGRADES := [
	{"resource_id": &"jewels", "base_price": 10, "fixed_price": true, "purchase_slot": 0, "amount": 2, "stat_icon": preload("res://Sprites/ShieldIcon.webp"), "stat": &"defense", "color": FoxPlayer.COLOR_RED, "name": "Defense", "description": "Increase defense by 2."},
	{"resource_id": &"fish", "base_price": 10, "fixed_price": true, "purchase_slot": 1, "amount": 3, "display_amount": "+3", "stat_icon": REGENERATION_ICON, "stat": &"regeneration", "name": "Regeneration", "description": "Increase regeneration by 3."},
	{"resource_id": &"wood", "base_price": 10, "fixed_price": true, "purchase_slot": 2, "amount": 60, "stat_icon": HEALTH_ICON, "stat": &"health", "name": "Max Health", "description": "Increase maximum health by 60."},
	{"resource_id": &"fish", "base_price": 7, "fixed_price": true, "purchase_slot": 3, "amount": 1, "stat_icon": preload("res://Sprites/PotionRope.webp"), "stat": &"item", "item_id": "potion_rope", "name": "Upgraded Potion", "description": "Consume to heal 100 HP."},
]


func _get_upgrades() -> Array:
	return LUCA_UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	return [
		{"resource_id": &"fish", "cost_resource_id": &"jewels", "price": 1},
		{"resource_id": &"jewels", "cost_resource_id": &"gold_ore", "price": 5},
	]


func _get_shop_title() -> String:
	return "Luca's Store"


func _notify_story_purchase(_upgrade_index := -1) -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.on_luca_purchase()
