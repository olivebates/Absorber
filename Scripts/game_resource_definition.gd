class_name GameResourceDefinition
extends Resource

## Editor-authored definition for one resource in the shared resource economy.
@export var resource_id: StringName = &"gold_ore"
@export var display_name := "Gold Ore"
@export var icon: Texture2D
@export var display_color := Color("e9c64d")
@export_range(1, 999999, 1) var maximum_amount := 99
@export_range(0, 999999, 1) var starting_amount := 0
@export_range(0.0, 9999.0, 0.001, "suffix:/sec") var production_speed := 0.0
