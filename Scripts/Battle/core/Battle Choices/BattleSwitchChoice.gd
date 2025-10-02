class_name BattleSwitchChoice
extends BattleChoice

var target_index: int # El índice del Pokémon al que cambiar

func get_priority() -> int:
	return 6 # En los juegos oficiales, cambiar tiene prioridad 6

func resolve() -> Array[BattleHandler]:
	# Crear el handler de switch
	var spot := pokemon.battle_spot
	var current := spot.get_active_pokemon()
	var target_idx := target_index
	var party := pokemon.side.pokemonParty
	
	if target_idx < 0 or target_idx >= party.size():
		print("[SWITCH] Índice destino inválido")
		return []
	
	var incoming: BattlePokemon = party[target_idx]
	if incoming == current:
		print("[SWITCH] Mismo Pokémon, no se realiza el cambio")
		return []

	if incoming.in_battle:
		print("[SWITCH] El Pokémon ya está en combate")
		return []
	
	var handler = BattleSwitchHandler.new(pokemon.side, spot, current, incoming, pokemon.side.battle_rules)
	return [handler]
