@tool
extends "res://addons/database_editor/resource_tab.gd"

## Pestaña específica para editar recursos de tipo Item
## DESHABILITADA TEMPORALMENTE - No carga recursos automáticamente

func get_resource_type_name() -> String:
	return "Item"

func get_resource_directory() -> String:
	return "res://Resources/Data/Items"

func get_resource_class() -> String:
	return "ItemData"

func _ready() -> void:
	# No llamar a super._ready() para evitar carga automática
	# Esta pestaña está deshabilitada temporalmente
	pass

