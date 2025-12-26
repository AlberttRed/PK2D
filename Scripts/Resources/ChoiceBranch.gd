extends Resource
class_name ChoiceBranch

## ChoiceBranch - Representa una rama de elección (choice) dentro de un evento
##
## Cada branch contiene:
## - Un label (texto que aparece como opción)
## - Una lista de comandos que se ejecutan si esta opción es seleccionada
##
## Uso:
## Crear múltiples ChoiceBranch dentro de un ShowChoicesCommand
## Cada branch se ejecutará solo si el jugador selecciona esa opción

## Texto que aparece como opción en el ChoiceBox
@export var label: String = ""

## Lista de comandos que se ejecutarán si esta opción es seleccionada
@export var commands: Array[EventCommand] = []

## Si true, cierra el MessageBox después de ejecutar los comandos de este branch
## Si false, mantiene el MessageBox visible (útil para mostrar más mensajes después)
@export var close_previous_message: bool = true

## (Opcional) Valor a guardar en la variable cuando este branch es seleccionado
## Si está vacío/null y la variable está informada en ShowChoicesCommand.store_result_in,
## se guardará null
## Si la variable no está informada, no se guarda nada
## Puede ser cualquier tipo: int, bool, String, float, etc.
@export var value_stored = ""

## Constructor opcional para facilitar creación desde código
func _init(p_label: String = "", p_commands: Array[EventCommand] = []) -> void:
	label = p_label
	commands = p_commands

