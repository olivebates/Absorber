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
