extends Resource
class_name SwitchCase

## SwitchCase - Representa un caso dentro de un SwitchCommand
##
## Cada caso contiene:
## - Una lista de valores posibles (values) que activan este caso
## - Una lista de comandos que se ejecutan si el valor evaluado coincide con alguno de ellos
##
## Uso:
## Crear múltiples SwitchCase dentro de un SwitchCommand
## Los casos se evalúan en orden y se ejecuta solo el primero que coincida
##
## Ejemplo:
## SwitchCase 0: values=[1, 2, 3] → [ShowMessageCommand("Número pequeño")]
## SwitchCase 1: values=[10, 20, 30] → [ShowMessageCommand("Número mediano")]
## SwitchCase 2: values=[100] → [ShowMessageCommand("Número grande")]

## Lista de valores que activan este caso
## Si el valor de la variable evaluada coincide con alguno de estos valores, se ejecutan los comandos
## Puede contener cualquier tipo: int, bool, String, float, etc.
@export var values: Array = []

## Lista de comandos que se ejecutarán si el valor evaluado coincide con alguno de los values
@export var commands: Array[EventCommand] = []

## Constructor opcional para facilitar creación desde código
func _init(p_values: Array = [], p_commands: Array[EventCommand] = []) -> void:
	values = p_values
	commands = p_commands
