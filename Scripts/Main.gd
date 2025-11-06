extends Node
class_name Main

## Main - Escena raíz del juego
## Contenedor global de sesión que gestiona DisplayManager y GameContainer
## GameContainer alojará las sesiones de juego (nueva partida, continuar partida)

@onready var display_manager = $DisplayManager
@onready var game_container: Node = $GameContainer

# Referencia a la sesión activa (GameSession)
var active_session = null

func _ready() -> void:
	print("Main: Inicializando escena raíz...")

	# Esperar un frame para asegurar que DisplayManager esté listo
	await get_tree().process_frame

	# TODO: En el futuro, aquí se mostraría un menú principal
	# Por ahora, iniciamos directamente una nueva sesión de juego
	start_new_game_session()

## Inicia una nueva sesión de juego (nueva partida)
func start_new_game_session() -> void:
	print("Main: Iniciando nueva sesión de juego...")

	# Limpiar sesión anterior si existe
	if active_session:
		active_session.queue_free()
		active_session = null

	# Cargar la escena GameSession
	var game_session_scene = load("res://Scenes/GameSession.tscn")
	if game_session_scene == null:
		push_error("Main: No se pudo cargar GameSession.tscn")
		return

	# Instanciar y añadir al contenedor
	active_session = game_session_scene.instantiate()
	game_container.add_child(active_session)

	print("Main: GameSession cargada exitosamente")

## Continúa una partida guardada (futuro)
func continue_game_session() -> void:
	print("Main: Continuando partida guardada...")
	# TODO: Implementar cuando exista sistema de guardado
	start_new_game_session()

## Finaliza la sesión actual y vuelve al menú principal (futuro)
func end_current_session() -> void:
	print("Main: Finalizando sesión actual...")

	if active_session:
		active_session.end_session()
		active_session = null

	# TODO: Volver al menú principal cuando exista
	print("Main: Sesión finalizada")

## Limpia el contenedor de juego (útil para cambios de escena global)
func clear_game_container() -> void:
	for child in game_container.get_children():
		child.queue_free()
	active_session = null
