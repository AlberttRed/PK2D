extends Resource

class_name BattleIA

## Clase base para la inteligencia artificial de combate.
## 
## Las subclases deben implementar el método decide_action() que devuelve
## un BattleChoice válido para el Pokémon controlado por la IA.
##
## Ejemplos de subclases:
## - BattleIA_Wild: Comportamiento aleatorio simple
## - BattleIA_Easy: Considera efectividad de tipos
## - BattleIA_Medium: (Futuro) Considera stats y cambios
## - BattleIA_Hard: (Futuro) Estrategia avanzada

## Configuración exportable para ajustar comportamiento desde el editor
@export var difficulty_name: String = "Default"
@export var use_items: bool = false
@export var can_switch_strategically: bool = false

## Método principal que debe implementarse en todas las subclases.
## Recibe el Pokémon que debe tomar una decisión y devuelve un BattleChoice válido.
func decide_action(_pokemon: BattlePokemon) -> BattleChoice:
	push_error("decide_action() debe ser implementado en la subclase de BattleIA")
	return BattlePassChoice.new()
