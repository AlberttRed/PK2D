class_name BattleSwitchChoice
extends BattleChoice

var target_index: int # El índice del Pokémon al que cambiar

func get_priority() -> int:
	return 6 # En los juegos oficiales, cambiar tiene prioridad 6

func resolve() -> BattleResult:
	# Placeholder funcional: integra el flujo secuencial sin efectos aún.
	# La lógica de cambio (switch-out/in) se implementará en un efecto dedicado.
	return BattleResult.new()
