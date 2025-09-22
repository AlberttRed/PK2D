extends Node

## GameStart - Punto de entrada principal del juego
## Decide si cargar una partida existente o iniciar una nueva
## Luego carga la escena Overworld con la configuración correcta

# Referencias a escenas
const OVERWORLD_SCENE = preload("res://Scenes/Overworld/Overworld.tscn")

func _ready() -> void:
	print("GameStart: Iniciando sistema de carga de partida")
	
	# Esperar un frame para asegurar que todos los sistemas estén inicializados
	await get_tree().process_frame
	
	# Decidir si cargar partida existente o nueva partida
	if GameStateManager.load_saved_game():
		print("GameStart: Partida guardada encontrada, cargando...")
		_load_overworld_scene()
	else:
		print("GameStart: No hay partida guardada, iniciando nueva partida...")
		GameStateManager.initialize_new_game()
		_load_overworld_scene()

## Carga la escena Overworld y configura el player según el GameState
func _load_overworld_scene() -> void:
	print("GameStart: Cargando escena Overworld...")
	
	# Instanciar la escena Overworld
	var overworld_instance = OVERWORLD_SCENE.instantiate()
	if not overworld_instance:
		push_error("GameStart: No se pudo instanciar la escena Overworld")
		return
	
	# Reemplazar la escena actual
	get_tree().root.add_child(overworld_instance)
	get_tree().current_scene = overworld_instance
	
	# Configurar el player después de cargar la escena
	await get_tree().process_frame
	var map_system:MapSystem = overworld_instance.get_node("MapSystem")
	if map_system and map_system.has_method("configure_player_from_gamestate"):
		print("GameStart: Configurando player según GameState...")
		map_system.configure_player_from_gamestate()
		print("GameStart: Player configurado exitosamente")
	else:
		push_warning("GameStart: No se pudo configurar el player - MapSystem no encontrado o método no disponible")
	
	# Remover esta escena de la jerarquía
	queue_free()
	
	print("GameStart: Escena Overworld cargada exitosamente")

## Método público para forzar nueva partida (útil para testing)
func force_new_game() -> void:
	print("GameStart: Forzando nueva partida...")
	GameStateManager.initialize_new_game()
	_load_overworld_scene()

## Método público para simular carga de partida (útil para testing)
func simulate_load_game(map_id: String, position: Vector2i, facing_dir: Vector2) -> void:
	print("GameStart: Simulando carga de partida...")
	GameStateManager.set_current_map_id(map_id)
	GameStateManager.set_current_position(position)
	GameStateManager.set_facing_direction(facing_dir)
	_load_overworld_scene()
