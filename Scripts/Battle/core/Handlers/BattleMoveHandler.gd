extends BattleHandler

class_name BattleMoveHandler

var user
var target: BattleTarget
var move
var category = null

# Marcador genérico que los Multi-Hit pueden consultar al final
var show_effectiveness: bool = false

# Control de ejecución: si apply() falla, no se ejecuta visualize()
var _should_visualize: bool = true

func _init(_move, _user, _target, _category = null):
	move = _move
	user = _user
	target = _target
	category = _category


# Template method: valida target y ejecuta _apply() de los hijos
func apply() -> void:
	if not target.is_valid():
		_should_visualize = false
		return
	_apply()
	_should_visualize = true

# Template method: solo visualiza si apply() tuvo éxito
func visualize(ui: BattleUI) -> void:
	if not _should_visualize:
		return
	await _play_move_battle_animation(ui)
	await _visualize(ui)

# Métodos abstractos que cada hijo debe implementar
func _apply() -> void:
	pass

func _visualize(_ui: BattleUI) -> void:
	pass


## Reproduce MoveData.battle_animation si existe. Sin side effects lógicos.
func _play_move_battle_animation(ui: BattleUI) -> void:
	if ui == null or move == null:
		return
	if not move.has_method("get_battle_animation"):
		return
	var anim: BattleAnimation = move.get_battle_animation()
	if anim == null:
		return
	var layer: Node2D = ui.get_animation_layer()
	var user_spot: BattleSpot = _resolve_user_spot_for_animation()
	var target_spots: Array[BattleSpot] = _resolve_target_spots_for_animation()
	await anim.play(layer, user_spot, target_spots)


func _resolve_user_spot_for_animation() -> BattleSpot:
	if user == null:
		return null
	if user.has_method("resolve_battle_spot"):
		return user.resolve_battle_spot()
	return user.battle_spot


func _resolve_target_spots_for_animation() -> Array[BattleSpot]:
	var spots: Array[BattleSpot] = []
	if target == null:
		return spots
	if target.is_pokemon() or target.is_spot():
		var spot: BattleSpot = target.get_spot()
		if spot == null:
			var p: BattlePokemon = target.get_pokemon()
			if p != null:
				spot = p.resolve_battle_spot() if p.has_method("resolve_battle_spot") else p.battle_spot
		if spot != null:
			spots.append(spot)
		return spots
	if target.is_side():
		var side: BattleSide = target.get_side()
		if side != null:
			for s in side.battle_spots:
				if s != null:
					spots.append(s)
		return spots
	return spots

# Valida/retarget en runtime si el movimiento es de objetivo único enemigo.
# Devuelve true si hay target válido (posiblemente retargeteado); false si no hay objetivos.
func ensure_valid_single_enemy_target_or_null() -> bool:
	if move == null or target == null:
		return true

	var is_single: bool = target.is_pokemon() and target.is_single_enemy_selection_type()
	if not is_single:
		return true

	if target.selection_type == BattleTarget.TYPE.SELECCIONAR \
			or target.selection_type == BattleTarget.TYPE.ESPECIFICO:
		return target.is_valid()

	var tp: BattlePokemon = target.get_pokemon()
	if tp != null and tp.in_battle and not tp.is_fainted() and tp.battle_spot != null:
		return true

	var candidates: Array[BattlePokemon] = user.get_opponent_side().get_active_pokemons()
	candidates = candidates.filter(func(p): return p != tp and not p.is_fainted() and p.battle_spot != null)
	if candidates.is_empty():
		return false
	target = BattleTarget.new(candidates[0].battle_spot, target.selection_type)
	return true


func _bind_effect_context(effect: PersistentBattleEffect) -> void:
	if effect == null:
		return
	effect.user = user
	effect.target = target.get_pokemon() if target != null else null
	if move != null:
		effect.source_move_id = move.get_id()


func _validate_ailment_apply(ailment: AilmentData, effect_instance: PersistentBattleEffect) -> int:
	var pokemon: BattlePokemon = target.get_pokemon() if target != null else null
	if ailment == null or pokemon == null:
		return ApplyFailReason.Values.OK

	if ailment.is_persistent:
		var current_status := _get_current_major_ailment(pokemon)
		if current_status != null:
			if _ailments_match(current_status, ailment):
				return ApplyFailReason.Values.ALREADY_ACTIVE
			return ApplyFailReason.Values.GENERIC_FAIL

	var ctx := BattlePhaseContext.for_ailment(pokemon, ailment)
	BattleEffectController.run_apply_phase(pokemon, BattleEffect.Phases.ON_VALIDATE_AILMENT, ctx)
	if ctx.validation != null and ctx.validation.rejected:
		return ApplyFailReason.Values.GENERIC_FAIL

	if effect_instance != null:
		return effect_instance.can_apply()
	return ApplyFailReason.Values.OK


func _get_current_major_ailment(pokemon: BattlePokemon) -> AilmentData:
	if pokemon.status != null:
		return pokemon.status
	if pokemon.base_data != null:
		return AilmentData.from_major_status(pokemon.base_data.major_status)
	return null


func _ailments_match(current: AilmentData, incoming: AilmentData) -> bool:
	if current == null or incoming == null:
		return false
	var current_enum := current.get_enum_value()
	var incoming_enum := incoming.get_enum_value()
	if current_enum != AilmentsEnum.Values.NONE and current_enum == incoming_enum:
		return true
	if not current.internal_name.is_empty() and current.internal_name == incoming.internal_name:
		return true
	var current_major := AilmentData.to_major_status(current)
	var incoming_major := AilmentData.to_major_status(incoming)
	return current_major != CONST.STATUS.OK and current_major == incoming_major


func _ailment_check_passed(chance_percent: int) -> bool:
	if chance_percent <= 0:
		return false
	if BattleDebugAilmentTest.force_ailment_apply:
		return true
	return randf() < float(chance_percent) / 100.0


func _try_apply_ailment_entry(entry: MoveAilmentEntry) -> Dictionary:
	var empty := {
		"entry": entry,
		"result": ApplyFailReason.Values.SKIPPED,
		"effect": null,
	}
	if entry == null or entry.ailment == null:
		return empty

	var pokemon: BattlePokemon = target.get_pokemon() if target != null else null
	if pokemon == null or pokemon.is_fainted():
		return empty

	if not _ailment_check_passed(entry.chance):
		return empty

	var effect_instance: PersistentBattleEffect = null
	if entry.ailment.effect != null:
		effect_instance = entry.ailment.get_effect(
			move.get_min_turns(),
			move.get_max_turns(),
			entry.chance
		)
		_bind_effect_context(effect_instance)

	var apply_result := _validate_ailment_apply(entry.ailment, effect_instance)
	if not ApplyFailReason.is_success(apply_result):
		return {
			"entry": entry,
			"result": apply_result,
			"effect": effect_instance,
		}

	if effect_instance != null:
		BattleEffectController.add_pokemon_effect(pokemon, effect_instance)
	if entry.ailment.is_persistent:
		pokemon.set_status(entry.ailment)

	return {
		"entry": entry,
		"result": ApplyFailReason.Values.OK,
		"effect": effect_instance,
	}

func _finalize_defender_move_resolution(damage_effect: DamageEffect = null) -> void:
	var pokemon: BattlePokemon = target.get_pokemon() if target != null else null
	if pokemon == null:
		return
	pokemon = pokemon.get_active_battle_pokemon()
	var ctx: BattlePhaseContext = null
	if damage_effect != null:
		damage_effect.target = pokemon
		ctx = BattlePhaseContext.for_incoming_damage(pokemon, damage_effect)
	BattleEffectController.run_apply_phase(
		pokemon, BattleEffect.Phases.ON_INCOMING_DAMAGE_FINALIZE, ctx
	)


func _visualize_ailment_entry_result(ui: BattleUI, apply_data: Dictionary, show_fail_messages: bool) -> void:
	var entry: MoveAilmentEntry = apply_data.get("entry")
	var result: int = apply_data.get("result", ApplyFailReason.Values.SKIPPED)
	var pokemon: BattlePokemon = target.get_pokemon() if target != null else null
	if entry == null or entry.ailment == null or pokemon == null:
		return
	if result == ApplyFailReason.Values.SKIPPED:
		return

	if not ApplyFailReason.is_success(result):
		if show_fail_messages:
			await ui.show_already_effect_message(
				MessageFamily.Values.AILMENT,
				pokemon,
				entry.ailment.get_enum_value(),
				ApplyFailReason.uses_generic_fail_message(result)
			)
		return

	if entry.ailment.get_enum_value() == AilmentsEnum.Values.FLINCH:
		return

	await entry.ailment.play_battle_animation_on(ui, pokemon)

	var effect_instance: PersistentBattleEffect = apply_data.get("effect")
	var display_move_id: int = (
		effect_instance.get_start_causing_move_id()
		if effect_instance != null
		else move.get_id()
	)
	await ui.show_start_effect_message(
		MessageFamily.Values.AILMENT,
		pokemon,
		entry.ailment.get_enum_value(),
		null,
		user,
		display_move_id
	)
	pokemon.status_changed.emit()
