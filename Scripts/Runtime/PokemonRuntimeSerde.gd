extends RefCounted
class_name PokemonRuntimeSerde


## Reconstruye un Pokémon desde datos planos (DatabaseService en runtime; sin rutas desde Party).
func deserialize(data: Dictionary) -> Pokemon:
	var pid := int(data.get("pokemon_id", int(PokemonsEnum.Values.BULBASAUR)))
	var lvl := int(data.get("level", 5))
	var mon := Pokemon.new(pid, lvl, null, null, null, false)
	if mon.base == null:
		push_error("PokemonRuntimeSerde.deserialize: no se pudo crear Pokémon id=%d" % pid)
		return null

	mon.nickname = str(data.get("nickname", ""))
	mon.gender = int(data.get("gender", mon.gender))
	mon.is_wild = bool(data.get("is_wild", false))
	mon.shiny = bool(data.get("shiny", false))

	mon.hp_IVs = int(data.get("hp_IVs", mon.hp_IVs))
	mon.attack_IVs = int(data.get("attack_IVs", mon.attack_IVs))
	mon.defense_IVs = int(data.get("defense_IVs", mon.defense_IVs))
	mon.spAttack_IVs = int(data.get("spAttack_IVs", mon.spAttack_IVs))
	mon.spDefense_IVs = int(data.get("spDefense_IVs", mon.spDefense_IVs))
	mon.speed_IVs = int(data.get("speed_IVs", mon.speed_IVs))

	mon.hp_EVs = int(data.get("hp_EVs", mon.hp_EVs))
	mon.attack_EVs = int(data.get("attack_EVs", mon.attack_EVs))
	mon.defense_EVs = int(data.get("defense_EVs", mon.defense_EVs))
	mon.spAttack_EVs = int(data.get("spAttack_EVs", mon.spAttack_EVs))
	mon.spDefense_EVs = int(data.get("spDefense_EVs", mon.spDefense_EVs))
	mon.speed_EVs = int(data.get("speed_EVs", mon.speed_EVs))

	mon.nature_id = int(data.get("nature_id", int(mon.nature_id))) as NaturesEnum.Values
	mon.ability_id = int(data.get("ability_id", int(mon.ability_id))) as AbilitiesEnum.Values
	mon.ability_slot = int(data.get("ability_slot", mon.ability_slot))
	mon.held_item_id = int(data.get("held_item_id", 0))

	var restored_moves: Array[MovesEnum.Values] = []
	for x in data.get("custom_move_ids", []):
		restored_moves.append(int(x) as MovesEnum.Values)
	mon.custom_move_ids = restored_moves

	mon.trainer_id = int(data.get("trainer_id", mon.trainer_id))
	mon.original_trainer = str(data.get("original_trainer", mon.original_trainer))
	mon.capture_date = str(data.get("capture_date", mon.capture_date))
	mon.capture_route = str(data.get("capture_route", mon.capture_route))
	mon.capture_level = int(data.get("capture_level", mon.capture_level))
	mon.personality = str(data.get("personality", mon.personality))

	if not Engine.is_editor_hint():
		mon.ability = DatabaseService.get_ability(mon.ability_id)
		mon.nature = DatabaseService.get_nature(NaturesEnum.get_id(mon.nature_id))

	mon._initialize_stats(false)
	mon._load_learnable_moves()
	mon._load_initial_moves()

	var max_hp := mon.get_final_stat(StatsEnum.Values.HP)
	if data.has("hp_actual"):
		mon.hp_actual = clampi(int(data.get("hp_actual", max_hp)), 0, max_hp)
	else:
		mon.hp_actual = max_hp

	mon.major_status = int(data.get("major_status", int(CONST.STATUS.OK)))

	mon.totalExp = int(data.get("totalExp", mon.actualLevelExpBase))
	mon._update_resource_name()
	return mon
