## Clase base para efectos de items
## Define el contrato que deben cumplir todos los efectos de items
## Similar a BattleMoveCategory, usa composición en lugar de herencia de ItemData
extends Resource
class_name ItemEffect

## Verifica si el item puede usarse en el contexto dado
## @param context: ItemUseContext con toda la información del uso
## @return: true si puede usarse, false en caso contrario
func can_use(context: ItemUseContext) -> bool:
	return true

## Aplica el efecto del item
## @param context: ItemUseContext con toda la información del uso
## @return: ItemUseResult con el resultado de la ejecución
func apply(context: ItemUseContext) -> ItemUseResult:
	push_error("ItemEffect.apply() no implementado en " + get_script().resource_path)
	return ItemUseResult.failure_error("Efecto no implementado")

## Valida que el contexto tenga un Pokémon objetivo
func require_pokemon_target(context: ItemUseContext) -> Pokemon:
	if context.target_pokemon == null:
		push_warning("%s requiere un target_pokemon" % get_script().resource_path)
		return null
	return context.target_pokemon

## Valida que el contexto tenga un slot de party válido
func require_party_slot(context: ItemUseContext) -> int:
	if context.target_party_slot < 0 or context.target_party_slot >= context.party.size():
		push_warning("%s requiere un target_party_slot válido" % get_script().resource_path)
		return -1
	return context.target_party_slot


## Valida extensión de combate (`battle_controller`, usuario en campo). Para efectos exclusivos de batalla, llamar al inicio de `apply`.
func require_battle_runtime(context: ItemUseContext) -> ItemUseResult:
	var outside: ItemUseResult = context.failure_if_not_battle_use()
	if outside != null:
		return outside
	return context.validate_battle_binding_or_error()

