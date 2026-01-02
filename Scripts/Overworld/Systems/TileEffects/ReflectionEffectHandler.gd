extends TileEffectHandler
class_name ReflectionEffectHandler

## Handler para efectos de reflejo en agua
## Controla la visibilidad del ReflectionSprite basándose en los tiles de agua cercanos
## Verifica: tile actual, inferior, delante, y delante inferior según la dirección
## La conexión a actores se hace desde TileEffectSystem

func _init(p_effect_system: TileEffectSystem) -> void:
	super._init("water", p_effect_system)

## Se llama cuando un actor EMPIEZA a moverse hacia un tile
func on_step_started_to_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	var direction: Vector2 = Vector2.DOWN  # Por defecto abajo
	var motion := _actor.get_node_or_null("GridMotion")
	direction = motion.get("dir")
	if direction == Vector2.DOWN:
		_check_water_reflection(_grid, _tile, _actor)

## Se llama cuando un actor TERMINA un paso
func on_step_finished_on_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D, _had_collision: bool) -> void:
	_check_water_reflection(_grid, _tile, _actor)

## Se llama cuando un actor SALE de un tile
func on_step_exited_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	var direction: Vector2 = Vector2.DOWN  # Por defecto abajo
	var motion := _actor.get_node_or_null("GridMotion")
	direction = motion.get("dir")
	var front_tile = Vector2(_tile) + direction

	var tile_info := _grid.get_tile_info(front_tile)
	if !tile_info.water_reflection:
		if direction == Vector2.UP:
			await _grid.get_tree().create_timer(motion.get_step_duration()/1.5).timeout
		deactivate_actor(_actor)
		return

## Verifica si hay agua en los tiles relevantes y actualiza la visibilidad del reflejo
func _check_water_reflection(grid: OverworldGrid, current_tile: Vector2i, actor: Node2D) -> void:
	var reflection_sprite := actor.get_node_or_null("ReflectionSprite")
	if not reflection_sprite:
		return

	# Para Events: verificar si el EventPage actual permite reflejo
	if actor is Event:
		var event := actor as Event
		if event.current_page:
			var event_page := event.current_page as EventPage
			if not event_page.has_water_reflection:
				reflection_sprite.visible = false
				return

	# Obtener dirección del actor
	var direction: Vector2 = Vector2.DOWN  # Por defecto abajo
	var motion := actor.get_node_or_null("GridMotion")
	direction = motion.get("dir")

	# Calcular los tiles a verificar: actual, inferior, delante, delante inferior
	var tiles_to_check: Array[Vector2i] = []

	# Tile actual (donde está el actor)
	tiles_to_check.append(current_tile)

	# Tile inferior (debajo del actor)
	tiles_to_check.append(current_tile + Vector2i(0, 1))

	# Tile delante y delante inferior según la dirección
	if direction == Vector2.UP:
		tiles_to_check.append(current_tile + Vector2i(0, -1))  # Delante (arriba)
		# Delante inferior sería arriba+abajo = actual, no necesario
	elif direction == Vector2.DOWN:
		tiles_to_check.append(current_tile + Vector2i(0, 2))
		# Delante (abajo) ya es el inferior, ya incluido - no agregar más tiles
	elif direction == Vector2.LEFT:
		tiles_to_check.append(current_tile + Vector2i(-1, 0))  # Delante (izquierda)
		tiles_to_check.append(current_tile + Vector2i(-1, 1))  # Delante inferior (izquierda + abajo)
	elif direction == Vector2.RIGHT:
		tiles_to_check.append(current_tile + Vector2i(1, 0))   # Delante (derecha)
		tiles_to_check.append(current_tile + Vector2i(1, 1))   # Delante inferior (derecha + abajo)

	# Verificar si alguno de los tiles es agua
	var has_water_nearby: bool = false
	for tile in tiles_to_check:
		var tile_info := grid.get_tile_info(tile)
		if tile_info.water_reflection:
			has_water_nearby = true
			break

	# Actualizar visibilidad solo si hay agua
	reflection_sprite.visible = has_water_nearby

## Se llama cuando un actor se desactiva
func deactivate_actor(actor: Node2D) -> void:
	var reflection_sprite := actor.get_node_or_null("ReflectionSprite")
	if reflection_sprite:
		reflection_sprite.visible = false

## Verifica el reflejo inicial cuando un actor se conecta al sistema
## Se llama cuando el actor se posiciona por primera vez o se conecta al sistema
func check_initial_reflection(actor: Node2D) -> void:
	if not actor or not is_instance_valid(actor) or not actor.is_inside_tree():
		return

	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion or not grid_motion.is_inside_tree():
		return

	var grid = grid_motion.grid
	if not grid:
		# Si el grid aún no está disponible, intentar de nuevo en el siguiente frame
		if grid_motion.is_inside_tree():
			await grid_motion.get_tree().process_frame
			check_initial_reflection(actor)
		return

	var current_tile = grid_motion.current_tile()
	if current_tile == Vector2i(-9999, -9999):
		# Si el tile aún no está inicializado, intentar de nuevo en el siguiente frame
		if grid_motion.is_inside_tree():
			await grid_motion.get_tree().process_frame
			check_initial_reflection(actor)
		return

	_check_water_reflection(grid, current_tile, actor)
