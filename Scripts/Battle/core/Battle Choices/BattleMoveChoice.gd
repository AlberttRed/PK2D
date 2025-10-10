class_name BattleMoveChoice
extends BattleChoice

var move: BattleMove
var move_index: int = -1

# Array de BattleTarget generados para este movimiento
var targets: Array[BattleTarget] = []
# Para selección manual, guardamos el spot seleccionado
var manual_selected_spot: BattleSpot = null

func get_move() -> BattleMove:
	if not pokemon or move_index == -1:
		return null
	return pokemon.get_available_moves()[move_index]

func get_priority() -> int:
	return get_move().get_priority() if get_move() != null else 0

## Resuelve el movimiento y genera los handlers correspondientes
func resolve() -> Array[BattleHandler]:
	var handlers: Array[BattleHandler] = []
	
	var move_instance := get_move()
	if not move_instance:
		return handlers
	
	# Generar los targets usando BattleTargetSelector
	targets = BattleTargetSelector.generate_targets(move_instance, pokemon, manual_selected_spot)
	
	if targets.is_empty():
		return handlers
	
	var category: BattleMoveCategory = move_instance.get_category() if move_instance.has_method("get_category") else null
	if not category:
		print("No category found for move: " + move_instance.get_name())
		return handlers
	
	# Determinar si el movimiento afecta al campo o a un lado (un solo handler)
	if _is_field_or_side_move(targets):
		# Movimientos de campo o lado: un único handler
		var target := targets[0]
		var handler := category.create_handler(move_instance, pokemon, target)
		if handler:
			handlers.append(handler)
	else:
		# Movimientos que afectan a pokémon individuales: chequear precisión por cada uno
		for target in targets:
			if not target.is_pokemon():
				continue
			
			var target_pokemon := target.get_pokemon()
			
			# Chequeo de precisión solo para targets de tipo POKEMON
			if move_instance.get_accuracy() > 0 and not AccuracyUtils.check_hit(move_instance, pokemon, target_pokemon):
				handlers.append(MissHandler.new(pokemon))
				continue
			
			var handler := category.create_handler(move_instance, pokemon, target)
			if handler:
				handlers.append(handler)
	
	return handlers

## Determina si el movimiento afecta al campo completo o a un lado
func _is_field_or_side_move(target_list: Array[BattleTarget]) -> bool:
	if target_list.is_empty():
		return false
	
	# Si hay un único target y es de tipo FIELD o SIDE, es un movimiento de campo/lado
	if target_list.size() == 1:
		var first_target := target_list[0]
		return first_target.is_field() or first_target.is_side()
	
	return false
