@tool
extends "res://addons/database_editor/resource_tab.gd"

func get_resource_type_name() -> String:
	return "Shop"

func get_resource_directory() -> String:
	return "res://Resources/Shops"

func get_resource_class() -> String:
	return "ShopData"

func _ready() -> void:
	# La carga y señales se gestionan desde database_editor.gd
	pass
