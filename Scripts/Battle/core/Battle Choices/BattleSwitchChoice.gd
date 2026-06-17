class_name BattleSwitchChoice
extends BattleChoice

var target_index: int # El índice del Pokémon al que cambiar
var side: BattleSide = null
var outgoing_pokemon: BattlePokemon = null
var incoming_pokemon: BattlePokemon = null
var origin_spot_index: int = -1

func get_priority() -> int:
	return 6 # En los juegos oficiales, cambiar tiene prioridad 6

func resolve() -> Array[BattleHandler]:
	# Crear el handler de switch
	var side_ref := side if side != null else pokemon.side
	if side_ref == null:
		print("[SWITCH] Side inválido")
		return []
	var spot := pokemon.battle_spot
	if spot == null:
		print("[SWITCH] Spot de origen inválido")
		return []
	var current := outgoing_pokemon if outgoing_pokemon != null else spot.get_active_pokemon()
	if TrapAilmentEffect.is_trapped(current):
		print("[SWITCH] Pokémon atrapado, no puede cambiar")
		return []
	var target_idx := target_index
	var party := side_ref.pokemonParty

	if target_idx < 0 or target_idx >= party.size():
		print("[SWITCH] Índice destino inválido")
		return []

	var incoming: BattlePokemon = incoming_pokemon if incoming_pokemon != null else party[target_idx]
	if incoming == null:
		print("[SWITCH] Pokémon de entrada inválido")
		return []
	if incoming == current:
		print("[SWITCH] Mismo Pokémon, no se realiza el cambio")
		return []

	if incoming.in_battle:
		print("[SWITCH] El Pokémon ya está en combate")
		return []

	var handler = BattleSwitchHandler.new(side_ref, spot, current, incoming, side_ref.battle_rules)
	return [handler]
