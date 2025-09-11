class_name BattleEffectController
extends Node

# 🔁 Singleton interno
static var _instance: BattleEffectController

func _ready():
	_instance = self

static func get_instance() -> BattleEffectController:
	if _instance == null:
		push_warning("BattleEffectController.get_instance() llamado antes de inicializarse.")
	return _instance

# 📦 API pública
static func add_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	get_instance()._add_pokemon_effect(pokemon, effect)

static func remove_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	get_instance()._remove_pokemon_effect(pokemon, effect)

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

static func get_all_effects_for(pokemon):
	return get_instance()._get_all_effects_for(pokemon)

static func get_pokemon_effects(pokemon):
	return get_instance()._get_pokemon_effects(pokemon)

static func get_side_effects(pokemon):
	return get_instance()._get_side_effects(pokemon)

static func get_field_effects():
	return get_instance()._get_field_effects()

static func get_all_active_effects() -> Array[PersistentBattleEffect]:
	return get_instance()._get_all_active_effects()

static func process_phase(pokemon, phase: BattleEffect.Phases):
	await get_instance()._process_phase(pokemon, phase)

static func process_global_phase(phase: BattleEffect.Phases):
	await get_instance()._process_global_phase(phase)

static func apply_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases):
	return await get_instance()._apply_phase(pokemon, phase)

static func visualize_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases):
	return await get_instance()._visualize_phase(pokemon, phase)

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

# 🔐 Datos internos
var pokemon_effects: Dictionary = {}
var field_effects: Array[PersistentBattleEffect] = []
var side_effects: Dictionary = { "Player": [], "Enemy": [] }
var ui: BattleUI

# 🔧 Métodos internos
func _add_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	if not pokemon_effects.has(pokemon):
		pokemon_effects[pokemon] = []
	pokemon_effects[pokemon].append(effect)

func _remove_pokemon_effect(pokemon, effect: PersistentBattleEffect):
	if not pokemon_effects.has(pokemon):
		return
	var target_class = effect.get_script().get_global_name()
	pokemon_effects[pokemon] = pokemon_effects[pokemon].filter(func(e): return e.get_script().get_global_name() != target_class)
	if pokemon_effects[pokemon].is_empty():
		pokemon_effects.erase(pokemon)

func _add_side_effect(side: String, effect: PersistentBattleEffect):
	if not side_effects.has(side):
		side_effects[side] = []
	side_effects[side].append(effect)

func _remove_side_effect(side: String, effect: PersistentBattleEffect):
	if not side_effects.has(side):
		return
	var target_class = effect.get_script().get_global_name()
	side_effects[side] = side_effects[side].filter(func(e): return e.get_script().get_global_name() != target_class)
	if side_effects[side].is_empty():
		side_effects.erase(side)

func _add_field_effect(effect: PersistentBattleEffect):
	field_effects.append(effect)

func _remove_field_effect(effect: PersistentBattleEffect):
	var target_class = effect.get_script().get_global_name()
	field_effects = field_effects.filter(func(e): return e.get_script().get_global_name() != target_class)
	
func _has_effect_for(pokemon, effect: PersistentBattleEffect) -> bool:
	var target_class = effect.get_script().get_global_name()
	var all = _get_all_effects_for(pokemon)
	return all.any(func(e): return e.get_script().get_global_name() == target_class)

func _get_all_effects_for(pokemon) -> Array[PersistentBattleEffect]:
	var result: Array[PersistentBattleEffect] = []
	result.append_array(_get_pokemon_effects(pokemon))
	result.append_array(_get_side_effects(pokemon))
	result.append_array(_get_field_effects())
	result.sort_custom(func(a, b): return b.get_priority() - a.get_priority())
	return result

func _get_pokemon_effects(pokemon):
	if pokemon_effects.has(pokemon):
		return pokemon_effects[pokemon].duplicate()
	return []

func _get_side_effects(pokemon:BattlePokemon):
	var side = pokemon.side.to_string()
	if side_effects.has(side):
		return side_effects[side].duplicate()
	return []

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

func _process_phase(pokemon: BattlePokemon, phase: BattleEffect.Phases):
	apply_phase(pokemon, phase)
	await visualize_phase(pokemon, phase)
	
func _process_global_phase(phase: BattleEffect.Phases):
	for effect in field_effects:
		effect.apply_phase(null, phase)
	for effect in field_effects:
		await effect.visualize_phase(null, ui, phase)
		if effect.has_finished(): remove_field_effect(effect)
	for side in side_effects.keys():
		for effect in side_effects[side]:
			effect.apply_phase(null, phase)
		for effect in side_effects[side]:
			await effect.visualize_phase(null, ui, phase)
			if effect.has_finished(): remove_side_effect(side, effect)
			
func _apply_phase(pokemon, phase):
	for effect in _get_all_effects_for(pokemon):
		effect.apply_phase(pokemon, phase)

func _visualize_phase(pokemon, phase):
	for effect in _get_all_effects_for(pokemon):
		await effect.visualize_phase(pokemon, ui, phase)
		if effect.has_finished(): remove_pokemon_effect(pokemon, effect)
			

func _apply_global_phase(phase: BattleEffect.Phases) -> void:
	for effect in field_effects:
		await effect.apply_phase(null, phase)

	for side in side_effects.keys():
		for effect in side_effects[side]:
			# Nota: puedes pasar el "lado" como string si lo necesita
			await effect.apply_phase(null, phase)

func _visualize_global_phase(phase: BattleEffect.Phases) -> void:
	for effect in field_effects:
		await effect.visualize_phase(null, ui, phase)
		if effect.has_finished(): remove_field_effect(effect)
	for side in side_effects.keys():
		for effect in side_effects[side]:
			await effect.visualize_phase(null, ui, phase)
			if effect.has_finished(): remove_side_effect(side, effect)
