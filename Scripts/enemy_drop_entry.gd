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
	BLUE_SWORD,
	RED_DAMAGE_STONE,
	YELLOW_DAMAGE_STONE,
	BLUE_DAMAGE_STONE,
	RED_DEFENSE_STONE,
	YELLOW_DEFENSE_STONE,
	BLUE_DEFENSE_STONE,
}

const ITEM_IDS := [
	&"weathered_armor", &"weathered_sword", &"potion_basic", &"potion_rope",
	&"potion_bronze", &"potion_silver", &"potion_royal", &"potion_holy",
	&"blue_sword", &"red_damage_stone", &"yellow_damage_stone", &"blue_damage_stone",
	&"red_defense_stone", &"yellow_defense_stone", &"blue_defense_stone",
]

@export_enum("Orange Shield", "Yellow Sword", "Basic Potion", "Upgraded Potion", "Bronze Potion", "Silver Potion", "Royal Potion", "Holy Potion", "Blue Sword", "Red Damage Stone", "Yellow Damage Stone", "Blue Damage Stone", "Red Defense Stone", "Yellow Defense Stone", "Blue Defense Stone") var item_type: int = ItemType.WEATHERED_ARMOR
@export_range(0.0, 1.0, 0.01, "suffix: chance") var chance := 0.5
@export_enum("Crude", "Ordinary", "Superior", "Elite", "Masterwork", "Mythic", "Divine", "Immortal", "Omnipotent", "Void") var grade := 0


func to_drop_dictionary() -> Dictionary:
	return {
		"item_id": str(ITEM_IDS[clampi(item_type, 0, ITEM_IDS.size() - 1)]),
		"chance": clampf(chance, 0.0, 1.0),
		"grade": clampi(grade, 0, ItemPickup.GRADES.size() - 1),
	}
