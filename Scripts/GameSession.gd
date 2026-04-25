extends Node
class_name GameSession

## GameSession - Representa una sesión de juego completa
## Gestiona el ciclo de vida de una partida (nueva o cargada)
## Contiene el Overworld y mantiene el estado de la sesión activa

# Referencias a escenas
const OVERWORLD_SCENE = preload("res://Scenes/Overworld/Overworld.tscn")
@export var load_existing_on_start: bool = false

func _ready() -> void:
	# Esperar un frame para asegurar que todos los sistemas estén inicializados
	await get_tree().process_frame

	# Decidir si cargar partida existente o nueva partida
	if load_existing_on_start:
		if GameStateService.load_saved_game():
			_load_overworld_scene()
		else:
			push_warning("GameSession: Se solicitó continuar, pero no hay save válido. Iniciando nueva partida.")
			GameStateService.initialize_new_game()
			_load_overworld_scene()
	else:
		GameStateService.initialize_new_game()
		_load_overworld_scene()

## Carga la escena Overworld y configura el player según el GameState
func _load_overworld_scene() -> void:
	# Instanciar la escena Overworld
	var overworld_instance = OVERWORLD_SCENE.instantiate()
	if not overworld_instance:
		push_error("GameSession: No se pudo instanciar la escena Overworld")
		return

	# Añadir como hijo de esta sesión (no reemplazar la escena actual)
	add_child(overworld_instance)

	# Esperar un frame para que el Overworld inicialice su contexto y sistemas
	await get_tree().process_frame

	# Obtener el coordinador (orquestador de sistemas del overworld)
	var overworld_coordinator = overworld_instance as OverworldCoordinator
	var overworld_context: OverworldContext = null
	if overworld_coordinator and overworld_coordinator.has_method("get_context"):
		overworld_context = overworld_coordinator.get_context()

	if overworld_context:
		overworld_context.block_player_control()
	else:
		push_warning("GameSession: OverworldContext no disponible para bloquear control del jugador")

	if overworld_coordinator and overworld_coordinator.has_method("configure_from_gamestate"):
		var success = overworld_coordinator.configure_from_gamestate()

		if success:
			# Desvanecer desde negro cuando todo está listo
			await DisplayManager.fade_out(0.25)
			# Desbloquear control ahora que terminó el fade
			if overworld_context:
				overworld_context.unblock_player_control()
			else:
				push_warning("GameSession: OverworldContext no disponible para desbloquear control del jugador")
		else:
			push_error("GameSession: Error al configurar overworld desde GameState")
	else:
		push_error("GameSession: OverworldCoordinator no encontrado o método no disponible")

## Método público para forzar nueva partida (útil para testing)
func force_new_game() -> void:
	print("GameSession: Forzando nueva partida...")
	GameStateService.initialize_new_game()
	_load_overworld_scene()

## Método público para simular carga de partida (útil para testing)
func simulate_load_game(map_id: String, position: Vector2i, facing_dir: Vector2) -> void:
	print("GameSession: Simulando carga de partida...")
	GameStateService.set_current_map_id(map_id)
	GameStateService.set_current_position(position)
	GameStateService.set_facing_direction(facing_dir)
	_load_overworld_scene()

## Finaliza la sesión actual (para volver al menú principal, por ejemplo)
func end_session() -> void:
	print("GameSession: Finalizando sesión de juego...")
	queue_free()
