extends BattleAnimation
class_name BattleAnimationWithFieldFlash

## Ejemplo de subclase (PBI 673): oscurece el campo, reproduce la escena base y restaura.
## El caller externo sigue usando solo await battle_animation.play(...).

func play(
	animation_layer: Node2D,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var overlay: Polygon2D = null
	if animation_layer != null and is_instance_valid(animation_layer):
		overlay = await BattleAnimationUtils.darken_overlay(animation_layer, 0.35, 0.12)
	await super.play(animation_layer, user_spot, target_spots)
	if overlay != null:
		await BattleAnimationUtils.restore_overlay(overlay, 0.12)
