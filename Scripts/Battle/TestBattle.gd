extends Node2D

#Battlers
@onready var player: Battler = $Player
@onready var singleTrainer: Battler = $SingleTrainer
@onready var wildPokemons = $WildPokemons.get_children() 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GUI/FadeLayer.visible = false
	
	wildSingleBattle()
	return
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
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wildPokemons[0].to_battle_pokemon()])
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE  
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]
	
	SignalManager.battle_requested.emit(participants, rules)
	await SignalManager.battle_finished
	
	
func wildDoubleBattle():
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wildPokemons[0].to_battle_pokemon(), wildPokemons[1].to_battle_pokemon()])
	var playerParticipant: BattleParticipant = player.to_battle_participant()

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
	pass

# Helper: genera un Pokémon aleatorio
func _create_random_pokemon(is_wild: bool = false) -> BattlePokemon:
	var pkmn_instance := PokemonInstance.new()
	pkmn_instance.create(true, -1, randi_range(1, 100))  # Pokémon aleatorio nivel 1-100
	pkmn_instance.isWild = is_wild
	return pkmn_instance.to_battle_pokemon()

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
