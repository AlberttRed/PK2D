class_name BattleEffectController
extends Node

# 🔁 Singleton interno
static var _instance: BattleEffectController

static func get_instance() -> BattleEffectController:
	if _instance == null:
		push_warning("BattleEffectController.get_instance() llamado antes de inicializarse.")
	return _instance

# 📦 API pública
static func add_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	get_instance()._add_pokemon_effect(pokemon, effect)

static func remove_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	get_instance()._remove_pokemon_effect(pokemon, effect)

## Quita el efecto de combate asociado a un estado mayor (veneno, sueño, etc.).
static func remove_major_status_ailment_effect(pokemon: BattlePokemon, ailment_enum: int) -> void:
	var effect_class := _major_status_ailment_class_name(ailment_enum)
	if pokemon == null or effect_class.is_empty():
		return
	for effect in get_pokemon_effects(pokemon):
		if effect.get_script().get_global_name() == effect_class:
			remove_pokemon_effect(pokemon, effect)
			return

static func clear_pokemon_effects(pokemon):
	get_instance()._clear_pokemon_effects(pokemon)

static func add_side_effect(side: String, effect: PersistentBattleEffect):
	get_instance()._add_side_effect(side, effect)

static func remove_side_effect(side: String, effect: PersistentBattleEffect):
	get_instance()._remove_side_effect(side, effect)

static func add_field_effect(effect: PersistentBattleEffect):
	get_instance()._add_field_effect(effect)

static func remove_field_effect(effect: PersistentBattleEffect):
	get_instance()._remove_field_effect(effect)

static func remove_field_weather_effects() -> void:
	get_instance()._remove_field_weather_effects()

static func has_effect_for(pokemon, effect_instance: PersistentBattleEffect) -> bool:
	return effect_instance != null and get_instance()._has_effect_for(pokemon, effect_instance)

static func has_field_effect(effect_instance: PersistentBattleEffect) -> bool:
	return effect_instance != null and get_instance()._has_field_effect(effect_instance)

static func has_side_effect(side: String, effect_instance: PersistentBattleEffect) -> bool:
	return effect_instance != null and get_instance()._has_side_effect(side, effect_instance)

static func get_all_effects_for(pokemon):
	return get_instance()._get_all_effects_for(pokemon)

static func get_all_effects_to_apply_for(
	pokemon, phase: BattleEffect.Phases = BattleEffect.Phases.ON_BATTLE_START
) -> Array[PersistentBattleEffect]:
	return get_instance()._get_all_effects_to_apply_for(pokemon, phase)

static func get_all_effects_to_visualize_for(
	pokemon, phase: BattleEffect.Phases = BattleEffect.Phases.ON_BATTLE_START
) -> Array[PersistentBattleEffect]:
	return get_instance()._get_all_effects_to_visualize_for(pokemon, phase)

static func get_pokemon_effects(pokemon):
	return get_instance()._get_pokemon_effects(pokemon)

static func get_side_effects(pokemon):
	return get_instance()._get_side_effects(pokemon)

static func get_field_effects():
	return get_instance()._get_field_effects()

static func get_all_active_effects() -> Array[PersistentBattleEffect]:
	return get_instance()._get_all_active_effects()

static func process_phase(pokemon, phase: BattleEffect.Phases, ctx: BattlePhaseContext = null):
	await get_instance()._process_phase(pokemon, phase, ctx)

static func get_selectable_move_indices(pokemon: BattlePokemon) -> Array[int]:
	return get_instance()._get_selectable_move_indices(pokemon)

static func get_move_selection_filter(pokemon: BattlePokemon) -> MoveSelectionFilter:
	return get_instance()._build_move_selection_filter(pokemon)

## Comprueba si un índice es elegible (PP + restricciones de efectos), opcionalmente omitiendo uno.
static func is_move_index_selectable(
	pokemon: BattlePokemon,
	index: int,
	excluding: PersistentBattleEffect = null
) -> bool:
	if index < 0:
		return false
	var filter := get_instance()._build_move_selection_filter(pokemon, excluding)
	return not filter.is_index_blocked(index)

static func process_global_phase(phase: BattleEffect.Phases):
	await get_instance()._process_global_phase(phase)

static func apply_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases, ctx: BattlePhaseContext = null):
	return await get_instance()._apply_phase(pokemon, phase, ctx)

## Ejecuta solo apply_phase (sin visualize); para puntos síncronos del pipeline de combate.
static func run_apply_phase(
	pokemon: BattlePokemon, phase: BattleEffect.Phases, ctx: BattlePhaseContext = null
) -> void:
	get_instance()._apply_phase(pokemon, phase, ctx)

static func visualize_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases, ctx: BattlePhaseContext = null):
	return await get_instance()._visualize_phase(pokemon, phase, ctx)

static func apply_global_phase(phase: BattleEffect.Phases) -> void:
	await get_instance()._apply_global_phase(phase)

static func visualize_global_phase(phase: BattleEffect.Phases) -> void:
	await get_instance()._visualize_global_phase(phase)

static func set_ui(_ui:BattleUI):
	get_instance().ui = _ui

static func cleanup():
	var instance = get_instance()
	instance.pokemon_effects.clear()
	instance.field_effects.clear()
	instance.side_effects.clear()
	_instance = null

static func reset_effects():
	var instance = get_instance()
	if instance:
		instance.pokemon_effects.clear()
		instance.field_effects.clear()
		instance.side_effects.clear()
		instance._ensure_side_effect_list("Player")
		instance._ensure_side_effect_list("Enemy")

# 🔐 Datos internos
var pokemon_effects: Dictionary = {}  # BattlePokemon -> Array[PersistentBattleEffect]
var field_effects: Array[PersistentBattleEffect] = []
var side_effects: Dictionary = {}  # String -> Array[PersistentBattleEffect]
var ui: BattleUI
## Primer efecto que bloqueó la acción en la fase ON_BEFORE_MOVE actual (visualización).
var _phase_blocker: PersistentBattleEffect = null

func _ready():
	_instance = self
	_ensure_side_effect_list("Player")
	_ensure_side_effect_list("Enemy")

func _empty_effect_list() -> Array[PersistentBattleEffect]:
	var list: Array[PersistentBattleEffect] = []
	return list

func _ensure_side_effect_list(side: String) -> Array[PersistentBattleEffect]:
	if not side_effects.has(side):
		side_effects[side] = _empty_effect_list()
	return side_effects[side]

func _filter_out_effect_class(
	effects: Array[PersistentBattleEffect], target_class: String
) -> Array[PersistentBattleEffect]:
	var kept := _empty_effect_list()
	for e in effects:
		if e.get_script().get_global_name() != target_class:
			kept.append(e)
	return kept

# 🔧 Métodos internos
func _register_effect(effect: PersistentBattleEffect) -> void:
	if effect != null:
		effect.detect_effect_source()

func _add_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	_register_effect(effect)
	var key: BattlePokemon = _resolve_pokemon_effect_key(pokemon)
	if key == null:
		return
	if not pokemon_effects.has(key):
		pokemon_effects[key] = _empty_effect_list()
	pokemon_effects[key].append(effect)

func _remove_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	var key: BattlePokemon = _resolve_pokemon_effect_key(pokemon)
	if key == null or not pokemon_effects.has(key):
		return
	var target_class = effect.get_script().get_global_name()
	pokemon_effects[key] = _filter_out_effect_class(pokemon_effects[key], target_class)
	if pokemon_effects[key].is_empty():
		pokemon_effects.erase(key)

func _clear_pokemon_effects(pokemon) -> void:
	var key: BattlePokemon = _resolve_pokemon_effect_key(pokemon)
	if key == null:
		return
	if pokemon_effects.has(key):
		pokemon_effects.erase(key)

func _add_side_effect(side: String, effect: PersistentBattleEffect):
	_register_effect(effect)
	_ensure_side_effect_list(side).append(effect)

func _remove_side_effect(side: String, effect: PersistentBattleEffect):
	if not side_effects.has(side):
		return
	var target_class = effect.get_script().get_global_name()
	side_effects[side] = _filter_out_effect_class(side_effects[side], target_class)
	if side_effects[side].is_empty():
		side_effects.erase(side)

func _add_field_effect(effect: PersistentBattleEffect):
	_register_effect(effect)
	field_effects.append(effect)

func _remove_field_effect(effect: PersistentBattleEffect):
	var target_class = effect.get_script().get_global_name()
	field_effects = _filter_out_effect_class(field_effects, target_class)

func _remove_field_weather_effects() -> void:
	var kept := _empty_effect_list()
	for effect in field_effects:
		if not effect is WeatherBattleEffect:
			kept.append(effect)
	field_effects = kept

func _has_effect_for(pokemon, effect: PersistentBattleEffect) -> bool:
	var target_class = effect.get_script().get_global_name()
	var all = _get_all_effects_for(pokemon)
	return all.any(func(e): return e.get_script().get_global_name() == target_class)

func _has_field_effect(effect: PersistentBattleEffect) -> bool:
	var target_class = effect.get_script().get_global_name()
	return field_effects.any(func(e): return e.get_script().get_global_name() == target_class)

func _has_side_effect(side: String, effect: PersistentBattleEffect) -> bool:
	if not side_effects.has(side):
		return false
	var target_class = effect.get_script().get_global_name()
	return side_effects[side].any(func(e): return e.get_script().get_global_name() == target_class)

func _get_all_effects_for(pokemon) -> Array[PersistentBattleEffect]:
	return _get_all_effects_to_apply_for(pokemon)

func _get_all_effects_to_apply_for(
	pokemon, phase: BattleEffect.Phases = BattleEffect.Phases.ON_BATTLE_START
) -> Array[PersistentBattleEffect]:
	var result: Array[PersistentBattleEffect] = []
	result.append_array(_get_pokemon_effects(pokemon))
	result.append_array(_get_side_effects(pokemon))
	result.append_array(_get_field_effects())
	return _sort_effects_for_phase(result, phase, false)

func _get_all_effects_to_visualize_for(
	pokemon, phase: BattleEffect.Phases = BattleEffect.Phases.ON_BATTLE_START
) -> Array[PersistentBattleEffect]:
	var result: Array[PersistentBattleEffect] = []
	result.append_array(_get_pokemon_effects(pokemon))
	result.append_array(_get_side_effects(pokemon))
	result.append_array(_get_field_effects())
	return _sort_effects_for_phase(result, phase, true)

static func _sort_effects_for_phase(
	effects: Array[PersistentBattleEffect],
	phase: BattleEffect.Phases,
	for_visualize: bool
) -> Array[PersistentBattleEffect]:
	var sorted := effects.duplicate()
	sorted.sort_custom(func(a, b): return _compare_effects(a, b, phase, for_visualize))
	return sorted

static func _compare_effects(
	a: PersistentBattleEffect,
	b: PersistentBattleEffect,
	phase: BattleEffect.Phases,
	for_visualize: bool
) -> bool:
	var order_a: int = (
		PersistentBattleEffect.get_visual_order(a.effect_source)
		if for_visualize
		else int(a.effect_source)
	)
	var order_b: int = (
		PersistentBattleEffect.get_visual_order(b.effect_source)
		if for_visualize
		else int(b.effect_source)
	)
	if order_a != order_b:
		return order_a < order_b
	var priority_a: int = BattleEffectPriority.get_for(a, phase)
	var priority_b: int = BattleEffectPriority.get_for(b, phase)
	if priority_a != priority_b:
		if priority_a == 0:
			return false
		if priority_b == 0:
			return true
		return priority_a > priority_b
	return a.get_instance_id() < b.get_instance_id()

static func _sort_effects_for_apply(effects: Array[PersistentBattleEffect]) -> Array[PersistentBattleEffect]:
	return _sort_effects_for_phase(effects, BattleEffect.Phases.ON_BATTLE_START, false)

static func _sort_effects_for_visualize(effects: Array[PersistentBattleEffect]) -> Array[PersistentBattleEffect]:
	return _sort_effects_for_phase(effects, BattleEffect.Phases.ON_BATTLE_START, true)

func _get_pokemon_effects(pokemon) -> Array[PersistentBattleEffect]:
	var key: BattlePokemon = _resolve_pokemon_effect_key(pokemon)
	if key == null:
		return _empty_effect_list()
	if pokemon_effects.has(key):
		var list: Array[PersistentBattleEffect] = pokemon_effects[key]
		return list.duplicate()
	return _empty_effect_list()

func _resolve_pokemon_effect_key(pokemon: BattlePokemon) -> BattlePokemon:
	if pokemon == null:
		return null
	return pokemon.get_active_battle_pokemon()

func _get_side_effects(pokemon: BattlePokemon) -> Array[PersistentBattleEffect]:
	if pokemon == null or pokemon.side == null:
		return _empty_effect_list()
	var side := pokemon.side.to_string()
	if side_effects.has(side):
		var list: Array[PersistentBattleEffect] = side_effects[side]
		return list.duplicate()
	return _empty_effect_list()

func _get_field_effects() -> Array[PersistentBattleEffect]:
	return field_effects.duplicate()

func _get_all_active_effects() -> Array[PersistentBattleEffect]:
	var result: Array[PersistentBattleEffect] = []
	result.append_array(field_effects)
	for list in side_effects.values():
		result.append_array(list)
	for list in pokemon_effects.values():
		result.append_array(list)
	return result

func _process_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases, ctx: BattlePhaseContext = null):
	_phase_blocker = null
	_apply_phase(pokemon, phase, ctx)
	await _visualize_phase(pokemon, phase, ctx)
	_phase_blocker = null

func _build_move_selection_filter(
	pokemon: BattlePokemon,
	excluding: PersistentBattleEffect = null
) -> MoveSelectionFilter:
	var filter := MoveSelectionFilter.from_pokemon(pokemon)
	if filter.moves.is_empty():
		return filter
	for effect in _get_all_effects_to_apply_for(pokemon, BattleEffect.Phases.ON_VALIDATE_MOVE):
		if effect == excluding:
			continue
		effect.restrict_selectable_moves(pokemon, filter)
	return filter


func _get_selectable_move_indices(pokemon: BattlePokemon) -> Array[int]:
	return _build_move_selection_filter(pokemon).get_selectable_indices()

func _process_global_phase(phase: BattleEffect.Phases):
	var global_effects: Array[PersistentBattleEffect] = []
	global_effects.append_array(field_effects)
	for side_key in side_effects.keys():
		global_effects.append_array(side_effects[side_key])
	global_effects = _sort_effects_for_phase(global_effects, phase, false)
	for effect in global_effects:
		effect.apply_phase(null, phase)
	for effect in _sort_effects_for_phase(global_effects, phase, true):
		await effect.visualize_phase(null, ui, phase)
		_remove_global_effect_if_finished(effect)
	for bp in _get_pokemon_keys_sorted_by_speed():
		var pokemon: BattlePokemon = bp as BattlePokemon
		if pokemon == null:
			continue
		var pokemon_effects_sorted := _sort_effects_for_phase(
			_get_pokemon_effects(pokemon), phase, false
		)
		for effect in pokemon_effects_sorted:
			effect.apply_phase(pokemon, phase)
		for effect in _sort_effects_for_phase(
			_get_pokemon_effects(pokemon), phase, true
		):
			await effect.visualize_phase(pokemon, ui, phase)
			if effect.has_finished():
				remove_pokemon_effect(pokemon, effect)

func _get_pokemon_keys_sorted_by_speed() -> Array:
	var keys: Array = pokemon_effects.keys()
	keys.sort_custom(func(a, b) -> bool:
		var pa := a as BattlePokemon
		var pb := b as BattlePokemon
		if pa == null or pb == null:
			return str(a) < str(b)
		var speed_a: int = pa.get_speed()
		var speed_b: int = pb.get_speed()
		if speed_a != speed_b:
			return speed_a > speed_b
		return pa.get_instance_id() < pb.get_instance_id()
	)
	return keys

func _apply_phase(pokemon, phase, ctx: BattlePhaseContext = null):
	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		_phase_blocker = null
	for effect in _get_all_effects_to_apply_for(pokemon, phase):
		if ctx != null and ctx.validation != null and ctx.validation.rejected:
			break
		var could_act: bool = pokemon.can_act_this_turn if pokemon != null else true
		effect.apply_phase(pokemon, phase, ctx)
		if (
			ctx != null
			and ctx.validation != null
			and ctx.validation.rejected
			and ctx.validation.blocking_effect == null
		):
			ctx.validation.blocking_effect = effect
		if (
			pokemon != null
			and could_act
			and not pokemon.can_act_this_turn
			and _phase_blocker == null
		):
			_phase_blocker = effect

func _visualize_phase(pokemon, phase, ctx: BattlePhaseContext = null):
	for effect in _get_all_effects_to_visualize_for(pokemon, phase):
		if _should_skip_phase_visualize(effect, pokemon, phase, ctx):
			continue
		await effect.visualize_phase(pokemon, ui, phase, ctx)
		if effect.has_finished():
			_remove_pokemon_scoped_effect(pokemon, effect)

func _should_skip_phase_visualize(
	effect: PersistentBattleEffect,
	pokemon: BattlePokemon,
	phase: BattleEffect.Phases,
	ctx: BattlePhaseContext
) -> bool:
	if phase == BattleEffect.Phases.ON_BEFORE_MOVE and pokemon != null:
		if not pokemon.can_act_this_turn and _phase_blocker != null:
			return effect != _phase_blocker
	if phase in [
		BattleEffect.Phases.ON_VALIDATE_MOVE,
		BattleEffect.Phases.ON_VALIDATE_SWITCH,
		BattleEffect.Phases.ON_VALIDATE_RUN,
	]:
		if ctx != null and ctx.validation != null and ctx.validation.blocking_effect != null:
			return effect != ctx.validation.blocking_effect
	return false

func _remove_global_effect_if_finished(effect: PersistentBattleEffect) -> void:
	if not effect.has_finished():
		return
	if field_effects.any(func(e): return e == effect):
		remove_field_effect(effect)
		return
	for side_key in side_effects.keys():
		if side_effects[side_key].any(func(e): return e == effect):
			remove_side_effect(side_key, effect)
			return

func _remove_pokemon_scoped_effect(pokemon, effect: PersistentBattleEffect) -> void:
	if _get_pokemon_effects(pokemon).any(func(e): return e == effect):
		remove_pokemon_effect(pokemon, effect)
	elif _get_side_effects(pokemon).any(func(e): return e == effect):
		remove_side_effect(pokemon.side.to_string(), effect)
	elif field_effects.any(func(e): return e == effect):
		remove_field_effect(effect)

func _apply_global_phase(phase: BattleEffect.Phases) -> void:
	var global_effects: Array[PersistentBattleEffect] = []
	global_effects.append_array(field_effects)
	for side_key in side_effects.keys():
		global_effects.append_array(side_effects[side_key])
	for effect in _sort_effects_for_phase(global_effects, phase, false):
		await effect.apply_phase(null, phase)

func _visualize_global_phase(phase: BattleEffect.Phases) -> void:
	var global_effects: Array[PersistentBattleEffect] = []
	global_effects.append_array(field_effects)
	for side_key in side_effects.keys():
		global_effects.append_array(side_effects[side_key])
	for effect in _sort_effects_for_phase(global_effects, phase, true):
		await effect.visualize_phase(null, ui, phase)
		_remove_global_effect_if_finished(effect)


static func _major_status_ailment_class_name(ailment_enum: int) -> String:
	match ailment_enum:
		AilmentsEnum.Values.POISON:
			return "PoisonAilmentEffect"
		AilmentsEnum.Values.BURN:
			return "BurnAilmentEffect"
		AilmentsEnum.Values.PARALYSIS:
			return "ParalysisAilmentEffect"
		AilmentsEnum.Values.SLEEP:
			return "SleepAilmentEffect"
		AilmentsEnum.Values.FREEZE:
			return "FreezeAilmentEffect"
		_:
			return ""
