extends Node2D

#Battlers
@onready var player: Battler = $Player
@onready var singleTrainer: Battler = $SingleTrainer
@onready var wildPokemons: Battler = $WildPokemons


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Lanzar combates en bucle para testing continuo
	while true:
		if randi() % 2 == 0:
			print(">>> Iniciando Single Wild Battle (Random)")
			await wildRandomSingleBattle()
		else:
			print(">>> Iniciando Double Wild Battle (Random)")
			await wildRandomDoubleBattle()
		# Pequeña pausa entre combates
		await get_tree().create_timer(0.5).timeout
	#get_tree().quit()
	
func wildSingleBattle():
	# Usar equipo del jugador (configurado en Player Battler)
	var playerParticipant: BattleParticipant = player.to_battle_participant()
	
	# Usar el primer Pokémon del equipo WildPokemons (configurado desde inspector)
	if wildPokemons.party.is_empty():
		push_error("wildSingleBattle: No hay Pokémon configurados en WildPokemons")
		return
	
	var wild_battle_pokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_battle_pokemon.is_wild = true
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wild_battle_pokemon])

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE  
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]
	
	SignalManager.battle_requested.emit(participants, rules)
	await SignalManager.battle_finished
	
	
func wildDoubleBattle():
	# Usar equipo del jugador (configurado en Player Battler)
	var playerParticipant: BattleParticipant = player.to_battle_participant()
	
	# Usar los primeros 2 Pokémon del equipo WildPokemons (configurado desde inspector)
	if wildPokemons.party.size() < 2:
		push_error("wildDoubleBattle: Se necesitan al menos 2 Pokémon en WildPokemons")
		return
	
	var wild1 = wildPokemons.party[0].to_battle_pokemon()
	wild1.is_wild = true
	var wild2 = wildPokemons.party[1].to_battle_pokemon()
	wild2.is_wild = true
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wild1, wild2])

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.DOUBLE  
	)
	
	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	SignalManager.battle_requested.emit(participants, rules)
	await SignalManager.battle_finished

func wildRandomSingleBattle():
	# Generar equipos completamente aleatorios para jugador y salvaje
	var playerParticipant: BattleParticipant = _create_random_player_participant(1)
	var wildParticipant: BattleParticipant = _create_random_wild_participant(1)

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE  
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]
	
	SignalManager.battle_requested.emit(participants, rules)
	await SignalManager.battle_finished

func wildRandomDoubleBattle():
	# Generar equipos completamente aleatorios para jugador (2) y salvajes (2)
	var playerParticipant: BattleParticipant = _create_random_player_participant(2)
	var wildParticipant: BattleParticipant = _create_random_wild_participant(2)

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.DOUBLE  
	)
	
	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	SignalManager.battle_requested.emit(participants, rules)
	await SignalManager.battle_finished
	
func singleTrainerBattle():
	# Usar equipos configurados en ambos Battlers (Player vs SingleTrainer)
	var playerParticipant: BattleParticipant = player.to_battle_participant()
	var trainerParticipant: BattleParticipant = singleTrainer.to_battle_participant()

	var rules = BattleRules.new(
		BattleRules.BattleTypes.TRAINER,
		BattleRules.BattleModes.SINGLE  
	)

	var participants:Array[BattleParticipant] = [playerParticipant, trainerParticipant]
	
	SignalManager.battle_requested.emit(participants, rules)
	await SignalManager.battle_finished

# Helper: genera un Pokémon aleatorio
func _create_random_pokemon(is_wild: bool = false) -> BattlePokemon:
	var random_id = randi_range(1, 151)
	var pokemon_data = DatabaseManager.get_pokemon(random_id)
	var pkmn := Pokemon.new(pokemon_data, randi_range(1, 100), -1, -1, 0, true)
	pkmn.is_wild = is_wild
	return pkmn.to_battle_pokemon()

# Helper: genera participante salvaje con N Pokémon aleatorios
func _create_random_wild_participant(num_pokemon: int = 1) -> BattleParticipant:
	var wild_team: Array[BattlePokemon] = []
	for i in num_pokemon:
		wild_team.append(_create_random_pokemon(true))
	return BattleParticipantWild.new(wild_team)

# Helper: genera participante de jugador con N Pokémon aleatorios
func _create_random_player_participant(num_pokemon: int = 1) -> BattleParticipant:
	var player_team: Array[BattlePokemon] = []
	for i in num_pokemon:
		player_team.append(_create_random_pokemon(false))
	var participant := BattleParticipant.new(player_team)
	participant.is_player = true
	participant.name = "Jugador"
	return participant
	
#
#func singleTrainerBattle_OLD():
	#var selected_pokemon = null#getPokemon()
	#var selected_level:int = 5#getLevel()
	#
	#var br : BattleRules = BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)	
	#var bc : BattleController = BattleController.new(br)
#
	#bc.playerSide.addParticipant($Player, true)
	#bc.enemySide.addParticipant($SingleTrainer, false)
	#
	#bc.playerSide.initSide(br)
	#bc.enemySide.initSide(br)
	#await bc.initBattle()
	#
	#
#func wildBattle_OLD():
	#var selected_pokemon = null#getPokemon()
	#var selected_level:int = 5#getLevel()
#
	#var pkmn = PokemonInstance.new().create(true)#, 5, selected_level)
	#pkmn.isWild = true
	#print("A wild " + str(pkmn.Name) + " Lvl. " + str(pkmn.level) + " appeared!")
	#
	#var enemyBattler : Battler = Battler.new().create(CONST.BATTLER_TYPES.WILD_POKEMON, [pkmn], BattleIA_Wild.new())
	#
	#var br : BattleRules = BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)	
	#var bc : BattleController = BattleController.new(br)
	##var bs_player : BattleSide = BattleSide.new(CONST.BATTLE_SIDES.PLAYER)
	##var bs_enemy : BattleSide = BattleSide.new(CONST.BATTLE_SIDES.ENEMY)
	#bc.playerSide.addParticipant($Player, true)
	#bc.enemySide.addParticipant(enemyBattler, false)
	#bc.enemySide.isWild = true
	#
	#bc.playerSide.initSide(br)
	#bc.enemySide.initSide(br)
	#await bc.initBattle()
	#
