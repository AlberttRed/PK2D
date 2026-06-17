class_name RunEffect
extends ImmediateBattleEffect

var pokemon: BattlePokemon
var can_escape: bool
var succeeded: bool = false

func _init(_pokemon: BattlePokemon, _can_escape: bool):
	pokemon = _pokemon
	can_escape = _can_escape

func apply():
	if not can_escape:
		return

	if TrapAilmentEffect.is_trapped(pokemon):
		succeeded = false
		return

	# Calcular probabilidad de escape basada en velocidad
	succeeded = _calculate_escape_success()
	
	if succeeded:
		pokemon.side.escapedBattle = true

func _calculate_escape_success() -> bool:
	# Fórmula fiel a los juegos originales de Pokémon
	var user_speed = pokemon.get_speed()
	var side = pokemon.side
	var opponent_side = side.opponent_side
	
	if not opponent_side or opponent_side.get_active_pokemons().is_empty():
		return true
	
	var opponent_pokemons = opponent_side.get_active_pokemons()
	var success = true
	
	# Iterar por cada Pokémon rival activo
	for opponent_pokemon in opponent_pokemons:
		var a = user_speed
		var b = opponent_pokemon.get_speed()
		var n = side.escapeAttempts
		
		var base_chance = (a * 128.0) / b + 30 * n
		
		print("base_chance: ", base_chance)

		# Si la probabilidad supera 255, huida garantizada
		if base_chance > 255:
			success = true
			continue
		
		var escape_chance = int(base_chance) % 256
		randomize()
		var roll = randi() % 256
		
		if escape_chance <= roll:
			success = false
			break
	
	# Incrementar intentos de escape después de cada intento
	side.escapeAttempts += 1
	
	return success

func visualize(ui):
	var is_trainer_battle = not can_escape
	
	await ui.show_escape_message(is_trainer_battle, succeeded)
