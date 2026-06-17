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

static func has_effect_for(pokemon, effect_instance: PersistentBattleEffect) -> bool:
	return effect_instance != null and get_instance()._has_effect_for(pokemon, effect_instance)

static func has_field_effect(effect_instance: PersistentBattleEffect) -> bool:
	return effect_instance != null and get_instance()._has_field_effect(effect_instance)

static func has_side_effect(side: String, effect_instance: PersistentBattleEffect) -> bool:
	return effect_instance != null and get_instance()._has_side_effect(side, effect_instance)

static func get_all_effects_for(pokemon):
	return get_instance()._get_all_effects_for(pokemon)

static func get_all_effects_to_apply_for(pokemon) -> Array[PersistentBattleEffect]:
	return get_instance()._get_all_effects_to_apply_for(pokemon)

static func get_all_effects_to_visualize_for(pokemon) -> Array[PersistentBattleEffect]:
	return get_instance()._get_all_effects_to_visualize_for(pokemon)

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

static func process_global_phase(phase: BattleEffect.Phases):
	await get_instance()._process_global_phase(phase)

static func apply_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases, ctx: BattlePhaseContext = null):
	return await get_instance()._apply_phase(pokemon, phase, ctx)

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
	if not pokemon_effects.has(pokemon):
		pokemon_effects[pokemon] = _empty_effect_list()
	pokemon_effects[pokemon].append(effect)

func _remove_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	if not pokemon_effects.has(pokemon):
		return
	var target_class = effect.get_script().get_global_name()
	pokemon_effects[pokemon] = _filter_out_effect_class(pokemon_effects[pokemon], target_class)
	if pokemon_effects[pokemon].is_empty():
		pokemon_effects.erase(pokemon)

func _clear_pokemon_effects(pokemon) -> void:
	if pokemon == null:
		return
	if pokemon_effects.has(pokemon):
		pokemon_effects.erase(pokemon)

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

func _get_all_effects_to_apply_for(pokemon) -> Array[PersistentBattleEffect]:
	var result: Array[PersistentBattleEffect] = []
	result.append_array(_get_pokemon_effects(pokemon))
	result.append_array(_get_side_effects(pokemon))
	result.append_array(_get_field_effects())
	return _sort_effects_for_apply(result)

func _get_all_effects_to_visualize_for(pokemon) -> Array[PersistentBattleEffect]:
	var result: Array[PersistentBattleEffect] = []
	result.append_array(_get_pokemon_effects(pokemon))
	result.append_array(_get_side_effects(pokemon))
	result.append_array(_get_field_effects())
	return _sort_effects_for_visualize(result)

static func _sort_effects_for_apply(effects: Array[PersistentBattleEffect]) -> Array[PersistentBattleEffect]:
	var sorted := effects.duplicate()
	sorted.sort_custom(func(a, b): return a.effect_source < b.effect_source)
	return sorted

static func _sort_effects_for_visualize(effects: Array[PersistentBattleEffect]) -> Array[PersistentBattleEffect]:
	var sorted := effects.duplicate()
	sorted.sort_custom(func(a, b): return PersistentBattleEffect.get_visual_order(a.effect_source) < PersistentBattleEffect.get_visual_order(b.effect_source))
	return sorted

func _get_pokemon_effects(pokemon) -> Array[PersistentBattleEffect]:
	if pokemon_effects.has(pokemon):
		var list: Array[PersistentBattleEffect] = pokemon_effects[pokemon]
		return list.duplicate()
	return _empty_effect_list()

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
	apply_phase(pokemon, phase, ctx)
	await visualize_phase(pokemon, phase, ctx)

func _get_selectable_move_indices(pokemon: BattlePokemon) -> Array[int]:
	var filter := MoveSelectionFilter.from_pokemon(pokemon)
	if filter.moves.is_empty():
		return []
	for effect in _get_all_effects_to_apply_for(pokemon):
		effect.apply_selectable_moves_filter(pokemon, filter)
	return filter.get_selectable_indices()

func _process_global_phase(phase: BattleEffect.Phases):
	var global_effects: Array[PersistentBattleEffect] = []
	global_effects.append_array(field_effects)
	for side_key in side_effects.keys():
		global_effects.append_array(side_effects[side_key])
	global_effects = _sort_effects_for_apply(global_effects)
	for effect in global_effects:
		effect.apply_phase(null, phase)
	for effect in _sort_effects_for_visualize(global_effects):
		await effect.visualize_phase(null, ui, phase)
		_remove_global_effect_if_finished(effect)
	for bp in pokemon_effects.keys():
		var pokemon: BattlePokemon = bp as BattlePokemon
		if pokemon == null:
			continue
		for effect in _sort_effects_for_visualize(_get_pokemon_effects(pokemon)):
			effect.apply_phase(pokemon, phase)
			await effect.visualize_phase(pokemon, ui, phase)
			if effect.has_finished():
				remove_pokemon_effect(pokemon, effect)

func _apply_phase(pokemon, phase, ctx: BattlePhaseContext = null):
	for effect in _get_all_effects_to_apply_for(pokemon):
		effect.apply_phase(pokemon, phase, ctx)

func _visualize_phase(pokemon, phase, ctx: BattlePhaseContext = null):
	for effect in _get_all_effects_to_visualize_for(pokemon):
		await effect.visualize_phase(pokemon, ui, phase, ctx)
		if effect.has_finished():
			_remove_pokemon_scoped_effect(pokemon, effect)

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
	for effect in _sort_effects_for_apply(global_effects):
		await effect.apply_phase(null, phase)

func _visualize_global_phase(phase: BattleEffect.Phases) -> void:
	var global_effects: Array[PersistentBattleEffect] = []
	global_effects.append_array(field_effects)
	for side_key in side_effects.keys():
		global_effects.append_array(side_effects[side_key])
	for effect in _sort_effects_for_visualize(global_effects):
		await effect.visualize_phase(null, ui, phase)
		_remove_global_effect_if_finished(effect)
