extends EventCommand
class_name PlayAnimationCommand

## Comando para reproducir animaciones en el ActorAnimator de un evento
## Útil para animaciones contextuales (abrir puerta, cofre, switch, etc.)
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
	
	# Buscar el ActorAnimator en el evento actual
	_actor_animator = _find_actor_animator(context)
	
	if not _actor_animator:
		push_warning("PlayAnimationCommand: El evento no tiene un ActorAnimator. El comando se omite.")
		context.continue_execution()
		return
	
	# Verificar que el ActorAnimator tiene un sprite válido
	if not _actor_animator.sprite or not _actor_animator.sprite.sprite_frames:
		push_warning("PlayAnimationCommand: El ActorAnimator no tiene un sprite o SpriteFrames configurado")
		context.continue_execution()
		return
	
	# Verificar que la animación existe
	if not _actor_animator.sprite.sprite_frames.has_animation(animation_name):
		push_warning("PlayAnimationCommand: La animación '%s' no existe en el SpriteFrames del evento" % animation_name)
		context.continue_execution()
		return
	
	print("PlayAnimationCommand: Reproduciendo animación '%s' (wait=%s)" % [animation_name, wait_until_finished])
	
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

## Busca el ActorAnimator en el evento que ejecuta este comando
func _find_actor_animator(context: Node) -> ActorAnimator:
	# El contexto es el EventController
	# El EventController tiene current_page, que tiene source_event
	
	if not context is EventController:
		push_warning("PlayAnimationCommand: El contexto no es un EventController")
		return null
	
	var event_controller := context as EventController
	
	# Obtener la página actual
	if not event_controller.current_page:
		push_warning("PlayAnimationCommand: El EventController no tiene una página actual")
		return null
	
	# Obtener el evento de origen
	var source_event := event_controller.current_page.source_event
	if not source_event:
		push_warning("PlayAnimationCommand: La EventPage no tiene un source_event asignado")
		return null
	
	# Buscar el ActorAnimator en el evento
	return _search_actor_animator_in_node(source_event)

## Busca recursivamente un ActorAnimator en un nodo y sus hijos
func _search_actor_animator_in_node(node: Node) -> ActorAnimator:
	if node is ActorAnimator:
		return node
	
	for child in node.get_children():
		if child is ActorAnimator:
			return child
		var found = _search_actor_animator_in_node(child)
		if found:
			return found
	
	return null

func is_async() -> bool:
	return wait_until_finished

func is_safe_for_parallel() -> bool:
	return false

