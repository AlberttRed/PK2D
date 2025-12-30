extends CanvasLayer
class_name DisplayManager

## DisplayManager - Sistema centralizado para gestionar toda la UI del juego
## Reemplaza al antiguo GUI y actúa como singleton accesible globalmente

# === SINGLETON ===
static var instance: DisplayManager = null

# === SEÑALES ===
signal input
signal selected_choice
signal battle_started()
signal battle_finished(winner_side: String)
signal messagebox_input_accept
signal messagebox_input_cancel
signal hide_overworld_messagebox
signal input_accept
signal input_cancel
signal input_start
signal input_left
signal input_right
signal input_up
signal input_down
signal player_control_blocked
signal player_control_unblocked
signal portrait_box_closed

# === CONSTANTES ===
const MO_OVERLAY_SCENE: PackedScene = preload("res://Scenes/UI/Overlays/MOOverlay.tscn")
const PORTRAIT_BOX_SCENE: PackedScene = preload("res://Scenes/UI/PortraitBox.tscn")

# === VARIABLES ===
var fading: bool = false
var next = false
var input_locked := false
var pressed_actions := {}
var choices_options = null
var _mo_animation_count: int = 0  # Contador de animaciones MO activas (puede haber múltiples simultáneas)
var _current_portrait_box: PortraitBox = null  # Referencia al PortraitBox actual

# === NODOS ===
@onready var msg: MessageBox = $MSG
@onready var choice_box: ChoiceBox = $ChoiceBox
@onready var BattleNew: BattleScene = $BattleNew
@onready var pause_menu = $PauseMenu
@onready var overlay_layer: OverlayLayer = $OverlayLayer
@onready var fade_layer: ColorRect = $FadeLayer

# === INICIALIZACIÓN ===
func _ready() -> void:
	# Registrar como singleton
	if instance != null:
		push_error("DisplayManager: Ya existe una instancia. Solo debe haber una.")
		queue_free()
		return

	instance = self

	# Configurar para que continúe procesando aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Configurar todos los elementos de UI para que continúen procesando cuando el árbol esté pausado
	msg.process_mode = Node.PROCESS_MODE_ALWAYS
	choice_box.process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	BattleNew.process_mode = Node.PROCESS_MODE_ALWAYS

	# Conectar señales del MessageBox
	msg.finished.connect(_on_message_finished)
	# Conectar señal de visibilidad del MessageBox
	if msg.has_signal("visibility_changed"):
		msg.visibility_changed.connect(_on_ui_visibility_changed)

	# Conectar señales del ChoiceBox
	if choice_box.has_signal("visibility_changed"):
		choice_box.visibility_changed.connect(_on_ui_visibility_changed)

	# Conectar señales del PauseMenu
	if pause_menu:
		pause_menu.pokedex_requested.connect(_on_pause_pokedex_requested)
		pause_menu.party_requested.connect(_on_pause_party_requested)
		pause_menu.bag_requested.connect(_on_pause_bag_requested)
		pause_menu.player_requested.connect(_on_pause_player_requested)
		pause_menu.save_requested.connect(_on_pause_save_requested)
		pause_menu.options_requested.connect(_on_pause_options_requested)
		pause_menu.exit_requested.connect(_on_pause_exit_requested)
		pause_menu.menu_closed.connect(_on_pause_menu_closed)
		if pause_menu.has_signal("visibility_changed"):
			pause_menu.visibility_changed.connect(_on_ui_visibility_changed)

	# Conectar señal de visibilidad de BattleNew
	if BattleNew.has_signal("visibility_changed"):
		BattleNew.visibility_changed.connect(_on_ui_visibility_changed)

	if overlay_layer:
		overlay_layer.reset_to_defaults()

	# Conectar señales de GridMotion del Player para saltos de ledge
	call_deferred("_connect_player_motion_signals")

	# Verificar estado inicial de pausa
	call_deferred("_update_game_pause_state")

# === API PÚBLICA ESTÁTICA (Métodos globales) ===
## Muestra un mensaje con configuración específica
static func show_message(text: String, config: Dictionary = {}) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._show_message_with_config(text, config)

## Muestra opciones y devuelve el índice seleccionado
static func show_choices(options: Array[String]) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._show_choices(options)

## Muestra un mensaje seguido de opciones
## close_at_end: Si true, cierra el MessageBox después de la selección. Si false, lo mantiene visible.
static func show_message_with_choices(text: String, options: Array[String], close_at_end: bool = true) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._show_message_with_choices(text, options, close_at_end)

## Cierra el MessageBox del overworld si está visible
static func close_message() -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	instance._close_message()

## Hace fade out (de visible a negro)
static func fade_out(duration: float = 0.3) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance.fade_layer.fade_out(duration)

## Hace fade in (de negro a visible)
static func fade_in(duration: float = 0.3) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance.fade_layer.fade_in(duration)

## Verifica si está en fade
static func is_fading() -> bool:
	if instance == null:
		return false
	return instance._is_fading()

## Inicia una batalla y devuelve el ganador
static func start_battle(participants: Array[BattleParticipant], rules: BattleRules, from_event: bool = false) -> String:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return ""
	return await instance._start_battle(participants, rules, from_event)

## Ejecuta la transición de entrada a batalla con efecto de máscara
static func play_battle_transition(texture_path: String, duration: float = 1.5) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance.fade_layer.play_battle_transition(texture_path, duration)

## Revela la escena de batalla con efecto de transición inversa
static func reveal_battle(duration: float = 0.4) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance.fade_layer.reveal_battle(duration)

## Cierra el portrait box actual si está visible
static func close_portrait_box() -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	instance._close_portrait_box()

## Muestra un portrait box con una imagen (Pokémon o Texture2D)
## @param image_source: ShowPortraitCommand.ImageSource (POKEMON o TEXTURE)
## @param image_data: Texture2D o AtlasTexture con la imagen a mostrar
## @param frame_style: Estilo de marco del MessageBox
## @param position: Posición de la caja (LEFT, RIGHT, CENTER)
## @param close_mode: Modo de cierre (WAIT_INPUT, AUTO_TIME, NO_CLOSE)
## @param auto_close_time: Tiempo de cierre automático (solo si close_mode es AUTO_TIME)
## @param scale_mode: Modo de escala (PIXEL_PERFECT, FIT_BOX)
## @param z_index_offset: Offset de z_index
static func show_portrait_box(
	image_source: int,
	image_data: Texture2D,
	frame_style: int,
	position: int,
	close_mode: int,
	auto_close_time: float = 0.0,
	scale_mode: int = 0,
	z_index_offset: int = 0
) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._show_portrait_box(
		image_source,
		image_data,
		frame_style,
		position,
		close_mode,
		auto_close_time,
		scale_mode,
		z_index_offset
	)

## ========================
## OVERLAY API
## ========================

static func get_overlay_layer() -> OverlayLayer:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return null
	return instance.overlay_layer

static func set_overlay_darkness(level: float, duration: float = 0.3) -> void:
	var overlay := get_overlay_layer()
	if overlay == null:
		return
	overlay.set_darkness(level, duration)

static func set_overlay_weather(weather_type: String) -> void:
	var overlay := get_overlay_layer()
	if overlay == null:
		return
	overlay.set_weather(weather_type)

static func reset_overlay() -> void:
	var overlay := get_overlay_layer()
	if overlay == null:
		return
	overlay.reset_to_defaults()

static func play_flash_reveal(target_darkness: float, duration: float = 0.55) -> void:
	var overlay := get_overlay_layer()
	if overlay == null:
		push_warning("DisplayManager: OverlayLayer no disponible para animar DESTELLO")
		return
	await overlay.play_flash_reveal(target_darkness, duration)

static func play_mo_overlay(pokemon_visual: Variant = null) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._play_mo_overlay(pokemon_visual)

static func set_overlay_flashlight(enabled: bool, config: Dictionary = {}) -> void:
	var overlay := get_overlay_layer()
	if overlay == null:
		return
	var radius: float = float(config.get("radius", -1.0))
	var softness: float = float(config.get("softness", -1.0))
	overlay.set_flashlight_enabled(enabled, radius, softness)
	if config.has("center"):
		var center_value = config["center"]
		if center_value is Vector2:
			overlay.set_flashlight_center_screen(center_value)

static func set_overlay_flashlight_center(center: Vector2) -> void:
	var overlay := get_overlay_layer()
	if overlay == null:
		return
	overlay.set_flashlight_center_screen(center)

## Solicita ocultar el MessageBox del overworld durante transiciones (p.ej. FadeLayer)
static func request_hide_overworld_messagebox() -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	instance._handle_hide_overworld_messagebox()

# === MÉTODOS DE INSTANCIA PRIVADOS ===
## Métodos internos (no llamar directamente, usar la API estática)

func _show_message_with_config(text: String, config: Dictionary = {}) -> void:
	await msg.show_custom(text, config)

func _show_choices(options: Array[String]) -> int:
	if options.is_empty():
		push_error("DisplayManager._show_choices: Array de opciones vacío")
		return -1

	var selected_index = await choice_box.show_choices(options)

	return selected_index

func _show_message_with_choices(text: String, options: Array[String], close_at_end: bool = true) -> int:
	if options.is_empty():
		push_error("DisplayManager._show_message_with_choices: Array de opciones vacío")
		return -1

	# Mostrar el mensaje sin esperar input y sin cerrar
	# Con waitInput: false, show_custom espera a que el texto se escriba pero no espera input
	await msg.show_custom(text, {
		"waitInput": false,
		"closeAtEnd": false,
		"waitTime": 0.0,
		"showIconAtEnd": false
	})

	# Pequeña pausa adicional para que el mensaje sea legible
	await get_tree().create_timer(0.3).timeout

	# Mostrar las opciones (el MessageBox permanece visible de fondo)
	var selected_index = await choice_box.show_choices(options)

	# Cerrar el MessageBox después de la selección solo si close_at_end es true
	if close_at_end:
		msg.hide()
		msg.clear()

	return selected_index

func _close_message() -> void:
	if msg.visible:
		msg.hide()
		msg.clear()

func _is_fading() -> bool:
	return fading or (fade_layer != null and fade_layer.is_fade_active())

func _is_visible() -> bool:
	return msg.visible || BattleNew.visible || choice_box.visible || (pause_menu != null && pause_menu.visible)

## Método privado para iniciar batalla
## from_event: true si el combate fue iniciado desde un evento (no desbloquear control al terminar)
func _start_battle(participants: Array[BattleParticipant], rules: BattleRules, from_event: bool = false) -> String:
	print("DisplayManager: Iniciando batalla... (from_event: %s)" % from_event)

	# Guardar si el combate fue iniciado desde un evento
	_battle_from_event = from_event

	# Bloquear control del jugador al iniciar batalla
	player_control_blocked.emit()

	# Separar participantes en player y enemy
	var player_participants: Array[BattleParticipant] = []
	var enemy_participants: Array[BattleParticipant] = []

	for participant in participants:
		if participant.is_player:
			player_participants.append(participant)
		else:
			enemy_participants.append(participant)

	# Emitir señal de inicio de batalla
	battle_started.emit()

	# Mostrar la escena de batalla
	BattleNew.visible = true

	# Iniciar el combate y esperar resultado
	await BattleNew.start_battle(player_participants, enemy_participants, rules)

	# La batalla ya terminó, ahora manejar el cierre
	# (BattleController invoca DisplayManager._on_battle_finished)
	# Esperamos a que _on_battle_finished complete el fade out
	var winner = await _wait_for_battle_cleanup()

	return winner

## Espera a que termine el cleanup de batalla y devuelve el ganador
var _battle_winner: String = ""
var _battle_cleanup_done: bool = false
var _battle_from_event: bool = false  # Indica si el combate fue iniciado desde un evento

func _wait_for_battle_cleanup() -> String:
	# Esperar a que _on_battle_finished termine
	while not _battle_cleanup_done:
		await get_tree().process_frame

	_battle_cleanup_done = false
	return _battle_winner

# === MÉTODOS DE INSTANCIA LEGACY (compatibilidad) ===
func setMessageBox(msgBox: MessageBox) -> void:
	if self.msg != null:
		self.msg.clear()
	msgBox.setText("")
	self.msg = msgBox

func resetMessageBox() -> void:
	if self.msg != null:
		self.msg.clear()
	self.msg = $MSG

func showMessageInput(text: String) -> void:
	self.msg.waitInput = true
	await self.msg.showMessage(text)

func showMessageWait(text: String, waitTime: float) -> void:
	msg.waitTime = waitTime
	await msg.showMessage(text)

func showMessageNoClose(text: String) -> void:
	msg.closeAtEnd = false
	await msg.showMessage(text)

func showMsg(text: String, showIcon: bool = true, _waitTime: float = 0.0, waitInput: bool = false) -> void:
	msg.show_msgBattle(text, showIcon, _waitTime, waitInput)
	await msg.finished

func show_msg(text = "", wait = null, obj = null, sig = "", _choices_options = [], _close = true) -> void:
	msg.connect("finished", Callable(self, "close_msg"))
	choices_options = _choices_options
	var choices = []
	var close = _close
	if choices_options != [] and choices_options != null:
		choices = _choices_options[0]
		if choices != null and choices != []:
			close = false
			msg.disconnect("finished", Callable(self, "close_msg"))
			msg.connect("finished", Callable(self, "show_choices"))

	msg.show_msg(text, wait, obj, sig, close)

func add_choice_cmd(c) -> void:
	selected_choice.emit(c)

func close_msg() -> void:
	if msg.is_connected("finished", Callable(self, "show_choices")):
		msg.disconnect("finished", Callable(self, "show_choices"))

	if msg.is_connected("finished", Callable(self, "close_msg")):
		msg.disconnect("finished", Callable(self, "close_msg"))
	input.emit()

func clear_msg() -> void:
	msg.clear_msg()

func clear_choices() -> void:
	msg.clear_msg()

func isVisible() -> bool:
	return _is_visible()

func isFading() -> bool:
	return _is_fading()

func _on_message_finished() -> void:
	# Asegurar que no queden flags de pulsación retenidos tras cerrar el mensaje
	pressed_actions.clear()

func _handle_hide_overworld_messagebox() -> void:
	hide_overworld_messagebox.emit()
	_on_hide_overworld_messagebox()

func _on_hide_overworld_messagebox() -> void:
	print("DisplayManager: Limpiando y ocultando MessageBox del overworld")
	msg.cleanup_and_hide()

func _on_battle_finished(_winner_side: String) -> void:
	print("DisplayManager: Batalla terminada, iniciando transición de salida...")

	# Guardar el ganador
	_battle_winner = _winner_side

	# Hacer fade in (a negro) para ocultar la batalla
	await fade_layer.fade_in(0.3)

	# Ocultar la escena de batalla
	BattleNew.cleanup_battle()

	# Hacer fade out para revelar el overworld
	await fade_layer.fade_out(0.3)

	# Emitir señal de batalla terminada (señal de DisplayManager)
	battle_finished.emit(_winner_side)

	# Solo desbloquear control del jugador si el combate NO fue iniciado desde un evento
	# Si fue desde un evento, el EventController se encargará de desbloquear cuando termine
	if not _battle_from_event:
		player_control_unblocked.emit()
		print("DisplayManager: Combate no iniciado desde evento, desbloqueando control del jugador")
	else:
		print("DisplayManager: Combate iniciado desde evento, NO desbloqueando control (EventController lo manejará)")

	# Marcar cleanup como completado
	_battle_cleanup_done = true

func _play_mo_overlay(pokemon_visual: Variant) -> void:
	if MO_OVERLAY_SCENE == null:
		push_error("DisplayManager: Escena de MOOverlay no disponible")
		return

	var overlay = MO_OVERLAY_SCENE.instantiate()
	if overlay == null:
		push_error("DisplayManager: No se pudo instanciar MOOverlay")
		return

	add_child(overlay)

	# Conectar señales para rastrear cuando empieza/termina la animación
	if overlay.has_signal("mo_animation_started"):
		overlay.mo_animation_started.connect(_on_mo_animation_started)
	if overlay.has_signal("mo_animation_finished"):
		overlay.mo_animation_finished.connect(_on_mo_animation_finished)

	var previous_input_locked := input_locked
	input_locked = true

	await overlay.play(pokemon_visual)

	if is_instance_valid(overlay):
		overlay.queue_free()

	input_locked = previous_input_locked

## Método privado para mostrar el portrait box
func _show_portrait_box(
	_image_source: int,  # No se usa directamente, pero se mantiene para compatibilidad con la firma
	image_data: Texture2D,
	frame_style: int,
	position: int,
	close_mode: int,
	auto_close_time: float,
	scale_mode: int,
	z_index_offset: int
) -> void:
	if PORTRAIT_BOX_SCENE == null:
		push_error("DisplayManager: Escena de PortraitBox no disponible")
		return

	# Si ya hay un portrait box visible, cerrarlo primero
	if _current_portrait_box and is_instance_valid(_current_portrait_box):
		_current_portrait_box.close()
		await _current_portrait_box.closed

	# Instanciar el portrait box
	var portrait_box = PORTRAIT_BOX_SCENE.instantiate()
	if portrait_box == null:
		push_error("DisplayManager: No se pudo instanciar PortraitBox")
		return

	add_child(portrait_box)
	_current_portrait_box = portrait_box

	# Configurar el portrait box
	portrait_box.setup(
		image_data,
		frame_style as MessageBoxFrameStyle.Values,
		position as PortraitBox.Position,
		close_mode as PortraitBox.CloseMode,
		auto_close_time,
		scale_mode as PortraitBox.ScaleMode,
		z_index_offset,
		Vector2.ZERO  # Tamaño personalizado (Vector2.ZERO = usar tamaño por defecto)
	)

	# Conectar señal de cierre
	portrait_box.closed.connect(_on_portrait_box_closed)

	# Conectar señal de visibilidad para el sistema de pausa
	if portrait_box.has_signal("visibility_changed"):
		portrait_box.visibility_changed.connect(_on_ui_visibility_changed)

	# Solo esperar cierre si no es modo NO_CLOSE
	var portrait_close_mode = close_mode as PortraitBox.CloseMode
	if portrait_close_mode != PortraitBox.CloseMode.NO_CLOSE:
		# Esperar a que se cierre
		await portrait_box.closed
	else:
		# En modo NO_CLOSE, no esperar - el portrait box permanece visible
		# hasta que se llame a close_portrait_box()
		pass

## Callback cuando se cierra el portrait box
func _on_portrait_box_closed() -> void:
	portrait_box_closed.emit()

	# Limpiar referencia si existe
	if is_instance_valid(_current_portrait_box):
		_current_portrait_box.queue_free()
	_current_portrait_box = null

## Método privado para cerrar el portrait box actual
func _close_portrait_box() -> void:
	if _current_portrait_box and is_instance_valid(_current_portrait_box):
		_current_portrait_box.close()

# === INPUT ===
func _input(event: InputEvent) -> void:
	# Registrar liberaciones SIEMPRE
	if event is InputEventKey and !event.pressed:
		for action in ["ui_accept", "ui_cancel", "ui_start", "ui_up", "ui_down", "ui_right", "ui_left"]:
			if InputMap.event_is_action(event, action):
				pressed_actions.erase(action)

	# Si el foco está en BattleUI, no consumir el input
	if $BattleNew.visible:
		var focus_owner = get_viewport().gui_get_focus_owner()
		var battle_ui = $BattleNew/BattleUI
		if battle_ui != null and focus_owner != null and battle_ui.is_ancestor_of(focus_owner):
			return

	# Procesar ui_start ANTES del check de isVisible() para poder abrir el menú
	if event.is_action_pressed("ui_start") and !pressed_actions.has("ui_start"):
		pressed_actions["ui_start"] = true
		print("DisplayManager start")
		# Si el menú de pausa no está visible, intentar abrirlo
		if pause_menu and not pause_menu.visible:
			# Verificar si el jugador está en movimiento - no abrir menú si está moviéndose
			var player = get_tree().get_first_node_in_group("Player")
			if player and player.has_node("GridMotion"):
				var motion = player.get_node("GridMotion")
				if motion.moving:
					# El jugador está en movimiento, ignorar el input de ESC
					return

			# Solo abrir si no estamos en batalla y no hay otros menús abiertos
			if not BattleNew.visible and not msg.visible and not choice_box.visible:
				pause_menu.open()
				get_viewport().set_input_as_handled()
				return
		# Si el menú está visible, emitir la señal para que pueda cerrarse
		input_start.emit()
		# No consumir el input si el menú está visible (para que pueda procesarlo)
		if pause_menu and pause_menu.visible:
			return
		get_viewport().set_input_as_handled()
		return

	if input_locked or isFading():
		return

	var input_consumed = false

	# Verificar si el MessageBox de batalla está visible
	var battle_message_box_visible = false
	if BattleNew.visible:
		var battle_ui = BattleNew.get_node_or_null("BattleUI")
		if battle_ui and battle_ui.has_node("MessageBox"):
			var battle_msg = battle_ui.get_node("MessageBox")
			if battle_msg and battle_msg.visible:
				battle_message_box_visible = true

	# Si no hay menús visibles, no procesar ui_accept/ui_cancel aquí
	# Dejarlos pasar para que el Player pueda usarlos (interact)
	if not msg.visible and not choice_box.visible and not (pause_menu != null && pause_menu.visible) and not (_current_portrait_box != null && _current_portrait_box.visible) and not battle_message_box_visible:
		return

	# Evitar repeticiones automáticas
	if event.is_action_pressed("ui_accept") and !pressed_actions.has("ui_accept"):
		pressed_actions["ui_accept"] = true
		print("DisplayManager accept")
		input_accept.emit()
		messagebox_input_accept.emit()
		input_consumed = true

	if event.is_action_pressed("ui_cancel") and !pressed_actions.has("ui_cancel"):
		pressed_actions["ui_cancel"] = true
		print("DisplayManager cancel")
		input_cancel.emit()
		messagebox_input_cancel.emit()
		input_consumed = true

	if event.is_action_pressed("ui_up") and !pressed_actions.has("ui_up"):
		pressed_actions["ui_up"] = true
		print("DisplayManager up")
		input_up.emit()
		input_consumed = true

	if event.is_action_pressed("ui_down") and !pressed_actions.has("ui_down"):
		pressed_actions["ui_down"] = true
		print("DisplayManager down")
		input_down.emit()
		input_consumed = true

	if event.is_action_pressed("ui_right") and !pressed_actions.has("ui_right"):
		pressed_actions["ui_right"] = true
		print("DisplayManager right")
		input_right.emit()
		input_consumed = true

	if event.is_action_pressed("ui_left") and !pressed_actions.has("ui_left"):
		pressed_actions["ui_left"] = true
		print("DisplayManager left")
		input_left.emit()
		input_consumed = true

	# Consumir el input SOLO si hay menús visibles y se procesó algún input
	# Cuando no hay menús visibles, no consumir el input para que el Player pueda usarlo
	if input_consumed and (msg.visible or choice_box.visible or (pause_menu != null && pause_menu.visible) or battle_message_box_visible):
		get_viewport().set_input_as_handled()

# === CALLBACKS DEL PAUSE MENU ===
func _on_pause_pokedex_requested() -> void:
	print("PauseMenu: Pokédex solicitado (placeholder)")

func _on_pause_party_requested() -> void:
	print("PauseMenu: Party solicitado (placeholder)")

func _on_pause_bag_requested() -> void:
	print("PauseMenu: Bag solicitado (placeholder)")

func _on_pause_player_requested() -> void:
	print("PauseMenu: Player solicitado (placeholder)")

func _on_pause_save_requested() -> void:
	print("PauseMenu: Guardar solicitado (placeholder)")

func _on_pause_options_requested() -> void:
	print("PauseMenu: Opciones solicitado (placeholder)")

func _on_pause_exit_requested() -> void:
	print("PauseMenu: Salir solicitado")

func _on_pause_menu_closed() -> void:
	print("PauseMenu: Menú cerrado")

# === SISTEMA DE PAUSA AUTOMÁTICA ===
## Verifica si hay UI visible o animaciones MO activas y pausa/reanuda el juego automáticamente
func _update_game_pause_state() -> void:
	var has_ui_visible = (
		msg.visible or
		choice_box.visible or
		(pause_menu != null && pause_menu.visible) or
		BattleNew.visible or
		(_current_portrait_box != null && _current_portrait_box.visible)
	)

	# Verificar si hay animaciones MO activas (Player, saltos de ledge, etc.)
	var has_mo_animation = _check_mo_animations_active()

	var should_pause = has_ui_visible or has_mo_animation

	if should_pause and not get_tree().paused:
		get_tree().paused = true
		if has_mo_animation:
			print("DisplayManager: Juego pausado (animación MO activa, count: %d)" % _mo_animation_count)
		else:
			print("DisplayManager: Juego pausado (UI visible)")
	elif not should_pause and get_tree().paused:
		get_tree().paused = false
		print("DisplayManager: Juego reanudado (sin UI visible ni animaciones MO, count: %d)" % _mo_animation_count)
	else:
		# Debug: mostrar estado actual
		if get_tree().paused:
			print("DisplayManager: Juego sigue pausado (UI visible: %s, MO anim: %s, count: %d)" % [has_ui_visible, has_mo_animation, _mo_animation_count])

## Callback cuando cambia la visibilidad de cualquier elemento de UI
func _on_ui_visibility_changed() -> void:
	_update_game_pause_state()

## Verifica si hay animaciones MO activas (Player MO sequences, ledge jumps, etc.)
func _check_mo_animations_active() -> bool:
	# Si hay animaciones MO contadas, están activas
	if _mo_animation_count > 0:
		return true

	# Verificar Player MO sequences (como fallback)
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("is_mo_sequence_active"):
		if player.is_mo_sequence_active():
			return true

	# Verificar saltos de ledge en GridMotion del Player
	if player:
		var motion = player.get_node_or_null("GridMotion")
		if motion and motion is GridMotion:
			if motion.is_jumping_ledge:
				return true

	return false

## Callbacks para animaciones MO
func _on_mo_animation_started() -> void:
	_mo_animation_count += 1
	_update_game_pause_state()

func _on_mo_animation_finished() -> void:
	_mo_animation_count = max(0, _mo_animation_count - 1)
	_update_game_pause_state()

## Conecta las señales del GridMotion del Player para detectar saltos de ledge
func _connect_player_motion_signals() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var motion = player.get_node_or_null("GridMotion")
		if motion:
			if not motion.ledge_jump_started.is_connected(_on_ledge_jump_started):
				motion.ledge_jump_started.connect(_on_ledge_jump_started)
			if not motion.ledge_jump_finished.is_connected(_on_ledge_jump_finished):
				motion.ledge_jump_finished.connect(_on_ledge_jump_finished)

## Métodos públicos para notificar animaciones MO del Player
## Estos métodos pueden ser llamados desde Player cuando empiezan/terminan animaciones MO
func notify_mo_animation_started() -> void:
	_mo_animation_count += 1
	_update_game_pause_state()

func notify_mo_animation_finished() -> void:
	_mo_animation_count = max(0, _mo_animation_count - 1)
	_update_game_pause_state()

## Callbacks para saltos de ledge
func _on_ledge_jump_started() -> void:
	_mo_animation_count += 1
	_update_game_pause_state()

func _on_ledge_jump_finished() -> void:
	_mo_animation_count = max(0, _mo_animation_count - 1)
	_update_game_pause_state()
