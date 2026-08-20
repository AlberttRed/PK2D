class_name SafeguardFieldEffect
extends ScreenFieldEffect

## Bloquea la aplicación de estados alterados mayores (veneno, parálisis, sueño, etc.)
## a Pokémon del lado protegido. No afecta volátiles (confusión, retroceso, bostezo, …)
## ni limpia estados ya presentes antes de activar Velo Sagrado.


func on_status_restrict(
	pokemon: BattlePokemon,
	ailment: AilmentData,
	_ctx: BattlePhaseContext = null
) -> bool:
	if pokemon == null or pokemon.side == null or ailment == null:
		return false
	if not _is_major_status_ailment(ailment):
		return false
	return applies_to_side(pokemon.side.type)


static func _is_major_status_ailment(ailment: AilmentData) -> bool:
	return AilmentData.to_major_status(ailment) != CONST.STATUS.OK
