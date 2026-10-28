extends EventCondition
class_name ActorPositionCondition

## Condición que evalúa la posición de otro actor respecto al evento actual
## Comprueba si un actor (Player o NPC) está en una dirección relativa al evento que evalúa la condición

## Nombre del actor a comprobar (Player o nombre de NPC/Event)
@export var actor_name: String = "Player"

## Dirección relativa a comprobar
## UP: el actor está arriba (Y menor)
## DOWN: el actor está abajo (Y mayor)
## LEFT: el actor está a la izquierda (X menor)
## RIGHT: el actor está a la derecha (X mayor)
@export_enum("Up", "Down", "Left", "Right") var direction: int = 0

## Evalúa si el actor está en la dirección especificada respecto al evento actual
func evaluate(context: EventConditionContext) -> bool:
	if not context.source_event:
		push_warning("ActorPositionCondition: No hay source_event en el contexto, retornando false")
		return false

	if actor_name.is_empty():
		push_warning("ActorPositionCondition: actor_name está vacío, retornando false")
		return false

	# Obtener el actor objetivo
	var target_actor = _find_actor(context, actor_name)
	if not target_actor:
		push_warning("ActorPositionCondition: No se encontró el actor '%s', retornando false" % actor_name)
		return false

	# Obtener posiciones
	# En 3D se compara sobre el plano del suelo (X, Z): "arriba" = Z menor.
	var source_pos := _plane_position(context.source_event)
	var target_pos := _plane_position(target_actor)

	# Comparar posiciones según la dirección
	match direction:
		0: # UP - el actor está arriba (Y menor en pantalla / Z menor en 3D)
			return target_pos.y < source_pos.y
		1: # DOWN - el actor está abajo (Y mayor en pantalla)
			return target_pos.y > source_pos.y
		2: # LEFT - el actor está a la izquierda (X menor)
			return target_pos.x < source_pos.x
		3: # RIGHT - el actor está a la derecha (X mayor)
			return target_pos.x > source_pos.x
		_:
			push_warning("ActorPositionCondition: Dirección inválida %d" % direction)
			return false

## Posición global sobre el plano del mapa: (x, y) en 2D; (x, z) en 3D.
func _plane_position(node: Node) -> Vector2:
	if node is Node3D:
		var p := (node as Node3D).global_position
		return Vector2(p.x, p.z)
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO


## Busca un actor (Player o NPC/Event) por nombre (Node2D en 2D, Node3D en 3D)
func _find_actor(context: EventConditionContext, name: String) -> Node:
	# Si es "Player", obtener del OverworldContext
	if name == "Player" or name.to_lower() == "player":
		var overworld_context = _get_overworld_context(context)
		if overworld_context:
			return overworld_context.get_player()
		push_warning("ActorPositionCondition: OverworldContext no disponible para obtener Player")
		return null

	# Para NPCs/Events, buscar en la escena por nombre
	if not context.source_event:
		return null

	var tree = context.source_event.get_tree()
	if not tree:
		return null

	# Buscar recursivamente por nombre
	return _find_node_by_name_recursive(tree.root, name)

## Obtiene el OverworldContext desde el Event
func _get_overworld_context(context: EventConditionContext) -> OverworldContext:
	if not context.source_event:
		return null

	return context.source_event.overworld_context

## Búsqueda recursiva de nodo por nombre
func _find_node_by_name_recursive(node: Node, node_name: String) -> Node:
	if node.name == node_name and (node is Node2D or node is Node3D):
		return node

	for child in node.get_children():
		var result = _find_node_by_name_recursive(child, node_name)
		if result:
			return result

	return null

