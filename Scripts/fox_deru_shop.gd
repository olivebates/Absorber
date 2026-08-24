class_name FoxDeruShop
extends FoxShop

const DERU_UPGRADES := [
	{"resource_id": &"jewels", "base_price": 5, "fixed_price": true, "visible_by_default": true, "purchase_slot": 0, "amount": 1, "stat_icon": DAMAGE_ICON, "stat": &"damage", "color": FoxPlayer.COLOR_YELLOW, "name": "Yellow Damage", "description": "Increase yellow damage by 1."},
	{"resource_id": &"wood", "base_price": 5, "fixed_price": true, "visible_by_default": true, "purchase_slot": 1, "amount": 1, "stat_icon": preload("res://Sprites/ShieldIcon.webp"), "stat": &"defense", "color": FoxPlayer.COLOR_YELLOW, "name": "Yellow Defense", "description": "Increase yellow defense by 1."},
]


func _get_upgrades() -> Array:
	return DERU_UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	return [{"resource_id": &"jewels", "cost_resource_id": &"wood", "price": 4}]


func _get_shop_title() -> String:
	return "Deru's Store"


func _is_upgrade_available(index: int, _upgrade: Dictionary) -> bool:
	return is_instance_valid(_shopkeeper) and index < _shopkeeper.purchase_counts.size() and _shopkeeper.purchase_counts[index] == 0


func _notify_story_purchase(_upgrade_index := -1) -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
