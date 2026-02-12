@tool
extends "res://addons/database_editor/resource_tab.gd"

## Pestaña específica para editar recursos de tipo Pokémon

func _ready() -> void:
	print("[PokemonTab] _ready() llamado")
	super._ready()

func get_resource_type_name() -> String:
	return "Pokémon"

func get_resource_directory() -> String:
	return "res://Resources/Data/Pokemon"

func get_resource_class() -> String:
	return "PokemonData"
