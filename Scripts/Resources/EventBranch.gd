extends Resource
class_name EventBranch

## EventBranch - Representa una rama de ejecución condicional dentro de un evento
##
## Cada branch contiene:
## - Un label (texto que aparece como opción)
## - Una lista de comandos que se ejecutan si esta opción es seleccionada
##
## Uso:
## Crear múltiples EventBranch dentro de un ShowChoicesCommand
## Cada branch se ejecutará solo si el jugador selecciona esa opción

## Texto que aparece como opción en el ChoiceBox
@export var label: String = ""

## Lista de comandos que se ejecutarán si esta opción es seleccionada
@export var commands: Array[EventCommand] = []

## Si true, cierra el MessageBox después de ejecutar los comandos de este branch
## Si false, mantiene el MessageBox visible (útil para mostrar más mensajes después)
@export var close_previous_message: bool = true

## Constructor opcional para facilitar creación desde código
func _init(p_label: String = "", p_commands: Array[EventCommand] = []) -> void:
	label = p_label
	commands = p_commands

