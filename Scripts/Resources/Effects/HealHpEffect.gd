## Efecto que cura HP de un Pokémon
## Parametrizable: puede curar cantidad fija o porcentaje
extends ItemEffect
class_name HealHpEffect

## Modo de curación
enum HealMode {
	FIXED_AMOUNT,    # Cura una cantidad fija de HP
	PERCENTAGE,      # Cura un porcentaje del HP máximo
	FULL_HEAL        # Cura todo el HP
}

## Modo de curación a usar
@export_enum("Cantidad Fija", "Porcentaje", "Curación Completa") var heal_mode: int = HealMode.FIXED_AMOUNT

## Cantidad fija de HP a curar (si heal_mode = FIXED_AMOUNT)
@export var heal_amount: int = 20

## Porcentaje de HP máximo a curar (si heal_mode = PERCENTAGE, 0-100)
@export_range(0, 100) var heal_percentage: int = 50

## Mensaje personalizado (opcional, si está vacío se genera automáticamente)
@export var custom_message: String = ""

func can_use(context: ItemUseContext) -> bool:
	if context.target_pokemon == null:
		return false

	var pokemon: Pokemon = context.target_pokemon
	# No se puede usar si el Pokémon está KO
	if pokemon.hp_actual <= 0:
		return false

	# No se puede usar si ya tiene el HP al máximo
	var max_hp = pokemon.get_final_stat(StatsEnum.Values.HP)
	if pokemon.hp_actual >= max_hp:
		return false

	return true

func apply(context: ItemUseContext) -> ItemUseResult:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null:
		return ItemUseResult.failure_blocked("No hay Pokémon objetivo")

	if not can_use(context):
		if pokemon.hp_actual <= 0:
			return ItemUseResult.failure_blocked("El Pokémon está debilitado")
		var max_hp_check = pokemon.get_final_stat(StatsEnum.Values.HP)
		if pokemon.hp_actual >= max_hp_check:
			return ItemUseResult.failure_no_effect("El Pokémon ya tiene el HP al máximo")

	var max_hp = pokemon.get_final_stat(StatsEnum.Values.HP)
	var current_hp = pokemon.hp_actual
	var healed_amount: int = 0

	match heal_mode:
		HealMode.FIXED_AMOUNT:
			healed_amount = heal_amount
		HealMode.PERCENTAGE:
			healed_amount = int(max_hp * heal_percentage / 100.0)
		HealMode.FULL_HEAL:
			healed_amount = max_hp - current_hp

	# Asegurar que no se cure más del máximo
	healed_amount = min(healed_amount, max_hp - current_hp)

	# Aplicar la curación
	pokemon.hp_actual = min(current_hp + healed_amount, max_hp)

	# Generar mensaje
	var message: String = custom_message
	if message == "":
		message = "%s recuperó %d PS!" % [pokemon.get_display_name(), healed_amount]

	return ItemUseResult.success_result(
		1,
		message,
		{"healed_amount": healed_amount, "max_hp": max_hp, "current_hp": pokemon.hp_actual}
	)
