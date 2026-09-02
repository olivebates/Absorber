class_name ItemSlot
extends PanelContainer

const HELMET_ICON := preload("res://Sprites/HelmetIcon.webp")
const SWORD_ICON := preload("res://Sprites/SwordIcon.webp")
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const TRASH_ICON := preload("res://Sprites/IconTrash.webp")
const SPRITE_BASE_SIZE := Vector2(32, 32)
const SLOT_SIZE := Vector2(42, 42)
const EQUIPMENT_YELLOW_TINT := Color(0.99686, 0.95059, 0.83529, 1.0)

var owner_ui: Control
var storage := "inventory"
var slot_index := 0
var item: Dictionary = {}
var locked := false
var shows_unarmed_damage := false

var _icon: TextureRect
var _empty_icon: TextureRect
var _cooldown_overlay: ColorRect
var _lock_icon: TextureRect
var _merge_amount_label: Label
var _disabled_line: Line2D
var _was_dragged := false
var _merge_tween: Tween
var _panel_style: StyleBoxFlat


func configure(new_owner: Control, new_storage: String, new_slot_index: int, new_item: Dictionary, highlight := false, is_locked := false, show_unarmed_damage := false) -> void:
	add_to_group("item_slots")
	owner_ui = new_owner
	storage = new_storage
	slot_index = new_slot_index
	item = new_item.duplicate()
	locked = is_locked
	shows_unarmed_damage = show_unarmed_damage
	custom_minimum_size = SLOT_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not item.is_empty() and not locked else Control.CURSOR_ARROW
	_set_style(ItemPickup.get_grade_color(ItemPickup.get_item_grade(item)) if not item.is_empty() else Color("192236"), highlight)
	if _icon == null:
		_icon = TextureRect.new()
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.z_index = 1
		add_child(_icon)
	_icon.texture = ItemPickup.ITEM_TEXTURES.get(str(item.get("item_id", ""))) if not item.is_empty() else null
	_icon.visible = not item.is_empty()
	_icon.modulate = EQUIPMENT_YELLOW_TINT if not item.is_empty() and ItemPickup.is_equipment(str(item.get("item_id", ""))) else Color.WHITE
	if _merge_amount_label == null:
		_merge_amount_label = Label.new()
		_merge_amount_label.name = "MergeAmount"
		_merge_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_merge_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_merge_amount_label.add_theme_font_size_override("font_size", 11)
		_merge_amount_label.add_theme_color_override("font_color", Color.WHITE)
		_merge_amount_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_merge_amount_label.add_theme_constant_override("outline_size", 3)
		_merge_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_merge_amount_label.z_index = 4
		add_child(_merge_amount_label)
	_merge_amount_label.text = str(ItemPickup.get_merge_amount(item))
	_merge_amount_label.visible = not item.is_empty() and ItemPickup.is_equipment(str(item.get("item_id", "")))
	if _empty_icon == null:
		_empty_icon = TextureRect.new()
		_empty_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_icon.z_index = 0
		add_child(_empty_icon)
	_empty_icon.texture = TRASH_ICON if storage == "trash" else HELMET_ICON if storage == "armor" else DAMAGE_ICON if shows_unarmed_damage else SWORD_ICON if storage == "weapon" else null
	_empty_icon.visible = (storage == "trash" or item.is_empty()) and _empty_icon.texture != null
	if _cooldown_overlay == null:
		_cooldown_overlay = ColorRect.new()
		_cooldown_overlay.color = Color(0.0, 0.0, 0.0, 0.52)
		_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cooldown_overlay.z_index = 2
		add_child(_cooldown_overlay)
	if _lock_icon == null:
		_lock_icon = TextureRect.new()
		_lock_icon.texture = preload("res://Sprites/Lock.webp")
		_lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_icon.z_index = 3
		add_child(_lock_icon)
	_lock_icon.visible = locked
	if _disabled_line == null:
		_disabled_line = Line2D.new()
		_disabled_line.name = "DungeonEquipmentDisabled"
		_disabled_line.points = PackedVector2Array([Vector2(0, SLOT_SIZE.y), Vector2(SLOT_SIZE.x, 0)])
		_disabled_line.width = 3.0
		_disabled_line.default_color = Color("dc2626")
		_disabled_line.antialiased = true
		_disabled_line.z_index = 5
		add_child(_disabled_line)
	_disabled_line.visible = not item.is_empty() and (storage == "weapon" or storage == "armor") and owner_ui != null \
		and bool(owner_ui.call("is_equipment_disabled"))
	_update_cooldown_overlay()


func _process(_delta: float) -> void:
	if _panel_style and storage != "trash" and not item.is_empty() and ItemPickup.is_animated_grade(ItemPickup.get_item_grade(item)):
		_panel_style.bg_color = ItemPickup.get_grade_color(ItemPickup.get_item_grade(item))
	_update_cooldown_overlay()


func _update_cooldown_overlay() -> void:
	if _cooldown_overlay == null:
		return
	if _disabled_line:
		_disabled_line.visible = not item.is_empty() and (storage == "weapon" or storage == "armor") and owner_ui != null \
			and bool(owner_ui.call("is_equipment_disabled"))
	var ratio := 0.0
	if storage == "weapon" and (not item.is_empty() or shows_unarmed_damage) and owner_ui:
		ratio = float(owner_ui.call("get_weapon_cooldown_ratio", slot_index))
	var slot_size := size if size.length_squared() > 0.0 else custom_minimum_size
	if _disabled_line:
		_disabled_line.points = PackedVector2Array([Vector2(0, slot_size.y), Vector2(slot_size.x, 0)])
	var icon_size := Vector2(minf(SPRITE_BASE_SIZE.x, slot_size.x), minf(SPRITE_BASE_SIZE.y, slot_size.y))
	var icon_position := (slot_size - icon_size) * 0.5
	if _icon:
		_icon.position = icon_position
		_icon.size = icon_size
	if _empty_icon:
		_empty_icon.position = icon_position
		_empty_icon.size = icon_size
	_cooldown_overlay.position = Vector2.ZERO
	_cooldown_overlay.size = Vector2(slot_size.x, slot_size.y * clampf(ratio, 0.0, 1.0))
	_cooldown_overlay.visible = ratio > 0.0
	if _lock_icon:
		_lock_icon.position = icon_position
		_lock_icon.size = icon_size
	if _merge_amount_label:
		_merge_amount_label.position = Vector2(2, 1)
		_merge_amount_label.size = slot_size - Vector2(5, 4)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item.is_empty() or locked or owner_ui == null:
		return null
	_was_dragged = true
	owner_ui.call("begin_slot_drag", self)
	var preview := TextureRect.new()
	preview.texture = ItemPickup.ITEM_TEXTURES.get(str(item.get("item_id", "")))
	preview.modulate = EQUIPMENT_YELLOW_TINT if ItemPickup.is_equipment(str(item.get("item_id", ""))) else Color.WHITE
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"source": self}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if locked or not data is Dictionary or not data.has("source"):
		return false
	var source := data["source"] as ItemSlot
	return source != null and owner_ui != null and bool(owner_ui.call("can_drop_in_slot", source, self))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source := data["source"] as ItemSlot
	if source and owner_ui:
		owner_ui.call("drop_in_slot", source, self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not _was_dragged and not locked and not item.is_empty() and owner_ui:
		owner_ui.call("click_slot", self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and owner_ui:
		_was_dragged = false
		owner_ui.call("end_slot_drag")


func play_merge_success() -> void:
	if _merge_tween and _merge_tween.is_valid():
		_merge_tween.kill()
	var grade_color := ItemPickup.get_grade_color(ItemPickup.get_item_grade(item))
	_set_style(grade_color, true)
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	modulate = Color.WHITE
	var burst := Label.new()
	burst.text = "UP!"
	burst.position = Vector2(7, -20)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.add_theme_color_override("font_color", Color("fff2bd"))
	burst.add_theme_color_override("font_outline_color", Color.BLACK)
	burst.add_theme_constant_override("outline_size", 3)
	burst.z_index = 5
	add_child(burst)
	_merge_tween = create_tween()
	_merge_tween.set_parallel(true)
	_merge_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_merge_tween.tween_property(self, "modulate", Color("fff7ba"), 0.08)
	_merge_tween.tween_property(burst, "position:y", -34.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_merge_tween.tween_property(burst, "modulate:a", 0.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_merge_tween.chain().set_parallel(true)
	_merge_tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_merge_tween.tween_property(self, "modulate", Color.WHITE, 0.18)
	_merge_tween.chain().tween_callback(func() -> void:
		_set_style(grade_color, false)
		if is_instance_valid(burst):
			burst.queue_free()
	)


func play_unavailable_feedback() -> void:
	var origin := position
	var tween := create_tween()
	for offset in [Vector2(-4, 0), Vector2(4, 0), Vector2(-3, 0), Vector2(3, 0)]:
		tween.tween_property(self, "position", origin + offset, 0.04)
	tween.tween_property(self, "position", origin, 0.04)


func _set_style(background: Color, merge_highlight: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("5b171b") if storage == "trash" else background
	style.border_color = Color("ff5252") if storage == "trash" else Color.YELLOW if merge_highlight else Color.BLACK
	style.set_border_width_all(3 if merge_highlight else 2)
	style.set_corner_radius_all(4)
	_panel_style = style
	add_theme_stylebox_override("panel", style)
