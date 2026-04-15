@tool
extends "res://addons/database_editor/resource_tab.gd"

## Pestaña específica para editar recursos de tipo Trainer
## La carga se realiza desde DatabaseEditor para mantener consistencia.

func get_resource_type_name() -> String:
	return "Trainer"

func get_resource_directory() -> String:
	return "res://Resources/Trainers"

func get_resource_class() -> String:
	return "TrainerData"

func _ready() -> void:
	# La lógica de carga y eventos se maneja en database_editor.gd
	pass
