extends RefCounted
class_name BattlePartySwitchController

const SLOT_COUNT: int = 6

var _side: BattleSide
var _active_pokemon: BattlePokemon
var _force_switch: bool = false
var _owner_participant: BattleParticipant
var _scoped_party: Array[BattlePokemon] = []


func _init(side: BattleSide, active_pokemon: BattlePokemon, force_switch: bool = false) -> void:
	_side = side
	_active_pokemon = active_pokemon
	_force_switch = force_switch
	_owner_participant = active_pokemon.participant if active_pokemon != null else null
	_scoped_party = _build_scoped_party()


func _build_scoped_party() -> Array[BattlePokemon]:
	if _side == null:
		return []
	if _owner_participant != null:
		return _side.get_participant_battle_party(_owner_participant)
	return _side.pokemonParty


func get_slot_count() -> int:
	return SLOT_COUNT


func get_global_party_index(battle_pokemon: BattlePokemon) -> int:
	if _side == null:
		return -1
	return _side.find_party_index(battle_pokemon)


func get_party_members_ordered() -> Array[Pokemon]:
	var out: Array[Pokemon] = []
	for bp in _scoped_party:
		if bp != null and bp.base_data != null:
			out.append(bp.base_data)
	return out


func touch_pokemon(mon: Pokemon) -> void:
	if mon == null:
		return
	for bp in _scoped_party:
		if bp != null and bp.base_data == mon:
			var max_hp := mon.get_final_stat(StatsEnum.Values.HP)
			mon.hp_actual = clampi(bp.get_hp(), 0, max_hp)
			return


func get_slot_view(slot: int) -> Dictionary:
	var bp: BattlePokemon = get_battle_pokemon_at(slot)
	if bp == null or bp.base_data == null:
		return {"occupied": false}

	var mon: Pokemon = bp.base_data
	var max_hp := mon.get_final_stat(StatsEnum.Values.HP)
	mon.hp_actual = clampi(bp.get_hp(), 0, max_hp)
	var status := "—"
	if bp.is_fainted():
		status = "Debilitado"
	elif mon.major_status != CONST.STATUS.OK:
		status = AilmentData.major_status_display_name(mon.major_status)

	return {
		"occupied": true,
		"display_name": mon.get_display_name(),
		"species_name": mon.base.Name,
		"level": mon.level,
		"hp_current": bp.get_hp(),
		"hp_max": max_hp,
		"status_text": status,
		"icon": mon.get_icon_sprite(),
		"gender": mon.gender,
		"pokemon": mon,
		"battle_pokemon": bp,
		"is_active": bp == _active_pokemon
	}


func is_slot_occupied(slot: int) -> bool:
	return bool(get_slot_view(slot).get("occupied", false))


func get_battle_pokemon_at(slot: int) -> BattlePokemon:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	if slot >= _scoped_party.size():
		return null
	return _scoped_party[slot]


func find_slot_for_battle_pokemon(target: BattlePokemon) -> int:
	if target == null:
		return -1
	for i in range(_scoped_party.size()):
		if _scoped_party[i] == target:
			return i
	return -1


func is_selectable_switch_slot(slot: int) -> bool:
	return get_invalid_switch_reason(slot).is_empty()


func get_invalid_switch_reason(slot: int) -> String:
	if not is_slot_occupied(slot):
		return "No hay ningún Pokémon en ese slot."

	var candidate: BattlePokemon = get_battle_pokemon_at(slot)
	if candidate == null:
		return "No hay ningún Pokémon en ese slot."
	if candidate.is_fainted():
		return "¡A %s no le quedan fuerzas para luchar!" % candidate.get_display_name()
	if candidate == _active_pokemon:
		return "%s ya está en el campo de batalla." % candidate.get_display_name()
	if candidate.in_battle:
		return "%s ya está en el campo de batalla." % candidate.get_display_name()
	if not candidate.inBattleParty:
		return "%s no está disponible para este combate." % candidate.get_display_name()
	return ""


func get_invalid_switch_message(slot: int) -> Dictionary:
	var reason := get_invalid_switch_reason(slot)
	if reason.is_empty():
		return {}
	return {"type": "wait", "text": reason, "wait_time": 2.0}


func can_cancel_battle_switch() -> bool:
	return not _force_switch
