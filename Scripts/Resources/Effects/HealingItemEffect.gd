## Curación de PS como efecto de ítem (overworld y datos compartidos con batalla).
extends ItemEffect
class_name HealingItemEffect

enum HealMode {
	FIXED_AMOUNT,
	PERCENTAGE,
	FULL_HEAL,
}

@export_enum("Cantidad Fija", "Porcentaje", "Curación Completa") var heal_mode: int = HealMode.FIXED_AMOUNT
@export var heal_amount: int = 20
@export_range(0, 100) var heal_percentage: int = 50
@export var custom_message: String = ""


func can_use(context: ItemUseContext) -> bool:
	if context.target_pokemon == null:
		return false

	var pokemon: Pokemon = context.target_pokemon
	if pokemon.hp_actual <= 0:
		return false

	var max_hp: int = pokemon.get_final_stat(StatsEnum.Values.HP)
	if pokemon.hp_actual >= max_hp:
		return false

	return true


## Cantidad de PS que se curarían sin aplicar mutación (batalla y validaciones).
func compute_healed_amount(pokemon: Pokemon) -> int:
	if pokemon == null:
		return 0
	var max_hp: int = pokemon.get_final_stat(StatsEnum.Values.HP)
	var current_hp: int = pokemon.hp_actual
	if current_hp <= 0 or current_hp >= max_hp:
		return 0

	var healed_amount: int = 0
	match heal_mode:
		HealMode.FIXED_AMOUNT:
			healed_amount = heal_amount
		HealMode.PERCENTAGE:
			healed_amount = int(max_hp * heal_percentage / 100.0)
		HealMode.FULL_HEAL:
			healed_amount = max_hp - current_hp

	return mini(healed_amount, max_hp - current_hp)


func build_heal_success_message(pokemon: Pokemon, healed_amount: int) -> String:
	if custom_message != "":
		return custom_message
	return "%s ha recupera %d PS." % [pokemon.get_display_name(), healed_amount]


func apply(context: ItemUseContext) -> ItemUseResult:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null:
		return ItemUseResult.failure_blocked("No hay Pokémon objetivo")

	if not can_use(context):
		if pokemon.hp_actual <= 0:
			return ItemUseResult.failure_blocked("El Pokémon está debilitado")
		var max_hp_check: int = pokemon.get_final_stat(StatsEnum.Values.HP)
		if pokemon.hp_actual >= max_hp_check:
			return ItemUseResult.failure_no_effect(BattleMessageItem.get_no_effect_text())
		return ItemUseResult.failure_no_effect(BattleMessageItem.get_no_effect_text())

	var max_hp: int = pokemon.get_final_stat(StatsEnum.Values.HP)
	var healed_amount: int = compute_healed_amount(pokemon)
	if healed_amount <= 0:
		return ItemUseResult.failure_no_effect(BattleMessageItem.get_no_effect_text())

	pokemon.hp_actual = mini(pokemon.hp_actual + healed_amount, max_hp)

	var message: String = build_heal_success_message(pokemon, healed_amount)

	return ItemUseResult.success_result(
		1,
		message,
		{"healed_amount": healed_amount, "max_hp": max_hp, "current_hp": pokemon.hp_actual}
	)
