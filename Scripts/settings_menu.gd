class_name SettingsMenu
extends Control

const GEAR_ICON := preload("res://Sprites/Gear.webp")

var _overlay: Control
var _panel: PanelContainer
var _music_slider: HSlider
var _sfx_slider: HSlider
var _backup_button: Button
var _backup_menu: PopupMenu
var _status_label: Label
var _save_system: SaveSystem
var _game_audio: GameAudio
var _export_dialog: AcceptDialog
var _export_text: TextEdit
var _import_dialog: AcceptDialog
var _import_text: TextEdit
var _save_to_disk_button: Button
var _load_from_disk_button: Button
var _save_file_dialog: FileDialog
var _load_file_dialog: FileDialog
var _start_over_dialog: ConfirmationDialog
var _start_over_step := 0
var _backup_paths := PackedStringArray()
var _previous_interaction_locked := false
var _gear_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_gear_button()
	_build_overlay()
	_build_transfer_dialogs()
	_build_disk_file_dialogs()
	_build_start_over_dialog()
	call_deferred("_resolve_services")
	call_deferred("_position_gear_button")


func _process(_delta: float) -> void:
	_position_gear_button()


func _build_gear_button() -> void:
	_gear_button = Button.new()
	_gear_button.name = "SettingsButton"
	_gear_button.icon = GEAR_ICON
	_gear_button.expand_icon = true
	_gear_button.tooltip_text = "Settings"
	_gear_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_gear_button.size = Vector2(36, 36)
	_gear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear_button.pressed.connect(open_settings)
	add_child(_gear_button)


func _position_gear_button() -> void:
	if not is_instance_valid(_gear_button):
		return
	var anchor := get_parent().get_node_or_null("Minimap/MinimapHeader/Content/SettingsAnchor") as Control
	if is_instance_valid(anchor):
		_gear_button.global_position = anchor.get_global_rect().position
	else:
		_gear_button.global_position = get_viewport_rect().size - Vector2(48, get_viewport_rect().size.y - 10)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "SettingsOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	add_child(_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "TransparentBackdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.custom_minimum_size = Vector2(520, 420)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("242938")
	panel_style.border_color = Color("77819a")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_right = 30.0
	panel_style.content_margin_top = 22.0
	panel_style.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(close_settings)
	header.add_child(close_button)

	_music_slider = _add_volume_row(content, "Music", _on_music_changed)
	_sfx_slider = _add_volume_row(content, "Sound effects", _on_sfx_changed)

	var separator := HSeparator.new()
	content.add_child(separator)
	var save_title := Label.new()
	save_title.text = "Save data"
	save_title.add_theme_font_size_override("font_size", 20)
	content.add_child(save_title)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var export_button := Button.new()
	export_button.text = "Export"
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_show_export)
	actions.add_child(export_button)
	var import_button := Button.new()
	import_button.text = "Import"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(_show_import)
	actions.add_child(import_button)
	_backup_button = Button.new()
	_backup_button.text = "Backups ▾"
	_backup_button.tooltip_text = "Hold Shift to show all backups"
	_backup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backup_button.pressed.connect(_show_backups)
	actions.add_child(_backup_button)

	if supports_disk_save_dialogs():
		var disk_actions := HBoxContainer.new()
		disk_actions.name = "DiskSaveActions"
		disk_actions.add_theme_constant_override("separation", 10)
		content.add_child(disk_actions)
		_save_to_disk_button = Button.new()
		_save_to_disk_button.name = "SaveToDiskButton"
		_save_to_disk_button.text = "Save to Disk"
		_save_to_disk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_save_to_disk_button.pressed.connect(_show_save_to_disk)
		disk_actions.add_child(_save_to_disk_button)
		_load_from_disk_button = Button.new()
		_load_from_disk_button.name = "LoadFromDiskButton"
		_load_from_disk_button.text = "Load from Disk"
		_load_from_disk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_load_from_disk_button.pressed.connect(_show_load_from_disk)
		disk_actions.add_child(_load_from_disk_button)

	_status_label = Label.new()
	_status_label.text = "Autosaves every 5 seconds"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color("aeb8cc"))
	content.add_child(_status_label)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_spacer)
	var bottom_row := HBoxContainer.new()
	content.add_child(bottom_row)
	var start_over := Button.new()
	start_over.name = "StartOverButton"
	start_over.text = "Start Over"
	start_over.custom_minimum_size = Vector2(108, 32)
	var danger_style := StyleBoxFlat.new()
	danger_style.bg_color = Color("a92c35")
	danger_style.set_corner_radius_all(5)
	start_over.add_theme_stylebox_override("normal", danger_style)
	start_over.pressed.connect(_begin_start_over)
	bottom_row.add_child(start_over)

	_backup_menu = PopupMenu.new()
	_backup_menu.name = "BackupMenu"
	_backup_menu.id_pressed.connect(_on_backup_selected)
	_overlay.add_child(_backup_menu)


func _add_volume_row(parent: VBoxContainer, label_text: String, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 140.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return slider


func _build_transfer_dialogs() -> void:
	_export_dialog = AcceptDialog.new()
	_export_dialog.title = "Export save"
	_export_dialog.dialog_text = "Copy this save string and keep it somewhere safe."
	_export_dialog.min_size = Vector2i(680, 430)
	add_child(_export_dialog)
	_export_text = TextEdit.new()
	_export_text.custom_minimum_size = Vector2(640, 285)
	_export_text.editable = false
	_export_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_export_dialog.add_child(_export_text)
	_export_dialog.add_button("Copy", true, "copy")
	_export_dialog.custom_action.connect(_on_export_action)

	_import_dialog = AcceptDialog.new()
	_import_dialog.title = "Import save"
	_import_dialog.dialog_text = "Paste a save string below. Loading replaces the current autosave."
	_import_dialog.min_size = Vector2i(680, 430)
	add_child(_import_dialog)
	_import_text = TextEdit.new()
	_import_text.custom_minimum_size = Vector2(640, 285)
	_import_text.placeholder_text = "Paste save string here…"
	_import_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_import_dialog.add_child(_import_text)
	_import_dialog.add_button("Load", true, "load")
	_import_dialog.custom_action.connect(_on_import_action)


func _build_disk_file_dialogs() -> void:
	if not supports_disk_save_dialogs():
		return
	_save_file_dialog = FileDialog.new()
	_save_file_dialog.name = "SaveToDiskDialog"
	_save_file_dialog.title = "Save Absorber Save"
	_save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_configure_disk_file_dialog(_save_file_dialog)
	_save_file_dialog.current_file = "Absorber Save.absorber"
	_save_file_dialog.file_selected.connect(_on_disk_save_selected)
	add_child(_save_file_dialog)
	_load_file_dialog = FileDialog.new()
	_load_file_dialog.name = "LoadFromDiskDialog"
	_load_file_dialog.title = "Load Absorber Save"
	_load_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_configure_disk_file_dialog(_load_file_dialog)
	_load_file_dialog.file_selected.connect(_on_disk_load_selected)
	add_child(_load_file_dialog)


func _configure_disk_file_dialog(dialog: FileDialog) -> void:
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.absorber ; Absorber Save Files"])
	dialog.use_native_dialog = true


static func supports_disk_save_dialogs() -> bool:
	# Headless test/server processes have no native window for a filesystem dialog.
	return OS.has_feature("windows") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _build_start_over_dialog() -> void:
	_start_over_dialog = ConfirmationDialog.new()
	_start_over_dialog.title = "Start Over"
	_start_over_dialog.min_size = Vector2i(480, 180)
	_start_over_dialog.confirmed.connect(_advance_start_over)
	add_child(_start_over_dialog)


func _resolve_services() -> void:
	_save_system = get_tree().get_first_node_in_group("save_system") as SaveSystem
	_game_audio = get_tree().get_first_node_in_group("game_audio") as GameAudio
	if _game_audio:
		_music_slider.set_value_no_signal(_game_audio.music_volume)
		_sfx_slider.set_value_no_signal(_game_audio.sfx_volume)


func open_settings() -> void:
	_resolve_services()
	_overlay.show()
	_overlay.move_to_front()
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world:
		_previous_interaction_locked = world.interaction_locked
		world.interaction_locked = true


func close_settings() -> void:
	_export_dialog.hide()
	_import_dialog.hide()
	_start_over_dialog.hide()
	if _save_file_dialog:
		_save_file_dialog.hide()
	if _load_file_dialog:
		_load_file_dialog.hide()
	_backup_menu.hide()
	_overlay.hide()
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world:
		world.interaction_locked = _previous_interaction_locked


func _input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed("ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_settings()


func _on_music_changed(value: float) -> void:
	if _game_audio:
		_game_audio.set_music_volume(value)


func _on_sfx_changed(value: float) -> void:
	if _game_audio:
		_game_audio.set_sfx_volume(value)


func _show_export() -> void:
	if not _save_system:
		return
	_export_text.text = _save_system.create_save_string()
	_export_text.select_all()
	_export_dialog.popup_centered()


func _on_export_action(action: StringName) -> void:
	if action == &"copy":
		DisplayServer.clipboard_set(_export_text.text)
		_status_label.text = "Save string copied to clipboard"


func _show_import() -> void:
	_import_dialog.dialog_text = "Paste a save string below. Loading replaces the current autosave."
	_import_text.clear()
	_import_dialog.popup_centered()
	_import_text.grab_focus()


func _on_import_action(action: StringName) -> void:
	if action != &"load" or not _save_system:
		return
	if _save_system.import_save_string(_import_text.text):
		_import_dialog.hide()
		_status_label.text = "Save imported and loaded"
	else:
		_import_dialog.dialog_text = "That save string is invalid or incompatible. Nothing was changed."


func _show_save_to_disk() -> void:
	_resolve_services()
	if _save_system and _save_file_dialog:
		_save_file_dialog.popup_centered_ratio(0.7)


func _show_load_from_disk() -> void:
	_resolve_services()
	if _save_system and _load_file_dialog:
		_load_file_dialog.popup_centered_ratio(0.7)


func _on_disk_save_selected(path: String) -> void:
	if not _save_system:
		return
	if _save_system.save_string_to_file(path, _save_system.create_save_string()):
		_status_label.text = "Save written to disk"
	else:
		_status_label.text = "Could not write that save file"


func _on_disk_load_selected(path: String) -> void:
	if not _save_system:
		return
	if _save_system.load_file(path):
		_save_system.save_auto()
		_status_label.text = "Save loaded from disk"
		# Loading resets transient interaction flags, but Settings remains modal.
		var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
		if world:
			world.interaction_locked = true
	else:
		_status_label.text = "That save file is invalid or incompatible"


func _show_backups() -> void:
	if not _save_system:
		return
	var show_all := Input.is_key_pressed(KEY_SHIFT)
	_backup_paths = _save_system.get_backup_paths(show_all)
	_backup_menu.clear()
	if _backup_paths.is_empty():
		_backup_menu.add_item("No backups yet", 0)
		_backup_menu.set_item_disabled(0, true)
	else:
		for index in range(_backup_paths.size()):
			_backup_menu.add_item(_save_system.get_backup_display_name(_backup_paths[index]), index)
		if not show_all and _save_system.get_backup_paths(true).size() > 5:
			_backup_menu.add_separator("Hold Shift for older backups")
	var button_rect := _backup_button.get_global_rect()
	_backup_menu.position = Vector2i(roundi(button_rect.position.x), roundi(button_rect.end.y))
	_backup_menu.popup()


func _on_backup_selected(id: int) -> void:
	if id < 0 or id >= _backup_paths.size() or not _save_system:
		return
	if _save_system.load_backup(_backup_paths[id]):
		_status_label.text = "Backup loaded"
	else:
		_status_label.text = "Could not load that backup"


func _begin_start_over() -> void:
	_start_over_step = 0
	_start_over_dialog.dialog_text = "This deletes the autosave and reloads the game from the very beginning. Your backups remain available. Continue?"
	_start_over_dialog.popup_centered()


func _advance_start_over() -> void:
	_start_over_step += 1
	if _start_over_step == 1:
		_start_over_dialog.dialog_text = "Are you really sure? The fox has already started packing a tiny suitcase."
		_start_over_dialog.popup_centered()
	elif _start_over_step == 2:
		_start_over_dialog.dialog_text = "Last chance. The save goblin is hovering over the big red button and making eye contact."
		_start_over_dialog.popup_centered()
	else:
		if _save_system and _save_system.delete_auto_save():
			get_tree().reload_current_scene()
		else:
			_status_label.text = "Could not delete the autosave"
