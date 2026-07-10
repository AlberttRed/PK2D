extends BattleMoveEffect
class_name SubstituteMoveEffect

var _already_active := false
var _hp_cost_failed := false
var _hp_cost: int = 0


func apply() -> void:
	var owner: BattlePokemon = user.get_active_battle_pokemon() if user != null else null
	if owner == null:
		return

	var spot: BattleSpot = owner.resolve_battle_spot()
	var pokemon: BattlePokemon = spot.get_active_pokemon() if spot != null else owner
	if pokemon == null:
		return

	if SubstituteAilmentEffect.get_active_effect(pokemon) != null:
		_already_active = true
		return

	var max_hp := pokemon.get_final_stat(StatsEnum.Values.HP)
	var cost := maxi(1, int(floor(float(max_hp) / 4.0)))
	if pokemon.hp <= cost:
		_hp_cost_failed = true
		return

	pokemon.hp -= cost
	_hp_cost = cost

	var substitute := SubstituteAilmentEffect.new(move, cost)
	substitute.set_owner(pokemon)
	substitute.source_move_id = move.get_id()
	BattleEffectController.add_pokemon_effect(pokemon, substitute)


func visualize(ui: BattleUI) -> void:
	var owner: BattlePokemon = user.get_active_battle_pokemon() if user != null else null
	if owner == null:
		return

	var spot: BattleSpot = owner.resolve_battle_spot()
	var pokemon: BattlePokemon = spot.get_active_pokemon() if spot != null else owner

	if _already_active:
		await ui.show_already_effect_message(MessageFamily.Values.FIELD_EFFECT, pokemon, move.get_id())
	elif _hp_cost_failed:
		await ui.show_failed_move_message(pokemon)
	else:
		if spot != null:
			await spot.apply_damage(_hp_cost)
		await ui.show_start_effect_message(
			MessageFamily.Values.AILMENT, pokemon, AilmentsEnum.Values.SUBSTITUTE
		)
		SubstituteAilmentEffect.set_owner_sprite_visible(pokemon, false)
