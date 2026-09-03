class_name WorldMap
extends Control

var _world: WorldNavigation
var _canvas: WorldMapCanvas
var _title: Label
var _leave_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_interface()
	call_deferred("_connect_world")


func _connect_world() -> void:
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	_canvas.setup(_world)


func open() -> void:
	var manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
	_world = manager.get_active_level() if manager and manager.is_dungeon_active() else get_tree().current_scene as WorldNavigation
	if _world == null:
		_connect_world()
	_canvas.setup(_world)
	if is_instance_valid(_title):
		_title.text = "%s Map" % (_world.display_name if _world is DungeonLevel else "World")
	if is_instance_valid(_leave_button):
		_leave_button.visible = _world is DungeonLevel
	var shopkeeper := get_tree().get_first_node_in_group("shopkeepers") as FoxAsha
	if shopkeeper:
		shopkeeper.close_shop()
	show()
	move_to_front()


func close() -> void:
	if is_instance_valid(_canvas):
		_canvas._hide_shop_popup()
	hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_M or key == KEY_TAB:
		if _world:
			_world.dismiss_second_campfire_tab_prompt()
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 0.76)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.98)
	style.border_color = Color("e9c64d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	_title = Label.new()
	var title := _title
	title.text = "World Map — Select a Campfire"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Color("ffe082"))
	title_row.add_child(_title)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(28, 26)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	title_row.add_child(close_button)
	_canvas = WorldMapCanvas.new()
	content.add_child(_canvas)
	_leave_button = Button.new()
	_leave_button.name = "LeaveDungeonButton"
	_leave_button.text = "Leave Dungeon"
	_leave_button.custom_minimum_size = Vector2(190, 38)
	_leave_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave_button.focus_mode = Control.FOCUS_NONE
	_leave_button.visible = false
	_leave_button.pressed.connect(_leave_active_dungeon)
	content.add_child(_leave_button)


func _leave_active_dungeon() -> void:
	var manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
	if manager:
		manager.leave_dungeon()
