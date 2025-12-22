extends EventCommand
class_name FollowActorCommand

## Comando para activar o desactivar el seguimiento de un actor a otro
##
## Permite que un actor (follower) siga automáticamente a otro (leader),
## reproduciendo los movimientos al mismo tiempo.

## Nombre del actor seguidor (o "Player" para el jugador)
## Si está vacío, usa el evento actual donde se ejecuta el comando
@export var follower_actor_name: String = ""

## Nombre del actor líder (o "Player" para el jugador)
@export var leader_actor_name: String = "Player"

## Acción a realizar: START o STOP
@export_enum("START", "STOP") var action: int = 0

## Distancia en tiles que debe mantener el follower (solo para START)
@export var distance_tiles: int = 1

## Si debe copiar la dirección del líder
@export var copy_facing: bool = true

## Si debe copiar el estado de correr del líder
@export var copy_run_state: bool = true

## Política de recuperación cuando queda bloqueado
## 0 = SNAP, 1 = WAIT, 2 = TELEPORT_IF_FAR
@export var catchup_policy: int = 0

func execute(context: Node) -> void:
	match action:
		0:  # START
			_start_following(context)
		1:  # STOP
			_stop_following(context)

## Inicia el seguimiento
func _start_following(context: Node) -> void:
	# Resolver actores
	var follower = _resolve_actor(context, follower_actor_name, true)
	var leader = _resolve_actor(context, leader_actor_name, false)

	if not follower:
		push_warning("FollowActorCommand: No se pudo resolver el follower")
		return

	if not leader:
		push_warning("FollowActorCommand: No se pudo resolver el leader")
		return

	# Verificar que el follower tiene GridMotion
	var follower_motion = follower.get_node_or_null("GridMotion")
	if not follower_motion:
		push_warning("FollowActorCommand: El follower '%s' no tiene GridMotion" % follower.name)
		return

	# Verificar que el leader tiene GridMotion
	var leader_motion = leader.get_node_or_null("GridMotion")
	if not leader_motion:
		push_warning("FollowActorCommand: El leader '%s' no tiene GridMotion" % leader.name)
		return

	# Si el follower es un NPC, desactivar su movimiento automático
	if follower is NPC:
		follower.movement_enabled = false
		# Pausar cualquier movimiento en curso
		if follower.has_method("_pause_movement"):
			follower._pause_movement()
		print("FollowActorCommand: Movimiento automático del NPC '%s' desactivado" % follower.name)

	# Obtener o crear FollowerComponent
	var follower_component = follower.get_node_or_null("FollowerComponent")
	if not follower_component:
		# Crear el componente
		follower_component = FollowerComponent.new()
		follower.add_child(follower_component)
		follower_component.name = "FollowerComponent"

		# Configurar el contexto si está disponible
		var overworld_context = _get_overworld_context(context)
		if overworld_context:
			follower_component.set_context(overworld_context)

	# Configurar parámetros
	var config = {
		"distance_tiles": distance_tiles,
		"copy_facing": copy_facing,
		"copy_run_state": copy_run_state,
		"catchup_policy": catchup_policy
	}

	# Iniciar seguimiento
	follower_component.start_follow(leader, config)

	print("FollowActorCommand: '%s' ahora sigue a '%s'" % [follower.name, leader.name])

## Detiene el seguimiento
func _stop_following(context: Node) -> void:
	# Resolver follower
	var follower = _resolve_actor(context, follower_actor_name, true)

	if not follower:
		push_warning("FollowActorCommand: No se pudo resolver el follower para detener")
		return

	# Obtener FollowerComponent
	var follower_component = follower.get_node_or_null("FollowerComponent")
	if not follower_component:
		push_warning("FollowActorCommand: El follower '%s' no tiene FollowerComponent" % follower.name)
		return

	# Detener seguimiento
	follower_component.stop_follow()

	# Si el follower es un NPC, reactivar su movimiento automático
	if follower is NPC:
		follower.movement_enabled = true
		# Reanudar movimiento si estaba pausado
		if follower.has_method("_resume_movement"):
			follower._resume_movement()
		print("FollowActorCommand: Movimiento automático del NPC '%s' reactivado" % follower.name)

	print("FollowActorCommand: '%s' dejó de seguir" % follower.name)

## Resuelve un actor por nombre
func _resolve_actor(context: Node, name: String, is_follower: bool) -> Node2D:
	# Si está vacío y es follower, usar el evento actual
	if name.is_empty() and is_follower:
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				return source_event as Node2D
		push_warning("FollowActorCommand: No se especificó follower y no se pudo obtener el evento actual")
		return null

	# Si es "Player", obtener del contexto
	if name == "Player" or name.to_lower() == "player":
		var overworld_context = _get_overworld_context(context)
		if overworld_context:
			return overworld_context.get_player()
		push_error("FollowActorCommand: OverworldContext no disponible para obtener Player")
		return null

	# Buscar por nombre en la escena
	var root = context.get_tree().root
	var actor = _find_node_by_name_recursive(root, name)

	return actor

## Búsqueda recursiva de nodo por nombre
func _find_node_by_name_recursive(node: Node, name: String) -> Node2D:
	if node.name == name and node is Node2D:
		return node as Node2D

	for child in node.get_children():
		var result = _find_node_by_name_recursive(child, name)
		if result:
			return result

	return null

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return false

