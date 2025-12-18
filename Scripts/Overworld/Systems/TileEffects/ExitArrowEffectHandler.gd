extends TileEffectHandler
class_name ExitArrowEffectHandler

## Handler para la flecha de salida (exit arrow)
## Muestra una flecha cuando el jugador está sobre un tile con exit_dir
## y está mirando en la misma dirección

# Escena del efecto de flecha
var exit_arrow_scene: PackedScene

# Estado de la flecha activa (singleton visual)
var _active_arrow: Node2D = null
var _current_tile: Vector2i = Vector2i(-9999, -9999)
var _current_exit_dir: String = ""


func _init(p_effect_system: TileEffectSystem) -> void:
	# No usamos terrain_type para este handler, usamos un valor especial
	super._init("exit_arrow", p_effect_system)


## Configura la escena del efecto
func setup_effects(arrow_scene: PackedScene) -> void:
	exit_arrow_scene = arrow_scene


## Convierte Vector2 a string de dirección
func _vector2_to_direction_string(direction: Vector2) -> String:
	if direction == Vector2.UP:
		return "up"
	elif direction == Vector2.DOWN:
		return "down"
	elif direction == Vector2.LEFT:
		return "left"
	elif direction == Vector2.RIGHT:
		return "right"
	return ""


## Convierte string de dirección a nombre de animación
func _direction_string_to_animation(exit_dir: String) -> String:
	match exit_dir.to_lower():
		"up":
			return "arrow_up"
		"down":
			return "arrow_down"
		"left":
			return "arrow_left"
		"right":
			return "arrow_right"
		_:
			return "arrow_down"  # Por defecto


## Calcula el offset de posición según la dirección de salida
## La flecha aparece un tile desplazada en la dirección opuesta
func _get_arrow_offset(exit_dir: String) -> Vector2:
	match exit_dir.to_lower():
		"down":
			return Vector2(0, 32)  # Un tile abajo
		"up":
			return Vector2(0, -32)  # Un tile arriba
		"right":
			return Vector2(32, 0)  # Un tile a la derecha
		"left":
			return Vector2(-32, 0)  # Un tile a la izquierda
		_:
			return Vector2.ZERO


func on_step_started_to_tile(_grid: OverworldGrid, _destination_tile: Vector2i, _actor: Node2D) -> void:
	# No hacer nada al iniciar el movimiento
	pass


func on_step_finished_on_tile(grid: OverworldGrid, tile: Vector2i, actor: Node2D, _had_collision: bool) -> void:
	# Solo procesar para el jugador
	if not actor.is_in_group("Player"):
		return

	# Obtener información del tile
	var tile_info = grid.get_tile_info(tile)
	var exit_dir = tile_info.get("exit_dir", "")

	# Si el tile no tiene exit_dir, ocultar la flecha
	if exit_dir.is_empty():
		_hide_arrow()
		_current_tile = Vector2i(-9999, -9999)
		_current_exit_dir = ""
		return

	# Obtener la dirección del jugador
	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion:
		_hide_arrow()
		return

	var player_dir_string = _vector2_to_direction_string(grid_motion.dir)

	# Solo mostrar la flecha si el jugador está mirando en la misma dirección que exit_dir
	if player_dir_string == exit_dir.to_lower():
		# Mostrar o actualizar la flecha
		_show_arrow_at_tile(grid, tile, exit_dir)
	else:
		# Ocultar la flecha si la dirección no coincide
		_hide_arrow()
		_current_tile = Vector2i(-9999, -9999)
		_current_exit_dir = ""


func on_step_exited_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	# Ocultar la flecha al salir del tile
	_hide_arrow()
	_current_tile = Vector2i(-9999, -9999)
	_current_exit_dir = ""


func clear_state() -> void:
	_hide_arrow()
	_current_tile = Vector2i(-9999, -9999)
	_current_exit_dir = ""


## Muestra la flecha en el tile especificado
func _show_arrow_at_tile(grid: OverworldGrid, tile: Vector2i, exit_dir: String) -> void:
	# Si ya hay una flecha activa en el mismo tile y dirección, no hacer nada
	if _active_arrow and is_instance_valid(_active_arrow) and _current_tile == tile and _current_exit_dir == exit_dir:
		return

	# Si hay una flecha activa pero en otro tile o dirección, ocultarla primero
	if _active_arrow and is_instance_valid(_active_arrow):
		_hide_arrow()

	# Crear nueva flecha si no existe
	if not exit_arrow_scene:
		push_warning("ExitArrowEffectHandler: exit_arrow_scene no configurada")
		return

	var arrow = exit_arrow_scene.instantiate() as Node2D
	if not arrow:
		push_error("ExitArrowEffectHandler: No se pudo instanciar la flecha")
		return

	# Posicionar la flecha en el centro del tile con offset según la dirección
	var world_pos = grid.tile_to_world_center(tile)
	var offset = _get_arrow_offset(exit_dir)
	arrow.global_position = world_pos + offset

	# Configurar la animación según la dirección
	var animated_sprite = arrow.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		var anim_name = _direction_string_to_animation(exit_dir)
		animated_sprite.play(anim_name)
	else:
		push_warning("ExitArrowEffectHandler: No se encontró AnimatedSprite2D en la flecha")

	# Añadir a la capa de efectos
	effect_system._add_effect_to_scene(arrow)

	# Guardar referencia
	_active_arrow = arrow
	_current_tile = tile
	_current_exit_dir = exit_dir


## Oculta y libera la flecha activa
func _hide_arrow() -> void:
	if _active_arrow and is_instance_valid(_active_arrow):
		_active_arrow.queue_free()
		_active_arrow = null
