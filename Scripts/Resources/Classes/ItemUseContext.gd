## Contexto de uso de un item
## Contiene toda la información necesaria para que un ItemEffect pueda ejecutarse
extends RefCounted
class_name ItemUseContext

const BAG_SCRIPT = preload("res://Scripts/Resources/Classes/Bag.gd")

## Contexto donde se está usando el item
var use_context: ItemEnums.UseContext = ItemEnums.UseContext.OVERWORLD

## Referencia al party del jugador (puede ser null si no aplica)
var party: Array = []

## Referencia al bag/inventario (puede ser null si no aplica)
var bag = null

## Pokémon objetivo (si aplica)
var target_pokemon: Pokemon = null

## Slot del party objetivo (si aplica)
var target_party_slot: int = -1

## Slot de movimiento objetivo (si aplica)
var target_move_slot: int = -1

## Datos adicionales del contexto de combate (opcional, para futuras fases)
var battle_controller = null
var battle_pokemon = null

## Constructor
func _init(
	context: ItemEnums.UseContext,
	_party: Array = [],
	_bag = null,
	_target_pokemon: Pokemon = null,
	_target_party_slot: int = -1,
	_target_move_slot: int = -1
) -> void:
	use_context = context
	party = _party
	if _bag != null and not (_bag is BAG_SCRIPT):
		push_warning("ItemUseContext: _bag no es una instancia de Bag")
	bag = _bag
	target_pokemon = _target_pokemon
	target_party_slot = _target_party_slot
	target_move_slot = _target_move_slot

