class_name GoldOre
extends Node2D

const MINER_STRUCTURE_SCENE := preload("res://Scenes/miner_structure.tscn")

@export var build_cost: Dictionary = {"gold_ore": 5, "jewels": 2}

var _mine: MinerStructure
var _resource_manager: ResourceManager
var _button_is_in_hud := false
var _build_tooltip: BuildMineTooltip

@onready var build_button: Button = $BuildMineButton


func _ready() -> void:
	add_to_group("gold_ores")
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	build_button.pressed.connect(_try_build_mine)
	build_button.mouse_entered.connect(_show_build_tooltip)
	build_button.mouse_exited.connect(_hide_build_tooltip)
	build_button.visible = false
	build_button.tooltip_text = ""
	_set_button_style()
	if _resource_manager:
		_resource_manager.resource_changed.connect(_on_resource_changed)
	call_deferred("_move_build_button_to_hud")


func show_build_button() -> void:
	if _mine == null:
		build_button.text = "Build Mine"
		_update_build_availability()
		build_button.visible = true
		_update_build_button_position()


func hide_build_button() -> void:
	if _mine == null:
		build_button.visible = false
		_hide_build_tooltip()


func _try_build_mine() -> void:
	if _mine != null or _resource_manager == null:
		return
	if not _resource_manager.spend_resources(build_cost):
		_update_build_availability()
		return
	_mine = MINER_STRUCTURE_SCENE.instantiate() as MinerStructure
	add_child(_mine)
	build_button.visible = false
	_hide_build_tooltip()


func get_save_data() -> Array:
	return [0] if _mine == null else [1, _mine.get_save_data()]


func load_save_data(data: Array, offline_seconds: int) -> bool:
	if data.is_empty():
		return false
	var should_have_mine := int(data[0]) != 0
	if not should_have_mine:
		if is_instance_valid(_mine):
			_mine.free()
		_mine = null
		return true
	if not is_instance_valid(_mine):
		_mine = MINER_STRUCTURE_SCENE.instantiate() as MinerStructure
		add_child(_mine)
	_mine.load_save_data(int(data[1]) if data.size() > 1 else 0, offline_seconds)
	build_button.visible = false
	_hide_build_tooltip()
	return true


func _cost_text() -> String:
	var entries: Array[String] = []
	for resource_id in build_cost:
		var definition := _resource_manager.get_definition(StringName(resource_id)) if _resource_manager else null
		entries.append("%d %s" % [int(build_cost[resource_id]), definition.display_name if definition else str(resource_id)])
	return ", ".join(entries)


func _process(_delta: float) -> void:
	if build_button.visible:
		_update_build_button_position()


func _on_resource_changed(_resource_id: StringName, _amount: int, _maximum_amount: int) -> void:
	if _mine == null:
		_update_build_availability()


func _update_build_availability() -> void:
	build_button.disabled = _resource_manager == null or not _resource_manager.can_afford(build_cost)


func _move_build_button_to_hud() -> void:
	if _button_is_in_hud:
		return
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	var hud: CanvasLayer
	if world:
		hud = world.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	build_button.reparent(hud, false)
	_button_is_in_hud = true
	_build_tooltip = hud.get_node_or_null("BuildMineTooltip") as BuildMineTooltip
	_update_build_button_position()


func _update_build_button_position() -> void:
	if not _button_is_in_hud:
		return
	var screen_position := get_global_transform_with_canvas().origin
	build_button.position = screen_position - build_button.size * 0.5


func _set_button_style() -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4d3d12") if state == "normal" else Color("715b19") if state == "hover" else Color("2f260a") if state == "pressed" else Color("25272d")
		style.border_color = Color("e9c64d") if state != "disabled" else Color("626975")
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		build_button.add_theme_stylebox_override(state, style)
	build_button.add_theme_color_override("font_color", Color("fff2bd"))
	build_button.add_theme_color_override("font_outline_color", Color.BLACK)
	build_button.add_theme_constant_override("outline_size", 2)


func _show_build_tooltip() -> void:
	if _mine == null and build_button.visible and _build_tooltip:
		_build_tooltip.show_cost(build_cost, _resource_manager)


func _hide_build_tooltip() -> void:
	if _build_tooltip:
		_build_tooltip.hide_tooltip()
