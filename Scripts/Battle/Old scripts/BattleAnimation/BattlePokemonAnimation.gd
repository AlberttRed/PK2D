class_name BattlePokemonAnimation extends Animation

var pokemon : BattlePokemon

#func _init(pokemon :BattlePokemon):
	#self.pokemon = pokemon
	
func _init():
	pass

func doAnimation():
	assert(false, "Please override doAnimation()` in the BattlePokemonAnimation script.")
