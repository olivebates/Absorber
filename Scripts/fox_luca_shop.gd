class_name FoxLucaShop
extends FoxShop

const LUCA_UPGRADES := [
	{"resource_id": &"jewels", "base_price": 10, "fixed_price": true, "purchase_slot": 0, "amount": 2, "stat_icon": DAMAGE_ICON, "stat": &"damage", "color": FoxPlayer.COLOR_YELLOW, "name": "Yellow Damage", "description": "Increase yellow damage by 2."},
	{"resource_id": &"fish", "base_price": 10, "fixed_price": true, "purchase_slot": 1, "amount": 3, "display_amount": "+3", "stat_icon": REGENERATION_ICON, "stat": &"regeneration", "name": "Regeneration", "description": "Increase regeneration by 3."},
	{"resource_id": &"wood", "base_price": 10, "fixed_price": true, "purchase_slot": 2, "amount": 60, "stat_icon": HEALTH_ICON, "stat": &"health", "name": "Max Health", "description": "Increase maximum health by 60."},
	{"resource_id": &"fish", "base_price": 7, "fixed_price": true, "purchase_slot": 3, "amount": 1, "stat_icon": preload("res://Sprites/PotionRope.webp"), "stat": &"item", "item_id": "potion_rope", "name": "Upgraded Potion", "description": "Consume to heal 100 HP."},
	{"resource_id": &"jewels", "base_price": 20, "fixed_price": true, "visible_by_default": true, "purchase_slot": 4, "amount": 1, "stat_icon": preload("res://Sprites/SwordIcon.webp"), "stat": &"auto_fight", "name": "Auto Fight", "description": "Automatically fight previously defeated enemies within range."},
	{"resource_id": &"wood", "base_price": 30, "fixed_price": true, "visible_by_default": true, "purchase_slot": 5, "amount": 1, "stat_icon": preload("res://Sprites/SwordIcon.webp"), "stat": &"auto_fight_range", "name": "Auto Fight Range", "description": "Increase Auto Fight range by 1 tile."},
	{"resource_id": &"gold_ore", "base_price": 2, "fixed_price": true, "visible_by_default": true, "purchase_slot": 6, "amount": 1, "stat_icon": preload("res://Sprites/PotionBasic.webp"), "stat": &"item", "item_id": "potion_basic", "name": "Basic Potion", "description": "Consume to heal 40 HP."},
]


func _get_upgrades() -> Array:
	return LUCA_UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	return [
		{"resource_id": &"fish", "cost_resource_id": &"jewels", "price": 2},
		{"resource_id": &"jewels", "cost_resource_id": &"gold_ore", "price": 5},
	]


func _get_shop_title() -> String:
	return "Lucie's Store"


func _notify_story_purchase(_upgrade_index := -1) -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.on_luca_purchase()
