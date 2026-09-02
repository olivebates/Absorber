class_name AutoFightControl
extends PanelContainer

const TOOLTIP := "Will automatically attack any creatures you have already defeated, within radius."
const SIDEBAR_MARGIN := 12.0
const SIDEBAR_CONTENT_WIDTH := 296.0
const PANEL_GAP := 8.0

var _player: FoxPlayer
var _world: WorldNavigation
var _toggle: CheckButton


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_set_style()
	_toggle = CheckButton.new()
	_toggle.name = "AutoFightToggle"
	_toggle.text = "Auto Fight"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = ""
	_toggle.mouse_entered.connect(_show_inventory_style_tooltip)
	_toggle.mouse_exited.connect(_hide_inventory_style_tooltip)
	_toggle.toggled.connect(_on_toggled)
	add_child(_toggle)
	call_deferred("_connect_world")


func _process(_delta: float) -> void:
	_position_above_resources()


func _connect_world() -> void:
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _player == null or _world == null:
		call_deferred("_connect_world")
		return
	if not _player.auto_fight_changed.is_connected(_refresh):
		_player.auto_fight_changed.connect(_refresh)
	_refresh()


func _on_toggled(enabled: bool) -> void:
	if is_instance_valid(_player):
		_player.set_auto_fight_enabled(enabled)
	if enabled:
		_hide_inventory_style_tooltip()
		var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
		if story:
			story.on_auto_fight_first_toggled()


func _show_inventory_style_tooltip() -> void:
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if tooltip:
		tooltip.show_description(null, "Auto Fight", TOOLTIP)


func _hide_inventory_style_tooltip() -> void:
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if tooltip:
		tooltip.hide_item()


func _refresh() -> void:
	if not is_instance_valid(_player):
		return
	visible = _player.auto_fight_unlocked
	_toggle.set_pressed_no_signal(_player.auto_fight_enabled)
	_player.set_auto_fight_range_visible(_player.auto_fight_unlocked and _player.auto_fight_enabled)


func _position_above_resources() -> void:
	if not visible:
		return
	var resources := get_parent().get_node_or_null("ResourcePanel") as Control
	var fitted := get_combined_minimum_size()
	if fitted == Vector2.ZERO:
		fitted = Vector2(118, 42)
	var bottom := -SIDEBAR_MARGIN
	if resources and resources.visible:
		bottom = resources.get_offset(SIDE_TOP) - PANEL_GAP
	set_offset(SIDE_LEFT, SIDEBAR_MARGIN)
	set_offset(SIDE_TOP, bottom - fitted.y)
	set_offset(SIDE_RIGHT, SIDEBAR_MARGIN + SIDEBAR_CONTENT_WIDTH)
	set_offset(SIDE_BOTTOM, bottom)


func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.83)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
