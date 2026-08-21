extends BattleParticipant
class_name BattleParticipantWild

func _init(_pokemon_team: Array[BattlePokemon] = []):
	self.is_trainer = false
	self.name = ""
	self.set_ai_controller(BattleIA_WildBasic.new(), "wild")
	self.sprite_path = ""  # O alguna imagen genérica de Pokémon salvaje
	self.add_pokemon_team(_pokemon_team)
