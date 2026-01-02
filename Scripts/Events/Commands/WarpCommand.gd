extends EventCommand
class_name WarpCommand

## Comando para teletransportar a un actor a una posición de tile específica
## Si actor_name está vacío, será el propio evento donde se ejecuta el comando
## Si target_scene está vacío, el warp es dentro de la misma escena
@export var actor_name: String = "Player"
@export var target_scene: String = ""
## Coordenadas de tile destino
@export var target_tile: Vector2i = Vector2i.ZERO

enum FacingDirection {
	ARRIBA,
	ABAJO,
	IZQUIERDA,
	DERECHA
}

@export var facing_direction: FacingDirection = FacingDirection.ABAJO

func execute(_context: Node) -> void:
	# Resolver el actor a teletransportar
	var actor = _resolve_actor(_context, actor_name)
	if not actor:
		push_error("WarpCommand: No se pudo resolver el actor")
		_context.continue_execution()
		return

	var overworld_context = _get_overworld_context(_context)
	if not overworld_context:
		push_error("WarpCommand: OverworldContext no disponible")
		_context.continue_execution()
		return

	var world_system = overworld_context.get_world_system()
	if not world_system:
		push_error("WarpCommand: WorldSystem no disponible")
		_context.continue_execution()
		return

	# Determinar el mapa destino
	var target_map_id: String
	var is_same_map: bool = false

	if target_scene.is_empty():
		# Warp dentro de la misma escena
		target_map_id = world_system.get_active_map_id()
		is_same_map = true
		if target_map_id.is_empty():
			push_error("WarpCommand: No se pudo obtener el mapa actual")
			_context.continue_execution()
			return
	else:
		target_map_id = target_scene

	# Validar que solo el player puede hacer warp a otro mapa
	var is_player = actor.is_in_group("Player")
	if not is_same_map and not is_player:
		push_warning("WarpCommand: Solo el Player puede hacer warp a otro mapa. El actor '%s' solo puede hacer warp dentro del mismo mapa." % actor.name)
		_context.continue_execution()
		return

	# Si es el player, usar el sistema de warp
	if is_player:
		print("Warp: Solicitando teletransporte del Player a escena '%s' en tile %s" % [target_map_id, target_tile])
		await overworld_context.request_warp(target_map_id, target_tile)
		# Aplicar la dirección con el nuevo mapa ya activo
		_apply_facing_direction(actor)
	else:
		# Para otros actores, solo warp dentro del mismo mapa
		print("Warp: Teletransportando '%s' dentro del mismo mapa a tile %s" % [actor.name, target_tile])
		_warp_actor_same_map(actor, target_tile, overworld_context)
		# Aplicar la dirección
		_apply_facing_direction(actor)

	# Continuar ejecución del EventController al terminar este comando asíncrono
	_context.continue_execution()

## Aplica la dirección configurada en el inspector
func _apply_facing_direction(actor: Node) -> void:
	var direction = get_facing_vector()
	print("WarpCommand: Aplicando dirección: ", direction)

	if not actor:
		push_error("WarpCommand: Actor no disponible para aplicar dirección")
		return

	# Aplicar la dirección al actor
	if actor.has_method("set_facing_direction"):
		actor.set_facing_direction(direction)

	# Si es el player, actualizar también el GameStateService
	if actor.is_in_group("Player"):
		GameStateService.set_facing_direction(direction)

	print("WarpCommand: Dirección aplicada correctamente a '%s'" % actor.name)

## Resuelve el actor a teletransportar
func _resolve_actor(context: Node, actor_name_to_resolve: String) -> Node2D:
	# Si está vacío, usar el evento actual
	if actor_name_to_resolve.is_empty():
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				return source_event as Node2D
		push_warning("WarpCommand: No se especificó actor y no se pudo obtener el evento actual")
		return null

	# Si es "Player", obtener del contexto
	if actor_name_to_resolve == "Player" or actor_name_to_resolve.to_lower() == "player":
		var overworld_context = _get_overworld_context(context)
		if overworld_context:
			return overworld_context.get_player()
		push_error("WarpCommand: OverworldContext no disponible para obtener Player")
		return null

	# Buscar por nombre en la escena
	var root = context.get_tree().root
	var actor = _find_node_by_name_recursive(root, actor_name_to_resolve)
	if not actor:
		push_warning("WarpCommand: No se encontró el actor '%s'" % actor_name_to_resolve)
	return actor

## Búsqueda recursiva de nodo por nombre
func _find_node_by_name_recursive(node: Node, node_name: String) -> Node2D:
	if node.name == node_name and node is Node2D:
		return node as Node2D

	for child in node.get_children():
		var result = _find_node_by_name_recursive(child, node_name)
		if result:
			return result

	return null

## Realiza el warp de un actor dentro del mismo mapa a una coordenada de tile
func _warp_actor_same_map(actor: Node, tile_pos: Vector2i, overworld_context: OverworldContext) -> void:
	var world_system = overworld_context.get_world_system()
	if not world_system:
		push_error("WarpCommand: WorldSystem no disponible")
		return

	var grid = world_system.get_active_grid()
	if not grid:
		push_error("WarpCommand: No se pudo obtener el OverworldGrid del mapa activo")
		return

	# Teletransportar el actor a la coordenada de tile
	if actor.has_method("teleport_to_tile"):
		actor.teleport_to_tile(tile_pos)
	else:
		# Fallback: teletransporte directo
		actor.global_position = grid.tile_to_world_center(tile_pos)


## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

## Convierte el enum a Vector2
func get_facing_vector() -> Vector2:
	match facing_direction:
		FacingDirection.ARRIBA:
			return Vector2.UP
		FacingDirection.ABAJO:
			return Vector2.DOWN
		FacingDirection.IZQUIERDA:
			return Vector2.LEFT
		FacingDirection.DERECHA:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
