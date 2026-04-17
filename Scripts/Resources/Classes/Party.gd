extends RefCounted
class_name Party

const MAX_SIZE: int = 6
const POKEMON_SERDE_SCRIPT = preload("res://Scripts/Runtime/PokemonRuntimeSerde.gd")

var _pokemon_serde = POKEMON_SERDE_SCRIPT.new()

var _members: Array[Pokemon] = []


func clear() -> void:
	_members.clear()


func add_pokemon(pokemon: Pokemon) -> bool:
	if pokemon == null:
		push_warning("Party.add_pokemon: pokemon es null")
		return false
	if pokemon.base == null:
		push_warning("Party.add_pokemon: Pokémon sin inicializar (base == null)")
		return false
	if is_full():
		return false
	_members.append(pokemon)
	return true


func remove_pokemon(index: int) -> Pokemon:
	if index < 0 or index >= _members.size():
		return null
	return _members.pop_at(index)


func swap_slots(i: int, j: int) -> void:
	if i == j:
		return
	if i < 0 or j < 0 or i >= _members.size() or j >= _members.size():
		push_warning("Party.swap_slots: índices fuera de rango (%d, %d), count=%d" % [i, j, count()])
		return
	var tmp: Pokemon = _members[i]
	_members[i] = _members[j]
	_members[j] = tmp


func get_pokemon(index: int) -> Pokemon:
	if index < 0 or index >= _members.size():
		return null
	return _members[index]


func get_all() -> Array[Pokemon]:
	return _members.duplicate()


func count() -> int:
	return _members.size()


func is_full() -> bool:
	return _members.size() >= MAX_SIZE


## Array de diccionarios planos (sin rutas); rehidrata vía PokemonRuntimeSerde.
func to_serializable_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for mon in _members:
		if mon != null:
			data.append(mon.to_serializable_state())
	return data


func load_serializable_data(entries: Array[Dictionary]) -> void:
	clear()
	for entry in entries:
		if is_full():
			push_warning("Party.load_serializable_data: se ignoraron entradas por encima del límite de %d" % MAX_SIZE)
			break
		var mon: Pokemon = _pokemon_serde.deserialize(entry) as Pokemon
		if mon != null:
			_members.append(mon)
