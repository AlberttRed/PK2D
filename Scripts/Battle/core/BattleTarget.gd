class_name BattleTarget
extends RefCounted

signal request_manual_selection(candidates: Array[BattleSpot])
signal target_selected

enum TYPE {
	NONE, ESPECIFICO, YO_PRIMERO, ALIADO,
	BASE_PLAYER, USER_OR_ALLY, BASE_ENEMY,
	USER, RANDOM_ENEMY, ALL_OTHER, SELECCIONAR,
	ENEMIES, ALL_FIELD, PLAYERS, ALL_POKEMON
}

var move: BattleMove
var type: TYPE:
	get: return move.base_data.get_target_id()

var selected_targets: Array[BattleSpot] = []
var _targetCursor: int = -1

func _init(move: BattleMove):
	self.move = move

func get_actual_target() -> BattleSpot:
	if selected_targets.is_empty() or _targetCursor >= selected_targets.size():
		return null
	return selected_targets[_targetCursor]

func nextTarget() -> bool:
	_targetCursor += 1
	return get_actual_target() != null

#func select_targets() -> void:
	#selected_targets.clear()
	#_targetCursor = -1
#
	#match type:
		#TYPE.SELECCIONAR:
			#if move.pokemon.controllable:
				#await await_manual_selection(_get_selectable_enemy_spots())
			#else:
				#selected_targets.append(_get_random_enemy_spot())
#
		#TYPE.USER:
			#selected_targets.append(move.pokemon.battle_spot)
#
		#TYPE.ENEMIES:
			#selected_targets = _get_enemy_spots()
#
		#TYPE.PLAYERS:
			#selected_targets = _get_player_spots()
#
		## Otros tipos según necesidad...

func select_targets() -> void:
	selected_targets.clear()
	_targetCursor = -1

	match type:
		TYPE.ESPECIFICO:
			# No se selecciona en combate, se usa internamente
			pass

		TYPE.YO_PRIMERO:
			selected_targets.append(move.pokemon.battle_spot)

		TYPE.ALIADO:
			selected_targets.append(_get_ally_spot())

		TYPE.BASE_PLAYER:
			selected_targets.append(_get_player_base_spot())

		TYPE.USER_OR_ALLY:
			selected_targets.append(_get_user_or_ally_spot())

		TYPE.BASE_ENEMY:
			selected_targets.append(_get_enemy_base_spot())

		TYPE.USER:
			selected_targets.append(move.pokemon.battle_spot)

		TYPE.RANDOM_ENEMY:
			selected_targets.append(_get_random_enemy_spot())

		TYPE.ALL_OTHER:
			selected_targets = _get_all_other_spots()

		TYPE.SELECCIONAR:
			if move.pokemon.controllable:
				await await_manual_selection(_get_selectable_enemy_spots())
			else:
				selected_targets.append(_get_random_enemy_spot())

		TYPE.ENEMIES:
			selected_targets = _get_enemy_spots()

		TYPE.ALL_FIELD:
			selected_targets = _get_all_field_spots()

		TYPE.PLAYERS:
			selected_targets = _get_player_spots()

		TYPE.ALL_POKEMON:
			selected_targets = _get_all_pokemon_spots()

		_:
			push_warning("Target type no manejado: %s" % str(type))


func set_manual_target(spot: BattleSpot) -> void:
	selected_targets = [spot]
	_targetCursor = 0
	emit_signal("target_selected")

# --------------------------------------
# Métodos auxiliares

func _get_enemy_spots() -> Array[BattleSpot]:
	return move.pokemon.get_opponent_side().battle_spots.filter(
		func(s): return s.has_active_pokemon()
	)

func _get_player_spots() -> Array[BattleSpot]:
	return move.pokemon.side.battle_spots.filter(
		func(s): return s.has_active_pokemon()
	)

func _get_selectable_enemy_spots() -> Array[BattleSpot]:
	var all := _get_enemy_spots()
	return all if not all.is_empty() else []
	
func _get_random_enemy_spot() -> BattleSpot:
	var enemies = _get_enemy_spots()
	if enemies.is_empty(): return null
	return enemies[randi() % enemies.size()]
	
func await_manual_selection(candidates: Array[BattleSpot]) -> void:
	if candidates.size() == 1:
		set_manual_target(candidates[0])
	else:
		emit_signal("request_manual_selection", candidates)
		await target_selected
	
func get_candidate_spots() -> Array[BattleSpot]:
	match type:
		TYPE.SELECCIONAR:
			return _get_selectable_enemy_spots()
		#TYPE.USER_OR_ALLY:
			#return _get_user_or_ally_spots()
		# Otros tipos si quieres extenderlo...
		_:
			return []

func _get_ally_spot() -> BattleSpot:
	# Devuelve el compañero del usuario si existe
	return _get_player_spots().filter(func(s): return s != move.pokemon.battle_spot)[0]

func _get_user_or_ally_spot() -> BattleSpot:
	return move.pokemon.battle_spot if _get_ally_spot() == null else _get_ally_spot()

func _get_player_base_spot() -> BattleSpot:
	# Nodo de la base del jugador (ej: suelo, decorativo)
	return null

func _get_enemy_base_spot() -> BattleSpot:
	return null

func _get_all_other_spots() -> Array:
	var all := _get_all_pokemon_spots()
	return all.filter(func(s): return s != move.pokemon.battle_spot)

func _get_all_field_spots() -> Array:
	return _get_player_spots() + _get_enemy_spots()

func _get_all_pokemon_spots() -> Array:
	return _get_all_field_spots().filter(func(s): return s.has_active_pokemon())
