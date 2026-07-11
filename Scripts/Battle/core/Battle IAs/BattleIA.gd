extends Resource

class_name BattleIA

## Clase base para la inteligencia artificial de combate.
## 
## Las subclases deben implementar el método decide_action() que devuelve
## un BattleChoice válido para el Pokémon controlado por la IA.
##
## Esta clase también proporciona métodos de utilidad comunes para evaluar
## movimientos y objetivos basados en efectividad de tipos, que pueden ser
## utilizados por cualquier IA.
##
## Ejemplos de subclases:
## - BattleIA_Wild: Comportamiento aleatorio simple
## - BattleIA_Easy: Considera efectividad de tipos
## - BattleIA_Medium: (Futuro) Considera stats y cambios
## - BattleIA_Hard: (Futuro) Estrategia avanzada

## Configuración exportable para ajustar comportamiento desde el editor
@export var difficulty_name: String = "Default"
@export var use_items: bool = false
@export var can_switch_strategically: bool = false

## Método principal que debe implementarse en todas las subclases.
## Recibe el Pokémon que debe tomar una decisión y devuelve un BattleChoice válido.
func decide_action(_pokemon: BattlePokemon) -> BattleChoice:
	push_error("decide_action() debe ser implementado en la subclase de BattleIA")
	return BattlePassChoice.new()

## Elige el sustituto tras debilitarse el activo (cambio forzado por KO).
## Las subclases pueden sobreescribir para estrategia (tipos, matchups, etc.).
func decide_forced_switch(side: BattleSide, spot: BattleSpot, fainted: BattlePokemon) -> BattleSwitchChoice:
	return build_first_available_forced_switch(side, spot, fainted)

## Primer Pokémon vivo del party que no esté en campo (orden de lista).
func build_first_available_forced_switch(
	side: BattleSide,
	spot: BattleSpot,
	fainted: BattlePokemon
) -> BattleSwitchChoice:
	var incoming := find_first_bench_pokemon(side)
	if incoming == null:
		return null
	return _make_forced_switch_choice(side, spot, fainted, incoming)


func find_first_bench_pokemon(side: BattleSide) -> BattlePokemon:
	if side == null:
		return null
	for p in side.pokemonParty:
		if p != null and not p.is_fainted() and not p.in_battle:
			return p
	return null


func _make_forced_switch_choice(
	side: BattleSide,
	spot: BattleSpot,
	fainted: BattlePokemon,
	incoming: BattlePokemon
) -> BattleSwitchChoice:
	var choice := BattleSwitchChoice.new()
	choice.side = side
	choice.target_spot = spot
	choice.outgoing_pokemon = fainted
	choice.incoming_pokemon = incoming
	choice.pokemon = incoming
	choice.forced_by_faint = true
	if spot != null:
		choice.origin_spot_index = spot.index
	choice.target_index = side.pokemonParty.find(incoming)
	return choice

# ============================================================================
# MÉTODOS DE UTILIDAD COMUNES PARA TODAS LAS IAS
# ============================================================================

## Movimientos que la IA puede elegir (PP + reglas de efectos activos).
func get_selectable_move_indices(pokemon: BattlePokemon) -> Array[int]:
	return pokemon.get_selectable_move_indices()

## Evalúa todas las combinaciones posibles de (movimiento, objetivo) y retorna
## la mejor basándose en efectividad de tipos.
##
## Este método puede ser usado por cualquier IA que quiera tomar decisiones
## basadas en efectividad de tipos.
##
## Retorna un Dictionary con:
## - move_index: int - Índice del mejor movimiento
## - target_spot: BattleSpot o null - Objetivo específico (null para multi-objetivo)
## - effectiveness: float - Efectividad de la combinación elegida
func evaluate_best_move_target_combination(
	moves: Array[BattleMove],
	enemies: Array[BattlePokemon],
	only_move_indices: Array[int] = []
) -> Dictionary:
	var indices: Array[int] = only_move_indices
	if indices.is_empty():
		for i in range(moves.size()):
			indices.append(i)

	var all_combinations: Array[Dictionary] = []

	for i in indices:
		if i < 0 or i >= moves.size():
			continue
		var move := moves[i]
		var target_type = move.base_data.get_target_id() as BattleTarget.TYPE
		
		# Evaluar según el tipo de objetivo del movimiento
		match target_type:
			BattleTarget.TYPE.SELECCIONAR, BattleTarget.TYPE.RANDOM_ENEMY, BattleTarget.TYPE.BASE_ENEMY:
				# Movimientos de objetivo único: evaluar contra cada enemigo
				for enemy in enemies:
					var effectiveness = move.get_effectiveness_against_pokemon(enemy)
					all_combinations.append({
						"move_index": i,
						"target_spot": enemy.battle_spot,
						"effectiveness": effectiveness
					})
			
			BattleTarget.TYPE.ENEMIES, BattleTarget.TYPE.ALL_FIELD, BattleTarget.TYPE.ALL_POKEMON:
				# Movimientos multi-objetivo: calcular efectividad promedio
				var avg_effectiveness = _calculate_average_effectiveness(move, enemies)
				all_combinations.append({
					"move_index": i,
					"target_spot": null,  # No hay objetivo específico
					"effectiveness": avg_effectiveness
				})
			
			_:
				# Otros tipos (USER, ALIADO, etc.): usar efectividad promedio
				var avg_effectiveness = _calculate_average_effectiveness(move, enemies)
				all_combinations.append({
					"move_index": i,
					"target_spot": null,
					"effectiveness": avg_effectiveness
				})
	
	# Si no hay combinaciones válidas, retornar una aleatoria entre índices permitidos
	if all_combinations.is_empty():
		if indices.is_empty():
			return {"move_index": 0, "target_spot": null, "effectiveness": 0.0}
		return {"move_index": indices[randi() % indices.size()], "target_spot": null, "effectiveness": 0.0}
	
	# Encontrar y retornar la mejor combinación
	return _select_best_combination(all_combinations)

## Calcula la efectividad promedio de un movimiento contra múltiples enemigos.
func _calculate_average_effectiveness(move: BattleMove, enemies: Array[BattlePokemon]) -> float:
	if enemies.is_empty():
		return 0.0
	
	var total_effectiveness := 0.0
	for enemy in enemies:
		total_effectiveness += move.get_effectiveness_against_pokemon(enemy)
	
	return total_effectiveness / float(enemies.size())

## Selecciona la mejor combinación de un array de combinaciones.
## En caso de empate, elige aleatoriamente entre las mejores.
func _select_best_combination(combinations: Array[Dictionary]) -> Dictionary:
	# Encontrar la mejor efectividad
	var best_effectiveness := 0.0
	for combo in combinations:
		if combo.effectiveness > best_effectiveness:
			best_effectiveness = combo.effectiveness
	
	# Si todos tienen efectividad 0 o negativa (inmunes), elegir aleatorio
	if best_effectiveness <= 0.0:
		return combinations[randi() % combinations.size()]
	
	# Recopilar todas las combinaciones con la mejor efectividad
	var best_combos: Array[Dictionary] = []
	for combo in combinations:
		if is_equal_approx(combo.effectiveness, best_effectiveness):
			best_combos.append(combo)
	
	# Si hay empate, elegir aleatoriamente
	return best_combos[randi() % best_combos.size()]
