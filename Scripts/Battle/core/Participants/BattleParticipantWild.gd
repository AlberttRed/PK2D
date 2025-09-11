extends BattleParticipant
class_name BattleParticipantWild

func _init(_pokemon_team: Array[BattlePokemon] = []):
	self.is_trainer = false
	self.name = ""
	self.ai_controller = BattleIA_Wild.new()
	self.sprite_path = ""  # O alguna imagen genérica de Pokémon salvaje
	self.add_pokemon_team(_pokemon_team)
