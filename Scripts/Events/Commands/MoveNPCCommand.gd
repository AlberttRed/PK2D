extends EventCommand
class_name MoveNPCCommand

## Separación (m, en pantalla) entre la cabeza del actor y el borde inferior del frame de la exclamación 3D.
## Negativo = más baja / pegada a la cabeza; positivo = más alta.
const EXCLAMATION_HEAD_GAP_3D := -0.5

## Comando para mover un NPC (o el Player) mediante instrucciones predefinidas
##
## Este comando ejecuta desplazamientos paso a paso utilizando GridMotion (2D) o GridMotion3D (3D),
## similar al path movement de los NPCs. Es UN solo comando para los dos mundos: las páginas
## (EventPage) son un recurso compartido y el mismo `.tres` debe funcionar en 2D y en 3D. El motor
## se detecta por el actor (GridMotion vs GridMotion3D); `_execute_path` es el flujo 2D original y
## `_execute_path_3d` su equivalente en celdas XZ.

## Nombre o identificador del NPC a mover (o "Player" para el jugador)
## Si está vacío, usa el evento actual donde se ejecuta el comando
@export var target_name: String = ""

## Lista de direcciones a seguir (usa el enum DirectionEnum.Type)
@export var path: Array[DirectionEnum.Type] = []

## Si es true, espera a que termine el movimiento antes de continuar
@export var wait_until_finished: bool = true

func execute(context: Node) -> void:
	var actor: Node = null

	# Si no se especificó nombre, usar el evento actual
	if target_name.is_empty():
		if context is EventController and context.current_page:
			var source_event = context.current_page.source_event
			if source_event:
				actor = source_event
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

	# Verificar que tiene motor de movimiento (GridMotion 2D o GridMotion3D)
	var motion: Object = _get_motion(actor)
	if not motion:
		var actor_name: String
		if not target_name.is_empty():
			actor_name = target_name
		elif actor:
			actor_name = actor.name
		else:
			actor_name = "desconocido"
		push_warning("MoveNPCCommand: El actor '%s' no tiene componente GridMotion/GridMotion3D" % actor_name)
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
		set_state(CommandState.RUNNING)
		await _run_path(motion, context)
		set_state(CommandState.IDLE)
		context.continue_execution()
	else:
		# No espera: ejecuta en background
		# Como is_async() = false, el EventController continuará automáticamente
		_execute_path_background(motion, context)

## Busca un actor (NPC o Player) por nombre en la escena
func _find_actor(context: Node, name: String) -> Node:
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
func _find_node_by_name_recursive(node: Node, name: String) -> Node:
	if node.name == name and (node is Node2D or node is Node3D):
		return node

	for child in node.get_children():
		var result = _find_node_by_name_recursive(child, name)
		if result:
			return result

	return null

## Motor de movimiento del actor: GridMotion (2D) o GridMotion3D (3D); null si no tiene.
func _get_motion(actor: Node) -> Object:
	var motion_2d: Node = actor.get_node_or_null("GridMotion")
	if motion_2d != null:
		return motion_2d
	# Player3D y NPC3D exponen `motion` (el GridMotion3D hijo).
	var motion_3d: Variant = actor.get("motion")
	if motion_3d is GridMotion3D:
		return motion_3d
	return actor.get_node_or_null("GridMotion3D")


## Despacha al flujo 2D o 3D según el motor del actor.
func _run_path(motion: Object, context: Node) -> void:
	if motion is GridMotion3D:
		await _execute_path_3d(motion as GridMotion3D, context)
	else:
		await _execute_path(motion as GridMotion, context)


## Ejecuta el path paso a paso (función principal, 2D)
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
		print("MoveNPCCommand: Acción=%d (%s), target='%s'" % [int(dir_enum), _action_name(int(dir_enum)), target_name if not target_name.is_empty() else "<evento_actual>"])
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
func _execute_path_background(motion: Object, context: Node) -> void:
	# Esta función ejecuta el path de forma asíncrona sin esperar
	# Marca como RUNNING mientras se ejecuta
	set_state(CommandState.RUNNING)
	# Ejecutar el path de forma asíncrona
	var callable = func():
		await _run_path(motion, context)
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

func _action_name(action: int) -> String:
	match action:
		DirectionEnum.Type.UP: return "UP"
		DirectionEnum.Type.DOWN: return "DOWN"
		DirectionEnum.Type.LEFT: return "LEFT"
		DirectionEnum.Type.RIGHT: return "RIGHT"
		DirectionEnum.Type.LOOK_UP: return "LOOK_UP"
		DirectionEnum.Type.LOOK_DOWN: return "LOOK_DOWN"
		DirectionEnum.Type.LOOK_LEFT: return "LOOK_LEFT"
		DirectionEnum.Type.LOOK_RIGHT: return "LOOK_RIGHT"
		DirectionEnum.Type.TURN_UP: return "TURN_UP"
		DirectionEnum.Type.TURN_DOWN: return "TURN_DOWN"
		DirectionEnum.Type.TURN_LEFT: return "TURN_LEFT"
		DirectionEnum.Type.TURN_RIGHT: return "TURN_RIGHT"
		DirectionEnum.Type.LOOK_PLAYER: return "LOOK_PLAYER"
		DirectionEnum.Type.WAIT_025: return "WAIT_025"
		DirectionEnum.Type.WAIT_050: return "WAIT_050"
		DirectionEnum.Type.WAIT_100: return "WAIT_100"
		DirectionEnum.Type.SPEED_SLOWEST: return "SPEED_SLOWEST"
		DirectionEnum.Type.SPEED_SLOWER: return "SPEED_SLOWER"
		DirectionEnum.Type.SPEED_NORMAL: return "SPEED_NORMAL"
		DirectionEnum.Type.SPEED_FASTER: return "SPEED_FASTER"
		DirectionEnum.Type.SPEED_FASTEST: return "SPEED_FASTEST"
		DirectionEnum.Type.EXCLAMATION_ANIM: return "EXCLAMATION_ANIM"
		_: return "UNKNOWN"


# --- Flujo 3D (GridMotion3D, celdas XZ) ---

## Equivalente 3D de `_execute_path`. Direcciones en celdas: arriba = (0,-1).
func _execute_path_3d(motion: GridMotion3D, context: Node) -> void:
	var actor = motion.actor # sin tipo: puede ser Player3D o NPC3D (duck typing)
	var previous_speed := motion.base_speed
	# Evita que el input del Player pise is_running / encadene pasos propios.
	motion.is_command_controlled = true
	motion.is_running = false

	# Un NPC 3D deja de tomar decisiones propias mientras dura el comando.
	var controls_npc: bool = actor != null and actor.has_method("begin_command_control")
	if controls_npc:
		await actor.begin_command_control()

	await _execute_path_3d_internal(motion, context)

	if is_instance_valid(motion):
		motion.is_command_controlled = false
		motion.base_speed = previous_speed
	if controls_npc and is_instance_valid(actor):
		actor.end_command_control()
	print("MoveNPCCommand: Path 3D completado")


func _execute_path_3d_internal(motion: GridMotion3D, context: Node) -> void:
	for dir_enum in path:
		# El actor puede desaparecer a mitad (cambio de mapa).
		if not is_instance_valid(motion) or motion.actor == null or not is_instance_valid(motion.actor) \
				or not motion.actor.is_inside_tree():
			return
		var tree := motion.get_tree()

		if DirectionEnum.is_turn(dir_enum):
			# TURN: gira con animación de caminar sin moverse.
			await motion.try_turn(_cell_dir(dir_enum))
			await tree.create_timer(0.25).timeout
		elif DirectionEnum.is_animation(dir_enum):
			if dir_enum == DirectionEnum.Type.EXCLAMATION_ANIM:
				await _show_exclamation_3d(motion)
		elif DirectionEnum.is_speed_change(dir_enum):
			motion.base_speed = MoveSpeedEnum.to_multiplier(DirectionEnum.to_speed_enum(dir_enum))
		elif DirectionEnum.is_movement(dir_enum):
			# Primero orientar (evita el "initial step"), luego dar el paso si es posible.
			var d := _cell_dir(dir_enum)
			_face_3d(motion, d)
			if motion.can_step(d):
				motion.try_step(d)
				if motion.moving:
					await motion.step_finished
			else:
				# Bloqueado: igual que en 2D, espera un momento y sigue con el siguiente comando.
				await tree.create_timer(0.5).timeout
		elif DirectionEnum.is_wait(dir_enum):
			await tree.create_timer(DirectionEnum.get_wait_duration(dir_enum)).timeout
		else:
			# LOOK: solo girar sin moverse.
			var d := Vector2i.ZERO
			if dir_enum == DirectionEnum.Type.LOOK_PLAYER:
				d = _direction_to_player_3d(motion, context)
				if d == Vector2i.ZERO:
					push_warning("MoveNPCCommand: No se pudo calcular dirección hacia el jugador, saltando LOOK_PLAYER")
					continue
			else:
				d = _cell_dir(dir_enum)
			_face_3d(motion, d)
			# Breve delay para que se vea el giro.
			await tree.create_timer(0.25).timeout


## DirectionEnum → dirección en celdas XZ (UP = (0,-1)).
func _cell_dir(dir_enum: int) -> Vector2i:
	var v := DirectionEnum.to_vector2(dir_enum)
	return Vector2i(int(v.x), int(v.y))


## Gira al actor 3D y actualiza su pose (Player3D / NPC3D: `set_facing_direction`).
func _face_3d(motion: GridMotion3D, d: Vector2i) -> void:
	var actor = motion.actor
	if actor != null and actor.has_method("set_facing_direction"):
		actor.set_facing_direction(Vector2(d))
	else:
		motion.face(d)


## Dirección cardinal predominante hacia el Player (misma lógica que 2D, en celdas).
func _direction_to_player_3d(motion: GridMotion3D, context: Node) -> Vector2i:
	var overworld_context := _get_overworld_context(context)
	var player: Node = overworld_context.get_player() if overworld_context != null else null
	if player == null or not player.has_method("current_cell"):
		push_warning("MoveNPCCommand: Player 3D no disponible para calcular la dirección")
		return Vector2i.ZERO
	return NPCBehavior.direction_toward(motion.current_cell(), player.current_cell())


## Altura (en pantalla, metros) del sprite plano del actor: alto del frame * pixel_size.
func _actor_sprite_height_3d(actor: Node, cell: float) -> float:
	var found := _find_flat_sprite_3d(actor)
	if found != null and found.sprite_frames != null:
		var tex := found.sprite_frames.get_frame_texture(found.animation, 0)
		if tex != null:
			return tex.get_height() * found.pixel_size
	return 48.0 * cell / ActorSprite3D.DEFAULT_TILE_PIXELS


func _find_flat_sprite_3d(node: Node) -> AnimatedSprite3D:
	for child in node.get_children():
		if child is AnimatedSprite3D and (child as AnimatedSprite3D).billboard != BaseMaterial3D.BILLBOARD_ENABLED:
			return child
		var deeper := _find_flat_sprite_3d(child)
		if deeper != null:
			return deeper
	return null


## Coloca el billboard justo encima de la cabeza, desplazando en la vertical *de pantalla* (eje Y de la cámara),
## porque el sprite del actor está inclinado hacia la cámara y subir en Y del mundo lo dejaría solapado.
func _place_above_head_3d(sprite: AnimatedSprite3D, actor: Node3D, head_height: float,
		tex: Texture2D, cell: float) -> void:
	var back_offset = actor.get("sprite_back_offset")
	var feet := actor.global_position + Vector3(0.0, 0.0, back_offset if back_offset != null else ActorSprite3D.DEFAULT_BACK_OFFSET)
	var cam := actor.get_viewport().get_camera_3d() if actor.is_inside_tree() else null
	var up := cam.global_transform.basis.y if cam != null else Vector3(0.0, 0.7071, -0.7071)
	var half_h := (tex.get_height() * sprite.pixel_size * 0.5) if tex != null else cell
	sprite.global_position = feet + up * (head_height + EXCLAMATION_HEAD_GAP_3D + half_h)


## Exclamación sobre el actor 3D (mismo SpriteFrames y tiempos que en 2D). Billboard sobre la cabeza.
func _show_exclamation_3d(motion: GridMotion3D) -> void:
	var frames: SpriteFrames = preload("res://Resources/Animations/Overworld/trainer_exclamation.tres")
	var actor := motion.actor
	if frames == null or actor == null:
		return
	var anim_name := "default"
	var cell := motion.grid.cell_size().x if motion.grid != null else 2.0

	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.pixel_size = cell / ActorSprite3D.DEFAULT_TILE_PIXELS
	var head_height := _actor_sprite_height_3d(actor, cell)
	actor.add_child(sprite)
	_place_above_head_3d(sprite, actor, head_height, frames.get_frame_texture(anim_name, 0), cell)
	sprite.play(anim_name)
	await sprite.animation_finished

	sprite.stop()
	var frame_count := frames.get_frame_count(anim_name)
	if frame_count > 0:
		sprite.frame = frame_count - 1
	var animation_duration := 0.0
	var fps := frames.get_animation_speed(anim_name)
	if fps > 0.0:
		animation_duration = frame_count / fps
	var remaining := maxf(0.0, 1.5 - animation_duration)
	if remaining > 0.0 and is_instance_valid(actor):
		await actor.get_tree().create_timer(remaining).timeout
	if is_instance_valid(sprite):
		sprite.queue_free()
