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
			if user.battle_spot != null:
				targets.append(BattleTarget.new(user.battle_spot, target_type))
			
		BattleTarget.TYPE.ALIADO:
			var ally_spot := _get_ally_spot(user)
			if ally_spot:
				targets.append(BattleTarget.new(ally_spot, target_type))
				
		BattleTarget.TYPE.USER_OR_ALLY:
			var target_spot: BattleSpot = _get_ally_spot(user)
			if target_spot == null:
				target_spot = user.battle_spot
			if target_spot != null:
				targets.append(BattleTarget.new(target_spot, target_type))
			
		BattleTarget.TYPE.BASE_PLAYER:
			# Target es el lado del jugador
			targets.append(BattleTarget.new(user.side, target_type))
			
		BattleTarget.TYPE.BASE_ENEMY:
			# Target es el lado enemigo
			targets.append(BattleTarget.new(user.get_opponent_side(), target_type))
			
		BattleTarget.TYPE.RANDOM_ENEMY:
			var random_enemy_spot := _get_random_enemy_spot(user)
			if random_enemy_spot:
				targets.append(BattleTarget.new(random_enemy_spot, target_type))
				
		BattleTarget.TYPE.SELECCIONAR:
			# Si hay un target manual, usarlo; sino seleccionar enemigo aleatorio
			if manual_target and manual_target.has_active_pokemon():
				targets.append(BattleTarget.new(manual_target, target_type))
			else:
				var random_enemy2 := _get_random_enemy_spot(user)
				if random_enemy2:
					targets.append(BattleTarget.new(random_enemy2, target_type))
					
		BattleTarget.TYPE.ENEMIES:
			# Todos los enemigos activos como targets individuales
			var enemy_spots := _get_enemy_spots(user)
			for spot in enemy_spots:
				targets.append(BattleTarget.new(spot, target_type))
				
		BattleTarget.TYPE.PLAYERS:
			# Todos los aliados activos como targets individuales
			var ally_spots := _get_ally_spots(user)
			for ally_spot in ally_spots:
				targets.append(BattleTarget.new(ally_spot, target_type))
				
		BattleTarget.TYPE.ALL_OTHER:
			# Todos los pokémon excepto el usuario
			var other_spots := _get_all_other_spots(user)
			for other_spot in other_spots:
				targets.append(BattleTarget.new(other_spot, target_type))
				
		BattleTarget.TYPE.ALL_POKEMON:
			# Todos los pokémon en el campo
			var all_spots := _get_all_active_spots(user)
			for active_spot in all_spots:
				targets.append(BattleTarget.new(active_spot, target_type))
				
		BattleTarget.TYPE.ALL_FIELD:
			# El campo completo - un único target de tipo FIELD
			targets.append(BattleTarget.new(null, target_type))  # null = FIELD
			
		_:
			push_warning("Target type no manejado: %s" % str(target_type))
	
	return targets

## Verifica si el tipo de targeting requiere selección manual del jugador
func requires_manual_selection(target_type: BattleTarget.TYPE, user: BattlePokemon) -> bool:
	return target_type == BattleTarget.TYPE.SELECCIONAR and user.controllable

## Cuadrícula para la UI: fila 0 = rivales, fila 1 = aliado (sin el usuario).
func build_selection_grid(user: BattlePokemon, enemies_only: bool = false) -> TargetSelectionGrid:
	var rows: Array = [_spots_sorted_by_index(_get_enemy_spots(user))]
	if not enemies_only:
		var allies: Array[BattleSpot] = []
		for spot in _get_ally_spots(user):
			if spot != user.battle_spot:
				allies.append(spot)
		allies = _spots_sorted_by_index(allies)
		if not allies.is_empty():
			rows.append(allies)
	return TargetSelectionGrid.new(rows)


## Lista plana de candidatos (auto-target 1 candidato, resolve_targets, etc.).
func get_selectable_spots(user: BattlePokemon, enemies_only: bool = false) -> Array[BattleSpot]:
	return build_selection_grid(user, enemies_only).all_spots()


func _spots_sorted_by_index(spots: Array[BattleSpot]) -> Array[BattleSpot]:
	var sorted := spots.duplicate()
	sorted.sort_custom(func(a: BattleSpot, b: BattleSpot) -> bool:
		return int(a.index) < int(b.index)
	)
	return sorted

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

func _get_all_active_spots(user: BattlePokemon) -> Array[BattleSpot]:
	var spots: Array[BattleSpot] = []
	spots.append_array(_get_ally_spots(user))
	spots.append_array(_get_enemy_spots(user))
	return spots

func _get_all_other_spots(user: BattlePokemon) -> Array[BattleSpot]:
	var all_spots := _get_all_active_spots(user)
	return all_spots.filter(func(s): return s != user.battle_spot)

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

func _get_random_enemy_spot(user: BattlePokemon) -> BattleSpot:
	var enemy_spots := _get_enemy_spots(user)
	if enemy_spots.is_empty():
		return null
	return enemy_spots[randi() % enemy_spots.size()]

func _get_ally_spot(user: BattlePokemon) -> BattleSpot:
	for spot in _get_ally_spots(user):
		if spot != user.battle_spot:
			return spot
	return null

func _get_ally_pokemon(user: BattlePokemon) -> BattlePokemon:
	# Devuelve el compañero del usuario si existe
	var allies := _get_ally_side_pokemons(user)
	for ally in allies:
		if ally != user:
			return ally
	return null
