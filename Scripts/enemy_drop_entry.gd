class_name EnemyDropEntry
extends Resource

enum ItemType {
	WEATHERED_ARMOR,
	WEATHERED_SWORD,
	POTION_BASIC,
	POTION_ROPE,
	POTION_BRONZE,
	POTION_SILVER,
	POTION_ROYAL,
	POTION_HOLY,
}

const ITEM_IDS := [
	&"weathered_armor", &"weathered_sword", &"potion_basic", &"potion_rope",
	&"potion_bronze", &"potion_silver", &"potion_royal", &"potion_holy",
]

@export_enum("Weathered Armor", "Weathered Sword", "Basic Potion", "Upgraded Potion", "Bronze Potion", "Silver Potion", "Royal Potion", "Holy Potion") var item_type: int = ItemType.WEATHERED_ARMOR
@export_range(0.0, 1.0, 0.01, "suffix: chance") var chance := 0.5
@export_enum("Crude", "Ordinary", "Superior", "Elite", "Masterwork", "Mythic", "Divine", "Immortal", "Omnipotent", "Void") var grade := 0


func to_drop_dictionary() -> Dictionary:
	return {
		"item_id": str(ITEM_IDS[clampi(item_type, 0, ITEM_IDS.size() - 1)]),
		"chance": clampf(chance, 0.0, 1.0),
		"grade": clampi(grade, 0, ItemPickup.GRADES.size() - 1),
	}
