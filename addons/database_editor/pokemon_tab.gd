@tool
extends "res://addons/database_editor/resource_tab.gd"

## Pestaña específica para editar recursos de tipo Pokémon
## Igual que MoveTab: no llama a super._ready() para que solo DatabaseEditor
## gestione lista, búsqueda y detalle (evitar doble handler que rompe el filtro).

func get_resource_type_name() -> String:
	return "Pokémon"

func get_resource_directory() -> String:
	return "res://Resources/Data/Pokemon"

func get_resource_class() -> String:
	return "PokemonData"

func _ready() -> void:
	# No llamar a super._ready(): ResourceTab conectaría búsqueda/selección
	# en paralelo a database_editor.gd y tras filtrar la selección falla.
	pass
