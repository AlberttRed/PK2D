extends Node2D

#Battlers
@onready var player: Battler = $Player
@onready var singleTrainer: Battler = $SingleTrainer
@onready var wildPokemons = $WildPokemons.get_children() 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GUI/FadeLayer.visible = false
	#await wildBattle_OLD()
	await wildSingleBattle()
#	await wildDoubleBattle()
	#get_tree().quit()
	
func wildSingleBattle():
	#var wildPokemon:PokemonInstance = PokemonInstance.new().create(true) 
	#wildPokemon.isWild = true
	
	# Configurar HP de los Pokémon del jugador en 10 para testing
	
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wildPokemons[0].to_battle_pokemon()])
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	for pokemon in playerParticipant.pokemon_team:
		pokemon.hp = 10
		
	for pokemon in wildParticipant.pokemon_team:
		pokemon.hp = 10
	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE  
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]
	
	SignalManager.battle_requested.emit(participants, rules)
	
	
func wildDoubleBattle():
	#var wildPokemon:PokemonInstance = PokemonInstance.new().create(true) 
	#wildPokemon.isWild = true
	#var wildPokemon2:PokemonInstance = PokemonInstance.new().create(true) 
	#wildPokemon2.isWild = true
	#
	# Configurar HP de los Pokémon del jugador en 10 para testing
	
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wildPokemons[0].to_battle_pokemon(), wildPokemons[1].to_battle_pokemon()])
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	for pokemon in playerParticipant.pokemon_team:
		pokemon.hp = 10
	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.DOUBLE  
	)
	
	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	SignalManager.battle_requested.emit(participants, rules)	
	
func singleTrainerBattle():
	pass
	
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
