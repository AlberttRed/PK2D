extends Node
class_name Main

## Main - Escena raíz del juego
## Contenedor global de sesión que gestiona DisplayManager y GameContainer
## GameContainer alojará las sesiones de juego (nueva partida, continuar partida)

@onready var display_manager = $DisplayManager
@onready var game_container: Node = $GameContainer
@onready var main_menu = $MainMenu

## Modo debug de sesión: activa `GameStateService.debug_mode` (seeds de prueba,
## atajo de arranque sin menú, y cualquier otra lógica que consulte ese flag).
@export var debug_mode: bool = false

@export_group("Debug start")
## Mapa donde empieza la nueva partida en `debug_mode` (id = nombre de la escena; 2D o 3D).
## Ej. 3D: "Overworld3DTest" con posición (1, 1).
@export var debug_start_map_id: String = "Centro_Pokemon"
## Tile (2D) o celda XZ (3D) de inicio.
@export var debug_start_position: Vector2i = Vector2i(-29, -10)
## Orientación inicial: (0,-1) arriba/norte, (0,1) abajo/sur, (-1,0) izquierda, (1,0) derecha.
@export var debug_start_facing: Vector2 = Vector2.UP
@export_group("")

# Referencia a la sesión activa (GameSession)
var active_session = null



func _ready() -> void:
	# Esperar un frame para asegurar que DisplayManager esté listo
	await get_tree().process_frame
	GameStateService.debug_mode = self.debug_mode
	GameStateService.debug_start_map_id = debug_start_map_id
	GameStateService.debug_start_position = debug_start_position
	GameStateService.debug_start_facing = debug_start_facing
	_wire_main_menu()
	if self.debug_mode:
		if main_menu != null:
			main_menu.hide()
		start_new_game_session()
		return
	_show_main_menu()
	# FadeLayer arranca en negro (carga); descubrir menú principal.
	if DisplayManager.instance != null:
		await DisplayManager.fade_out(0.25)

## Inicia una nueva sesión de juego (nueva partida)
func start_new_game_session() -> void:
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
	if active_session != null:
		active_session.load_existing_on_start = false
	game_container.add_child(active_session)

## Continúa una partida guardada (futuro)
func continue_game_session() -> void:
	print("Main: Continuando partida guardada...")
	# Limpiar sesión anterior si existe
	if active_session:
		active_session.queue_free()
		active_session = null

	var game_session_scene = load("res://Scenes/GameSession.tscn")
	if game_session_scene == null:
		push_error("Main: No se pudo cargar GameSession.tscn")
		return

	active_session = game_session_scene.instantiate()
	if active_session != null:
		active_session.load_existing_on_start = true
	game_container.add_child(active_session)

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


func _wire_main_menu() -> void:
	if main_menu == null:
		push_error("Main: Nodo MainMenu no disponible.")
		return
	if not main_menu.continue_requested.is_connected(_on_main_menu_continue_requested):
		main_menu.continue_requested.connect(_on_main_menu_continue_requested)
	if not main_menu.new_game_requested.is_connected(_on_main_menu_new_game_requested):
		main_menu.new_game_requested.connect(_on_main_menu_new_game_requested)
	if not main_menu.options_requested.is_connected(_on_main_menu_options_requested):
		main_menu.options_requested.connect(_on_main_menu_options_requested)
	if not main_menu.quit_requested.is_connected(_on_main_menu_quit_requested):
		main_menu.quit_requested.connect(_on_main_menu_quit_requested)


func _show_main_menu() -> void:
	if main_menu == null:
		return
	main_menu.refresh_continue_panel()
	main_menu.show()


func _hide_main_menu() -> void:
	if main_menu == null:
		return
	main_menu.hide()


func _on_main_menu_continue_requested() -> void:
	_hide_main_menu()
	continue_game_session()


func _on_main_menu_new_game_requested() -> void:
	_hide_main_menu()
	start_new_game_session()


func _on_main_menu_options_requested() -> void:
	print("MainMenu: Opciones pendiente de implementar.")


func _on_main_menu_quit_requested() -> void:
	get_tree().quit()
