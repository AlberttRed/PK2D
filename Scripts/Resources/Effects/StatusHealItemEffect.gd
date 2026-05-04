## Cura estados mayores persistidos en `Pokemon.major_status` (`CONST.STATUS`).
extends ItemEffect
class_name StatusHealItemEffect

enum CureMode {
	ALL_STATUS,
	SPECIFIC_STATUS,
}

@export_enum("Todos los Estados", "Estados Específicos") var cure_mode: int = CureMode.SPECIFIC_STATUS
@export var status_to_cure: Array[int] = []
@export var custom_message: String = ""


func can_use(context: ItemUseContext) -> bool:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null or pokemon.hp_actual <= 0:
		return false
	if cure_mode == CureMode.SPECIFIC_STATUS:
		return pokemon.major_status in status_to_cure
	return pokemon.major_status != CONST.STATUS.OK


func can_clear_major_status(major_status: int) -> bool:
	if major_status == CONST.STATUS.OK:
		return false
	if cure_mode == CureMode.SPECIFIC_STATUS:
		return major_status in status_to_cure
	return true


func build_success_message(pokemon: Pokemon, cured_prev: int) -> String:
	if custom_message != "":
		return custom_message
	match cure_mode:
		CureMode.ALL_STATUS:
			return "%s se curó de todos los problemas de estado." % pokemon.get_display_name()
		_:
			if cured_prev == CONST.STATUS.POISON:
				return "¡%s se curó del veneno!" % pokemon.get_display_name()
			return "¡%s se curó!" % pokemon.get_display_name()


func apply(context: ItemUseContext) -> ItemUseResult:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null:
		return ItemUseResult.failure_blocked("No hay Pokémon objetivo")
	if pokemon.hp_actual <= 0:
		return ItemUseResult.failure_blocked("El Pokémon está debilitado")

	match cure_mode:
		CureMode.SPECIFIC_STATUS:
			if not pokemon.major_status in status_to_cure:
				return ItemUseResult.failure_no_effect("No tendrá efecto.")
			var prev: int = pokemon.major_status
			pokemon.major_status = CONST.STATUS.OK
			return ItemUseResult.success_result(1, build_success_message(pokemon, prev), {"cured_status": prev})

		CureMode.ALL_STATUS:
			if pokemon.major_status == CONST.STATUS.OK:
				return ItemUseResult.failure_no_effect("No tendrá efecto.")
			var prev_all: int = pokemon.major_status
			pokemon.major_status = CONST.STATUS.OK
			return ItemUseResult.success_result(1, build_success_message(pokemon, prev_all), {"cured_status": prev_all})

	return ItemUseResult.failure_no_effect("No tendrá efecto.")
