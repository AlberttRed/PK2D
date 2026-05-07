## Contexto de uso de un item
## Contiene toda la información necesaria para que un ItemEffect pueda ejecutarse
extends RefCounted
class_name ItemUseContext

const BAG_SCRIPT = preload("res://Scripts/Resources/Classes/Bag.gd")

## Contexto donde se está usando el item (`OVERWORLD`, `PARTY_MENU`, `BATTLE`; combinable con bitmask).
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

## Solo combate: controlador activo (inyectado por `BattleItemHandler` / UI).
var battle_controller: BattleController = null

## Pokémon que usa el objeto en combate (activo del jugador que declaró la acción).
var user_battle_pokemon: BattlePokemon = null

## Objetivo en runtime de combate (aliado/enemigo según el ítem; puede coincidir con el usuario).
var target_battle_pokemon: BattlePokemon = null


func is_battle_use() -> bool:
	return ItemEnums.has_context(use_context, ItemEnums.UseContext.BATTLE)


## Si `use_context` incluye combate, exige datos mínimos del runtime de batalla.
func validate_battle_binding_or_error() -> ItemUseResult:
	if not is_battle_use():
		return null
	if battle_controller == null or user_battle_pokemon == null:
		return ItemUseResult.failure_error("Contexto de combate incompleto.")
	return null


## Para efectos exclusivos de combate: fuera de batalla devuelve fallo controlado.
func failure_if_not_battle_use(message: String = "Este objeto solo puede usarse en combate.") -> ItemUseResult:
	if is_battle_use():
		return null
	return ItemUseResult.failure_blocked(message)


func _init(
	context: ItemEnums.UseContext,
	_party: Array = [],
	_bag = null,
	_target_pokemon: Pokemon = null,
	_target_party_slot: int = -1,
	_target_move_slot: int = -1,
	_battle_controller: BattleController = null,
	_user_battle_pokemon: BattlePokemon = null,
	_target_battle_pokemon: BattlePokemon = null
) -> void:
	use_context = context
	party = _party
	if _bag != null and not (_bag is BAG_SCRIPT):
		push_warning("ItemUseContext: _bag no es una instancia de Bag")
	bag = _bag
	target_pokemon = _target_pokemon
	target_party_slot = _target_party_slot
	target_move_slot = _target_move_slot
	battle_controller = _battle_controller
	user_battle_pokemon = _user_battle_pokemon
	target_battle_pokemon = _target_battle_pokemon
