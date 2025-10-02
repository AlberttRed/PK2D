class_name BattleRunChoice
extends BattleChoice

func get_priority() -> int:
	# Placeholder: resolveremos reglas reales de prioridad más adelante
	return 6

func resolve() -> Array[BattleHandler]:
	# Crear el handler de huida
	var side := pokemon.side
	var handler = BattleRunHandler.new(side, side.battle_rules)
	return [handler]
