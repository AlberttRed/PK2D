extends EventCommand
class_name PlayAnimationCommand

## Comando para reproducir animaciones en el ActorAnimator de un evento
## Útil para animaciones contextuales (abrir puerta, cofre, switch, etc.)
## Si target_name está vacío, será el propio evento donde se ejecuta el comando
@export var target_name: String = ""
@export var animation_name: String = ""
@export var wait_until_finished: bool = true
## Multiplicador de velocidad (1.0 = normal, 2.0 = doble). Se restaura a 1.0 al terminar si wait.
@export_range(0.1, 5.0, 0.1) var speed_scale: float = 1.0

func execute(context: Node) -> void:
	# Validar que se proporcionó un nombre de animación
	if animation_name.is_empty():
		push_warning("PlayAnimationCommand: No se especificó un nombre de animación")
		_finish_if_async(context)
		return

	# Resolver el target y buscar el ActorAnimator
	var target = _resolve_target(context, target_name)
	if not target:
		push_warning("PlayAnimationCommand: No se pudo resolver el target")
		_finish_if_async(context)
		return

	# Target 3D (Event3D, Door3D...): animación local con el AnimationPlayer del propio nodo.
	if target is Node3D:
		await _play_animation_player(context, target)
		return

	var actor_animator := _find_actor_animator_in_node(target)

	if not actor_animator:
		push_warning("PlayAnimationCommand: El target '%s' no tiene un ActorAnimator. El comando se omite." % target.name)
		_finish_if_async(context)
		return

	# Verificar que el ActorAnimator tiene un sprite válido
	if not actor_animator.sprite or not actor_animator.sprite.sprite_frames:
		push_warning("PlayAnimationCommand: El ActorAnimator no tiene un sprite o SpriteFrames configurado")
		_finish_if_async(context)
		return

	# Verificar que la animación existe
	if not actor_animator.sprite.sprite_frames.has_animation(animation_name):
		push_warning("PlayAnimationCommand: La animación '%s' no existe en el SpriteFrames del target '%s'" % [animation_name, target.name])
		_finish_if_async(context)
		return

	print("PlayAnimationCommand: Reproduciendo animación '%s' en '%s' (wait=%s, speed=%.1f)" % [animation_name, target.name, wait_until_finished, speed_scale])

	var previous_speed_scale: float = actor_animator.sprite.speed_scale
	actor_animator.set_speed_scale(maxf(speed_scale, 0.1))
	actor_animator.play(animation_name)

	# Con wait: await dentro de execute() para que funcione también dentro de ramas
	# (ShowChoices / Conditional). Sin wait: síncrono — EventController avanza solo.
	if wait_until_finished:
		await actor_animator.sprite.animation_finished
		actor_animator.set_speed_scale(previous_speed_scale)
		print("PlayAnimationCommand: Animación '%s' completada" % animation_name)
		context.continue_execution()

func _finish_if_async(context: Node) -> void:
	if wait_until_finished:
		context.continue_execution()

## Reproduce `animation_name` en el AnimationPlayer del target 3D (mismo contrato wait/speed que en 2D).
func _play_animation_player(context: Node, target: Node) -> void:
	# Event3D: la animación vive en el visual de su página activa (AnimationPlayer o sprite plano).
	var anim_player: AnimationPlayer = null
	if target.has_method("get_animation_player"):
		anim_player = target.get_animation_player()
		if (anim_player == null or not anim_player.has_animation(animation_name)) \
				and target.has_method("get_flat_sprite"):
			var flat: AnimatedSprite3D = target.get_flat_sprite()
			if flat != null and flat.sprite_frames != null and flat.sprite_frames.has_animation(animation_name):
				await _play_flat_sprite(context, target, flat)
				return
	else:
		anim_player = _find_animation_player_in_node(target)
	if anim_player == null:
		push_warning("PlayAnimationCommand: El target 3D '%s' no tiene AnimationPlayer. El comando se omite." % target.name)
		_finish_if_async(context)
		return
	if not anim_player.has_animation(animation_name):
		push_warning("PlayAnimationCommand: La animación '%s' no existe en el AnimationPlayer de '%s'" % [animation_name, target.name])
		_finish_if_async(context)
		return

	print("PlayAnimationCommand: Reproduciendo animación 3D '%s' en '%s' (wait=%s, speed=%.1f)" % [animation_name, target.name, wait_until_finished, speed_scale])
	var previous_speed_scale := anim_player.speed_scale
	anim_player.speed_scale = maxf(speed_scale, 0.1)
	anim_player.play(animation_name)

	if wait_until_finished:
		await anim_player.animation_finished
		anim_player.speed_scale = previous_speed_scale
		print("PlayAnimationCommand: Animación 3D '%s' completada" % animation_name)
		context.continue_execution()

## Reproduce `animation_name` en el AnimatedSprite3D plano de un Event3D (visual por sprite_frames).
func _play_flat_sprite(context: Node, target: Node, sprite: AnimatedSprite3D) -> void:
	print("PlayAnimationCommand: Reproduciendo animación sprite 3D '%s' en '%s' (wait=%s)" % [animation_name, target.name, wait_until_finished])
	var previous_speed_scale := sprite.speed_scale
	sprite.speed_scale = maxf(speed_scale, 0.1)
	sprite.play(animation_name)
	if wait_until_finished:
		await sprite.animation_finished
		sprite.speed_scale = previous_speed_scale
		context.continue_execution()

## Busca recursivamente un AnimationPlayer en un nodo y sus hijos
func _find_animation_player_in_node(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player_in_node(child)
		if found:
			return found
	return null

## Resuelve el target donde buscar el ActorAnimator (2D) o el AnimationPlayer (3D)
func _resolve_target(context: Node, name: String) -> Node:
	# Si está vacío, usar el evento actual
	if name.is_empty():
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				return source_event
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
func _find_node_by_name_recursive(node: Node, name: String) -> Node:
	if node.name == name and (node is Node2D or node is Node3D):
		return node

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
