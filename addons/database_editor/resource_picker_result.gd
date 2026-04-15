## Resultado de la selección en el Resource Picker
## Se devuelve cuando el usuario confirma una selección en modo picker
@tool
extends RefCounted
class_name ResourcePickerResult

## ID del recurso seleccionado
var resource_id: int = 0

## Path del recurso seleccionado (opcional, para compatibilidad)
var resource_path: String = ""

## Nombre para mostrar del recurso (display_name o Name)
var display_name: String = ""

## Tipo de recurso seleccionado (POKEMON, MOVE, ITEM, TRAINER, TYPE, AILMENT, ABILITY, WEATHER)
var resource_type: String = ""

## Recurso completo (opcional, para acceso directo)
var resource: Resource = null

func _init(p_id: int = 0, p_path: String = "", p_name: String = "", p_type: String = "", p_resource: Resource = null) -> void:
	resource_id = p_id
	resource_path = p_path
	display_name = p_name
	resource_type = p_type
	resource = p_resource

