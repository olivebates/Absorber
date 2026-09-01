extends SceneTree


const EXPECTED_NAMES := [
	"Crude", "Ordinary", "Superior", "Elite", "Masterwork",
	"Mythic", "Divine", "Immortal", "Omnipotent", "Void",
]
const EXPECTED_COLORS := [
	Color("777777"), Color("f2f2f2"), Color("47b85c"), Color("4785e8"),
	Color("9a58d4"), Color("e99032"), Color("e65ac5"), Color("2ec4b6"),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(ItemPickup.GRADES.size() == 10, "Equipment must have ten named base grades")
	for grade in range(EXPECTED_NAMES.size()):
		assert(ItemPickup.get_grade_name(grade) == EXPECTED_NAMES[grade], "Grade %d must use its requested name" % grade)
	for grade in range(EXPECTED_COLORS.size()):
		assert(ItemPickup.get_grade_color(grade).is_equal_approx(EXPECTED_COLORS[grade]), "Grade %d must retain its requested fixed color" % grade)
	assert(ItemPickup.is_animated_grade(8), "Omnipotent must be the animated grade")
	assert(not ItemPickup.is_animated_grade(7) and not ItemPickup.is_animated_grade(9), "Only Omnipotent may animate")
	var first_rainbow_color := ItemPickup.get_grade_color(8, 0.0)
	assert(not first_rainbow_color.is_equal_approx(ItemPickup.get_grade_color(8, 1.0)), "Omnipotent must cycle through rainbow colors over time")
	assert(ItemPickup.get_grade_color(9).is_equal_approx(Color("141414")), "Void must be black")
	assert(ItemPickup.get_grade_color(27).is_equal_approx(Color("141414")), "Grades above Void must remain black")
	assert(ItemPickup.get_grade_name(10) == "Void +1" and ItemPickup.get_grade_name(12) == "Void +3", "Grades above Void must receive increasing +N suffixes")

	var overflow_item := ItemPickup.make_item("weathered_sword", 12)
	assert(ItemPickup.get_item_grade(overflow_item) == 12, "Creating an item must preserve grades above Void")
	assert(ItemPickup.get_damage_bonus(overflow_item) > ItemPickup.get_damage_bonus(ItemPickup.make_item("weathered_sword", 9)), "Overflow grades must continue increasing equipment stats")
	var player := FoxPlayer.new()
	assert(player.can_merge(ItemPickup.make_item("weathered_sword", 12), ItemPickup.make_item("weathered_sword", 12)), "Matching Void +N equipment must remain mergeable")
	player.inventory_slots[0] = ItemPickup.make_item("weathered_sword", 12)
	player.inventory_slots[1] = ItemPickup.make_item("weathered_sword", 12)
	assert(player.merge_inventory_pair(0, 1), "Overflow equipment merge must succeed")
	assert(player.inventory_slots[0].is_empty() and ItemPickup.get_item_grade(player.inventory_slots[1]) == 13, "An overflow merge must produce the next grade")
	var packed_items := player._pack_items(player.inventory_slots)
	var restored_items := player._unpack_items(packed_items, player.inventory_slots.size())
	assert(ItemPickup.get_item_grade(restored_items[1]) == 13, "Save packing must preserve overflow grades")
	player.free()
	print("EQUIPMENT_GRADE_SMOKE_TEST_PASS")
	quit()
