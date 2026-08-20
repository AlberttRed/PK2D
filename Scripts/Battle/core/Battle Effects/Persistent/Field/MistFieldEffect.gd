class_name MistFieldEffect
extends ScreenFieldEffect

## Bloquea bajadas de estadísticas infligidas por el rival al lado protegido.
## No impide subidas ni bajadas auto-infligidas (mismo lado que el objetivo).


func on_stat_validate(_pokemon: BattlePokemon, ctx: BattlePhaseContext = null) -> void:
	if ctx == null or ctx.stat_change == null or ctx.validation == null:
		return
	if ctx.stat_change.delta >= 0:
		return
	var stat_source := ctx.stat_change.source
	var stat_target := ctx.pokemon
	if stat_source == null or stat_target == null or stat_source.side == null or stat_target.side == null:
		return
	if stat_source.side == stat_target.side:
		return
	if applies_to_side(stat_target.side.type):
		ctx.validation.block_reason = "mist"
		ctx.validation.rejected = true
		ctx.validation.rejection_message = BattleMessageFieldEffect.new().get_mist_stat_block_message(
			stat_target
		)
