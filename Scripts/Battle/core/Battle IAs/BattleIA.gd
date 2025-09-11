extends Resource

class_name BattleIA

var pokemon : BattlePokemon = null

func _init(_active_pokemon : BattlePokemon = null):
	pokemon = _active_pokemon
	
func assign_pokemon(_active_pokemon : BattlePokemon = null):
	pokemon = _active_pokemon

func pokemon_assigned():
	return pokemon != null	
	
func selectAction():
	pass

func selectMove():
	pass
	
func selectTargets():
	pass
	
func selectNextPokemon():
	pass
