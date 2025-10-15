class_name BattleBagChoice
extends BattleChoice

# Placeholder: identificador/índice del objeto a usar
var item_id: int = -1

func get_priority() -> int:
    # En juegos oficiales, usar objeto suele resolverse antes que los movimientos
    return 6

func is_blocking_action() -> bool:
    # Por defecto, usar objetos NO bloquea (pociones, bayas, etc.)
    # TODO: Cuando se implementen los items, verificar el tipo:
    #   - Pokéballs → return true (bloquean)
    #   - Pociones, bayas, etc. → return false (no bloquean)
    # Ejemplo futuro:
    #   var item = ItemDatabase.get_item(item_id)
    #   return item.is_pokeball()
    return false

func resolve() -> Array[BattleHandler]:
    # Crear el handler de bolsa (placeholder)
    var handler = BattleBagHandler.new()
    return [handler]


