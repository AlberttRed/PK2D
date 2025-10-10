extends Control
class_name BattleTargetSelector

## Unifica la lógica de targeting y la UI de selección manual de objetivos.
## - Genera listas de BattleTarget según el tipo de movimiento
## - Gestiona la selección manual del jugador cuando es necesario

signal target_chosen(spot: BattleSpot)

# Variables para UI de selección manual
var spots: Array[BattleSpot] = []
var current_index := 0

func _ready():
	# Conectar a las señales de input del SignalManager
	SignalManager.input_left.connect(_on_input_left)
	SignalManager.input_right.connect(_on_input_right)
	SignalManager.input_accept.connect(_on_input_accept)

# ============================================================================
# API Pública - Generación de Targets
# ============================================================================

## Genera una lista de BattleTarget según el tipo de targeting del movimiento
## move: el BattleMove que se va a usar
## user: el BattlePokemon que usa el movimiento
## manual_target: opcional, si el jugador ya seleccionó un target manualmente (BattleSpot)
static func generate_targets(move: BattleMove, user: BattlePokemon, manual_target: BattleSpot = null) -> Array[BattleTarget]:
	var targets: Array[BattleTarget] = []
	var target_type := move.base_data.get_target_id() as BattleTarget.TYPE
	
	match target_type:
		BattleTarget.TYPE.ESPECIFICO:
			# No se selecciona en combate, se usa internamente
			pass
			
		BattleTarget.TYPE.YO_PRIMERO, BattleTarget.TYPE.USER:
			# El usuario se apunta a sí mismo
			targets.append(BattleTarget.new(user))
			
		BattleTarget.TYPE.ALIADO:
			var ally := _get_ally_pokemon(user)
			if ally:
				targets.append(BattleTarget.new(ally))
				
		BattleTarget.TYPE.USER_OR_ALLY:
			var ally := _get_ally_pokemon(user)
			var target_pokemon = ally if ally else user
			targets.append(BattleTarget.new(target_pokemon))
			
		BattleTarget.TYPE.BASE_PLAYER:
			# Target es el lado del jugador
			targets.append(BattleTarget.new(user.side))
			
		BattleTarget.TYPE.BASE_ENEMY:
			# Target es el lado enemigo
			targets.append(BattleTarget.new(user.get_opponent_side()))
			
		BattleTarget.TYPE.RANDOM_ENEMY:
			var random_enemy := _get_random_enemy_pokemon(user)
			if random_enemy:
				targets.append(BattleTarget.new(random_enemy))
				
		BattleTarget.TYPE.SELECCIONAR:
			# Si hay un target manual, usarlo; sino seleccionar enemigo aleatorio
			if manual_target and manual_target.has_active_pokemon():
				targets.append(BattleTarget.new(manual_target.get_active_pokemon()))
			else:
				var random_enemy := _get_random_enemy_pokemon(user)
				if random_enemy:
					targets.append(BattleTarget.new(random_enemy))
					
		BattleTarget.TYPE.ENEMIES:
			# Todos los enemigos activos como targets individuales
			var enemies := _get_enemy_pokemons(user)
			for enemy in enemies:
				targets.append(BattleTarget.new(enemy))
				
		BattleTarget.TYPE.PLAYERS:
			# Todos los aliados activos como targets individuales
			var allies := _get_ally_side_pokemons(user)
			for ally in allies:
				targets.append(BattleTarget.new(ally))
				
		BattleTarget.TYPE.ALL_OTHER:
			# Todos los pokémon excepto el usuario
			var all_others := _get_all_other_pokemons(user)
			for pokemon in all_others:
				targets.append(BattleTarget.new(pokemon))
				
		BattleTarget.TYPE.ALL_POKEMON:
			# Todos los pokémon en el campo
			var all_pokemon := _get_all_active_pokemons(user)
			for pokemon in all_pokemon:
				targets.append(BattleTarget.new(pokemon))
				
		BattleTarget.TYPE.ALL_FIELD:
			# El campo completo - un único target de tipo FIELD
			targets.append(BattleTarget.new(null))  # null = FIELD
			
		_:
			push_warning("Target type no manejado: %s" % str(target_type))
	
	return targets

## Verifica si el tipo de targeting requiere selección manual del jugador
static func requires_manual_selection(target_type: BattleTarget.TYPE, user: BattlePokemon) -> bool:
	return target_type == BattleTarget.TYPE.SELECCIONAR and user.controllable

## Obtiene los candidatos para selección manual (como BattleSpot para la UI)
static func get_selectable_spots(user: BattlePokemon) -> Array[BattleSpot]:
	return _get_enemy_spots(user)

# ============================================================================
# UI de Selección Manual
# ============================================================================

func show_targets(selectable_spots: Array[BattleSpot]) -> void:
	spots = selectable_spots
	current_index = 0
	visible = true
	
	print("[BattleTargetSelector] Mostrando selector con %d spots" % spots.size())
	
	# Verificar si ya está conectada antes de conectar
	if not SignalManager.input_cancel.is_connected(_on_input_cancel):
		SignalManager.input_cancel.connect(_on_input_cancel)
	
	_update_selector()

func _on_input_left():
	if not visible or spots.is_empty():
		return
	
	current_index = (current_index - 1 + spots.size()) % spots.size() 
	_update_selector()

func _on_input_right():
	if not visible or spots.is_empty():
		return
	
	current_index = (current_index + 1) % spots.size()
	_update_selector()

func _on_input_accept():
	print("[BattleTargetSelector] Input accept recibido - visible: %s, spots: %d" % [visible, spots.size()])
	
	if not visible or spots.is_empty():
		print("[BattleTargetSelector] Ignorando input (no visible o sin spots)")
		return
	
	var chosen_spot = spots[current_index]
	print("[BattleTargetSelector] Target seleccionado: %s" % chosen_spot)
	emit_signal("target_chosen", chosen_spot)
	hide_selector()

func _on_input_cancel():
	if not visible or spots.is_empty():
		return
	
	hide_selector()
	emit_signal("target_chosen", null)

func _update_selector():
	for i in spots.size():
		spots[i].highlight(i == current_index)

func hide_selector():
	for spot in spots:
		spot.highlight(false)
	
	# Verificar si está conectada antes de desconectar
	if SignalManager.input_cancel.is_connected(_on_input_cancel):
		SignalManager.input_cancel.disconnect(_on_input_cancel)
	
	visible = false

# ============================================================================
# Métodos auxiliares privados (estáticos para generación de targets)
# ============================================================================

static func _get_enemy_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var pokemons: Array[BattlePokemon] = []
	for spot in _get_enemy_spots(user):
		if spot.has_active_pokemon():
			pokemons.append(spot.get_active_pokemon())
	return pokemons

static func _get_ally_side_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var pokemons: Array[BattlePokemon] = []
	for spot in _get_ally_spots(user):
		if spot.has_active_pokemon():
			pokemons.append(spot.get_active_pokemon())
	return pokemons

static func _get_all_active_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var pokemons: Array[BattlePokemon] = []
	pokemons.append_array(_get_ally_side_pokemons(user))
	pokemons.append_array(_get_enemy_pokemons(user))
	return pokemons

static func _get_all_other_pokemons(user: BattlePokemon) -> Array[BattlePokemon]:
	var all := _get_all_active_pokemons(user)
	return all.filter(func(p): return p != user)

static func _get_enemy_spots(user: BattlePokemon) -> Array[BattleSpot]:
	return user.get_opponent_side().battle_spots.filter(
		func(s): return s.has_active_pokemon()
	)

static func _get_ally_spots(user: BattlePokemon) -> Array[BattleSpot]:
	return user.side.battle_spots.filter(
		func(s): return s.has_active_pokemon()
	)

static func _get_random_enemy_pokemon(user: BattlePokemon) -> BattlePokemon:
	var enemies := _get_enemy_pokemons(user)
	if enemies.is_empty():
		return null
	return enemies[randi() % enemies.size()]

static func _get_ally_pokemon(user: BattlePokemon) -> BattlePokemon:
	# Devuelve el compañero del usuario si existe
	var allies := _get_ally_side_pokemons(user)
	for ally in allies:
		if ally != user:
			return ally
	return null
