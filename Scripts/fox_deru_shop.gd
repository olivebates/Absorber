class_name FoxDeruShop
extends FoxShop

const DERU_UPGRADES := [
	{
		"resource_id": &"cave_moss", "base_price": 6, "fixed_price": true,
		"visible_by_default": true, "one_time": true, "purchase_slot": 0, "amount": 1,
		"stat_icon": preload("res://Sprites/skillBulwark.webp"), "stat": &"skill",
		"skill_id": FoxPlayer.SKILL_BULWARK, "name": "Bulwark",
		"description": "Gain 20 Yellow armor for 3 seconds. Costs 5 mana. Cooldown: 8 seconds.",
	},
]


func _get_upgrades() -> Array:
	return DERU_UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	return []


func _get_shop_title() -> String:
	return "Deru's Store"


func _notify_story_purchase(_upgrade_index := -1) -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
