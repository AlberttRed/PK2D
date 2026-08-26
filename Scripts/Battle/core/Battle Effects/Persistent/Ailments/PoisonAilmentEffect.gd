class_name PoisonAilmentEffect
extends PersistentBattleEffect

## Veneno normal: 1/8 max HP/turno.
## Tóxico (gravemente envenenado): N/16 creciente (mismo icono ENV).
var is_toxic: bool = false
var toxic_counter: int = 0


func can_apply() -> int:
	var base := super.can_apply()
	if not ApplyFailReason.is_success(base):
		return base
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	if _is_immune(target):
		return ApplyFailReason.Values.GENERIC_FAIL
	return ApplyFailReason.Values.OK


func apply_phase(pokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return
	var dmg: int = 0
	if is_toxic:
		toxic_counter += 1
		dmg = int(floor(float(pokemon.total_hp) * float(toxic_counter) / 16.0))
		if dmg < 1:
			dmg = 1
	else:
		dmg = int(ceili(pokemon.total_hp / 8.0))
	var effect := DamageEffect.new(null, pokemon, null, dmg)
	pokemon.take_damage(effect)


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases, _ctx: BattlePhaseContext = null):
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	if source != null and source.has_method("play_battle_animation_on"):
		await source.play_battle_animation_on(ui, pokemon)
	await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
	await pokemon.battle_spot.apply_damage()

func get_priority() -> int:
	return BattleEffectPriority.END_POISON


## Aplica veneno/tóxico vía pipeline de ailments (Safeguard, ya tiene estado, can_apply del ailment).
static func try_apply(
	pokemon: BattlePokemon,
	badly: bool = false,
	source_move_id: int = 0
) -> bool:
	if pokemon == null or pokemon.is_fainted():
		return false

	var poison_data := AilmentData.from_major_status(CONST.STATUS.POISON)
	if poison_data == null or poison_data.effect == null:
		push_warning("PoisonAilmentEffect.try_apply: no se pudo cargar POISON.tres")
		return false

	if pokemon.status != null and pokemon.status.is_persistent:
		return false
	if pokemon.base_data != null:
		var major: int = pokemon.base_data.major_status
		if major != CONST.STATUS.OK and major != CONST.STATUS.NONE:
			return false

	var poison_effect := poison_data.get_effect(null, null) as PoisonAilmentEffect
	if poison_effect == null:
		return false

	poison_effect.target = pokemon
	poison_effect.source = poison_data
	poison_effect.source_move_id = source_move_id
	poison_effect.is_toxic = badly
	poison_effect.toxic_counter = 0

	if not ApplyFailReason.is_success(poison_effect.can_apply()):
		return false

	var ctx := BattlePhaseContext.for_ailment(pokemon, poison_data)
	BattleEffectController.run_apply_phase(pokemon, BattleEffect.Phases.ON_VALIDATE_AILMENT, ctx)
	if ctx.validation != null and ctx.validation.rejected:
		return false

	pokemon.set_status(poison_data)
	BattleEffectController.add_pokemon_effect(pokemon, poison_effect)
	return true


static func _is_immune(pokemon: BattlePokemon) -> bool:
	if pokemon == null:
		return true
	if _has_type(pokemon, TypesEnum.Values.POISON):
		return true
	if _has_type(pokemon, TypesEnum.Values.STEEL):
		return true
	if pokemon.ability != null and int(pokemon.ability.id) == AbilitiesEnum.Values.IMMUNITY:
		return true
	return false


static func _has_type(pokemon: BattlePokemon, type_id: int) -> bool:
	var type1 := pokemon.get_type1()
	if type1 != null and type1.id == type_id:
		return true
	var type2 := pokemon.get_type2()
	return type2 != null and type2.id == type_id
