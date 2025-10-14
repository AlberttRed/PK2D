extends RefCounted
class_name BattleTargetSelector

## Lógica de targeting reutilizable (sin UI)

## Genera/resuelve una lista de BattleTarget según el tipo de movimiento
func resolve_targets(move: BattleMove, user: BattlePokemon, manual_target: BattleSpot = null) -> Array[BattleTarget]:
	var targets: Array[BattleTarget] = []
	var target_type := move.base_data.get_target_id() as BattleTarget.TYPE
	
	match target_type:
		BattleTarget.TYPE.ESPECIFICO:
			# No se selecciona en combate, se usa internamente
			pass
			
		BattleTarget.TYPE.YO_PRIMERO, BattleTarget.TYPE.USER:
			# El usuario se apunta a sí mismo
			targets.append(BattleTarget.new(user, target_type))
			
		BattleTarget.TYPE.ALIADO:
			var ally := _get_ally_pokemon(user)
			if ally:
				targets.append(BattleTarget.new(ally, target_type))
				
		BattleTarget.TYPE.USER_OR_ALLY:
			var ally := _get_ally_pokemon(user)
			var target_pokemon = ally if ally else user
			targets.append(BattleTarget.new(target_pokemon, target_type))
			
		BattleTarget.TYPE.BASE_PLAYER:
			# Target es el lado del jugador
			targets.append(BattleTarget.new(user.side, target_type))
			
		BattleTarget.TYPE.BASE_ENEMY:
			# Target es el lado enemigo
			targets.append(BattleTarget.new(user.get_opponent_side(), target_type))
			
		BattleTarget.TYPE.RANDOM_ENEMY:
			var random_enemy := _get_random_enemy_pokemon(user)
			if random_enemy:
				targets.append(BattleTarget.new(random_enemy, target_type))
				
		BattleTarget.TYPE.SELECCIONAR:
			# Si hay un target manual, usarlo; sino seleccionar enemigo aleatorio
			if manual_target and manual_target.has_active_pokemon():
				targets.append(BattleTarget.new(manual_target.get_active_pokemon(), target_type))
			else:
				var random_enemy2 := _get_random_enemy_pokemon(user)
				if random_enemy2:
					targets.append(BattleTarget.new(random_enemy2, target_type))
					
		BattleTarget.TYPE.ENEMIES:
			# Todos los enemigos activos como targets individuales
			var enemies := _get_enemy_pokemons(user)
			for enemy in enemies:
				targets.append(BattleTarget.new(enemy, target_type))
				
		BattleTarget.TYPE.PLAYERS:
			# Todos los aliados activos como targets individuales
			var allies := _get_ally_side_pokemons(user)
			for ally in allies:
				targets.append(BattleTarget.new(ally, target_type))
				
		BattleTarget.TYPE.ALL_OTHER:
			# Todos los pokémon excepto el usuario
			var all_others := _get_all_other_pokemons(user)
			for pokemon in all_others:
				targets.append(BattleTarget.new(pokemon, target_type))
				
		BattleTarget.TYPE.ALL_POKEMON:
			# Todos los pokémon en el campo
			var all_pokemon := _get_all_active_pokemons(user)
			for pokemon in all_pokemon:
				targets.append(BattleTarget.new(pokemon, target_type))
				
		BattleTarget.TYPE.ALL_FIELD:
			# El campo completo - un único target de tipo FIELD
			targets.append(BattleTarget.new(null, target_type))  # null = FIELD
			
		_:
			push_warning("Target type no manejado: %s" % str(target_type))
	
	return targets

## Verifica si el tipo de targeting requiere selección manual del jugador
func requires_manual_selection(target_type: BattleTarget.TYPE, user: BattlePokemon) -> bool:
	return target_type == BattleTarget.TYPE.SELECCIONAR and user.controllable

## Obtiene los candidatos para selección manual (como BattleSpot para la UI)
func get_selectable_spots(user: BattlePokemon) -> Array[BattleSpot]:
	return _get_enemy_spots(user)

# ============================================================================
# Métodos auxiliares privados (sin UI)
# ============================================================================

func _get_enemy_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var pokemons: Array[BattlePokemon] = []
	for spot in _get_enemy_spots(user):
		if spot.has_active_pokemon():
			pokemons.append(spot.get_active_pokemon())
	return pokemons

func _get_ally_side_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var pokemons: Array[BattlePokemon] = []
	for spot in _get_ally_spots(user):
		if spot.has_active_pokemon():
			pokemons.append(spot.get_active_pokemon())
	return pokemons

func _get_all_active_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var pokemons: Array[BattlePokemon] = []
	pokemons.append_array(_get_ally_side_pokemons(user))
	pokemons.append_array(_get_enemy_pokemons(user))
	return pokemons

func _get_all_other_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var all := _get_all_active_pokemons(user)
	return all.filter(func(p): return p != user)

func _get_enemy_spots(user: BattlePokemon) -> Array[BattleSpot]:
	return user.get_opponent_side().battle_spots.filter(
		func(s): return s.has_active_pokemon()
	)

func _get_ally_spots(user: BattlePokemon) -> Array[BattleSpot]:
	return user.side.battle_spots.filter(
		func(s): return s.has_active_pokemon()
	)

func _get_random_enemy_pokemon(user: BattlePokemon) -> BattlePokemon:
	var enemies := _get_enemy_pokemons(user)
	if enemies.is_empty():
		return null
	return enemies[randi() % enemies.size()]

func _get_ally_pokemon(user: BattlePokemon) -> BattlePokemon:
	# Devuelve el compañero del usuario si existe
	var allies := _get_ally_side_pokemons(user)
	for ally in allies:
		if ally != user:
			return ally
	return null
