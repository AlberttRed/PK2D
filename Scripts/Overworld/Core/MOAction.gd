extends Resource
class_name MOAction

## Clase base para todas las acciones de Máquinas Ocultas (MO)
## Define la interfaz que deben implementar todas las MO específicas

## Nombre de la MO (ej: "CUT", "SURF", "STRENGTH", etc.)
@export var mo_name: String = ""

## Descripción de la acción que realiza (útil para debug/logs)
@export var description: String = ""

## ========================
## CONFIGURACIÓN DE UI/UX (Opcional - para override)
## ========================

## Si true, muestra un choice (Sí/No) antes de ejecutar
## Puede sobrescribirse en cada MOAction
@export var requires_confirmation: bool = true

## ========================
## MÉTODOS A SOBRESCRIBIR
## ========================

## Verifica si el jugador puede usar esta MO en el contexto actual
## @param _player: Nodo del jugador que intenta usar la MO
## @param _target: Nodo sobre el que se intenta usar la MO (puede ser un Event, TileMap, etc.)
## @return: true si se puede usar, false si no
func can_use(_player: Node, _target: Node) -> bool:
	push_warning("MOAction.can_use() debe ser sobrescrito en la clase hija: %s" % mo_name)
	return false

## Obtiene el mensaje de detección que se muestra SIEMPRE (antes de validar)
## Este mensaje se muestra incluso si el jugador no puede usar la MO
## @param _target: Nodo sobre el que se intenta usar la MO
## @return: String con el mensaje a mostrar
func get_detect_message(_target: Node) -> String:
	return "¡Parece que se puede usar %s aquí!" % mo_name

## Ejecuta el FLUJO de la MO: choice, animación, mensajes de éxito
## Este método se llama SOLO si can_use() retornó true
## @param _player: Nodo del jugador que usa la MO
## @param _target: Nodo sobre el que se aplica la MO
## @param _context: EventController (para acceder a get_tree(), GUI, etc.)
## @return: Dictionary con:
##   - success: bool - Si la MO se ejecutó correctamente
##   - cancelled: bool (opcional) - Si el jugador canceló
func execute(_player: Node, _target: Node, _context: Node) -> Dictionary:
	push_warning("MOAction.execute() debe ser sobrescrito en la clase hija: %s" % mo_name)
	return {"success": false, "cancelled": false}

## ========================
## MÉTODOS AUXILIARES
## ========================

## Verifica si el jugador tiene una MO específica en su equipo
## @param _mo_move_name: Nombre del movimiento de la MO (ej: "CUT", "SURF")
## @return: true si tiene la MO, false si no
func player_has_mo(_mo_move_name: String) -> bool:
	# TODO: Implementar verificación real cuando tengamos el sistema de equipo
	# Por ahora, retornamos true para pruebas
	push_warning("MOAction.player_has_mo() - Implementación temporal, siempre retorna true")
	return true

## Obtiene el nombre de la MO
func get_mo_name() -> String:
	return mo_name

## Obtiene la descripción de la MO
func get_description() -> String:
	return description

func _play_player_mo_start(player: Node) -> void:
	if player and player.has_method("play_mo_start"):
		await player.play_mo_start()

func _play_player_mo_end(player: Node) -> void:
	if player and player.has_method("play_mo_end"):
		await player.play_mo_end()
