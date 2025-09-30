class_name BattleBagChoice
extends BattleChoice

# Placeholder: identificador/índice del objeto a usar
var item_id: int = -1

func get_priority() -> int:
    # En juegos oficiales, usar objeto suele resolverse antes que los movimientos
    return 6

func resolve() -> BattleResult:
    # Placeholder: resultado vacío hasta implementar lógica de mochila
    return BattleResult.new()


