class_name SpikesFieldEffect
extends HazardFieldEffect

## Daño Gen 4 (HGSS) al entrar: 1/8 · 1/6 · 1/4 del PS máximo según capas.
## No afecta a Volador / Levitate / Magic Guard.

var _pending_entry_damage: int = 0
var _pending_entry_target: BattlePokemon = null


func _init(
	_source = null,
	_side_type: BattleSide.Types = BattleSide.Types.NONE,
	_max_layers: int = 3
) -> void:
	super._init(_source, _side_type, _max_layers)


func apply_on_entry(pokemon: BattlePokemon) -> void:
	_pending_entry_damage = 0
	_pending_entry_target = null
	if pokemon == null or pokemon.is_fainted():
		return
	if _is_immune(pokemon):
		return
	var dmg := _damage_for_layers(pokemon.total_hp, layers)
	if dmg <= 0:
		return
	var effect := DamageEffect.new(null, pokemon, null, dmg)
	pokemon.take_damage(effect)
	_pending_entry_damage = dmg
	_pending_entry_target = pokemon


func visualize_on_entry(pokemon: BattlePokemon, ui: BattleUI) -> void:
	if _pending_entry_target == null or _pending_entry_damage <= 0:
		return
	if pokemon != _pending_entry_target:
		return
	if pokemon.battle_spot != null:
		await pokemon.battle_spot.apply_damage()
	if ui != null:
		await ui.show_spikes_damage_message(pokemon)
	_pending_entry_damage = 0
	_pending_entry_target = null


static func find_on_side(lookup_side_type: BattleSide.Types) -> SpikesFieldEffect:
	if lookup_side_type == BattleSide.Types.NONE:
		return null
	for effect in BattleEffectController.get_all_active_effects():
		if effect is SpikesFieldEffect and (effect as SpikesFieldEffect).side_type == lookup_side_type:
			return effect as SpikesFieldEffect
	return null


static func _damage_for_layers(max_hp: int, layer_count: int) -> int:
	if max_hp <= 0 or layer_count <= 0:
		return 0
	match layer_count:
		1:
			return int(ceili(max_hp / 8.0))
		2:
			return int(ceili(max_hp / 6.0))
		_:
			return int(ceili(max_hp / 4.0))


func _is_immune(pokemon: BattlePokemon) -> bool:
	if _has_type(pokemon, TypesEnum.Values.FLYING):
		return true
	if pokemon.ability == null:
		return false
	var ability_id := int(pokemon.ability.id)
	return (
		ability_id == AbilitiesEnum.Values.LEVITATE
		or ability_id == AbilitiesEnum.Values.MAGIC_GUARD
	)


func _has_type(pokemon: BattlePokemon, type_id: int) -> bool:
	var type1 := pokemon.get_type1()
	if type1 != null and type1.id == type_id:
		return true
	var type2 := pokemon.get_type2()
	return type2 != null and type2.id == type_id
