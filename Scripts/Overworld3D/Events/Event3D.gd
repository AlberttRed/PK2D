@tool
extends Node3D
class_name Event3D
## Equivalente 3D de `Event` (2D).
##
## `@tool`: en el editor SOLO se hace (a) vista previa del `visual_scene` de la página activa y
## (b) snap al centro de celda al mover el nodo. Toda la lógica de juego se salta con
## `Engine.is_editor_hint()` (los autoloads y los scripts no-tool no existen/funcionan en el editor). Reutiliza EventPage / triggers / commands / conditions del sistema 2D.
##
## PBI #962: núcleo + ocupación en celda.
##  - `pages` + selección de página activa (port 1:1 de Event.setup_current_page).
##  - Se ajusta al centro de su celda XZ (conserva Y) y se registra en el OverworldGrid3D del mapa.
##  - Una página no-through (o sin página) bloquea el paso, igual que en 2D.
##  - Visual placeholder (caja + etiqueta) hasta que cada evento tenga su modelo (p.ej. Door3D).
## PBI #963: disparo de triggers (try_fire / trigger / on_player_action / on_player_collision),
## igual que Event 2D. La ejecución real (EventSystem/EventController) llega en #964.

signal event_triggered(page)
signal page_changed(page)

## Lista de páginas (EventPage) con sus comandos; igual que en el Event 2D.
@export var pages: Array[EventPage] = []:
	set(v):
		pages = v
		if Engine.is_editor_hint() and is_node_ready():
			_editor_watch_pages()
			_apply_editor_preview()
@export var current_page_index: int = 0:
	set(v):
		current_page_index = v
		if Engine.is_editor_hint() and is_node_ready():
			_apply_editor_preview()
## Si está deshabilitado, el evento no se disparará (útil para debug)
@export var disabled: bool = false
## Mantener visible el placeholder en juego (en 2D se oculta; en 3D aún no hay sprite/modelo).
@export var show_placeholder_in_game: bool = true:
	set(v):
		show_placeholder_in_game = v
		_apply_placeholder_visibility()

## Empuje del sprite plano hacia la cámara (+Z). Mismo valor por defecto que `Player3D.sprite_back_offset`.
@export var sprite_back_offset: float = ActorSprite3D.DEFAULT_BACK_OFFSET

## Solo editor: ajustar automáticamente la posición al centro de celda XZ al mover el nodo.
@export var snap_to_cell_in_editor: bool = true
## Solo editor: tamaño de celda XZ si no se encuentra el GridMap "Floor" (2 m = 32 px).
@export var editor_cell_size: Vector2 = Vector2(2.0, 2.0)

var current_page: Resource = null
## Solo editor: páginas a las que estamos conectados (señal `changed`) para refrescar la vista previa.
var _editor_watched_pages: Array = []
## Solo editor: `visual_scene` observado; si cambia en disco/recarga, se reconstruye la vista previa.
var _editor_watched_scene: PackedScene = null

# Visual de la página activa (ver `_apply_page_visual`).
var _visual_root: Node3D = null
var _visual_instance: Node3D = null
## Clave de la escena aplicada (ruta o id de instancia); "" si no hay `visual_scene` aplicada.
var _visual_scene_key: String = ""
## Página cuyo sprite plano está aplicado (null si no hay).
var _visual_sprite_page: EventPage = null
var _flat_pivot: Node3D = null
var _flat_sprite: AnimatedSprite3D = null
var _visual_visible: bool = true

## Referencia al contexto del Overworld (se conectará en #963/#964).
var overworld_context: OverworldContext = null

var grid: OverworldGrid3D = null
var _cell: Vector2i = Vector2i.ZERO
var _registered: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_ready()
		return
	# Duplicar páginas para no modificar Resources compartidos (igual que Event 2D).
	_duplicate_all_pages()
	# Los comandos (SetEventThrough, SetActorVisibility...) buscan eventos por nombre en este grupo.
	if not is_in_group("events"):
		add_to_group("events")

	grid = _find_grid()
	if grid == null:
		push_warning("Event3D '%s': no se encontró OverworldGrid3D; el evento no ocupará celda." % name)
	else:
		_cell = grid.world_to_cell(global_position)
		global_position = grid.cell_to_world_center(_cell, global_position.y)
		grid.register_event(_cell, self)
		_registered = true

	_apply_placeholder_visibility()
	setup_current_page()
	_connect_to_state_signals()


# --- Editor (@tool): vista previa + snap a celda ---

func _editor_ready() -> void:
	# Igual que en juego (`_ready` recoloca el evento en el centro de su celda): así el editor
	# muestra la misma posición que verás al ejecutar. Solo dentro de un mapa (con GridMap "Floor")
	# y no si este nodo es la raíz de su propia escena (p.ej. editando Door3D.tscn).
	if snap_to_cell_in_editor and owner != null and _editor_find_floor() != null:
		_snap_to_cell_center_in_editor()
	_editor_watch_pages()
	_apply_editor_preview()
	_apply_placeholder_visibility()
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and snap_to_cell_in_editor \
			and owner != null:
		_snap_to_cell_center_in_editor()


func _editor_watch_pages() -> void:
	for p in _editor_watched_pages:
		if p != null and is_instance_valid(p) and p.changed.is_connected(_apply_editor_preview):
			p.changed.disconnect(_apply_editor_preview)
	_editor_watched_pages.clear()
	for p in pages:
		if p != null:
			p.changed.connect(_apply_editor_preview)
			_editor_watched_pages.append(p)


func _editor_watch_scene(scene: PackedScene) -> void:
	if _editor_watched_scene == scene:
		return
	if _editor_watched_scene != null and is_instance_valid(_editor_watched_scene) \
			and _editor_watched_scene.changed.is_connected(_editor_rebuild_preview):
		_editor_watched_scene.changed.disconnect(_editor_rebuild_preview)
	_editor_watched_scene = scene
	if scene != null:
		scene.changed.connect(_editor_rebuild_preview)


## Fuerza una nueva instancia (p.ej. tras editar DoorVisual.tscn con la escena abierta).
func _editor_rebuild_preview() -> void:
	_clear_visual()
	_apply_editor_preview()


## Instancia en el editor el `visual_scene` de la página `current_page_index` (sin `owner`: no se guarda).
func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var page: Resource = null
	if pages.size() > 0:
		page = pages[clampi(current_page_index, 0, pages.size() - 1)]
	var scene: PackedScene = null
	if page != null:
		scene = page.get("visual_scene") as PackedScene
	_editor_watch_scene(scene)
	if scene == null:
		_clear_visual()
		_apply_placeholder_visibility()
		return

	var root := _ensure_visual_root()
	var key: String = scene.resource_path
	if key.is_empty():
		key = "instance:%d" % scene.get_instance_id()
	if _visual_scene_key != key or not has_visual():
		_clear_visual()
		var instance := scene.instantiate() as Node3D
		if instance == null:
			return
		root.add_child(instance)
		_visual_instance = instance
		_visual_scene_key = key
	var offset: Vector3 = page.get("visual_offset")
	var yaw: float = page.get("visual_yaw_degrees")
	_visual_instance.position = offset
	_visual_instance.rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
	_apply_placeholder_visibility()


## GridMap "Floor" del mapa (hermano del OverworldGrid3D), o null.
func _editor_find_floor() -> GridMap:
	var p := get_parent()
	while p != null:
		var g := p.get_node_or_null("Floor") as GridMap
		if g != null:
			return g
		p = p.get_parent()
	return null


## Mismo cálculo que `OverworldGrid3D.cell_to_world_center` (esquina de celda + medio tamaño).
func _snap_to_cell_center_in_editor() -> void:
	if not is_inside_tree():
		return
	var p := global_position
	var target := p
	var floor_grid := _editor_find_floor()
	if floor_grid != null:
		var cs := floor_grid.cell_size
		var l := floor_grid.to_local(p)
		var snapped_local := Vector3(
			floorf(l.x / cs.x) * cs.x + cs.x * 0.5,
			l.y,
			floorf(l.z / cs.z) * cs.z + cs.z * 0.5)
		target = floor_grid.to_global(snapped_local)
	else:
		var cs2 := editor_cell_size
		target = Vector3(
			floorf(p.x / cs2.x) * cs2.x + cs2.x * 0.5,
			p.y,
			floorf(p.z / cs2.y) * cs2.y + cs2.y * 0.5)
	target.y = p.y
	if not p.is_equal_approx(target):
		global_position = target


func _exit_tree() -> void:
	if grid != null and is_instance_valid(grid) and _registered:
		grid.unregister_event(_cell, self)
		_registered = false


func _find_grid() -> OverworldGrid3D:
	var p := get_parent()
	while p != null:
		if p is OverworldGrid3D:
			return p as OverworldGrid3D
		p = p.get_parent()
	return get_tree().get_first_node_in_group(OverworldGrid3D.GROUP) as OverworldGrid3D


# --- Celda / ocupación ---

func current_cell() -> Vector2i:
	return _cell


## true si el evento bloquea el paso (página no-through o sin página activa, como en 2D).
func blocks_movement() -> bool:
	return current_page == null or not current_page.through


## Mueve el evento a otra celda XZ (conserva Y) y actualiza el registro.
func move_to_cell(cell: Vector2i) -> void:
	if grid == null:
		return
	if _registered:
		grid.unregister_event(_cell, self)
	_cell = cell
	global_position = grid.cell_to_world_center(_cell, global_position.y)
	grid.register_event(_cell, self)
	_registered = true


# --- Páginas (port de Event.gd, sin la parte de sprite 2D) ---

## Configura current_page evaluando las condiciones de todas las páginas.
func setup_current_page() -> void:
	if pages.size() == 0:
		current_page = null
		current_page_index = 0
		_on_page_applied()
		return

	var event_id := _get_event_id()
	var best_page_with_conditions: EventPage = null
	var best_index_with_conditions: int = -1
	var best_page_without_conditions: EventPage = null
	var best_index_without_conditions: int = -1

	# Orden inverso (prioridad a las últimas páginas).
	for i in range(pages.size() - 1, -1, -1):
		var page = pages[i]
		if not page:
			continue
		if page.evaluate_conditions(event_id, self):
			if page.has_conditions():
				if best_page_with_conditions == null or i > best_index_with_conditions:
					best_page_with_conditions = page
					best_index_with_conditions = i
			else:
				if best_page_without_conditions == null or i > best_index_without_conditions:
					best_page_without_conditions = page
					best_index_without_conditions = i

	# Prioridad: páginas con condiciones sobre páginas sin condiciones.
	var selected_page: EventPage = null
	var selected_index: int = -1
	if best_page_with_conditions:
		selected_page = best_page_with_conditions
		selected_index = best_index_with_conditions
	elif best_page_without_conditions:
		selected_page = best_page_without_conditions
		selected_index = best_index_without_conditions

	if selected_page:
		current_page_index = selected_index
		current_page = selected_page
	else:
		# Todas con condiciones y ninguna cumple: evento desactivado.
		current_page = null
		current_page_index = -1
	_on_page_applied()


## Aplica efectos de la página activa (posición y visual de la página).
func _on_page_applied() -> void:
	if current_page and current_page.page_position != Vector2i(-1, -1):
		# Solo "no definida" si es exactamente (-1, -1): las celdas pueden ser negativas.
		move_to_cell(current_page.page_position)
	_apply_page_visual()
	page_changed.emit(current_page)


# --- Visual por página (PBI #974) ---
# El modelo NO forma parte de la estructura del Event3D: lo informa cada EventPage.
#  1) `visual_scene` (PackedScene/.glb) → se instancia bajo el nodo "Visual".
#  2) Si no hay, `sprite_frames`/textura → sprite plano con la misma altura/tilt que el Player3D.
#  3) Si no hay nada, se muestra el placeholder (si `show_placeholder_in_game`).
# La misma escena entre páginas NO se reinstancia (una puerta abierta no reinicia su animación).

func _apply_page_visual() -> void:
	var page := current_page as EventPage
	if page == null:
		_clear_visual()
		_apply_placeholder_visibility()
		return

	if page.visual_scene != null:
		_apply_scene_visual(page)
	else:
		var frames := page.get_sprite_frames(self)
		if frames != null:
			_apply_flat_sprite_visual(page, frames)
		else:
			_clear_visual()
	_apply_placeholder_visibility()


func _ensure_visual_root() -> Node3D:
	if _visual_root == null or not is_instance_valid(_visual_root):
		_visual_root = Node3D.new()
		_visual_root.name = "Visual"
		_visual_root.visible = _visual_visible
		add_child(_visual_root)
	return _visual_root


func _clear_visual() -> void:
	if _visual_instance != null and is_instance_valid(_visual_instance):
		var parent := _visual_instance.get_parent()
		if parent != null:
			parent.remove_child(_visual_instance)
		_visual_instance.queue_free()
	_visual_instance = null
	_visual_scene_key = ""
	_visual_sprite_page = null
	_flat_sprite = null
	_flat_pivot = null


func _apply_scene_visual(page: EventPage) -> void:
	var root := _ensure_visual_root()
	# Clave por ruta: aunque las páginas se dupliquen, la misma escena no se reinstancia.
	var key: String = page.visual_scene.resource_path
	if key.is_empty():
		key = "instance:%d" % page.visual_scene.get_instance_id()
	if _visual_scene_key != key or _visual_instance == null or not is_instance_valid(_visual_instance):
		_clear_visual()
		var instance := page.visual_scene.instantiate() as Node3D
		if instance == null:
			push_warning("Event3D '%s': visual_scene debe tener un Node3D como raíz." % name)
			return
		root.add_child(instance)
		_visual_instance = instance
		_visual_scene_key = key
		show_sprite()
	_visual_instance.position = page.visual_offset
	_visual_instance.rotation = Vector3(0.0, deg_to_rad(page.visual_yaw_degrees), 0.0)


func _apply_flat_sprite_visual(page: EventPage, frames: SpriteFrames) -> void:
	var root := _ensure_visual_root()
	# Misma página ya aplicada (p.ej. refresco por un flag que no cambia de página): no resetear el frame.
	if _visual_sprite_page == page and _flat_sprite != null and is_instance_valid(_flat_sprite):
		return
	_clear_visual()

	var pivot := Node3D.new()
	pivot.name = "FlatSprite"
	var sprite := AnimatedSprite3D.new()
	sprite.name = "AnimatedSprite3D"
	pivot.add_child(sprite)
	root.add_child(pivot)
	_visual_instance = pivot
	_flat_pivot = pivot
	_flat_sprite = sprite
	_visual_sprite_page = page
	show_sprite()

	var frame_px := _frame_pixels_for(page, frames)
	var cell_size := grid.cell_size().x if grid != null else 2.0
	var extra_offset := page.sprite_offset if page.sprite_offset_configured else Vector2.ZERO
	ActorSprite3D.setup(pivot, sprite, cell_size, ActorSprite3D.DEFAULT_TILE_PIXELS, frame_px,
		sprite_back_offset, extra_offset)
	sprite.sprite_frames = frames
	_show_initial_frame(page, frames, sprite)


## Tamaño de frame en píxeles: el de la textura real del primer frame; si no, el de la página.
func _frame_pixels_for(page: EventPage, frames: SpriteFrames) -> Vector2:
	for anim in frames.get_animation_names():
		if frames.get_frame_count(anim) > 0:
			var tex := frames.get_frame_texture(anim, 0)
			if tex != null:
				return tex.get_size()
	return page.frame_size


## Equivalente 3D de la parte "frame inicial" de Event.update_sprite_from_current_page.
func _show_initial_frame(page: EventPage, frames: SpriteFrames, sprite: AnimatedSprite3D) -> void:
	var anim := page.initial_animation
	var frame := maxi(0, page.initial_frame)
	if anim.is_empty() or not frames.has_animation(anim):
		if frames.has_animation("idle"):
			anim = "idle"
			frame = 0
		else:
			var names := frames.get_animation_names()
			if names.size() == 0:
				return
			anim = names[0]
			frame = 0
	var count := frames.get_frame_count(anim)
	if count <= 0:
		return
	sprite.stop()
	sprite.animation = anim
	sprite.frame = clampi(frame, 0, count - 1)


## true si la página activa muestra un visual (escena o sprite plano).
func has_visual() -> bool:
	return _visual_instance != null and is_instance_valid(_visual_instance)


## Raíz del visual activo (instancia de `visual_scene` o pivote del sprite plano), o null.
func get_visual() -> Node3D:
	return _visual_instance if has_visual() else null


## Sprite plano activo (solo si la página usa sprite_frames), o null.
func get_flat_sprite() -> AnimatedSprite3D:
	return _flat_sprite if _flat_sprite != null and is_instance_valid(_flat_sprite) else null


## AnimationPlayer del visual activo (para PlayAnimationCommand), o null.
func get_animation_player() -> AnimationPlayer:
	var v := get_visual()
	return _find_animation_player(v) if v != null else null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


## Equivalentes a Event.show_sprite()/hide_sprite() (SetActorVisibilityCommand).
func show_sprite() -> void:
	_visual_visible = true
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.visible = true


func hide_sprite() -> void:
	_visual_visible = false
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.visible = false


# --- Triggers (port de Event.gd) ---

## Intenta activar el evento con la señal dada. Retorna true si se activó.
func try_fire(signal_type: EventTriggerSignal.SignalType, instigator: Node) -> bool:
	# `disabled` solo bloquea eventos en debug_mode.
	if _is_runtime_disabled():
		return false
	if not current_page:
		return false

	var page_trigger = current_page.get_effective_trigger()
	if not page_trigger:
		return false

	if not page_trigger.can_fire(signal_type, overworld_context, self, instigator):
		return false

	page_trigger.fire(signal_type, overworld_context, self, instigator)
	return true


## Llamado por EventTrigger.fire(). Solicita la ejecución mediante el contexto (#964).
func trigger() -> void:
	if _is_runtime_disabled():
		return
	if current_page:
		print("Event3D '%s' triggered!" % name)
		event_triggered.emit(current_page)
		if overworld_context:
			overworld_context.request_event(self)


## El jugador pulsa "interact" frente al evento.
func on_player_action() -> void:
	if current_page:
		try_fire(EventTriggerSignal.SignalType.ACTION, get_tree().get_first_node_in_group("Player"))


## El jugador entra en la celda del evento (p.ej. tras un warp): trigger TOUCH.
func on_player_touch() -> void:
	if current_page:
		try_fire(EventTriggerSignal.SignalType.TOUCH, get_tree().get_first_node_in_group("Player"))


## El jugador intenta entrar en la celda del evento pero choca.
func on_player_collision() -> void:
	if current_page:
		try_fire(EventTriggerSignal.SignalType.COLLISION, get_tree().get_first_node_in_group("Player"))


func switch_to_page(page_index: int) -> void:
	if page_index >= 0 and page_index < pages.size():
		current_page_index = page_index
		setup_current_page()


func next_page() -> void:
	var next_index := current_page_index + 1
	if next_index < pages.size():
		switch_to_page(next_index)


func previous_page() -> void:
	var prev_index := current_page_index - 1
	if prev_index >= 0:
		switch_to_page(prev_index)


## Reevalúa condiciones y actualiza la página activa (llamado al cambiar flags/variables/self-switches).
## El autorun al cambiar de página se añadirá junto a los triggers (#963/#964).
func refresh_active_page() -> void:
	setup_current_page()


func set_overworld_context(context: OverworldContext) -> void:
	var had_context := overworld_context != null
	overworld_context = context
	if not had_context:
		refresh_active_page()


## ID único para self-switches: "mapid_eventname" (map id = padre del OverworldGrid3D).
func _get_event_id() -> String:
	if grid != null:
		var map_id := grid.get_map_id()
		if not map_id.is_empty():
			return "%s_%s" % [map_id, name]
	var current_map_id := GameStateService.get_current_map_id()
	if current_map_id.is_empty():
		return name
	return "%s_%s" % [current_map_id, name]


func _is_runtime_disabled() -> bool:
	return disabled and GameStateService.debug_mode


func _to_string() -> String:
	return name


func _apply_placeholder_visibility() -> void:
	var ph := get_node_or_null("Placeholder") as Node3D
	if ph != null:
		# El placeholder solo se muestra cuando la página activa no tiene visual.
		if Engine.is_editor_hint():
			ph.visible = not has_visual()
		else:
			ph.visible = show_placeholder_in_game and not has_visual()
		var label := ph.get_node_or_null("Label3D") as Label3D
		if label != null:
			label.text = String(name)


# --- Estado global (mismas señales que Event 2D) ---

func _duplicate_all_pages() -> void:
	var duplicated_pages: Array[EventPage] = []
	for page in pages:
		if page:
			var duplicated_page := page.duplicate(true) as EventPage
			duplicated_page.take_over_path("")
			duplicated_pages.append(duplicated_page)
		else:
			duplicated_pages.append(null)
	pages = duplicated_pages


func _connect_to_state_signals() -> void:
	if not GameStateService.flag_changed.is_connected(_on_state_changed):
		GameStateService.flag_changed.connect(_on_state_changed)
	if not GameStateService.variable_changed.is_connected(_on_state_changed_var):
		GameStateService.variable_changed.connect(_on_state_changed_var)
	if not GameStateService.self_switch_changed.is_connected(_on_state_changed_switch):
		GameStateService.self_switch_changed.connect(_on_state_changed_switch)
	if not GameStateService.trainer_battle_result_changed.is_connected(_on_trainer_battle_result_changed):
		GameStateService.trainer_battle_result_changed.connect(_on_trainer_battle_result_changed)


func _any_page_depends(check: Callable) -> bool:
	if current_page and check.call(current_page):
		return true
	for page in pages:
		if page and check.call(page):
			return true
	return false


func _on_state_changed(flag_name: String, _new_value: bool) -> void:
	if is_inside_tree() and _any_page_depends(func(p): return p.depends_on_flag(flag_name)):
		refresh_active_page()


func _on_state_changed_var(variable_name: String, _new_value: Variant) -> void:
	if is_inside_tree() and _any_page_depends(func(p): return p.depends_on_variable(variable_name)):
		refresh_active_page()


func _on_state_changed_switch(event_id: String, _switch_letter: String, _new_value: bool) -> void:
	if event_id == _get_event_id() and is_inside_tree():
		refresh_active_page()


func _on_trainer_battle_result_changed(trainer_id: String, _result: String) -> void:
	if is_inside_tree() and _any_page_depends(func(p): return p.depends_on_trainer(trainer_id)):
		refresh_active_page()
