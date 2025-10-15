class_name BattleRunChoice
extends BattleChoice

func get_priority() -> int:
	# Placeholder: resolveremos reglas reales de prioridad más adelante
	return 6

func is_blocking_action() -> bool:
	# Intentar huir bloquea las acciones del resto del equipo
	return true

func resolve() -> Array[BattleHandler]:
	# Crear el handler de huida
	var handler = BattleRunHandler.new(pokemon, pokemon.side.battle_rules)
	return [handler]
