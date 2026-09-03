class_name MergeUpgradeBanners
extends Control

const BANNER_HEIGHT := 84.0
const CONTENT_WIDTH := 620.0
const BANNER_GAP := 10.0
const STAGGER_SECONDS := 0.2
const HOLD_SECONDS := 3.0
const ENTER_SECONDS := 0.42
const EXIT_SECONDS := 0.46
const SCREEN_HEIGHT_RATIO := 0.25

var _player: FoxPlayer
var _active_banners: Array[Control] = []
var _next_reveal_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	resized.connect(_layout_banners)
	call_deferred("_connect_player")


func _process(_delta: float) -> void:
	for banner in _active_banners:
		if is_instance_valid(banner) and ItemPickup.is_animated_grade(int(banner.get_meta("grade", -1))):
			var strip := banner.get_node_or_null("BannerStrip") as Panel
			if strip:
				_apply_banner_color(strip, ItemPickup.get_grade_color(int(banner.get_meta("grade"))))


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _player and not _player.merge_completed.is_connected(_on_merge_completed):
		_player.merge_completed.connect(_on_merge_completed)


func _on_merge_completed(item: Dictionary, _target_storage: String, _target_index: int) -> void:
	var now := float(Time.get_ticks_msec()) * 0.001
	var reveal_time := maxf(now, _next_reveal_time)
	_next_reveal_time = reveal_time + STAGGER_SECONDS
	_reveal_after(item.duplicate(), maxf(0.0, reveal_time - now))


func _reveal_after(item: Dictionary, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var banner := _create_banner(item)
	_active_banners.append(banner)
	add_child(banner)
	_layout_banners()
	var shadow := banner.get_node("BannerShadow") as Panel
	var strip := banner.get_node("BannerStrip") as Panel
	var content := banner.get_node("BannerContent") as HBoxContainer
	shadow.position.x = size.x
	strip.position.x = size.x
	content.position.x = -CONTENT_WIDTH
	content.modulate.a = 1.0
	banner.set_meta("phase", "entering")
	var enter := create_tween().set_parallel(true)
	enter.tween_property(shadow, "position:x", 0.0, ENTER_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	enter.tween_property(strip, "position:x", 0.0, ENTER_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	enter.tween_property(content, "position:x", _content_center_x(), ENTER_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await enter.finished
	banner.set_meta("phase", "holding")
	await get_tree().create_timer(HOLD_SECONDS).timeout
	if not is_instance_valid(banner):
		return
	banner.set_meta("phase", "exiting")
	var exit_tween := create_tween().set_parallel(true)
	exit_tween.tween_property(shadow, "position:x", -size.x, EXIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(strip, "position:x", -size.x, EXIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(content, "modulate:a", 0.0, EXIT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await exit_tween.finished
	_active_banners.erase(banner)
	banner.queue_free()
	_layout_banners()


func _create_banner(item: Dictionary) -> Control:
	var banner := Control.new()
	banner.name = "MergeUpgradeBanner"
	banner.size = Vector2(size.x, BANNER_HEIGHT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ItemPickup.get_item_grade(item)
	banner.set_meta("grade", grade)

	var shadow := Panel.new()
	shadow.name = "BannerShadow"
	shadow.position.y = 7
	shadow.size = banner.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.72)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	banner.add_child(shadow)

	var strip := Panel.new()
	strip.name = "BannerStrip"
	strip.size = banner.size
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(strip)
	_apply_banner_color(strip, ItemPickup.get_grade_color(grade))

	var row := HBoxContainer.new()
	row.name = "BannerContent"
	row.size = Vector2(CONTENT_WIDTH, BANNER_HEIGHT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(row)
	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.texture = ItemPickup.ITEM_TEXTURES.get(str(item.get("item_id", "")))
	icon.modulate = ItemPickup.get_icon_modulate(str(item.get("item_id", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = "BannerText"
	label.text = _get_banner_text(item)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 5)
	label.add_theme_constant_override("shadow_outline_size", 4)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	_update_text_color(banner, ItemPickup.get_grade_color(grade))
	return banner


func _get_banner_text(item: Dictionary) -> String:
	var item_id := str(item.get("item_id", ""))
	var is_weapon := ItemPickup.is_weapon(item_id)
	var stat_name := "Damage" if is_weapon else "Armor"
	var previous_stat := int(item.get("_previous_stat", 0))
	var new_stat := ItemPickup.get_damage_bonus(item) if is_weapon else ItemPickup.get_block_amount(item)
	return "%s %s -> %s" % [stat_name, _format_stat(previous_stat), _format_stat(new_stat)]


func _format_stat(value: int) -> String:
	return str(value)


func _apply_banner_color(strip: Panel, grade_color: Color) -> void:
	var style := strip.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.border_width_top = 3
		style.border_width_bottom = 3
		strip.add_theme_stylebox_override("panel", style)
	style.bg_color = grade_color
	style.border_color = grade_color.lightened(0.35) if _is_dark(grade_color) else grade_color.darkened(0.35)
	_update_text_color(strip.get_parent() as Control, grade_color)


func _update_text_color(banner: Control, _background: Color) -> void:
	var label := banner.find_child("BannerText", true, false) as Label
	if label == null:
		return
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))


func _is_dark(color: Color) -> bool:
	return color.get_luminance() < 0.48


func _layout_banners() -> void:
	for index in range(_active_banners.size()):
		var banner := _active_banners[index]
		if is_instance_valid(banner):
			banner.position = Vector2(0, size.y * SCREEN_HEIGHT_RATIO - BANNER_HEIGHT * 0.5 + float(index) * (BANNER_HEIGHT + BANNER_GAP))
			banner.size = Vector2(size.x, BANNER_HEIGHT)
			var shadow := banner.get_node_or_null("BannerShadow") as Panel
			if shadow:
				shadow.size = banner.size
			var strip := banner.get_node_or_null("BannerStrip") as Panel
			if strip:
				strip.size = banner.size
			var content := banner.get_node_or_null("BannerContent") as HBoxContainer
			if content:
				content.size = Vector2(CONTENT_WIDTH, BANNER_HEIGHT)
				if str(banner.get_meta("phase", "")) == "holding":
					content.position.x = _content_center_x()


func _content_center_x() -> float:
	return (size.x - CONTENT_WIDTH) * 0.5
