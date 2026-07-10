extends BattleMoveHandler

class_name BattleStruggleMoveHandler

const MAGIC_GUARD_ABILITY_ID := 98

var damage: DamageEffect = null
var recoil_amount: int = 0
var _applied_recoil: bool = false


func _apply() -> void:
	var target_pokemon: BattlePokemon = (
		target.get_pokemon().get_active_battle_pokemon()
		if target.get_pokemon() != null
		else null
	)
	if target_pokemon == null:
		return

	damage = move.calculate_damage(target_pokemon)
	show_effectiveness = false
	damage.apply()
	_finalize_defender_move_resolution(damage)

	recoil_amount = maxi(1, user.total_hp / 4)
	_applied_recoil = not _has_magic_guard(user)


func _visualize(ui: BattleUI) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()

	if not _applied_recoil or user == null:
		return

	var active_user: BattlePokemon = user.get_active_battle_pokemon()
	if active_user == null:
		return

	var spot: BattleSpot = active_user.resolve_battle_spot()
	if spot == null:
		return

	await spot.play_hit_animation()
	active_user.hp = maxi(active_user.hp - recoil_amount, 0)
	await spot.apply_damage(recoil_amount)
	await ui.show_struggle_recoil_message(active_user)


func _has_magic_guard(pokemon: BattlePokemon) -> bool:
	return pokemon.ability != null and int(pokemon.ability.id) == MAGIC_GUARD_ABILITY_ID
