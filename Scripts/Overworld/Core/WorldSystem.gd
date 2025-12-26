extends Node2D
class_name WorldSystem

#region DOCUMENTACIÓN
## ================================================================================
## WORLDSYSTEM - DOCUMENTACIÓN COMPLETA
## ================================================================================
##
## DESCRIPCIÓN GENERAL:
## -------------------
## WorldSystem es el gestor global de mapas del juego. Centraliza la carga, descarga,
## cacheo y gestión de todos los MapChunks (escenas de mapa) del mundo.
## Gestiona el mapa activo, los mapas vecinos y el jugador.
##
## RESPONSABILIDADES PRINCIPALES:
## -----------------------------
## 1. Registro de mapas: Mantiene un índice de todos los mapas disponibles
## 2. Resolución de IDs: Convierte nombres de mapa (ej: "PuebloPaleta") a escenas
## 3. Caché inteligente: Mantiene mapas en memoria para transiciones rápidas
## 4. Carga dinámica: Carga/descarga mapas según la posición del jugador (chunks)
## 5. Sincronización: Mantiene GameStateService actualizado en puntos clave
## 6. Gestión de warps: Historial para restaurar estado al salir de interiores
##
## FLUJO DE INICIALIZACIÓN:
## -----------------------
## [Frame 0] Overworld.tscn se instancia
##   ├── WorldSystem._ready()
##   │   ├── _build_scene_index() → Indexa escenas de world_map_scenes
##   │   └── _register_maps() → Registra mapas y sus vecinos
##   │
##   └── EventSystem._ready()
##
## [Frame 1] GameStart llama a OverworldCoordinator.configure_from_gamestate()
##   ├── WorldSystem.change_to_map("MapaPuebloTest")
##   │   ├── get_map() → Carga/obtiene instancia del mapa
##   │   ├── change_to_map_instance() → Activa el mapa
##   │   ├── _preload_neighbors() → Precarga vecinos (Ruta1, Ruta21...)
##   │   ├── _unload_non_neighbors() → Descarga mapas no vecinos
##   │   └── Cola llamada diferida: force_sync_to_gamestate()
##   │
##   ├── WorldSystem.load_player() → Crea el nodo Player
##   └── OverworldGrid.position_player_at_tile() → Posiciona jugador
##
## [Frame 2] Se ejecutan las llamadas diferidas
##   └── force_sync_to_gamestate() → Sincroniza estado actual con GameStateService
##
## SISTEMA DE PRECARGA DE VECINOS (PBI 372):
## -------------------------------------------
## Carga/descarga automática de mapas vecinos para transiciones suaves.
##
## Funcionamiento:
##   - Al entrar a un mapa, precarga sus vecinos definidos en 'neighbors'
##   - Descarga mapas que ya no son vecinos del mapa actual
##   - Mantiene en caché hasta 'max_cached_maps' mapas
##
## Ejemplo:
##   Estás en PuebloPaleta (vecinos: ["Ruta1", "Ruta21"])
##   → Precarga: Ruta1, Ruta21
##
##   Cambias a Ruta1 (vecinos: ["PuebloPaleta", "CiudadVerde"])
##   → Mantiene: PuebloPaleta (ya cargado y es vecino)
##   → Precarga: CiudadVerde
##   → Descarga: Ruta21 (no es vecino de Ruta1)
##
## Ventajas:
##   ✓ Transiciones instantáneas a mapas vecinos (ya están cargados)
##   ✓ Memoria optimizada (solo mapas relevantes)
##   ✓ Configuración simple y flexible (lista de vecinos por mapa)
##
## SINCRONIZACIÓN CON GAMESTATE (PBI 373):
## ---------------------------------------
## ¿POR QUÉ ES NECESARIA?
##
## GameStateService es la FUENTE ÚNICA DE VERDAD del estado del jugador.
## Para guardado manual (estilo Pokémon), solo sincronizamos en momentos clave:
##
## Sincronización EFICIENTE (no en cada paso):
##   ✓ Al cambiar de mapa (transiciones importantes)
##   ✓ Al realizar un warp (puertas, cuevas)
##   ✓ Al abrir el menú de guardado (manual)
##   ✗ NO en cada paso del jugador (innecesario)
##
## Beneficios del sistema:
##   1. GUARDADO MANUAL 💾
##      Cuando el jugador abre el menú y guarda, GameStateService ya tiene
##      el mapa y posición actualizados. Solo falta leer la posición exacta
##      del jugador en ese momento.
##
##   2. CONSISTENCIA ENTRE ESCENAS 🔄
##      Al cambiar a batalla, menú, etc. el GameStateService mantiene el
##      contexto para restaurar el overworld correctamente.
##
##   3. EVENTOS Y SCRIPTS 📜
##      Los eventos pueden consultar el mapa actual sin buscar nodos:
##        if GameStateService.current_map_id == "PuebloPaleta":
##            activate_event()
##
## Métodos de sincronización:
##   - force_sync_to_gamestate() → Sincronización completa (cambios de mapa)
##   - sync_position_for_save() → Solo posición (al guardar manualmente)
##   - verify_gamestate_sync() → Verifica consistencia
##
## GESTIÓN DE WARPS (PBI 374):
## ---------------------------
## Sistema avanzado con historial para restaurar estado al salir de interiores.
##
## Ejemplo de flujo:
##   1. Jugador en PuebloPaleta (15, 23) mirando arriba
##   2. Entra a una casa → save_state_before_warp() guarda estado
##   3. Jugador explora la casa
##   4. Sale de la casa → restore_previous_overworld_state()
##      → Aparece en (15, 23) mirando arriba (donde entró)
##
## Ventajas:
##   ✓ No necesitas crear SpawnPoints de salida en cada interior
##   ✓ El jugador aparece exactamente donde entró
##   ✓ Historial de hasta 10 warps para navegación compleja
##
## Métodos principales:
##   - warp_with_state_management() → Warp inteligente con guardado de estado
##   - save_state_before_warp() → Guarda estado antes de cambiar
##   - restore_previous_overworld_state() → Restaura al salir de interior
##   - _is_overworld_map() → Detecta si un mapa es exterior o interior
##
## JERARQUÍA DE SISTEMAS:
## ---------------------
##   WorldSystem (Gestor global: mapas, jugador, vecinos)
##       ↓ contiene
##   OverworldGrid (Lógica de tiles del mapa activo)
##
## MÉTODOS PÚBLICOS IMPORTANTES:
## ----------------------------
## Gestión básica:
##   - change_to_map(map_id: String) → Cambia al mapa especificado
##   - get_map(map_id: String) → Obtiene/carga instancia de mapa
##   - has_map(map_id: String) → Verifica si existe el mapa
##
## Gestión de vecinos:
##   - set_map_neighbors(map_id, neighbors) → Define mapas vecinos
##   - get_map_info(map_id) → Obtiene información del mapa
##
## Warps avanzados:
##   - warp_with_state_management(map_id, spawn_id) → Warp con historial
##   - clear_warp_history() → Limpia historial
##
## Sincronización:
##   - force_sync_to_gamestate() → Sincronización completa (cambios de mapa)
##   - sync_position_for_save() → Solo posición (guardado manual)
##   - verify_gamestate_sync() → Verifica consistencia
##
## Debug:
##   - print_registry_status() → Estado de todos los mapas y sus vecinos
##   - print_warp_history() → Historial de warps
##
## NOTAS TÉCNICAS:
## --------------
## - Los mapas se mantienen en memoria vía cached_instance (referencias en GDScript)
## - El caché se limita a max_cached_maps (default: 5) para optimizar memoria
## - El sistema detecta interiores por keywords: "House", "Interior", "Cave", etc.
## - La sincronización con GameState NO ocurre en cada paso (optimización)
##   sino solo en cambios de mapa y warps
## - La precarga de vecinos se basa en la lista 'neighbors' configurada manualmente
##
## ================================================================================
#endregion

## Datos de un mapa
class MapData:
	var id: String                    # Identificador único (ej: "PuebloPaleta")
	var scene_path: String            # Ruta a la escena (resuelta dinámicamente)
	var neighbors: Array[String]      # IDs de mapas vecinos para precarga
	var world_position: Vector2 = Vector2.ZERO  # Posición mundial para seamless
	var cached_instance: Node = null  # Instancia cacheada (si aplica)
	var is_rendered: bool = false     # Indica si está visible en el árbol

	func _init(p_id: String, p_scene_path: String = "") -> void:
		id = p_id
		scene_path = p_scene_path

## Registro de todos los mapas del mundo
var map_registry: Dictionary = {} # {map_id: MapData}

## Índice de escenas para búsqueda rápida (nombre_archivo: PackedScene)
var scene_index: Dictionary = {}

## Lista de escenas de mapa para exportación
@export var world_map_scenes: Array[PackedScene] = []

## Referencia al OverworldContext (inyectada desde OverworldCoordinator)
var context: OverworldContext = null  # OverworldContext

## Mapa activo actual
var active_map: Node = null

## Referencia al jugador (instanciado como hijo de WorldSystem)
var player: Node = null

## Mapa anterior (para limpieza)
var previous_map: Node = null

## Configuración de caché y precarga de vecinos
@export var enable_map_caching: bool = true
@export var max_cached_maps: int = 5

## Configuración de chunks del mundo
## Tamaño de chunk en tiles (basado en tamaño de pantalla visible: ~14 tiles + 2 de margen = 16x16)
@export var chunk_size: Vector2i = Vector2i(16, 16)
## Distancia de activación (en chunks) desde la posición del jugador
@export var chunk_activation_radius: int = 1

## Referencia al WorldChunkController (hijo de WorldSystem)
var chunk_controller: Node = null  # WorldChunkController (usamos Node para evitar problemas de orden de carga)


func _ready() -> void:
	# Crear e inicializar WorldChunkController
	_setup_chunk_controller()

	# Indexar todas las escenas de mapa
	_build_scene_index()

	# Registrar mapas conocidos y sus vecinos
	_register_maps()

	# NOTA: El contexto se inyecta desde OverworldCoordinator después de _ready()
	# Se validará cuando se use en los métodos de lógica


## Configura el WorldChunkController como hijo de WorldSystem
func _setup_chunk_controller() -> void:
	# Crear instancia del WorldChunkController
	var controller_script = load("res://Scripts/Overworld/Core/WorldChunkController.gd")
	if not controller_script:
		push_error("WorldSystem: No se pudo cargar WorldChunkController.gd")
		return

	chunk_controller = Node.new()
	chunk_controller.set_script(controller_script)
	chunk_controller.name = "WorldChunkController"
	add_child(chunk_controller)

	# Inicializar con referencia a WorldSystem y configuración de chunks
	chunk_controller.initialize(self, chunk_size, chunk_activation_radius)


## Construye un índice de escenas para búsqueda rápida
func _build_scene_index() -> void:
	scene_index.clear()
	for scene: PackedScene in world_map_scenes:
		if scene == null:
			continue
		var path: String = scene.resource_path
		if path.is_empty():
			continue
		var file_name := path.get_file().get_basename()
		scene_index[file_name] = scene


## Registra todos los mapas del mundo y sus vecinos
## SISTEMA HÍBRIDO:
##   1. Intenta leer neighbors y world_position desde cada MapScene (inspector)
##   2. Si no están definidos, usa valores por defecto o configuración manual
func _register_maps() -> void:

	# Registrar todos los mapas del índice
	for scene_name in scene_index.keys():
		_register_map_from_scene(scene_name)

	# Configuración manual opcional (override)
	# Usa esto solo si necesitas forzar vecinos o posiciones que no están en el inspector
	# Ejemplo:
	# set_map_neighbors("MapaPuebloTest", ["Ruta1", "Ruta21"])
	# set_map_world_position("Ruta1", Vector2(0, -480))


## Registra un mapa leyendo su configuración desde la escena
func _register_map_from_scene(scene_name: String) -> void:
	if not scene_index.has(scene_name):
		push_warning("WorldSystem: Escena '%s' no encontrada en índice" % scene_name)
		return

	var packed_scene: PackedScene = scene_index[scene_name]

	# Intentar obtener el estado de la escena sin instanciarla completamente
	# (más eficiente para solo leer propiedades exportadas)
	var state := packed_scene.get_state()
	var world_pos := Vector2.ZERO
	var scene_neighbors: Array[String] = []

	# Buscar propiedades exportadas en el nodo raíz
	for i in range(state.get_node_property_count(0)):
		var prop_name = state.get_node_property_name(0, i)
		var prop_value = state.get_node_property_value(0, i)

		if prop_name == "world_position":
			world_pos = prop_value
		elif prop_name == "neighbors":
			scene_neighbors = prop_value

	# Registrar el mapa con la posición leída
	register_map_with_position(scene_name, world_pos)

	# Configurar vecinos si están definidos
	if not scene_neighbors.is_empty():
		set_map_neighbors(scene_name, scene_neighbors)


## Registra un nuevo mapa en el sistema (sin posición)
func register_map(map_id: String) -> bool:
	return register_map_with_position(map_id, Vector2.ZERO)


## Registra un nuevo mapa con posición mundial
## Puedes llamar esto manualmente para override la configuración del inspector
func register_map_with_position(map_id: String, world_pos: Vector2) -> bool:
	if map_registry.has(map_id):
		push_warning("WorldSystem: El mapa '%s' ya está registrado" % map_id)
		return false

	# Intentar resolver la escena desde el índice
	var scene_path := _resolve_scene_path(map_id)

	var map_data := MapData.new(map_id, scene_path)
	map_data.world_position = world_pos
	map_registry[map_id] = map_data

	return true


## Resuelve la ruta de escena para un ID de mapa
func _resolve_scene_path(map_id: String) -> String:
	# Buscar en el índice primero
	if scene_index.has(map_id):
		return scene_index[map_id].resource_path

	# Si no se encuentra, retornar vacío (se cargará bajo demanda)
	print("WorldSystem: No se encontró escena para mapa: %s" % map_id)
	return ""


## Configura los mapas vecinos de un mapa
## Puedes llamar esto manualmente para override la configuración del inspector
func set_map_neighbors(map_id: String, neighbor_ids: Array[String]) -> void:
	if not map_registry.has(map_id):
		push_warning("WorldSystem: Intento de configurar vecinos para mapa no registrado: %s" % map_id)
		return

	map_registry[map_id].neighbors = neighbor_ids


## Obtiene un mapa (cargándolo si es necesario)
func get_map(map_id: String) -> Node:
	if not map_registry.has(map_id):
		push_error("WorldSystem: Mapa no registrado: %s" % map_id)
		return null

	var map_data: MapData = map_registry[map_id]

	# Si ya está cacheado, devolverlo
	if map_data.cached_instance and is_instance_valid(map_data.cached_instance):
		return map_data.cached_instance

	# Cargar el mapa
	return _load_map(map_id)


## Carga un mapa desde su escena
func _load_map(map_id: String) -> Node:
	if not map_registry.has(map_id):
		return null

	var map_data: MapData = map_registry[map_id]

	# Obtener la escena
	var scene: PackedScene = scene_index.get(map_id)
	if not scene:
		push_error("WorldSystem: No se encontró escena para el mapa: %s" % map_id)
		return null

	# Instanciar
	var instance := scene.instantiate()
	if not instance:
		push_error("WorldSystem: No se pudo instanciar el mapa: %s" % map_id)
		return null

	instance.name = map_id

	# Cachear si está habilitado (solo guardar referencia en memoria)
	if enable_map_caching:
		map_data.cached_instance = instance
		# El mapa se añadirá al árbol cuando sea activado o renderizado como vecino
		_manage_cache()

	return instance


## Gestiona el límite de caché
func _manage_cache() -> void:
	if not enable_map_caching:
		return

	var cached_count := 0
	var oldest_maps: Array[MapData] = []

	for map_data: MapData in map_registry.values():
		if map_data.cached_instance and is_instance_valid(map_data.cached_instance):
			cached_count += 1
			oldest_maps.append(map_data)

	# Si excedemos el límite, liberar los más antiguos
	if cached_count > max_cached_maps:
		var to_free := cached_count - max_cached_maps
		print("WorldSystem: Gestionando caché - liberando %d mapas antiguos" % to_free)
		for i in range(to_free):
			if i < oldest_maps.size():
				_free_cached_map(oldest_maps[i])


## Libera un mapa cacheado
func _free_cached_map(map_data: MapData) -> void:
	if map_data.cached_instance and is_instance_valid(map_data.cached_instance):
		# Solo liberar si NO es el mapa activo
		if map_data.cached_instance != active_map:
			print("WorldSystem: Liberando mapa cacheado: %s" % map_data.id)
			map_data.cached_instance.queue_free()
			map_data.cached_instance = null


## Cambia al mapa especificado
func change_to_map(map_id: String) -> bool:
	var map_instance := get_map(map_id)
	if not map_instance:
		return false

	# Cambiar al mapa usando la instancia
	var success = change_to_map_instance(map_instance)

	if success:
		# Precarga de vecinos (para transiciones suaves)
		_preload_neighbors(map_id)

		# Descarga de mapas no vecinos (liberar memoria)
		_unload_non_neighbors(map_id)

		# Sincronización con GameState tras cambio de mapa
		call_deferred("force_sync_to_gamestate")

	return success


## Cambia al mapa usando una instancia ya proporcionada (por WorldSystem)
## NOTA: En sistema seamless, el mapa puede ya estar renderizado como vecino
func change_to_map_instance(map_instance: Node) -> bool:
	if not map_instance:
		push_error("WorldSystem: Instancia de mapa inválida")
		return false

	var map_id := map_instance.name

	# Si ya estamos en este mapa, no hacer nada
	if active_map == map_instance:
		print("WorldSystem: Ya estamos en el mapa: ", map_id)
		return true

	# Desactivar el mapa anterior (pero NO removerlo - sistema seamless)
	if active_map:
		_cleanup_previous_map()

		# En sistema seamless, los mapas pueden permanecer visibles
		# Solo desactivamos el procesamiento si tiene el método
		if active_map.has_method("deactivate"):
			active_map.deactivate()
		else:
			_disable_map_processing(active_map)

	# Añadir como child si no está ya en la jerarquía (primera carga)
	if not is_ancestor_of(map_instance):
		# CRÍTICO: Remover del padre actual si tiene uno (puede estar en cache_container)
		var current_parent = map_instance.get_parent()
		if current_parent:
			current_parent.remove_child(map_instance)
			print("  → Removido de: %s" % current_parent.name)

		add_child(map_instance)

	# Configurar visibilidad y procesamiento
	_set_subtree_visibility(map_instance, true)

	# Activar el procesamiento si tiene el método
	if map_instance.has_method("activate"):
		map_instance.activate()
	else:
		_enable_map_processing(map_instance)

	# Configurar el mapa activo (esto establece active_map y ejecuta toda la configuración)
	set_active_map(map_instance)

	# Registrar el mapa en chunks globales (si no estaba ya registrado)
	if chunk_controller:
		chunk_controller.register_map_to_global_chunks(map_id)

	return true


## Precarga y RENDERIZA mapas vecinos (para mundo seamless)
## Los mapas se cargan por sistema de vecinos (como siempre)
## Los chunks solo se usan para activar/desactivar eventos/tiles, no para cargar mapas
func _preload_neighbors(map_id: String) -> void:
	if not enable_map_caching or not map_registry.has(map_id):
		return

	var map_data: MapData = map_registry[map_id]

	if map_data.neighbors.is_empty():
		return

	# Cargar vecinos del mapa actual (sistema original - siempre ha funcionado así)
	for neighbor_id in map_data.neighbors:
		if map_registry.has(neighbor_id):
			_load_neighbor_map(neighbor_id)

	# Actualizar chunks activos después de cargar vecinos
	# (los chunks se usan solo para activar/desactivar eventos/tiles, no para cargar mapas)
	if chunk_controller:
		var player_position = Vector2.ZERO
		if player:
			player_position = player.global_position
		elif active_map:
			if active_map is Node2D:
				player_position = (active_map as Node2D).global_position

		chunk_controller.initialize_active_chunks(player_position)


## Carga y renderiza un mapa vecino (método auxiliar)
## También registra el mapa en chunks globales cuando se carga
func _load_neighbor_map(neighbor_id: String) -> void:
	if not map_registry.has(neighbor_id):
		return

	var neighbor_data: MapData = map_registry[neighbor_id]

	# Obtener o cargar la instancia
	var neighbor_instance = get_map(neighbor_id)

	if neighbor_instance and not neighbor_data.is_rendered:
		# CRÍTICO: Añadir al WorldSystem para que sea visible (no al cache)
		if not is_ancestor_of(neighbor_instance):
			# Remover del padre actual si tiene uno
			var current_parent = neighbor_instance.get_parent()
			if current_parent:
				current_parent.remove_child(neighbor_instance)

			# Añadir al WorldSystem
			add_child(neighbor_instance)

		# Posicionar según coordenadas mundiales
		if neighbor_instance is Node2D:
			neighbor_instance.global_position = neighbor_data.world_position

		# Hacer visible
		neighbor_instance.visible = true

		# Desactivar procesamiento (solo el activo procesa)
		if neighbor_instance.has_method("deactivate"):
			neighbor_instance.deactivate()
		else:
			_disable_map_processing(neighbor_instance)

		neighbor_data.is_rendered = true

		# Registrar el mapa en chunks globales (cuando se carga por primera vez)
		if chunk_controller:
			chunk_controller.register_map_to_global_chunks(neighbor_id)


## Descarga mapas que ya no son vecinos del mapa actual (libera memoria)
## Los mapas se descargan por sistema de vecinos (como siempre)
## Los chunks solo se usan para activar/desactivar eventos/tiles, no para descargar mapas
func _unload_non_neighbors(current_map_id: String) -> void:
	if not enable_map_caching or not map_registry.has(current_map_id):
		return

	var current_data: MapData = map_registry[current_map_id]
	var current_neighbors = current_data.neighbors

	# Lista de mapas a mantener: mapa actual + sus vecinos (sistema original)
	var maps_to_keep = [current_map_id] + current_neighbors

	# Recorrer todos los mapas
	for map_id in map_registry.keys():
		var map_data: MapData = map_registry[map_id]

		# Si está renderizado y NO está en la lista de mantener
		if map_data.is_rendered and not map_id in maps_to_keep:
			_unrender_map(map_data)

		# Liberar del caché si excedemos límite y no es necesario
		if map_data.cached_instance and is_instance_valid(map_data.cached_instance):
			if not map_id in maps_to_keep and not map_data.is_rendered:
				_free_cached_map(map_data)

	# Actualizar chunks activos después de descargar mapas
	# (los chunks se usan solo para activar/desactivar eventos/tiles)
	if chunk_controller:
		var player_position = Vector2.ZERO
		if player:
			player_position = player.global_position
		elif active_map:
			if active_map is Node2D:
				player_position = (active_map as Node2D).global_position

		chunk_controller.initialize_active_chunks(player_position)


## Des-renderiza un mapa (lo oculta pero mantiene en caché)
func _unrender_map(map_data: MapData) -> void:
	if not map_data.cached_instance or not is_instance_valid(map_data.cached_instance):
		return

	var map_instance = map_data.cached_instance

	# Remover del WorldSystem si está ahí
	if is_ancestor_of(map_instance):
		remove_child(map_instance)

	# El nodo queda sin padre pero en memoria vía cached_instance (referencia en GDScript)
	# Esto es más limpio que moverlo entre contenedores

	# Marcar como no renderizado
	map_data.is_rendered = false

	print("  ✓ Mapa des-renderizado: %s" % map_data.id)


## Deshabilita el procesamiento de un mapa (optimización para vecinos visibles)
## NOTA: El grid y los eventos NO se desactivan aquí - el sistema de chunks controla su activación
## Solo se desactivan si no hay eventos activos en ese mapa (verificado por WorldChunkController)
func _disable_map_processing(_map_node: Node) -> void:
	# NO desactivar grid ni eventos aquí - el sistema de chunks (WorldChunkController)
	# controla qué eventos/grids están activos basándose en chunks activos, no en el mapa activo
	# Los eventos/grids se activan/desactivan según si están en chunks activos
	# Si desactivamos aquí, rompemos el sistema de chunks
	pass


## Habilita el procesamiento de un mapa (cuando se vuelve activo)
## NOTA: El grid y los eventos NO se activan aquí - el sistema de chunks controla su activación
func _enable_map_processing(_map_node: Node) -> void:
	# NO activar grid ni eventos aquí - el sistema de chunks (WorldChunkController)
	# controla qué eventos/grids están activos basándose en chunks activos, no en el mapa activo
	# Los eventos/grids se activan/desactivan según si están en chunks activos
	pass


## ========================================================================================
## SISTEMA DE DETECCIÓN SEAMLESS (Cambio Automático de Mapa)
## ========================================================================================

## Maneja el cruce seamless de mapas (escucha señal de GridMotion)
## SISTEMA UNIFICADO: Gestiona active_map, neighbors y GameState
func _on_seamless_map_crossed(_from_map_id: String, to_map_id: String) -> void:
	# Buscar el nuevo mapa por ID
	var new_map: Node = null
	for child in get_children():
		if child.name == to_map_id and not child.is_in_group("Player"):
			new_map = child
			break

	if not new_map:
		push_warning("WorldSystem: No se encontró el mapa destino: %s" % to_map_id)
		return

	# Cambiar el active_map
	var old_map = active_map
	if old_map != new_map:
		# Desactivar el mapa anterior
		if old_map:
			if old_map.has_method("deactivate"):
				old_map.deactivate()
			else:
				_disable_map_processing(old_map)

		# Activar el nuevo mapa
		if new_map.has_method("activate"):
			new_map.activate()
		else:
			_enable_map_processing(new_map)

		# Establecer mapa activo
		set_active_map(new_map)

		# Emitir cambio de grid activo (CRÍTICO para Occupancy y otros sistemas)
		var new_grid = get_active_grid()
		if new_grid and context:
			context.emit_active_grid_changed(new_grid)

	# Actualizar neighbors: precargar vecinos del nuevo mapa
	_preload_neighbors(to_map_id)

	# Descargar mapas que ya no son necesarios
	_unload_non_neighbors(to_map_id)

	# Inicializar chunks activos según nueva posición del jugador (después de cambiar de mapa)
	if chunk_controller and player:
		chunk_controller.initialize_active_chunks(player.global_position)

	# Actualizar GameState con el nuevo mapa
	force_sync_to_gamestate()


## ========================================================================================
## FIN SISTEMA DE DETECCIÓN SEAMLESS
## ========================================================================================


## Obtiene información de un mapa sin cargarlo
func get_map_info(map_id: String) -> MapData:
	return map_registry.get(map_id)


## Lista todos los mapas registrados
func get_registered_maps() -> Array[String]:
	return map_registry.keys()


## Verifica si un mapa está registrado
func has_map(map_id: String) -> bool:
	return map_registry.has(map_id)


## Libera todos los mapas cacheados (útil para limpieza)
func clear_cache() -> void:
	print("WorldSystem: Limpiando caché de mapas")
	for map_data: MapData in map_registry.values():
		if map_data.cached_instance and is_instance_valid(map_data.cached_instance):
			# No liberar el mapa activo
			if map_data.cached_instance != active_map:
				map_data.cached_instance.queue_free()
				map_data.cached_instance = null


## Método de utilidad para debugging
func print_registry_status() -> void:
	print("=== WorldSystem Registry Status ===")
	print("Total mapas registrados: %d" % map_registry.size())
	print("Mapas cacheados: %d" % _count_cached_maps())
	var active_map_name = "ninguno"
	if active_map:
		active_map_name = active_map.name
	print("Mapa activo: %s" % active_map_name)
	for map_id in map_registry.keys():
		var map_data: MapData = map_registry[map_id]
		var status = "cacheado" if map_data.cached_instance else "no cargado"
		var neighbors_str = str(map_data.neighbors) if not map_data.neighbors.is_empty() else "ninguno"
		print("  - %s: %s (vecinos: %s)" % [map_id, status, neighbors_str])


func _count_cached_maps() -> int:
	var count := 0
	for map_data: MapData in map_registry.values():
		if map_data.cached_instance and is_instance_valid(map_data.cached_instance):
			count += 1
	return count


## ========================================================================================
## INTEGRACIÓN CON GAMESTATE (PBI 373)
## ========================================================================================

## Sincroniza solo la posición actual del jugador (para guardado manual)
## Este método se llama cuando el jugador abre el menú y guarda la partida
func sync_position_for_save() -> void:
	if not GameStateService:
		return

	# Obtener referencia al jugador si no la tenemos
	var player_grid_motion = _get_player_grid_motion()
	if not player_grid_motion:
		push_warning("WorldSystem: No se pudo obtener GridMotion del jugador para sincronizar")
		return

	# Obtener posición y dirección actual del jugador
	var current_tile = player_grid_motion.current_tile()
	var current_direction = player_grid_motion.dir

	# Actualizar solo posición y dirección (el mapa ya está sincronizado)
	GameStateService.set_current_position(current_tile)
	GameStateService.set_facing_direction(current_direction)

	print("WorldSystem: Posición sincronizada para guardado - Tile: %s, Dir: %s" % [current_tile, current_direction])


## Verifica que la sincronización con GameState esté funcionando correctamente
func verify_gamestate_sync() -> bool:
	if not GameStateService:
		return false

	var game_map_id = GameStateService.get_current_map_id()
	var actual_map_id = active_map.name if active_map else ""

	if game_map_id != actual_map_id:
		push_warning("WorldSystem: Desincronización detectada - GameState: %s, Actual: %s" % [game_map_id, actual_map_id])
		return false

	return true


## Fuerza la sincronización completa con GameState (usado en cambios de mapa)
func force_sync_to_gamestate() -> void:
	if not GameStateService:
		return

	# Sincronizar mapa (lo más importante en cambios de mapa)
	if active_map:
		GameStateService.set_current_map_id(active_map.name)

	# Sincronizar posición del jugador si está disponible
	var player_grid_motion = _get_player_grid_motion()
	if player_grid_motion:
		var current_tile = player_grid_motion.current_tile()
		GameStateService.set_current_position(current_tile)

		# Sincronizar dirección
		if "dir" in player_grid_motion:
			GameStateService.set_facing_direction(player_grid_motion.dir)


## Obtiene la referencia al componente GridMotion del jugador
func _get_player_grid_motion() -> Node:
	if not player:
		push_error("WorldSystem: Player no disponible en _get_player_grid_motion")
		return null

	return player.get_node("GridMotion")


## ========================================================================================
## INTEGRACIÓN AVANZADA CON WARPSYSTEM (PBI 374)
## ========================================================================================

## Historial de mapas para restauración de estado
var warp_history: Array[Dictionary] = []
@export var max_warp_history: int = 10

## Guarda el estado actual antes de un warp (para restauración posterior)
func save_state_before_warp(from_map_id: String, to_map_id: String, player_tile: Vector2i, player_direction: Vector2) -> void:
	var state = {
		"map_id": from_map_id,
		"tile": player_tile,
		"direction": player_direction,
		"timestamp": Time.get_ticks_msec(),
		"warp_to": to_map_id
	}

	warp_history.push_front(state)

	# Limitar el historial
	if warp_history.size() > max_warp_history:
		warp_history = warp_history.slice(0, max_warp_history)

	print("WorldSystem: Estado guardado antes del warp - %s -> %s" % [from_map_id, to_map_id])


## Obtiene el último estado guardado para un mapa específico
func get_previous_state_for_map(map_id: String) -> Dictionary:
	for state in warp_history:
		if state.get("map_id", "") == map_id:
			return state
	return {}


## Restaura el estado previo al salir de un interior
func restore_previous_overworld_state() -> bool:
	# Buscar el último estado de overworld (no interior)
	for state in warp_history:
		var map_id = state.get("map_id", "")
		if _is_overworld_map(map_id):
			print("WorldSystem: Restaurando estado previo del overworld: %s" % map_id)

		# Cambiar al mapa del overworld
		var success = change_to_map(map_id)
		if not success:
			return false

		# NOTA: El movimiento ya fue detenido por WarpSystem._execute_warp()
		# Solo esperamos a que el grid se actualice

		# Esperar UN solo frame para que el grid se actualice
		await get_tree().process_frame

		# Posicionar al jugador en la posición guardada
		var grid = get_active_grid()
		if grid:
			var tile = state.get("tile", Vector2i.ZERO)
			var direction = state.get("direction", Vector2.DOWN)

			if player:
				grid.position_player_at_tile(tile, player)
				grid.set_player_facing_direction(direction, player)

			print("WorldSystem: Jugador restaurado en tile %s mirando %s" % [tile, direction])

		return true

	push_warning("WorldSystem: No se encontró estado previo del overworld para restaurar")
	return false


## Determina si un mapa es del overworld (exterior) o interior
func _is_overworld_map(map_id: String) -> bool:
	# Lógica simple: mapas que contengan "House", "Interior", "Cave", etc. son interiores
	var interior_keywords = ["House", "Interior", "Cave", "Building", "Shop"]

	for keyword in interior_keywords:
		if map_id.contains(keyword):
			return false

	return true


## Método público para warps con restauración automática de estado
func warp_with_state_management(to_map_id: String, spawn_id: String) -> bool:
	var player_grid_motion = _get_player_grid_motion()
	if not player_grid_motion:
		push_error("WorldSystem: No se pudo obtener GridMotion del jugador")
		return false

	# Guardar estado actual si vamos a un interior
	var current_map_id = active_map.name if active_map else ""
	var is_going_to_interior = not _is_overworld_map(to_map_id)
	var is_leaving_interior = not _is_overworld_map(current_map_id) and _is_overworld_map(to_map_id)

	if is_going_to_interior:
		var current_tile = player_grid_motion.current_tile()
		var current_direction = player_grid_motion.dir
		print("WorldSystem: Guardando estado antes de entrar a interior - Tile: %s, Dir: %s" % [current_tile, current_direction])
		save_state_before_warp(current_map_id, to_map_id, current_tile, current_direction)

	# Realizar el warp normal
	var success = change_to_map(to_map_id)
	if not success:
		return false

	# NOTA: El movimiento ya fue detenido por WarpSystem._execute_warp()
	# No es necesario volver a detenerlo aquí

	# Si salimos de un interior, intentar restaurar posición previa
	if is_leaving_interior:
		print("WorldSystem: Saliendo de interior, restaurando estado previo...")
		print_warp_history()  # Debug
		# En lugar de usar spawn_id, restaurar la posición guardada
		return await restore_previous_overworld_state()
	else:
		# Warp normal usando spawn_id
		await get_tree().process_frame
		var grid = get_active_grid()
		if grid and player:
			return grid.position_player_at_spawn(spawn_id, player)

	return true


## Limpia el historial de warps (útil al cambiar de área o resetear)
func clear_warp_history() -> void:
	warp_history.clear()
	print("WorldSystem: Historial de warps limpiado")


## Debug del historial de warps
func print_warp_history() -> void:
	print("=== WorldSystem Warp History ===")
	print("Entradas en historial: %d" % warp_history.size())
	for i in range(warp_history.size()):
		var state = warp_history[i]
		print("  %d: %s -> %s (tile: %s, dir: %s)" % [
			i,
			state.get("map_id", "?"),
			state.get("warp_to", "?"),
			state.get("tile", "?"),
			state.get("direction", "?")
		])


## ========================================================================================
## MÉTODOS DE MAPSYSTEM (MIGRADOS)
## ========================================================================================

## Obtiene el mapa activo actual
func get_active_map() -> Node:
	return active_map

## Obtiene el OverworldGrid del mapa activo
func get_active_grid() -> OverworldGrid:
	if not active_map:
		push_warning("WorldSystem: No hay mapa activo")
		return null

	var grid = active_map.get_node("OverworldGrid")
	if not grid or not grid is OverworldGrid:
		push_warning("WorldSystem: El mapa activo no tiene un OverworldGrid válido")
		return null

	return grid

## Obtiene el jugador
func get_player() -> Node:
	return player

## Carga el jugador dinámicamente
func load_player() -> bool:
	# Cargar la escena del jugador
	var player_scene = preload("res://Scenes/Overworld/Actors/Player.tscn")
	if not player_scene:
		push_error("WorldSystem: No se pudo cargar la escena del jugador")
		return false

	# Instanciar el jugador
	var player_instance = player_scene.instantiate()
	if not player_instance:
		push_error("WorldSystem: No se pudo instanciar el jugador")
		return false

	# Añadir el jugador como hijo del WorldSystem
	add_child(player_instance)
	player = player_instance

	# Registrar el jugador en el contexto si está disponible
	if context:
		context.register_system("Player", player_instance)

	# Inyectar el contexto al jugador si tiene el método
	if player_instance.has_method("set_context"):
		player_instance.set_context(context)

	return true

## Asigna un mapa como activo
func set_active_map(map_scene: Node) -> void:
	if not map_scene:
		push_error("WorldSystem: No se puede asignar un mapa nulo")
		return

	# Si ya hay un mapa activo, lo removemos
	if active_map and active_map != map_scene:
		# Desconectar el jugador del mapa anterior si es necesario
		_cleanup_previous_map()

	active_map = map_scene

	# Asegurar que el mapa esté en la escena
	if not is_instance_valid(active_map) or not is_ancestor_of(active_map):
		push_error("WorldSystem: El mapa debe ser un nodo hijo de WorldSystem")
		return

	# CRÍTICO: Actualizar el map_id en GameStateService INMEDIATAMENTE
	# antes de que los eventos se inicialicen (en _ready())
	# Esto asegura que los eventos calculen el event_id correcto desde el inicio
	if GameStateService and active_map:
		GameStateService.set_current_map_id(active_map.name)

	# Obtener el grid una sola vez
	var grid = get_active_grid()

	# Inyectar contexto al grid del mapa
	if context and grid:
		if grid.has_method("set_context"):
			grid.set_context(context)

	# Configurar el jugador para el nuevo mapa
	_setup_player_for_map()

	# Aplicar configuración de overlay asociada al mapa
	_apply_overlay_settings(map_scene)

	# Emitir cambio de grid activo
	if context and grid:
		context.emit_active_grid_changed(grid)

## Limpia la configuración del mapa anterior
func _cleanup_previous_map() -> void:
	if not active_map:
		return

	# Aquí se pueden añadir limpiezas específicas si es necesario
	# Por ejemplo, desconectar señales, limpiar referencias, etc.
	pass

## Configura el jugador para el mapa activo
func _setup_player_for_map() -> void:
	if not player or not active_map:
		return

	# Asegurar que el jugador esté en la jerarquía correcta
	if not is_ancestor_of(player):
		# Si el jugador no está bajo WorldSystem, moverlo
		var parent = player.get_parent()
		if parent:
			parent.remove_child(player)
		add_child(player)

	# Configurar la cámara del jugador para el nuevo mapa
	var camera = player.get_node("Camera2D")
	if camera and camera.has_method("set_map_layer_path"):
		var grid = get_active_grid()
		if grid:
			var terrain_layer = grid.get_node("Terrain")
			if terrain_layer:
				camera.map_layer_path = terrain_layer.get_path()

## Configura la visibilidad del nodo raíz (NO recursivo)
## Los nodos hijos gestionan su propia visibilidad (respeta SpawnPoints, etc.)
func _set_subtree_visibility(node: Node, vis: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = vis
	# NO hacer recursivo - respeta la visibilidad configurada de los hijos
	# Ejemplo: SpawnPoints con sprite oculto, eventos con sprites personalizados, etc.

## Configura la capa de overlays según los metadatos del mapa activo
func _apply_overlay_settings(map_scene: Node) -> void:
	if not context:
		return

	var overlay := context.get_overlay_layer()
	if not overlay:
		return

	if not map_scene or not map_scene.has_method("get_overlay_settings"):
		overlay.reset_to_defaults()
		return

	var settings: Dictionary = map_scene.get_overlay_settings()

	var darkness: float = float(settings.get("darkness", 0.0))
	var weather: String = str(settings.get("weather", "none"))
	var flashlight_required: bool = bool(settings.get("flashlight_required", false))
	overlay.set_weather(weather)

	var flash_on := GameStateService.get_event_flag("flash_on")
	if flash_on:
		overlay.set_darkness(0.0, 0.0)
		overlay.set_flashlight_enabled(false)
	else:
		overlay.set_darkness(darkness, 0.0)
		overlay.set_flashlight_enabled(flashlight_required)

## Reaplica la configuración de overlay para el mapa activo
func refresh_overlay_settings() -> void:
	_apply_overlay_settings(active_map)

## Encuentra el grid que contiene una posición global y retorna grid + tile convertido
## Optimizado: convierte una sola vez, evitando cálculos duplicados
## Retorna: {"grid": OverworldGrid, "tile": Vector2i}
func find_grid_and_tile_at_world_position(world_pos: Vector2) -> Dictionary:
	# Iterar por todos los hijos de WorldSystem (mapas renderizados)
	for child in get_children():
		if child.is_in_group("Player"):
			continue

		var grid = child.get_grid() if child.has_method("get_grid") else null
		if not grid:
			continue

		# Convertir posición global a tile local de este grid
		var tile_local = grid.world_to_tile(world_pos)

		# Verificar si el grid tiene tile data en esa posición
		var tile_data = grid.get_tile_data(tile_local)
		if not tile_data.is_empty():
			return {"grid": grid, "tile": tile_local}  # Encontrado!

	return {"grid": null, "tile": Vector2i.ZERO}

## Verifica movimiento usando posiciones globales y retorna resultado + grid destino
## Optimizado: usa find_grid_and_tile_at_world_position para evitar conversiones duplicadas
## Retorna: {"can_move": bool, "target_grid": OverworldGrid, "from_tile": Vector2i, "to_tile": Vector2i}
func check_world_movement(actor: Node, from_world_pos: Vector2, to_world_pos: Vector2) -> Dictionary:
	# Encontrar el grid que contiene la posición destino (con tile ya convertido)
	var to_result = find_grid_and_tile_at_world_position(to_world_pos)
	var target_grid: OverworldGrid = to_result["grid"]
	var to_tile: Vector2i = to_result["tile"]

	if not target_grid:
		return {"can_move": false, "target_grid": null, "from_tile": Vector2i.ZERO, "to_tile": Vector2i.ZERO}

	# Convertir posición origen al sistema del grid destino
	var from_tile = target_grid.world_to_tile(from_world_pos)

	# Verificar si puede moverse usando la lógica del grid correspondiente
	var can_move = target_grid.can_step_to(actor, from_tile, to_tile)

	return {
		"can_move": can_move,
		"target_grid": target_grid,
		"from_tile": from_tile,
		"to_tile": to_tile
	}


func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if context and not context.seamless_map_crossed.is_connected(_on_seamless_map_crossed):
		context.seamless_map_crossed.connect(_on_seamless_map_crossed)

	# Pasar el contexto al WorldChunkController
	if chunk_controller and chunk_controller.has_method("set_context"):
		chunk_controller.set_context(overworld_context)


## Obtiene el WorldChunkController (para acceso externo)
func get_chunk_controller() -> WorldChunkController:
	return chunk_controller as WorldChunkController


## Obtiene el ID del mapa activo
func get_active_map_id() -> String:
	if not active_map:
		return ""
	return active_map.name
