class_name TailwindFieldEffect
extends ScreenFieldEffect

## Duplica la velocidad efectiva de los Pokémon del lado protegido (Gen 4: 3 turnos).
## No modifica stat stages; el multiplicador se aplica en BattlePokemon.get_effective_speed().

const SPEED_MULTIPLIER: float = 2.0


func get_speed_multiplier(pokemon: BattlePokemon) -> float:
	if pokemon == null or pokemon.side == null or has_finished():
		return 1.0
	if applies_to_side(pokemon.side._to_string()):
		return SPEED_MULTIPLIER
	return 1.0
