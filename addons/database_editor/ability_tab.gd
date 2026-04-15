@tool
extends "res://addons/database_editor/resource_tab.gd"

func get_resource_type_name() -> String:
	return "Ability"

func get_resource_directory() -> String:
	return "res://Resources/Data/Abilities"

func get_resource_class() -> String:
	return "AbilityData"

func _ready() -> void:
	# La carga y señales se gestionan desde database_editor.gd
	pass
