class_name SkillSlot
extends PanelContainer

const BOOK_ICON := preload("res://Sprites/IconSkillBook.webp")
const LOCK_ICON := preload("res://Sprites/Lock.webp")
const COMPACT_SIZE := Vector2(42, 42)
const ARRANGE_SIZE := Vector2(42, 42)
const ICON_SIZE := Vector2(32, 32)

var owner_ui: Control
var slot_index := -1
var skill_id: StringName = &""
var source_kind := "player"
var locked := false
var _icon: TextureRect
var _cooldown_overlay: ColorRect
var _lock_icon: TextureRect
var _hotkey_label: Label
var _was_dragged := false
var _feedback_label: Label
var _feedback_tween: Tween
var _label_tween: Tween
var _cooldown_was_active := false
var _base_style: StyleBoxFlat
var _tutorial_glow_tween: Tween
var tutorial_glowing := false
var arranging := false
var interaction_state := ""
var _content: Control


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(new_owner: Control, new_slot_index: int, new_skill_id: StringName, texture: Texture2D, is_locked: bool, hotkey := "", kind := "player", is_arranging := false) -> void:
	owner_ui = new_owner
	slot_index = new_slot_index
	skill_id = new_skill_id
	source_kind = kind
	locked = is_locked
	arranging = is_arranging
	custom_minimum_size = ARRANGE_SIZE if arranging else COMPACT_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not locked else Control.CURSOR_ARROW
	_base_style = StyleBoxFlat.new()
	_base_style.bg_color = Color("192236")
	_base_style.border_color = Color.BLACK
	_base_style.set_border_width_all(2)
	_base_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", _base_style)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_icon = TextureRect.new()
	_icon.texture = texture if texture else BOOK_ICON
	_icon.position = (custom_minimum_size - ICON_SIZE) * 0.5 - Vector2(2, 2)
	_icon.size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_icon)
	_cooldown_overlay = ColorRect.new()
	_cooldown_overlay.color = Color(0, 0, 0, 0.58)
	_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_overlay.z_index = 2
	_content.add_child(_cooldown_overlay)
	_lock_icon = TextureRect.new()
	_lock_icon.texture = LOCK_ICON
	_lock_icon.position = (custom_minimum_size - ICON_SIZE) * 0.5
	_lock_icon.size = ICON_SIZE
	_lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_icon.z_index = 3
	_lock_icon.visible = locked
	_content.add_child(_lock_icon)
	_hotkey_label = Label.new()
	_hotkey_label.text = hotkey
	_hotkey_label.position = Vector2(custom_minimum_size.x - 14.0, custom_minimum_size.y - 17.0)
	_hotkey_label.size = Vector2(13, 16)
	_hotkey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hotkey_label.add_theme_font_size_override("font_size", 11)
	_hotkey_label.add_theme_color_override("font_color", Color.WHITE)
	_hotkey_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hotkey_label.add_theme_constant_override("outline_size", 3)
	_hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotkey_label.z_index = 4
	_content.add_child(_hotkey_label)
	_feedback_label = Label.new()
	_feedback_label.name = "CastFeedback"
	_feedback_label.position = Vector2(-28, -23)
	_feedback_label.size = Vector2(88, 20)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 12)
	_feedback_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_feedback_label.add_theme_constant_override("outline_size", 3)
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.z_index = 20
	_feedback_label.hide()
	# Keep transient text outside this PanelContainer. A Control child contributes
	# its text width to the container's minimum size, which made the slot grow for
	# messages such as "Cooling Down".
	owner_ui.add_child(_feedback_label)


func _process(_delta: float) -> void:
	if owner_ui == null or _cooldown_overlay == null:
		return
	_icon.position = (size - ICON_SIZE) * 0.5 - Vector2(2, 2)
	_icon.size = ICON_SIZE
	_lock_icon.position = (size - ICON_SIZE) * 0.5
	_lock_icon.size = ICON_SIZE
	_hotkey_label.position = Vector2(size.x - 14.0, size.y - 17.0)
	var ratio := float(owner_ui.call("get_skill_cooldown_ratio", source_kind, slot_index, skill_id))
	_cooldown_overlay.position = Vector2.ZERO
	_cooldown_overlay.size = Vector2(size.x, size.y * clampf(ratio, 0.0, 1.0))
	_cooldown_overlay.visible = ratio > 0.0
	if ratio > 0.0:
		_cooldown_was_active = true
	elif _cooldown_was_active:
		_cooldown_was_active = false
		play_ready_feedback()


func play_press_feedback() -> void:
	if locked or skill_id.is_empty():
		return
	_kill_feedback_tween()
	pivot_offset = size * 0.5
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_cast_feedback() -> void:
	_kill_feedback_tween()
	pivot_offset = size * 0.5
	self_modulate = Color("79eaff")
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(0.86, 0.86), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.10, 1.10), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.13)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_failure_feedback(reason: String) -> void:
	if reason.is_empty() or reason == "Empty" or reason == "Locked":
		return
	_kill_feedback_tween()
	pivot_offset = size * 0.5
	self_modulate = Color("ff7878")
	_feedback_tween = create_tween()
	for angle in [-0.10, 0.10, -0.07, 0.07]:
		_feedback_tween.tween_property(self, "rotation", angle, 0.035)
	_feedback_tween.tween_property(self, "rotation", 0.0, 0.045)
	_feedback_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.08)
	_feedback_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.12)
	_show_feedback_label(reason, Color("ff8d8d"))


func play_ready_feedback() -> void:
	if locked or skill_id.is_empty():
		return
	_kill_feedback_tween()
	pivot_offset = size * 0.5
	self_modulate = Color("a8fbff")
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.24)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_feedback_label("Ready", Color("9ffcff"))


func play_equip_feedback(hotkey: String, skill_name: String) -> void:
	_kill_feedback_tween()
	pivot_offset = size * 0.5
	self_modulate = Color("76f3ff")
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(0.82, 0.82), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.16, 1.16), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.18)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_feedback_label("%s · %s" % [hotkey, skill_name], Color("9ffcff"))


func _show_feedback_label(message: String, color: Color) -> void:
	if _label_tween and _label_tween.is_valid():
		_label_tween.kill()
	_feedback_label.text = message
	_feedback_label.size.x = 180.0
	_feedback_label.global_position = global_position + Vector2(size.x * 0.5 - 90.0, -23.0)
	_feedback_label.modulate = color
	_feedback_label.show()
	_label_tween = _feedback_label.create_tween().set_parallel(true)
	_label_tween.tween_property(_feedback_label, "global_position:y", _feedback_label.global_position.y - 14.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_label_tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.55).set_delay(0.16)
	_label_tween.chain().tween_callback(_feedback_label.hide)


func _kill_feedback_tween() -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	rotation = 0.0
	scale = Vector2.ONE
	self_modulate = Color.WHITE


func _get_drag_data(_at_position: Vector2) -> Variant:
	if locked or skill_id.is_empty() or owner_ui == null or source_kind == "asha" or source_kind == "picker":
		return null
	_was_dragged = true
	_icon.hide()
	owner_ui.call("begin_skill_drag", skill_id, self)
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.custom_minimum_size = ICON_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"source_kind": source_kind, "source_index": slot_index, "skill_id": skill_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if owner_ui == null:
		return false
	var valid := not locked and source_kind == "player" and bool(owner_ui.call("can_drop_skill", data, self))
	owner_ui.call("preview_skill_target", data.get("skill_id", &"") if data is Dictionary else &"", self, valid)
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if owner_ui:
		owner_ui.call("drop_skill", data, self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not locked and not skill_id.is_empty() and owner_ui and source_kind != "asha":
		if event.pressed:
			play_press_feedback()
			if source_kind == "picker":
				owner_ui.call("start_cursor_skill_drag", skill_id, self)
				accept_event()
		elif not _was_dragged:
			if source_kind != "picker" and not bool(owner_ui.call("is_arranging_skills")):
				owner_ui.call("cast_skill_slot", slot_index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and owner_ui:
		_was_dragged = false
		if is_instance_valid(_icon):
			_icon.show()
		_kill_feedback_tween()
		owner_ui.call("end_skill_drag")


func set_tutorial_glow(enabled: bool) -> void:
	if tutorial_glowing == enabled:
		return
	tutorial_glowing = enabled
	if _tutorial_glow_tween and _tutorial_glow_tween.is_valid():
		_tutorial_glow_tween.kill()
	_tutorial_glow_tween = null
	if not enabled:
		add_theme_stylebox_override("panel", _base_style)
		modulate = Color.WHITE
		return
	var glow_style := _base_style.duplicate() as StyleBoxFlat
	glow_style.bg_color = Color(0.35, 0.28, 0.03, 1.0)
	glow_style.border_color = Color(1.0, 0.86, 0.12, 1.0)
	glow_style.set_border_width_all(3)
	add_theme_stylebox_override("panel", glow_style)
	_tutorial_glow_tween = create_tween().set_loops()
	_tutorial_glow_tween.tween_property(self, "modulate", Color(1.28, 1.20, 0.55), 0.42)
	_tutorial_glow_tween.tween_property(self, "modulate", Color.WHITE, 0.42)


func set_interaction_state(state: String) -> void:
	if interaction_state == state:
		return
	interaction_state = state
	var style := _base_style.duplicate() as StyleBoxFlat
	_icon.modulate = Color.WHITE
	modulate = Color.WHITE
	if state == "valid":
		style.border_color = Color("67e8f9")
		style.set_border_width_all(3)
	elif state == "invalid":
		style.border_color = Color("e45c68")
		style.set_border_width_all(3)
		_icon.modulate = Color(0.48, 0.48, 0.52, 0.65)
	elif state == "hover":
		style.bg_color = Color("30425d")
		style.border_color = Color("ffe082")
		style.set_border_width_all(4)
		_icon.modulate = Color(0.72, 0.78, 0.88, 0.58)
	elif state == "selected":
		style.bg_color = Color("34355d")
		style.border_color = Color("ffe082")
		style.set_border_width_all(4)
	elif tutorial_glowing:
		style.bg_color = Color(0.35, 0.28, 0.03, 1.0)
		style.border_color = Color(1.0, 0.86, 0.12, 1.0)
		style.set_border_width_all(3)
	add_theme_stylebox_override("panel", style)
	pivot_offset = size * 0.5
	var target_scale := Vector2(1.10, 1.10) if state == "hover" else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if is_instance_valid(_feedback_label) and not _feedback_label.is_queued_for_deletion():
		_feedback_label.queue_free()


func _on_mouse_entered() -> void:
	if owner_ui and not skill_id.is_empty():
		owner_ui.call("show_skill_tooltip", skill_id, source_kind)
		owner_ui.call("skill_slot_hovered", self)


func _on_mouse_exited() -> void:
	if owner_ui:
		owner_ui.call("hide_skill_tooltip")
		owner_ui.call("skill_slot_unhovered", self)
