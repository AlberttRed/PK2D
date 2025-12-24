extends Resource
class_name EventBranch

## EventBranch - Representa una rama de ejecución condicional dentro de un evento
##
## Cada branch contiene:
## - Una condición (EventCondition) que se evalúa en tiempo de ejecución
## - Una lista de comandos que se ejecutan si la condición se cumple
##
## Uso:
## Crear múltiples EventBranch dentro de un ConditionalCommand
## Las ramas se evalúan en orden y se ejecuta solo la primera que cumpla la condición
##
## Si condition == null, la rama actúa como ELSE (rama por defecto)
##
## NOTA: EventBranch es exclusivo para ramas condicionales (if/else).
## Para opciones de elección del jugador, usar ChoiceBranch en ShowChoicesCommand.

## Condición que debe cumplirse para ejecutar esta rama
## Si es null, esta rama actúa como ELSE (rama por defecto)
## Puede ser:
## - GlobalFlagCondition
## - SelfFlagCondition
## - VariableCondition
## - GroupCondition (AND / OR / NOT)
@export var condition: EventCondition = null

## Lista de comandos que se ejecutarán si esta condición se cumple
@export var commands: Array[EventCommand] = []

## Constructor opcional para facilitar creación desde código
func _init(p_condition: EventCondition = null, p_commands: Array[EventCommand] = []) -> void:
	condition = p_condition
	commands = p_commands
