class_name BattlePokemon

signal status_changed

var base_data: Pokemon
var ai_controller: BattleIA
var participant: BattleParticipant
var side: BattleSide = null
var battle_spot: BattleSpot = null

var can_act_this_turn: bool = true
var in_battle:bool = false
var inBattleParty:bool = false
var controllable: bool
var fainted: bool
var is_wild: bool
var battle_moves: Array[BattleMove] = []

var hp: int
var total_hp: int
var attack: int
var defense: int
var sp_attack: int
var sp_defense: int
var speed: int

var ability: AbilityData = null
var nature: NatureData = null

var accuracy_stage: int = 0
var evasion_stage: int = 0
var critical_stage: int = 0

var status: AilmentData = null
var status_turns: int = 0

var stat_stages := StatStages.new()

# Recordar el último movimiento seleccionado por este Pokémon
var last_move_index: int = 0
## Último movimiento ejecutado con éxito en combate (id PokeAPI); 0 = ninguno.
var last_used_move_id: int = 0

## Pokémon del jugador que han estado en campo frente a este rival (EXP; no requiere daño).
var _player_exp_participants: Array[BattlePokemon] = []

var _selectedBattleChoice: BattleChoice

# Setter para selectedBattleChoice que automáticamente asigna el pokemon al choice
var selectedBattleChoice: BattleChoice:
	get:
		return _selectedBattleChoice
	set(value):
		_selectedBattleChoice = value
		if value != null:
			value.pokemon = self

func _init(_pokemon: Pokemon, _IA: BattleIA = null):
	base_data = _pokemon
	controllable = (_IA == null)
	hp = base_data.hp_actual
	total_hp = get_final_stat(StatsEnum.Values.HP)
	attack = get_final_stat(StatsEnum.Values.ATTACK)
	defense = get_final_stat(StatsEnum.Values.DEFENSE)
	sp_attack = get_final_stat(StatsEnum.Values.SP_ATTACK)
	sp_defense = get_final_stat(StatsEnum.Values.SP_DEFENSE)
	speed = get_final_stat(StatsEnum.Values.SPEED)
	ability = base_data.ability
	nature = base_data.nature

	# Los estados persistentes fuera de combate viven en Pokemon.major_status → AilmentData aquí al entrar.
	status = AilmentData.from_major_status(base_data.major_status)
	fainted = base_data.hp_actual <= 0


	setIA(_IA)


## Copia PS, estado mayor y PP (los Move del runtime ya comparten referencia con BattleMove) al Pokémon persistente del jugador.
func write_persistent_state_to_runtime() -> void:
	if base_data == null:
		return
	var max_hp := get_final_stat(StatsEnum.Values.HP)
	base_data.hp_actual = clampi(hp, 0, max_hp)
	if base_data.hp_actual <= 0:
		base_data.major_status = CONST.STATUS.OK
	else:
		base_data.major_status = AilmentData.to_major_status(status)

func set_battle_spot(spot: BattleSpot) -> void:
	battle_spot = spot


## Instancia activa en el spot (evita desajustes con varias refs al mismo Pokémon).
func get_active_battle_pokemon() -> BattlePokemon:
	if battle_spot != null:
		var active := battle_spot.get_active_pokemon()
		if active != null:
			return active
	if in_battle and side != null:
		for spot in side.battle_spots:
			if spot == null:
				continue
			var active := spot.get_active_pokemon()
			if active == self:
				return self
			if active != null and base_data != null and active.base_data == base_data:
				return active
	return self


func resolve_battle_spot() -> BattleSpot:
	var active := get_active_battle_pokemon()
	if active != null and active.battle_spot != null:
		return active.battle_spot
	return battle_spot


func setIA(_IA:BattleIA):
	if _IA != null:
		# Duplicar la IA para que cada Pokémon tenga su propia instancia
		self.ai_controller = _IA.duplicate()


## Recalcula PS máximos y stats de combate desde `base_data`; mantiene PS actuales coherentes con el runtime.
func refresh_derived_stats_from_base() -> void:
	if base_data == null:
		return
	total_hp = get_final_stat(StatsEnum.Values.HP)
	attack = get_final_stat(StatsEnum.Values.ATTACK)
	defense = get_final_stat(StatsEnum.Values.DEFENSE)
	sp_attack = get_final_stat(StatsEnum.Values.SP_ATTACK)
	sp_defense = get_final_stat(StatsEnum.Values.SP_DEFENSE)
	speed = get_final_stat(StatsEnum.Values.SPEED)
	hp = clampi(base_data.hp_actual, 0, total_hp)
	fainted = hp <= 0


func init_turn() -> void:
	selectedBattleChoice = null
	can_act_this_turn = true
	# Si más adelante agregas efectos temporales, pueden resetearse aquí


func commit_move_usage(move: BattleMove) -> void:
	if move == null:
		return
	last_used_move_id = move.get_id()
	if move.get_id() == MovesEnum.Values.STRUGGLE:
		return
	if move.base_data != null:
		move.base_data.use_pp()


func clear_last_used_move() -> void:
	last_used_move_id = 0


func register_player_exp_participant(player_bp: BattlePokemon) -> void:
	if player_bp == null or not player_bp.controllable or player_bp.fainted:
		return
	if _player_exp_participants.has(player_bp):
		return
	_player_exp_participants.append(player_bp)


## Receptores de EXP por este KO (`BattlePokemon` en campo); si no hay lista (caso raro), `fallback_executor`.
func get_runtime_exp_recipient_battle_pokemon(fallback_executor: BattlePokemon) -> Array[BattlePokemon]:
	var out: Array[BattlePokemon] = []
	for bp in _player_exp_participants:
		if bp != null and not bp.fainted and bp.base_data != null:
			out.append(bp)
	if out.is_empty() and fallback_executor != null and fallback_executor.controllable \
			and not fallback_executor.fainted and fallback_executor.base_data != null:
		out.append(fallback_executor)
	return out

func _to_string() -> String:
	return "patata"

func get_type1() -> TypeData:
	return base_data.get_type1()

func get_type2() -> TypeData:
	return base_data.get_type2()

func get_back_sprite():
	#var texture:Texture2D = ImageTexture.new().create_from_image(instance.battle_back_sprite.atlas.get_image().get_region(instance.battle_back_sprite.region))
	#texture.set_size_override(texture.get_size())
	return base_data.get_battle_back_sprite()

func get_front_sprite():
	#var texture:Texture2D = ImageTexture.new().create_from_image(instance.battle_front_sprite.atlas.get_image().get_region(instance.battle_front_sprite.region))
	#texture.set_size_override(texture.get_size())
	return base_data.get_battle_front_sprite()


func get_hp() -> int:
	return hp

func get_attack() -> int:
	return attack

func get_defense() -> int:
	return defense

func get_sp_attack() -> int:
	return sp_attack

func get_sp_defense() -> int:
	return sp_defense

func get_speed() -> int:
	return speed

func get_name() -> String:
	return base_data.base.Name

func get_display_name() -> String:
	return base_data.get_display_name()

func get_battle_display_name(upper:bool = false) -> String:
	var display_name = ""

	if controllable:
		display_name = get_display_name()
	elif is_wild:
		display_name = "el %s salvaje" % get_name()
	else:
		display_name = "el %s enemigo" % get_name()

	return display_name[0].to_upper() + display_name.substr(1) if upper else display_name

func get_battle_possessive_name() -> String:
	if controllable:
		return "de %s" % get_display_name()
	elif is_wild:
		return "del %s salvaje" % get_name()
	else:
		return "del %s enemigo" % get_name()

func get_battle_target_name() -> String:
	if controllable:
		return "a %s" % get_display_name()
	elif is_wild:
		return "al %s salvaje" % get_name()
	else:
		return "al %s enemigo" % get_name()

func get_level() -> int:
	return base_data.level

func is_fainted() -> bool:
	return get_hp() <= 0

func get_opponent_side() -> BattleSide:
	return side.opponent_side

func get_available_moves() -> Array[BattleMove]:
	if battle_moves.is_empty():
		prepare_battle_moves()
	return battle_moves


func find_move_index_by_id(move_id: int) -> int:
	if move_id <= 0:
		return -1
	var moves := get_available_moves()
	for i in range(moves.size()):
		if moves[i].get_id() == move_id:
			return i
	return -1


func get_move_by_id(move_id: int) -> BattleMove:
	var idx := find_move_index_by_id(move_id)
	if idx < 0:
		return null
	return get_available_moves()[idx]

## Índices en get_available_moves() elegibles (PP, mofa, disable, etc.) vía efectos.
func get_selectable_move_indices() -> Array[int]:
	return BattleEffectController.get_selectable_move_indices(self)

func prepare_battle_moves():
	battle_moves.clear()
	for move: Move in base_data.movements:
		battle_moves.append(move.to_battle_move(self))

func decide_random_action() -> BattleChoice:
	var moves = get_available_moves()
	if moves.is_empty():
		return BattleChoice.new()

	var struggle := BattleStruggleChoice.create_if_needed(self)
	if struggle != null:
		return struggle

	var legal_indices := get_selectable_move_indices()
	if legal_indices.is_empty():
		return BattlePassChoice.new()

	var index: int = legal_indices[randi() % legal_indices.size()]
	var move = moves[index]

	var choice = BattleMoveChoice.new()
	choice.move_index = index
	choice.pokemon = self

	var target_handler = BattleTarget.new(move)
	await target_handler.select_targets()
	choice.target_handler = target_handler

	return choice

func take_damage(damage: DamageEffect) -> void:
	hp -= damage.amount
	hp = max(hp, 0)

func take_heal(heal: HealEffect) -> void:
	hp += heal.amount
	hp = min(hp, total_hp)
	print("hp after heal: " + str(hp))

func set_status(new_status: AilmentData):
	if new_status and !new_status.is_persistent:
		push_warning("Intentando asignar un ailment volátil como status.")
		return

	if status == new_status:
		return

	if status != null and status.is_persistent:
		BattleEffectController.remove_major_status_ailment_effect(
			self, status.get_enum_value()
		)

	status = new_status
	if base_data != null:
		base_data.major_status = AilmentData.to_major_status(new_status) if new_status else CONST.STATUS.OK

func get_base_stat(stat: StatsEnum.Values) -> int:
	return base_data.get_base_stat(stat)

func get_iv(stat: StatsEnum.Values) -> int:
	return base_data.get_iv(stat)

func get_ev(stat: StatsEnum.Values) -> int:
	return base_data.get_ev(stat)

func get_final_stat(stat: StatsEnum.Values, level: int = base_data.level) -> int:
	return base_data.get_final_stat(stat, level)

func get_modified_stat(stat: StatsEnum.Values) -> float:
	var final = get_final_stat(stat)
	var multiplier = stat_stages.get_multiplier(stat)
	return final * multiplier

func log_pokemon_stats():
	print("=== Stats de %s (Lv. %d) ===" % [get_display_name(), get_level()])
	print("HP: %d/%d" % [hp, total_hp])
	print("Attack: %d | Defense: %d" % [attack, defense])
	print("Sp.Atk: %d | Sp.Def: %d" % [sp_attack, sp_defense])
	print("Speed: %d" % speed)
	print("Ability: %s" % (ability.display_name if ability else "None"))
	print("Nature: %s" % (nature.display_name if nature else "None"))
	print("Status: %s" % (status.display_name if status else "OK"))
	print("==============================")
