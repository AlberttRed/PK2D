## Revive a un Pokémon debilitado restaurando PS según porcentaje del máximo o al máximo.
extends ItemEffect
class_name ReviveItemEffect

enum ReviveMode {
	PERCENTAGE,
	FULL,
}

@export_enum("Porcentaje PS máximos", "PS completos") var revive_mode: int = ReviveMode.PERCENTAGE
@export_range(1, 100) var revive_hp_percentage: int = 50
@export var custom_message: String = ""


func can_use(context: ItemUseContext) -> bool:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null:
		return false
	return pokemon.hp_actual <= 0


func compute_revived_hp_amount(pokemon: Pokemon) -> int:
	if pokemon == null:
		return 0
	var max_hp: int = pokemon.get_final_stat(StatsEnum.Values.HP)
	var amt: int
	if revive_mode == ReviveMode.FULL:
		amt = max_hp
	else:
		amt = int(max_hp * revive_hp_percentage / 100.0)
	return clampi(amt, 1, max_hp)


func build_revive_success_message(pokemon: Pokemon, restored_hp: int) -> String:
	if custom_message != "":
		return custom_message
	return "¡%s revive con %d PS!" % [pokemon.get_display_name(), restored_hp]


func apply(context: ItemUseContext) -> ItemUseResult:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null:
		return ItemUseResult.failure_blocked("No hay Pokémon objetivo")

	if pokemon.hp_actual > 0:
		return ItemUseResult.failure_blocked("No tiene efecto en un Pokémon que no esté debilitado.")

	var restored: int = compute_revived_hp_amount(pokemon)
	pokemon.hp_actual = restored
	pokemon.major_status = CONST.STATUS.OK

	return ItemUseResult.success_result(
		1,
		build_revive_success_message(pokemon, restored),
		{"restored_hp": restored, "max_hp": pokemon.get_final_stat(StatsEnum.Values.HP)}
	)
