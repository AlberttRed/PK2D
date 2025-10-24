class_name BattlePokemon

signal status_changed

var base_data: PokemonInstance
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
var nature: Nature = null

var accuracy_stage: int = 0
var evasion_stage: int = 0
var critical_stage: int = 0

var status: AilmentData = null
var status_turns: int = 0

var stat_stages := StatStages.new()

# Recordar el último movimiento seleccionado por este Pokémon
var last_move_index: int = 0

var _selectedBattleChoice: BattleChoice

# Setter para selectedBattleChoice que automáticamente asigna el pokemon al choice
var selectedBattleChoice: BattleChoice:
	get:
		return _selectedBattleChoice
	set(value):
		_selectedBattleChoice = value
		if value != null:
			value.pokemon = self

func _init(_pokemon: PokemonInstance, _IA: BattleIA = null):
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

	#status = base_data.status
	#status_turns = base_data.status_turns
	fainted = base_data.hp_actual <= 0
	

	setIA(_IA)

func set_battle_spot(spot: BattleSpot) -> void:
	battle_spot = spot
	
func setIA(_IA:BattleIA):
	if _IA != null:
		# Duplicar la IA para que cada Pokémon tenga su propia instancia
		self.ai_controller = _IA.duplicate()

func init_turn() -> void:
	selectedBattleChoice = null
	can_act_this_turn = true
	# Si más adelante agregas efectos temporales, pueden resetearse aquí
	
func _to_string() -> String:
	return "patata"
	
func get_type1() -> Type:
	return base_data.type_a as Type

func get_type2() -> Type:
	return base_data.type_b as Type
	
func get_back_sprite():
	#var texture:Texture2D = ImageTexture.new().create_from_image(instance.battle_back_sprite.atlas.get_image().get_region(instance.battle_back_sprite.region))
	#texture.set_size_override(texture.get_size())
	return base_data.battle_back_sprite
	
func get_front_sprite():
	#var texture:Texture2D = ImageTexture.new().create_from_image(instance.battle_front_sprite.atlas.get_image().get_region(instance.battle_front_sprite.region))
	#texture.set_size_override(texture.get_size())
	return base_data.battle_front_sprite
	

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
	return base_data.Name
		
func get_display_name() -> String:
	if !base_data.nickname.is_empty():
		return base_data.nickname
	else:
		return base_data.Name

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

func prepare_battle_moves():
	battle_moves.clear()
	for move_instance:MoveInstance in base_data.movements:
		battle_moves.append(move_instance.to_battle_move(self))

func decide_random_action() -> BattleChoice:
	var moves = get_available_moves()
	if moves.is_empty():
		return BattleChoice.new()  # fallback

	var index = randi() % moves.size()
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

	status = new_status

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
	base_data.log_pokemon_stats()
