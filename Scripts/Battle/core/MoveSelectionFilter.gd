class_name MoveSelectionFilter
extends RefCounted

## Pokémon que va a elegir movimiento (IA o comprobaciones de decisión).
var pokemon: BattlePokemon = null
## Copia alineada con `pokemon.get_available_moves()` (mismo orden de índices).
var moves: Array[BattleMove] = []
var _blocked_indices: Dictionary = {}


static func from_pokemon(actor: BattlePokemon) -> MoveSelectionFilter:
	var filter := MoveSelectionFilter.new()
	filter.pokemon = actor
	filter.moves = actor.get_available_moves().duplicate()
	for i in range(filter.moves.size()):
		if filter.moves[i].get_pp() <= 0:
			filter.block_index(i)
	return filter


func block_index(index: int) -> void:
	_blocked_indices[index] = true


func is_index_blocked(index: int) -> bool:
	return bool(_blocked_indices.get(index, false))


func get_selectable_indices() -> Array[int]:
	var out: Array[int] = []
	for i in range(moves.size()):
		if not is_index_blocked(i):
			out.append(i)
	return out
