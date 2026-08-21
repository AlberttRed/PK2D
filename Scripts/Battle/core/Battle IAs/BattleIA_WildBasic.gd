extends WildBattleIA

class_name BattleIA_WildBasic

## IA básica para Pokémon salvajes (contrato WildBasic).
##
## Movimientos: random legal. Items/switch: no.
## No es “dificultad Easy de trainer”: es el suelo wild + utilidad de fallback.

func _init() -> void:
	difficulty_name = "WildBasic"
	use_items = false
	can_switch_strategically = false


func decide_action(pokemon: BattlePokemon) -> BattleChoice:
	return build_random_legal_move_choice(pokemon)
