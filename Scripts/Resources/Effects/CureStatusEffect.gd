## Efecto que cura estados alterados de un Pokémon
## Parametrizable: puede curar uno o varios estados específicos, o todos
extends ItemEffect
class_name CureStatusEffect

## Modo de curación de estados
enum CureMode {
	ALL_STATUS,      # Cura todos los estados alterados
	SPECIFIC_STATUS  # Cura solo estados específicos (definidos en status_to_cure)
}

## Modo de curación a usar
@export_enum("Todos los Estados", "Estados Específicos") var cure_mode: int = CureMode.ALL_STATUS

## IDs de estados a curar (si cure_mode = SPECIFIC_STATUS)
## Array de IDs de AilmentData
@export var status_to_cure: Array[int] = []

## Mensaje personalizado (opcional)
@export var custom_message: String = ""

func can_use(context: ItemUseContext) -> bool:
	if context.target_pokemon == null:
		return false

	var pokemon: Pokemon = context.target_pokemon
	# No se puede usar si el Pokémon está KO
	if pokemon.hp_actual <= 0:
		return false

	# Verificar si tiene algún estado alterado que se pueda curar
	# Nota: Esto requiere acceso al sistema de estados del Pokémon
	# Por ahora, asumimos que siempre puede usarse si el Pokémon no está KO
	# La validación real se hará en apply() cuando tengamos acceso al sistema de estados

	return true

func apply(context: ItemUseContext) -> ItemUseResult:
	var pokemon: Pokemon = require_pokemon_target(context)
	if pokemon == null:
		return ItemUseResult.failure_result("No hay Pokémon objetivo")

	if pokemon.hp_actual <= 0:
		return ItemUseResult.failure_result("El Pokémon está debilitado")

	# Nota: La implementación real de curación de estados requiere acceso al sistema
	# de estados del Pokémon (battle_status, ailments, etc.)
	# Por ahora, esta es una estructura base que debe completarse cuando se integre
	# con el sistema de combate/estados

	var cured_statuses: Array = []
	var message: String = custom_message

	match cure_mode:
		CureMode.ALL_STATUS:
			# TODO: Curar todos los estados alterados del Pokémon
			# pokemon.clear_all_status_conditions()
			cured_statuses = ["all"]
			if message == "":
				message = "%s se curó de todos los problemas de estado!" % pokemon.get_display_name()

		CureMode.SPECIFIC_STATUS:
			# TODO: Curar solo los estados específicos
			# for status_id in status_to_cure:
			#     if pokemon.has_status(status_id):
			#         pokemon.cure_status(status_id)
			#         cured_statuses.append(status_id)
			cured_statuses = status_to_cure.duplicate()
			if message == "":
				if cured_statuses.size() == 1:
					message = "%s se curó del problema de estado!" % pokemon.get_display_name()
				else:
					message = "%s se curó de los problemas de estado!" % pokemon.get_display_name()

	# Si no se curó ningún estado, el uso falla
	if cured_statuses.is_empty():
		return ItemUseResult.failure_result("El Pokémon no tiene problemas de estado")

	return ItemUseResult.success_result(
		1,  # consume_amount
		message,
		{"cured_statuses": cured_statuses}
	)

