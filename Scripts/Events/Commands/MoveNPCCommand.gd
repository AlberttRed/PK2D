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

	# Si no se especificó nombre, usar el evento actual
	if target_name.is_empty():
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				actor = source_event as Node2D
				print("MoveNPCCommand: Usando evento actual '%s' (no se especificó nombre)" % source_event.name)
			else:
				push_warning("MoveNPCCommand: No se pudo obtener el evento actual (source_event es nulo)")
				context.continue_execution()
				return
		else:
			push_warning("MoveNPCCommand: No se especificó target_name y no se pudo obtener el evento actual")
			context.continue_execution()
			return
	else:
		print("MoveNPCCommand: Iniciando movimiento para '%s'" % target_name)
		# Buscar el actor (NPC o Player) por nombre
		actor = _find_actor(context, target_name)
		if not actor:
			push_warning("MoveNPCCommand: No se encontró el actor '%s'" % target_name)
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
		context.continue_execution()
		return

	# Verificar que el path no esté vacío
	if path.is_empty():
		push_warning("MoveNPCCommand: El path está vacío")
		context.continue_execution()
		return

	print("MoveNPCCommand: Ejecutando path con %d direcciones" % path.size())

	# Ejecutar el movimiento
	if wait_until_finished:
		# Marcar como running y ejecutar con callable para poder usar await
		set_state(CommandState.RUNNING)
		_execute_async(motion, context)
	else:
		# No espera: ejecuta en background
		# Como is_async() = false, el EventController continuará automáticamente
		_execute_path_background(motion, context)

## Ejecuta el movimiento de forma asíncrona
func _execute_async(motion: GridMotion, context: Node) -> void:
	await _execute_path(motion, context)
	set_state(CommandState.IDLE)
	context.continue_execution()

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
	motion.is_command_controlled = true
	motion.is_running = false

	for dir_enum in path:
		# Determinar el tipo de comando primero
		var is_movement = DirectionEnum.is_movement(dir_enum)
		# Verificar si es wait (usando números directamente como workaround)
		var is_wait = (dir_enum >= 9)  # WAIT_025=9, WAIT_050=10, WAIT_100=11 (LOOK_PLAYER=8)

		if is_movement:
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
			# Obtener duración según el tipo de wait (usando números directamente)
			var wait_duration = 0.0
			match dir_enum:
				9:  # WAIT_025
					wait_duration = 0.25
				10:  # WAIT_050
					wait_duration = 0.50
				11: # WAIT_100
					wait_duration = 1.00
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
			elif actor_node.has_node("AnimatedSprite2D"):
				# Para el Player u otros actores sin ActorAnimator
				# La animación se actualiza automáticamente en su lógica interna
				pass

			# Esperar un breve delay para que se vea el giro
			await motion.get_tree().create_timer(0.5).timeout

	# Restaurar el control normal (el Player volverá a controlar is_running con input)
	motion.is_command_controlled = false

	print("MoveNPCCommand: Path completado")

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

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null
