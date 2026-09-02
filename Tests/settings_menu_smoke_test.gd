extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	var settings := world.get_node("HUD/SettingsMenu") as SettingsMenu
	assert(settings != null, "The HUD must contain the settings menu")
	assert(settings.get_node("SettingsButton").icon.resource_path == "res://Sprites/Gear.webp", "The settings button must use Gear.webp")
	var settings_anchor := world.get_node("HUD/Minimap/MinimapHeader/Content/SettingsAnchor") as Control
	assert((settings.get_node("SettingsButton") as Button).get_global_rect().position == settings_anchor.get_global_rect().position, "The settings gear must be embedded in the minimap header")
	assert(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "fractional", "The viewport must scale fractionally to the screen borders")
	if SettingsMenu.supports_disk_save_dialogs():
		assert(settings._save_to_disk_button.text == "Save to Disk" and settings._load_from_disk_button.text == "Load from Disk")
		assert(settings._save_file_dialog.access == FileDialog.ACCESS_FILESYSTEM and settings._save_file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE)
		assert(settings._load_file_dialog.access == FileDialog.ACCESS_FILESYSTEM and settings._load_file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE)
	else:
		assert(settings.find_child("DiskSaveActions", true, false) == null, "Disk save controls must not be created outside graphical Windows desktop builds")
	settings.open_settings()
	assert(settings._overlay.visible and world.interaction_locked, "Opening settings must show the modal overlay and lock world input")
	assert(is_equal_approx(settings._music_slider.value, world.game_audio.music_volume), "The music slider must reflect the saved music volume")
	assert(is_equal_approx(settings._sfx_slider.value, world.game_audio.sfx_volume), "The SFX slider must reflect the saved SFX volume")
	settings._show_export()
	assert(not settings._export_text.text.is_empty(), "Export must display a portable save string")
	settings._export_dialog.hide()
	settings._show_backups()
	settings._backup_menu.hide()
	settings._begin_start_over()
	assert(settings._start_over_dialog.visible and settings._start_over_step == 0, "Start Over must begin its confirmation sequence")
	settings.close_settings()
	assert(not settings._overlay.visible and not world.interaction_locked, "Closing settings must hide the overlay and restore world input")
	assert(SaveSystem.AUTO_SAVE_INTERVAL == 5.0 and SaveSystem.MAX_BACKUPS == 20, "Autosave and backup limits must match the settings contract")
	print("PASS: settings overlay, save transfer, backups, and reset controls work")
	quit()
