class_name LightScreenFieldEffect
extends ScreenFieldEffect


func on_damage(ctx: BattlePhaseContext = null) -> void:
	var effect: DamageEffect = ctx.damage if ctx != null else null
	if effect == null:
		return
	if effect.is_critical:
		return
	var damage_target := effect.target
	if damage_target == null or damage_target.side == null:
		return
	if not effect.move.is_special_category():
		return
	var target_side_key: String = damage_target.side._to_string()
	if not applies_to_side(target_side_key):
		return
	var is_double: bool = damage_target.side.get_active_pokemons().size() > 1
	var mult := 2.0 / 3.0 if is_double else 0.5
	effect.amount = int(floor(effect.amount * mult))
