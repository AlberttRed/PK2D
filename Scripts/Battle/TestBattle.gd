extends Node2D

#Battlers
@onready var player: Battler = $Player
@onready var singleTrainer: Battler = $SingleTrainer
@onready var wildPokemons = $WildPokemons.get_children() 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#await wildBattle_OLD()
	#await wildSingleBattle()
	await wildDoubleBattle()
	#get_tree().quit()
	
func wildSingleBattle():
	#var wildPokemon:PokemonInstance = PokemonInstance.new().create(true) 
	#wildPokemon.isWild = true
	
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wildPokemons[0].to_battle_pokemon()])
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE  
	)

	GUI.BattleNew.start_battle([playerParticipant], [wildParticipant], rules)
	
	
func wildDoubleBattle():
	#var wildPokemon:PokemonInstance = PokemonInstance.new().create(true) 
	#wildPokemon.isWild = true
	#var wildPokemon2:PokemonInstance = PokemonInstance.new().create(true) 
	#wildPokemon2.isWild = true
	#
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wildPokemons[0].to_battle_pokemon(), wildPokemons[1].to_battle_pokemon()])
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.DOUBLE  
	)

	GUI.BattleNew.start_battle([playerParticipant], [wildParticipant], rules)	
	
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
