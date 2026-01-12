extends Node2D
class_name Event

signal event_triggered(page)

##Lista de páginas de evento (EventPage) que puede ejecutar el vento, cada una con su lista de comandos (EventCommand) definida.
@export var pages: Array[EventPage] = []
@export var current_page_index: int = 0
## Si está deshabilitado, el evento no se disparará (útil para debug)
@export var disabled: bool = false

var current_page: Resource = null

var placeholder_sprite: AnimatedSprite2D
var actor_animator: ActorAnimator

# Referencia al OverworldContext para coordinación con EventSystem
var overworld_context: OverworldContext = null

## Métodos virtuales para conectar/desconectar señales externas
## Se llaman cuando el evento se activa/desactiva en un chunk
## Las clases hijas (NPC, Trainer) pueden sobrescribir estos métodos
func connect_external_signals() -> void:
	pass

func disconnect_external_signals() -> void:
	pass

func _ready() -> void:
	# Obtener referencias a los nodos manualmente para controlar el orden
	placeholder_sprite = $AnimatedSprite2D
	actor_animator = $ActorAnimator

	# Duplicar páginas para evitar modificar Resources compartidos
	_duplicate_all_pages()

	# Ocultar placeholder primero
	hide_placeholder_sprite()

	if name == "Bulbasaur":
		pass
	# Ahora configurar la página actual (esto aplicará el sprite)
	setup_current_page()

	# Conectar a señales de cambio de estado para reevaluación automática
	_connect_to_state_signals()

	# NOTA: Los eventos AUTORUN ahora se activan cuando el chunk se activa
	# (ver WorldChunkController._activate_chunk_events())
	# Esto asegura que el contexto y EventSystem estén listos antes de ejecutar

## Configura current_page basado en current_page_index y pages
## Evalúa condiciones de todas las páginas para encontrar la activa
func setup_current_page() -> void:

	if pages.size() == 0:
		current_page = null
		current_page_index = 0
		print("Event '%s': No hay páginas, llamando update_sprite_from_current_page()" % name)
		update_sprite_from_current_page()
		return

	# Obtener ID único del evento para self-switches
	var event_id = _get_event_id()
	if name == "Stop1":
		pass
	# Buscar todas las páginas que cumplen condiciones, separadas por si tienen condiciones o no
	var best_page_with_conditions: EventPage = null
	var best_index_with_conditions: int = -1
	var best_page_without_conditions: EventPage = null
	var best_index_without_conditions: int = -1

	# Evaluar páginas en orden inverso (prioridad a las últimas)
	# Esto permite tener una página "por defecto" al inicio y páginas condicionales después
	for i in range(pages.size() - 1, -1, -1):
		var page = pages[i]
		if not page:
			continue

		if page.evaluate_conditions(event_id, self):
			# Esta página cumple las condiciones
			if page.has_conditions():
				# Tiene condiciones y las cumple
				if best_page_with_conditions == null or i > best_index_with_conditions:
					best_page_with_conditions = page
					best_index_with_conditions = i
			else:
				# No tiene condiciones y cumple (siempre cumple si no tiene condiciones)
				if best_page_without_conditions == null or i > best_index_without_conditions:
					best_page_without_conditions = page
					best_index_without_conditions = i

	# Prioridad: páginas con condiciones sobre páginas sin condiciones
	var selected_page: EventPage = null
	var selected_index: int = -1

	if best_page_with_conditions:
		selected_page = best_page_with_conditions
		selected_index = best_index_with_conditions
	elif best_page_without_conditions:
		selected_page = best_page_without_conditions
		selected_index = best_index_without_conditions

	# Si encontramos una página válida, usarla
	if selected_page:
		if current_page_index != selected_index:
			current_page_index = selected_index
			current_page = selected_page
			update_sprite_from_current_page()
			# Actualizar ocupación cuando cambia la página (puede cambiar through)
			_refresh_occupancy()
			print("Event '%s': Página activa cambiada a índice %d" % [name, selected_index])
		else:
			current_page = selected_page
			update_sprite_from_current_page()
			# Actualizar ocupación cuando cambia la página (puede cambiar through)
			_refresh_occupancy()
		return

	# Si todas tienen condiciones y ninguna cumple, no ejecutar ninguna página
	current_page = null
	current_page_index = -1
	print("Event '%s': Ninguna página cumple condiciones, evento desactivado" % name)
	update_sprite_from_current_page()

## Actualiza el sprite y propiedades del evento según la página activa
func update_sprite_from_current_page() -> void:
	if not actor_animator or not actor_animator.sprite:
		return

	if current_page:
		# Aplicar posición de la página si está definida
		if current_page.page_position.x >= 0 and current_page.page_position.y >= 0:
			_apply_page_position(current_page.page_position)

		var style: ActorStyle = current_page.actor_style
		if style:
			actor_animator.apply_style(style)
			actor_animator.set_sprite_offset(current_page.sprite_offset)
			actor_animator.show_sprite()
		else:
			actor_animator.apply_style(null)
			# Usar el método get_sprite_frames() que soporta generación automática
			# Pasar el nodo Event para que pueda detectar si es NPC
			var frames = current_page.get_sprite_frames(self)

			if frames:
				actor_animator.set_sprite_frames(frames)
				actor_animator.set_sprite_offset(current_page.sprite_offset)
				actor_animator.show_sprite()

				# Para eventos normales (no NPCs), mostrar el frame inicial configurado
				# Los NPCs manejan sus propias animaciones (look, idle, etc.)
				if not self.has_method("get_movement_type"):
					# Determinar qué animación y frame mostrar
					var anim_to_show = current_page.initial_animation
					var frame_to_show = max(0, current_page.initial_frame)  # Asegurar que sea >= 0

					# Si no hay animación configurada o no existe, usar "idle" por defecto, o la primera disponible
					if anim_to_show.is_empty() or not frames.has_animation(anim_to_show):
						if frames.has_animation("idle"):
							anim_to_show = "idle"
							frame_to_show = 0
						else:
							var anim_names = frames.get_animation_names()
							if anim_names.size() > 0:
								anim_to_show = anim_names[0]
								frame_to_show = 0

					# Mostrar el frame específico sin reproducir la animación
					if frames.has_animation(anim_to_show):
						var frame_count = frames.get_frame_count(anim_to_show)
						if frame_count > 0:
							frame_to_show = clamp(frame_to_show, 0, frame_count - 1)
							# Establecer la animación primero, luego detener, y finalmente el frame
							# El orden es importante: primero stop(), luego animation, luego frame
							actor_animator.sprite.stop()
							actor_animator.sprite.animation = anim_to_show
							# Establecer el frame inmediatamente
							actor_animator.sprite.frame = frame_to_show
				else:
					# Para NPCs, simplemente mostrar el sprite (ya manejan sus propias animaciones)
					pass
			else:
				# No hay frames, ocultar el sprite (como en NPC.gd)
				actor_animator.hide_sprite()
	else:
		# No hay página activa, ocultar sprite
		actor_animator.hide_sprite()

## Aplica la posición de la página al evento
## Convierte coordenadas de celda a posición del mundo usando el OverworldGrid
## cell_pos son coordenadas reales del TileMapLayer (resultado de local_to_map)
func _apply_page_position(cell_pos: Vector2i) -> void:
	# Buscar el OverworldGrid en la jerarquía
	var grid = _get_grid()
	if not grid:
		push_warning("Event '%s': No se encontró OverworldGrid para aplicar posición de página" % name)
		return

	# Obtener la capa de referencia para acceder al used_rect
	var ref_layer = grid.reference_layer()
	if not ref_layer:
		push_warning("Event '%s': No se encontró capa de referencia para aplicar posición de página" % name)
		return

	# Obtener la celda actual antes de mover para liberar la ocupación
	# Usar global_position para obtener la celda actual (antes de mover)
	var old_tile = grid.world_to_tile(global_position)
	print("Event '%s': Liberando ocupación de celda original: (%d, %d), posición global: (%.1f, %.1f)" % [name, old_tile.x, old_tile.y, global_position.x, global_position.y])

	# Liberar ocupación de la celda anterior (siempre, independientemente de through)
	# Esto es importante porque el evento se registró inicialmente en esta posición
	grid.unregister_event(old_tile, self)
	grid.vacate(old_tile, self)

	# Las coordenadas cell_pos ya son coordenadas reales del TileMapLayer
	# (resultado de local_to_map en la ventana de selección)
	# No necesitamos ajustar, usar directamente

	# Convertir coordenadas de celda reales a posición del mundo
	var world_pos = grid.tile_to_world_center(cell_pos)

	# Aplicar la posición al evento usando global_position
	global_position = world_pos

	# Registrar en la nueva celda (usar global_position después de mover)
	var new_tile = grid.world_to_tile(global_position)
	grid.register_event(new_tile, self)
	if not current_page or not current_page.through:
		grid.occupy(new_tile, self)

	# Actualizar el Occupancy para que use la nueva posición
	# Esto es importante porque register_event_occupancy puede ejecutarse después con call_deferred
	var occupancy_node = get_node_or_null("Occupancy")
	if occupancy_node and occupancy_node.grid:
		# Forzar actualización de la ocupación en la nueva posición
		occupancy_node.refresh_occupancy()

	print("Event '%s': Posición aplicada desde página: celda (%d, %d) -> mundo (%.1f, %.1f), tile anterior: (%d, %d), tile nuevo: (%d, %d)" % [name, cell_pos.x, cell_pos.y, world_pos.x, world_pos.y, old_tile.x, old_tile.y, new_tile.x, new_tile.y])

## Obtiene el OverworldGrid desde la jerarquía del evento
func _get_grid() -> OverworldGrid:
	# Buscar en los padres
	var parent = get_parent()
	while parent:
		if parent is OverworldGrid:
			return parent as OverworldGrid
		# También buscar en los hijos del parent (puede estar en un contenedor)
		if parent.has_method("get_node"):
			var grid = parent.get_node_or_null("OverworldGrid")
			if grid and grid is OverworldGrid:
				return grid as OverworldGrid
		parent = parent.get_parent()

	# Buscar en el grupo
	var grids = get_tree().get_nodes_in_group("OverworldGrid")
	if not grids.is_empty():
		return grids[0] as OverworldGrid

	return null

## Establece el frame inicial de forma diferida para evitar que AnimatedSprite2D lo resetee
func _set_initial_frame_deferred(sprite: AnimatedSprite2D, frame_index: int) -> void:
	if not sprite:
		return
	# Usar call_deferred para establecer el frame después de que la animación esté completamente configurada
	sprite.call_deferred("set", "frame", frame_index)

## Intenta activar el evento con la señal dada
## Retorna true si el evento se activó, false en caso contrario
func try_fire(signal_type: EventTriggerSignal.SignalType, instigator: Node) -> bool:
	# Si el evento está deshabilitado, no se dispara
	if disabled:
		return false

	if not current_page:
		return false

	# Obtener el trigger efectivo de la página
	var page_trigger = current_page.get_effective_trigger()
	if not page_trigger:
		return false

	# Verificar si el trigger puede activarse
	if not page_trigger.can_fire(signal_type, overworld_context, self, instigator):
		return false

	# Activar el evento
	page_trigger.fire(signal_type, overworld_context, self, instigator)
	return true

func trigger() -> void:
	# Si el evento está deshabilitado, no se dispara
	if disabled:
		return

	if current_page:
		print("Event '%s' triggered!" % name)
		event_triggered.emit(current_page)

		# Solicitar la ejecución del evento mediante el contexto
		if overworld_context:
			overworld_context.request_event(self)
		else:
			push_warning("Event '%s': OverworldContext no disponible al solicitar ejecución" % name)

func on_player_action() -> void:
	# Si el jugador pulsa "A" frente al evento
	if current_page:
		try_fire(EventTriggerSignal.SignalType.ACTION, get_tree().get_first_node_in_group("Player"))

func on_player_touch() -> void:
	# Si el jugador entra en la misma celda
	if current_page:
		var player = get_tree().get_first_node_in_group("Player")
		try_fire(EventTriggerSignal.SignalType.TOUCH, player)

func on_player_collision() -> void:
	# Si el jugador colisiona contra el evento (intenta entrar pero no puede)
	if current_page:
		var player = get_tree().get_first_node_in_group("Player")
		try_fire(EventTriggerSignal.SignalType.COLLISION, player)

## Oculta el sprite placeholder (solo se usa en el editor)
func hide_placeholder_sprite() -> void:
	if placeholder_sprite:
		placeholder_sprite.visible = false

## Permite mostrar temporalmente el sprite del evento
func show_sprite() -> void:
	if actor_animator:
		actor_animator.show_sprite()

## Permite ocultar el sprite del evento
func hide_sprite() -> void:
	if actor_animator:
		actor_animator.hide_sprite()

## Cambia a una página específica del evento
func switch_to_page(page_index: int) -> void:
	if page_index >= 0 and page_index < pages.size():
		current_page_index = page_index
		setup_current_page()
		print("Event '%s': Cambiado a página %d" % [name, page_index])

## Cambia al siguiente página del evento
func next_page() -> void:
	var next_index = current_page_index + 1
	if next_index < pages.size():
		switch_to_page(next_index)
	else:
		print("Event '%s': No hay más páginas disponibles" % name)

## Cambia a la página anterior del evento
func previous_page() -> void:
	var prev_index = current_page_index - 1
	if prev_index >= 0:
		switch_to_page(prev_index)
	else:
		print("Event '%s': Ya está en la primera página" % name)

func _to_string() -> String:
	return name


## Actualiza la ocupación del evento en el grid cuando cambia de página
func _refresh_occupancy() -> void:
	# Buscar el nodo Occupancy (si existe)
	var occupancy_node = get_node_or_null("Occupancy")
	if occupancy_node and occupancy_node.has_method("refresh_occupancy"):
		occupancy_node.refresh_occupancy()


## Reevalúa las condiciones y actualiza la página activa
## Se llama automáticamente cuando cambian flags, variables o self-switches
func refresh_active_page() -> void:
	var old_page_index = current_page_index
	setup_current_page()

	# Si cambió de página, puede haber nuevo trigger type
	if old_page_index != current_page_index:
		# Si la nueva página tiene un AutorunTrigger, trigger inmediato
		if current_page:
			var page_trigger = current_page.get_effective_trigger()
			if page_trigger is AutorunTrigger:
				# Disparar con PAGE_ACTIVATED
				call_deferred("_fire_autorun")

## Dispara el autorun cuando la página se activa
func _fire_autorun() -> void:
	# Si el evento está deshabilitado, no se dispara
	if disabled:
		return

	if current_page and overworld_context:
		try_fire(EventTriggerSignal.SignalType.PAGE_ACTIVATED, self)

## Duplica todas las páginas para evitar modificar los Resources originales
## Esto permite que cada instancia del evento tenga sus propias copias que pueden modificarse
## sin afectar el Resource original cacheado por Godot
func _duplicate_all_pages() -> void:
	# Duplicar TODAS las páginas para evitar que eventos duplicados compartan referencias
	# Esto es necesario porque al duplicar un nodo en Godot, los Resources locales
	# (con resource_path == "") se copian por referencia, no por valor
	var duplicated_pages: Array[EventPage] = []
	for page in pages:
		if page:
			var duplicated_page = page.duplicate(true) as EventPage
			# Marcar como local a la escena para que no se guarde como archivo separado
			duplicated_page.take_over_path("")
			duplicated_pages.append(duplicated_page)
		else:
			duplicated_pages.append(null)
	pages = duplicated_pages

## Conecta el evento a las señales globales de cambio de estado
func _connect_to_state_signals() -> void:
	# Conectar directamente a las señales del GameStateService (autoload)
	if not GameStateService.flag_changed.is_connected(_on_state_changed):
		GameStateService.flag_changed.connect(_on_state_changed)
	if not GameStateService.variable_changed.is_connected(_on_state_changed_var):
		GameStateService.variable_changed.connect(_on_state_changed_var)
	if not GameStateService.self_switch_changed.is_connected(_on_state_changed_switch):
		GameStateService.self_switch_changed.connect(_on_state_changed_switch)


## Callback cuando cambia un flag global
func _on_state_changed(flag_name: String, _new_value: bool) -> void:
	# Reevaluar solo si la página actual o alguna página inactiva depende de este flag
	var should_refresh = false
	if current_page and current_page.depends_on_flag(flag_name):
		should_refresh = true
	else:
		for page in pages:
			if page and page.depends_on_flag(flag_name):
				should_refresh = true
				break
	if should_refresh:
		refresh_active_page()


## Callback cuando cambia una variable global
func _on_state_changed_var(variable_name: String, _new_value: Variant) -> void:
	# Reevaluar solo si la página actual o alguna página inactiva depende de esta variable
	var should_refresh = false
	if current_page and current_page.depends_on_variable(variable_name):
		should_refresh = true
	else:
		for page in pages:
			if page and page.depends_on_variable(variable_name):
				should_refresh = true
				break
	if should_refresh:
		refresh_active_page()


## Callback cuando cambia un self-switch
func _on_state_changed_switch(event_id: String, _switch_letter: String, _new_value: bool) -> void:
	# Solo reevaluar si el self-switch pertenece a este evento
	if event_id == _get_event_id():
		refresh_active_page()


## Obtiene un ID único para este evento (usado para self-switches)
## Formato: "mapid_eventname" para evitar colisiones entre eventos con el mismo nombre en diferentes mapas
func _get_event_id() -> String:
	var map_id = GameStateService.get_current_map_id()
	if map_id.is_empty():
		# Si no hay mapa actual, usar solo el nombre (fallback)
		return name
	return "%s_%s" % [map_id, name]

func set_overworld_context(context: OverworldContext) -> void:
	overworld_context = context
	# Re-evaluar la página activa después de recibir el contexto
	# Esto asegura que el event_id se calcula con el map_id correcto
	# (importante cuando se carga un mapa después de un teleport)
	refresh_active_page()
