extends BattleAnimation
class_name PokemonEnterBattleAnimation

## Entrada de Pokémon al campo (PBI 338): crece desde silueta blanca.
## Actúa sobre el sprite del BattleSpot (no requiere AnimationPlayer en escena).

@export var scale_duration: float = 0.45
## Debe ser mayor que scale_duration para que el blanco dure más que el grow.
@export var white_duration: float = 0.75


func play(
	_animation_layer: Node2D,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var landing := _first_target(target_spots)
	if landing == null:
		landing = user_spot
	if landing == null or not is_instance_valid(landing):
		return
	await BattleAnimationUtils.pokemon_enter_spot(
		landing, scale_duration, white_duration, _animation_layer
	)
