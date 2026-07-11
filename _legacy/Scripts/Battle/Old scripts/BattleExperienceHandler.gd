class_name BattleExperienceHandler

var pokemonToGiveExp: Array[BattlePokemonExperience]

func _init() -> void:
	SignalManager.Battle.ExperienceHandler.addPokemon.connect(addDefeatedPokemon)
	SignalManager.Battle.ExperienceHandler.free.connect(clear)
	SignalManager.Battle.ExperienceHandler.giveExp.connect(giveExp)

func addDefeatedPokemon(defeatedPokemon:BattlePokemon):
	for p:BattlePokemon in defeatedPokemon.listPokemonBattledAgainst:
		#p.getExpGained(self) #Enlloc de ferho per aqui, q el propi getExpGained li assigni a la variable
		pokemonToGiveExp.push_back(BattlePokemonExperience.new(p, p.getExpGained(defeatedPokemon)))
	for par:BattleParticipant in defeatedPokemon.side.opponentSide.participants:
		for p:BattlePokemon in par.getPKMNwithExpAll():
			pokemonToGiveExp.push_back(BattlePokemonExperience.new(p, p.getExpGained(defeatedPokemon)))
		
func giveExp():
	if pokemonToGiveExp.is_empty():
		await Engine.get_main_loop().process_frame
	for p:BattlePokemonExperience in pokemonToGiveExp:
		await p.giveExp()
	pokemonToGiveExp.clear()
	SignalManager.Battle.ExperienceHandler.finished.emit()
	
func clear():
	pokemonToGiveExp.clear()
	SignalManager.Battle.ExperienceHandler.addPokemon.disconnect(addDefeatedPokemon)
	SignalManager.Battle.ExperienceHandler.giveExp.disconnect(giveExp)
	SignalManager.Battle.ExperienceHandler.free.disconnect(clear)
		
class BattlePokemonExperience:
	var pokemon:BattlePokemon
	var experience:int
	
	func _init(_pokemon:BattlePokemon, _experience:int):
		self.pokemon = _pokemon
		self.experience = _experience
		
	func giveExp():
		if !pokemon.fainted:
			await GUI.battle.msgBox.showGainedEXPMessage(pokemon, experience)
			await pokemon.giveExp(200)#experience)
