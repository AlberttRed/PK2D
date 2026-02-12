@tool
extends "res://addons/database_editor/resource_tab.gd"

## Pestaña específica para editar recursos de tipo Move
## DESHABILITADA TEMPORALMENTE - No carga recursos automáticamente

func get_resource_type_name() -> String:
	return "Move"

func get_resource_directory() -> String:
	return "res://Resources/Data/Moves"

func get_resource_class() -> String:
	return "MoveData"

func _ready() -> void:
	# No llamar a super._ready() para evitar carga automática
	# Esta pestaña está deshabilitada temporalmente
	pass

