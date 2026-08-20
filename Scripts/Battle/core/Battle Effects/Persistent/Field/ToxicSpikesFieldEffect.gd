class_name ToxicSpikesFieldEffect
extends HazardFieldEffect

## Gen 4: 1 capa → veneno; 2 capas → tóxico (gravemente envenenado).
## No grounded (Volador / Levitate): sin efecto.
## Tipo Veneno grounded: absorbe y elimina las púas.
## Inmunidad Veneno/Acero/Inmunidad: en PoisonAilmentEffect.can_apply().

var _pending_poisoned: bool = false
var _pending_badly: bool = false
var _pending_absorbed: bool = false
var _pending_target: BattlePokemon = null


func _init(
	_source = null,
	_side_type: BattleSide.Types = BattleSide.Types.NONE,
	_max_layers: int = 2
) -> void:
	super._init(_source, _side_type, _max_layers)


func apply_on_entry(pokemon: BattlePokemon) -> void:
	_pending_poisoned = false
	_pending_badly = false
	_pending_absorbed = false
	_pending_target = null
	if pokemon == null or pokemon.is_fainted():
		return
	if not _is_grounded(pokemon):
		return

	# Tipo Veneno grounded absorbe las púas (Gen 4).
	if _has_type(pokemon, TypesEnum.Values.POISON):
		_absorb(pokemon)
		return

	var badly := layers >= 2
	var source_move_id := 0
	if source is BattleMove:
		source_move_id = (source as BattleMove).get_id()
	elif get_effect_id() != 0:
		source_move_id = get_effect_id()

	if PoisonAilmentEffect.try_apply(pokemon, badly, source_move_id):
		_pending_poisoned = true
		_pending_badly = badly
		_pending_target = pokemon


func _absorb(pokemon: BattlePokemon) -> void:
	_pending_absorbed = true
	_pending_target = pokemon
	# remove_side_effect se aplaza a visualize_on_entry para poder mostrar el mensaje.


func _is_grounded(pokemon: BattlePokemon) -> bool:
	if _has_type(pokemon, TypesEnum.Values.FLYING):
		return false
	if pokemon.ability != null and int(pokemon.ability.id) == AbilitiesEnum.Values.LEVITATE:
		return false
	return true


func _has_type(pokemon: BattlePokemon, type_id: int) -> bool:
	var type1 := pokemon.get_type1()
	if type1 != null and type1.id == type_id:
		return true
	var type2 := pokemon.get_type2()
	return type2 != null and type2.id == type_id


func _clear_pending() -> void:
	_pending_poisoned = false
	_pending_badly = false
	_pending_absorbed = false
	_pending_target = null


func visualize_on_entry(pokemon: BattlePokemon, ui: BattleUI) -> void:
	if pokemon == null or ui == null:
		return
	if pokemon != _pending_target:
		return
	if _pending_absorbed:
		await ui.show_toxic_spikes_absorbed_message(pokemon)
		BattleEffectController.remove_side_effect(side_type, self)
		layers = 0
		_clear_pending()
		return
	if _pending_poisoned:
		if _pending_badly:
			await ui.show_badly_poisoned_message(pokemon)
		else:
			await ui.show_start_effect_message(
				MessageFamily.Values.AILMENT,
				pokemon,
				AilmentsEnum.Values.POISON
			)
		pokemon.status_changed.emit()
	_clear_pending()


static func find_on_side(lookup_side_type: BattleSide.Types) -> ToxicSpikesFieldEffect:
	if lookup_side_type == BattleSide.Types.NONE:
		return null
	for effect in BattleEffectController.get_all_active_effects():
		if (
			effect is ToxicSpikesFieldEffect
			and (effect as ToxicSpikesFieldEffect).side_type == lookup_side_type
		):
			return effect as ToxicSpikesFieldEffect
	return null
