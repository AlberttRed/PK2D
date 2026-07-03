class_name MoveSelectionFilter
extends RefCounted

## Pokémon que va a elegir movimiento (IA o comprobaciones de decisión).
var pokemon: BattlePokemon = null
## Copia alineada con `pokemon.get_available_moves()` (mismo orden de índices).
var moves: Array[BattleMove] = []
## Si >= 0, la UI debe saltar el menú al pulsar Luchar (p. ej. Encore Gen 3/4).
var auto_submit_index: int = -1
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
	if auto_submit_index == index:
		auto_submit_index = -1


func request_auto_submit(index: int) -> void:
	if index < 0 or index >= moves.size() or is_index_blocked(index):
		return
	auto_submit_index = index


func is_index_blocked(index: int) -> bool:
	return bool(_blocked_indices.get(index, false))


func get_selectable_indices() -> Array[int]:
	var out: Array[int] = []
	for i in range(moves.size()):
		if not is_index_blocked(i):
			out.append(i)
	return out
