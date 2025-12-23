extends EventCommand
class_name PlayAnimationCommand

## Comando para reproducir animaciones en el ActorAnimator de un evento
## Útil para animaciones contextuales (abrir puerta, cofre, switch, etc.)
## Si target_name está vacío, será el propio evento donde se ejecuta el comando
@export var target_name: String = ""
@export var animation_name: String = ""
@export var wait_until_finished: bool = true

var _actor_animator: ActorAnimator = null
var _context: Node = null

func execute(context: Node) -> void:
	_context = context

	# Validar que se proporcionó un nombre de animación
	if animation_name.is_empty():
		push_warning("PlayAnimationCommand: No se especificó un nombre de animación")
		context.continue_execution()
		return

	# Resolver el target y buscar el ActorAnimator
	var target = _resolve_target(context, target_name)
	if not target:
		push_warning("PlayAnimationCommand: No se pudo resolver el target")
		context.continue_execution()
		return

	_actor_animator = _find_actor_animator_in_node(target)

	if not _actor_animator:
		push_warning("PlayAnimationCommand: El target '%s' no tiene un ActorAnimator. El comando se omite." % target.name)
		context.continue_execution()
		return

	# Verificar que el ActorAnimator tiene un sprite válido
	if not _actor_animator.sprite or not _actor_animator.sprite.sprite_frames:
		push_warning("PlayAnimationCommand: El ActorAnimator no tiene un sprite o SpriteFrames configurado")
		context.continue_execution()
		return

	# Verificar que la animación existe
	if not _actor_animator.sprite.sprite_frames.has_animation(animation_name):
		push_warning("PlayAnimationCommand: La animación '%s' no existe en el SpriteFrames del target '%s'" % [animation_name, target.name])
		context.continue_execution()
		return

	print("PlayAnimationCommand: Reproduciendo animación '%s' en '%s' (wait=%s)" % [animation_name, target.name, wait_until_finished])

	# Reproducir la animación
	_actor_animator.play(animation_name)

	# Si wait_until_finished está activado, esperar a que termine
	if wait_until_finished:
		# Conectar a la señal animation_finished del AnimatedSprite2D
		if not _actor_animator.sprite.animation_finished.is_connected(_on_animation_finished):
			_actor_animator.sprite.animation_finished.connect(_on_animation_finished)
	else:
		# Continuar inmediatamente sin esperar
		context.continue_execution()

## Callback cuando la animación termina
func _on_animation_finished() -> void:
	if _actor_animator and _actor_animator.sprite:
		# Desconectar la señal para evitar fugas de memoria
		if _actor_animator.sprite.animation_finished.is_connected(_on_animation_finished):
			_actor_animator.sprite.animation_finished.disconnect(_on_animation_finished)

	if _context:
		print("PlayAnimationCommand: Animación '%s' completada" % animation_name)
		_context.continue_execution()

## Resuelve el target donde buscar el ActorAnimator
func _resolve_target(context: Node, name: String) -> Node2D:
	# Si está vacío, usar el evento actual
	if name.is_empty():
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				return source_event as Node2D
		push_warning("PlayAnimationCommand: No se especificó target y no se pudo obtener el evento actual")
		return null

	# Si es "Player", obtener del contexto
	if name == "Player" or name.to_lower() == "player":
		var overworld_context = _get_overworld_context(context)
		if overworld_context:
			return overworld_context.get_player()
		push_error("PlayAnimationCommand: OverworldContext no disponible para obtener Player")
		return null

	# Buscar por nombre en la escena
	var root = context.get_tree().root
	var target = _find_node_by_name_recursive(root, name)
	if not target:
		push_warning("PlayAnimationCommand: No se encontró el target '%s'" % name)
	return target

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

## Busca recursivamente un ActorAnimator en un nodo y sus hijos
func _find_actor_animator_in_node(node: Node) -> ActorAnimator:
	if node is ActorAnimator:
		return node

	for child in node.get_children():
		if child is ActorAnimator:
			return child
		var found = _find_actor_animator_in_node(child)
		if found:
			return found

	return null

func is_async() -> bool:
	return wait_until_finished

func is_safe_for_parallel() -> bool:
	return false

