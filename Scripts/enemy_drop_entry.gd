class_name EnemyDropEntry
extends Resource

enum ItemType {
	WEATHERED_ARMOR,
	WEATHERED_SWORD,
}

const ITEM_IDS := [&"weathered_armor", &"weathered_sword"]

@export_enum("Weathered Armor", "Weathered Sword") var item_type: int = ItemType.WEATHERED_ARMOR
@export_range(0.0, 1.0, 0.01, "suffix: chance") var chance := 0.5
@export_enum("Gray", "White", "Green", "Blue", "Purple", "Orange", "Pink", "Black") var grade := 0


func to_drop_dictionary() -> Dictionary:
	return {
		"item_id": str(ITEM_IDS[clampi(item_type, 0, ITEM_IDS.size() - 1)]),
		"chance": clampf(chance, 0.0, 1.0),
		"grade": clampi(grade, 0, ItemPickup.GRADES.size() - 1),
	}
