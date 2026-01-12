extends EventCommand
class_name MoveNPCCommand

## Comando para mover un NPC (o el Player) mediante instrucciones predefinidas
##
## Este comando ejecuta desplazamientos paso a paso utilizando GridMotion,
## similar al path movement de los NPCs.

## Nombre o identificador del NPC a mover (o "Player" para el jugador)
## Si está vacío, usa el evento actual donde se ejecuta el comando
@export var target_name: String = ""

## Lista de direcciones a seguir (usa el enum DirectionEnum.Type)
@export var path: Array[DirectionEnum.Type] = []

## Si es true, espera a que termine el movimiento antes de continuar
@export var wait_until_finished: bool = true

func execute(context: Node) -> void:
	var actor: Node2D = null

	# Detectar si estamos siendo ejecutados desde un ShowChoicesCommand
	# Revisando el stack de llamadas para ver si hay un ShowChoicesCommand en ejecución
	var is_in_branch = _is_executing_in_branch(context)

	# Si no se especificó nombre, usar el evento actual
	if target_name.is_empty():
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				actor = source_event as Node2D
				print("MoveNPCCommand: Usando evento actual '%s' (no se especificó nombre)" % source_event.name)
			else:
				push_warning("MoveNPCCommand: No se pudo obtener el evento actual (source_event es nulo)")
				if not is_in_branch:
					context.continue_execution()
				return
		else:
			push_warning("MoveNPCCommand: No se especificó target_name y no se pudo obtener el evento actual")
			if not is_in_branch:
				context.continue_execution()
			return
	else:
		print("MoveNPCCommand: Iniciando movimiento para '%s'" % target_name)
		# Buscar el actor (NPC o Player) por nombre
		actor = _find_actor(context, target_name)
		if not actor:
			push_warning("MoveNPCCommand: No se encontró el actor '%s'" % target_name)
			if not is_in_branch:
				context.continue_execution()
			return

	# Verificar que tiene GridMotion
	var motion: GridMotion = actor.get_node_or_null("GridMotion")
	if not motion:
		var actor_name: String
		if not target_name.is_empty():
			actor_name = target_name
		elif actor:
			actor_name = actor.name
		else:
			actor_name = "desconocido"
		push_warning("MoveNPCCommand: El actor '%s' no tiene componente GridMotion" % actor_name)
		if not is_in_branch:
			context.continue_execution()
		return

	# Verificar que el path no esté vacío
	if path.is_empty():
		push_warning("MoveNPCCommand: El path está vacío")
		if not is_in_branch:
			context.continue_execution()
		return

	print("MoveNPCCommand: Ejecutando path con %d direcciones" % path.size())

	# Ejecutar el movimiento
	if wait_until_finished:
		# Marcar como running y ejecutar con await para esperar correctamente
		set_state(CommandState.RUNNING)
		await _execute_async(motion, context, is_in_branch)
	else:
		# No espera: ejecuta en background
		# Como is_async() = false, el EventController continuará automáticamente
		_execute_path_background(motion, context)

## Ejecuta el movimiento de forma asíncrona
func _execute_async(motion: GridMotion, context: Node, is_in_branch: bool = false) -> void:
	await _execute_path(motion, context)
	set_state(CommandState.IDLE)
	# Solo llamar continue_execution si NO estamos en un branch
	# Si estamos en un branch, ShowChoicesCommand ya está esperando con await
	if not is_in_branch:
		context.continue_execution()

## Detecta si este comando está siendo ejecutado dentro de un branch de ShowChoicesCommand
## Esto es necesario porque ShowChoicesCommand ejecuta los comandos del branch directamente
## con await, y no queremos que MoveNPCCommand llame a continue_execution() dos veces
func _is_executing_in_branch(context: Node) -> bool:
	# Cuando ShowChoicesCommand ejecuta comandos del branch, pasa el EventController como contexto
	# pero el comando actual no está en la cola del EventController, está siendo ejecutado directamente
	# por ShowChoicesCommand.
	#
	# La forma más confiable de detectar esto es verificar si el comando actual NO está en la cola
	# del EventController en la posición esperada. Si estamos siendo ejecutados desde un branch,
	# este comando no estará en command_queue[current_command_index].
	if context is EventController:
		var controller = context as EventController
		# Verificar si este comando está en la posición actual de la cola
		if controller.current_command_index < controller.command_queue.size():
			var current_cmd = controller.command_queue[controller.current_command_index]
			# Si el comando actual en la cola NO es este comando, probablemente estamos en un branch
			if current_cmd != self:
				return true
		else:
			# Si el índice está fuera de rango, probablemente estamos en un branch
			return true
	return false

## Busca un actor (NPC o Player) por nombre en la escena
func _find_actor(context: Node, name: String) -> Node2D:
	# Si es "Player", obtener del contexto
	if name == "Player" or name.to_lower() == "player":
		var overworld_context = _get_overworld_context(context)
		if overworld_context:
			return overworld_context.get_player()
		push_error("MoveNPCCommand: OverworldContext no disponible para obtener Player")
		return null

	# Para NPCs, buscar en el escenario actual por nombre exacto
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

## Ejecuta el path paso a paso (función principal)
func _execute_path(motion: GridMotion, context: Node) -> void:
	# Marcar que el movimiento está siendo controlado por comando
	# Esto evita que el input del jugador modifique is_running
	# y también evita que el evento se desactive cuando su chunk se desactiva
	motion.is_command_controlled = true
	motion.is_running = false

	# Ejecutar el path con protección para limpiar el flag incluso si hay errores
	await _execute_path_internal(motion, context)

	# Asegurar que el flag siempre se limpie al finalizar
	motion.is_command_controlled = false
	print("MoveNPCCommand: Path completado")

## Ejecuta el path internamente (separado para facilitar manejo de errores)
func _execute_path_internal(motion: GridMotion, context: Node) -> void:
	for dir_enum in path:
		# Determinar el tipo de comando primero
		var is_movement = DirectionEnum.is_movement(dir_enum)
		var is_wait = DirectionEnum.is_wait(dir_enum)
		var is_speed = DirectionEnum.is_speed_change(dir_enum)
		var is_animation = DirectionEnum.is_animation(dir_enum)
		var is_turn = DirectionEnum.is_turn(dir_enum)

		if is_turn:
			# Comando TURN: girar con animación de caminar sin moverse
			var direction = DirectionEnum.to_vector2(dir_enum)
			print("MoveNPCCommand: Girando hacia %s con animación (sin moverse)" % direction)

			# Ejecutar el giro con animación y esperar a que termine
			await motion.try_turn(direction)

			# Esperar un momento adicional para separar los giros
			await motion.get_tree().create_timer(0.25).timeout
			continue
		elif is_animation:
			# Comando de animación (exclamación, etc.)
			if dir_enum == DirectionEnum.Type.EXCLAMATION_ANIM:
				await _show_exclamation_animation(motion.actor)
			continue
		elif is_speed:
			# Comando de cambio de velocidad
			var speed_enum = DirectionEnum.to_speed_enum(dir_enum)
			var speed_multiplier = MoveSpeedEnum.to_multiplier(speed_enum)
			motion.base_speed = speed_multiplier

			var speed_name = MoveSpeedEnum.Type.keys()[speed_enum]
			print("MoveNPCCommand: Cambiando velocidad a %s (%.2fx)" % [speed_name, speed_multiplier])

			# No esperar, continuar inmediatamente
			continue
		elif is_movement:
			# Movimiento normal: primero orientar, luego ejecutar paso
			# Esto evita el "first step" cuando cambia de dirección
			var direction = DirectionEnum.to_vector2(dir_enum)
			motion.face(direction)

			# Verificar si puede moverse (similar al NPC path movement)
			var from = motion.current_tile()
			var to = from + Vector2i(direction)
			var can_step = motion.grid.can_step_to(motion.actor, from, to)

			if can_step:
				# Ejecutar paso
				motion.try_step(direction)

				# Esperar a que termine el paso
				await motion.step_finished
			else:
				# No puede moverse, esperar un momento antes de continuar
				await motion.get_tree().create_timer(0.5).timeout
		elif is_wait:
			# Comando WAIT: esperar un tiempo determinado
			var wait_duration = DirectionEnum.get_wait_duration(dir_enum)
			print("MoveNPCCommand: Esperando %s segundos" % wait_duration)
			await motion.get_tree().create_timer(wait_duration).timeout
		else:
			# Comando LOOK: solo girar sin moverse
			var direction: Vector2

			# Si es LOOK_PLAYER, calcular la dirección hacia el jugador
			if dir_enum == DirectionEnum.Type.LOOK_PLAYER:
				direction = _calculate_direction_to_player(motion, context)
				if direction == Vector2.ZERO:
					push_warning("MoveNPCCommand: No se pudo calcular dirección hacia el jugador, saltando LOOK_PLAYER")
					continue
				print("MoveNPCCommand: Mirando hacia el jugador (%s)" % direction)
			else:
				# Convertir el enum LOOK a Vector2 para la dirección
				direction = DirectionEnum.to_vector2(dir_enum)
				print("MoveNPCCommand: Mirando hacia %s" % direction)

			motion.face(direction)

			# Actualizar la animación del actor si tiene animator (NPC) o sprite (Player)
			var actor_node = motion.actor
			if actor_node.has_node("ActorAnimator"):
				var animator = actor_node.get_node("ActorAnimator")
				animator.idle(direction)
			elif actor_node.has_method("stop"):
				# Para el Player, llamar a stop() que actualiza la animación idle según la dirección
				actor_node.stop()
			elif actor_node.has_node("AnimatedSprite2D"):
				# Fallback: actualizar manualmente el sprite si tiene AnimatedSprite2D
				var sprite = actor_node.get_node("AnimatedSprite2D") as AnimatedSprite2D
				if sprite and sprite.sprite_frames:
					if sprite.sprite_frames.has_animation("idle"):
						sprite.animation = "idle"
						sprite.stop()
						match direction:
							Vector2.UP: sprite.frame = 3
							Vector2.DOWN: sprite.frame = 0
							Vector2.LEFT: sprite.frame = 1
							Vector2.RIGHT: sprite.frame = 2
					else:
						sprite.stop()
						match direction:
							Vector2.UP: sprite.frame = 3
							Vector2.DOWN: sprite.frame = 0
							Vector2.LEFT: sprite.frame = 1
							Vector2.RIGHT: sprite.frame = 2

			# Esperar un breve delay para que se vea el giro
			await motion.get_tree().create_timer(0.25).timeout

## Ejecuta el path en background (sin bloquear el EventController)
func _execute_path_background(motion: GridMotion, context: Node) -> void:
	# Esta función ejecuta el path de forma asíncrona sin esperar
	# Marca como RUNNING mientras se ejecuta
	set_state(CommandState.RUNNING)
	# Ejecutar el path de forma asíncrona
	var callable = func():
		await _execute_path(motion, context)
		set_state(CommandState.IDLE)
		print("MoveNPCCommand: Movimiento en background completado")
	callable.call()

func is_async() -> bool:
	return wait_until_finished

func is_safe_for_parallel() -> bool:
	return false

## Calcula la dirección hacia el jugador usando la misma lógica que NPC.gd
## Reutiliza el cálculo basado en tiles para consistencia con el comportamiento de NPCs
func _calculate_direction_to_player(motion: GridMotion, context: Node) -> Vector2:
	var overworld_context = _get_overworld_context(context)
	if not overworld_context:
		push_warning("MoveNPCCommand: OverworldContext no disponible para calcular dirección hacia el jugador")
		return Vector2.ZERO

	var player = overworld_context.get_player()
	if not player:
		push_warning("MoveNPCCommand: Player no disponible")
		return Vector2.ZERO

	# Requiere grid para calcular dirección (misma lógica que NPC._calculate_direction_to_player_for_path)
	if not motion.grid:
		push_warning("MoveNPCCommand: Grid no disponible para calcular dirección hacia el jugador")
		return Vector2.ZERO

	# Calcular diferencia en tiles (mismo método que NPC._calculate_direction_to_player_for_path)
	var actor_tile = motion.current_tile()
	var player_tile = motion.grid.world_to_tile(player.global_position)
	var tile_diff = player_tile - actor_tile

	# Determinar la dirección predominante (misma lógica que NPC)
	if abs(tile_diff.x) > abs(tile_diff.y):
		# Movimiento horizontal predominante
		return Vector2.RIGHT if tile_diff.x > 0 else Vector2.LEFT
	else:
		# Movimiento vertical predominante
		return Vector2.DOWN if tile_diff.y > 0 else Vector2.UP

## Muestra la animación de exclamación sobre un actor
func _show_exclamation_animation(actor: Node2D) -> void:
	# Cargar el SpriteFrames de exclamación
	var exclamation_sprite: SpriteFrames = preload("res://Resources/Animations/Overworld/trainer_exclamation.tres")
	if not exclamation_sprite:
		push_warning("MoveNPCCommand: No se pudo cargar trainer_exclamation.tres")
		return

	# Crear sprite de exclamación temporal
	var exclamation_node = AnimatedSprite2D.new()
	exclamation_node.sprite_frames = exclamation_sprite

	# Posición: 2 tiles arriba del actor (64px de alto = 2 tiles)
	# El sprite tiene 64px de alto, con centro a 32px, así que -64 lo centra en los 2 tiles superiores
	exclamation_node.position = Vector2(0, -64)

	actor.add_child(exclamation_node)

	# Determinar qué animación usar
	var anim_name = "default"

	# Reproducir animación una vez (sin loop)
	exclamation_node.play(anim_name)

	# Esperar a que termine la animación
	await exclamation_node.animation_finished

	# Detener en el último frame
	exclamation_node.stop()

	# Establecer el último frame manualmente
	var frame_count = exclamation_node.sprite_frames.get_frame_count(anim_name)
	if frame_count > 0:
		exclamation_node.frame = frame_count - 1

	# Esperar un tiempo adicional para que se vea el último frame
	# Duración total similar a Trainer (1.5 segundos)
	var exclamation_duration: float = 1.5

	# Calculamos el tiempo de la animación
	var animation_duration = 0.0
	if exclamation_node.sprite_frames:
		var fps = exclamation_node.sprite_frames.get_animation_speed(anim_name)
		if fps > 0:
			animation_duration = frame_count / fps

	var remaining_time = max(0.0, exclamation_duration - animation_duration)
	if remaining_time > 0:
		await actor.get_tree().create_timer(remaining_time).timeout

	# Eliminar exclamación
	if exclamation_node:
		exclamation_node.queue_free()

	print("MoveNPCCommand: Animación de exclamación completada")

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null
