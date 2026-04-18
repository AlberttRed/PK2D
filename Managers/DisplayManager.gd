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
const BAG_CONTROLLER_SCRIPT = preload("res://Scripts/UI/BagController.gd")
const PARTY_CONTROLLER_SCRIPT = preload("res://Scripts/UI/PartyController.gd")
# === VARIABLES ===
var fading: bool = false
var next = false
var input_locked := false
var pressed_actions := {}
var choices_options = null
var _mo_animation_count: int = 0  # Contador de animaciones MO activas (puede haber múltiples simultáneas)
var _current_portrait_box: PortraitBox = null  # Referencia al PortraitBox actual
var _bag_controller = null
var _party_controller = null
## Flujo party → mochila (Usar objeto) y vuelta al party.
var _resume_party_focus_slot: int = -1
## Mientras cerramos el party para abrir la mochila «Usar objeto»: no reabrir menú pausa en _on_party_closed.
var _closing_party_to_open_bag_for_item: bool = false
var _bag_dialog_layout_saved: bool = false
var _bag_dialog_saved_msg_layout: Dictionary = {}
var _bag_dialog_saved_choice_layout: Dictionary = {}
var _party_action_choice_layout_saved: bool = false
var _party_action_saved_choice_layout: Dictionary = {}
## Mochila (pausa) → «Usar» ítem que requiere Pokémon: id pendiente hasta elegir objetivo en party.
var _pending_bag_item_id: int = -1
## Party cerrado bajo fundido para reabrir mochila: no abrir menú pausa en _on_party_closed.
var _skip_pause_open_on_party_close: bool = false
## Party → bolsa → usar ítem: cerramos bolsa y mostramos feedback con party visible (no reapertura diferida duplicada).
var _suppress_party_resume_after_bag_close: bool = false
## Mensaje de resultado de ítem sin diálogo de bolsa activo (p. ej. party → aplicar): snapshot del MSG.
var _item_feedback_msg_layout_saved: bool = false
var _item_feedback_saved_msg_layout: Dictionary = {}

## Viewport base del UI overworld/pausa (MessageBox anclado en píxeles de escena).
const _MSG_VIEWPORT_BASE := Vector2(512.0, 384.0)
const _MSG_BAR_SAFE_MARGIN_PX := 2.0
const _MSG_BAR_HEIGHT_PX := 96.0
const _UI_SCREEN_FADE_DURATION: float = 0.2

# === NODOS ===
@onready var msg: MessageBox = $MSG
@onready var choice_box: ChoiceBox = $ChoiceBox
@onready var BattleNew: BattleScene = $BattleNew
@onready var pause_menu = $PauseMenu
@onready var _bag_ui = $BagUI
@onready var _party_ui = $PartyUI
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
	if _bag_ui:
		_bag_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _party_ui:
		_party_ui.process_mode = Node.PROCESS_MODE_ALWAYS
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

	if _bag_ui:
		_bag_ui.back_requested.connect(_on_bag_back_requested)
		_bag_ui.use_requested.connect(_on_bag_use_requested)
		_bag_ui.closed.connect(_on_bag_closed)
		if _bag_ui.has_signal("visibility_changed"):
			_bag_ui.visibility_changed.connect(_on_ui_visibility_changed)

	if _party_ui:
		_party_ui.back_requested.connect(_on_party_back_requested)
		_party_ui.closed.connect(_on_party_closed)
		_party_ui.use_item_requested.connect(_on_party_use_item_requested)
		_party_ui.bag_item_target_selected.connect(_on_party_bag_item_pick_slot)
		_party_ui.bag_item_target_cancelled.connect(_on_party_bag_item_target_cancelled)
		if _party_ui.has_signal("visibility_changed"):
			_party_ui.visibility_changed.connect(_on_ui_visibility_changed)

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


## Menú de acciones del party: borde derecho alineado al viewport (diseño 512×384), crece hacia la izquierda.
static func show_party_action_choices(options: Array[String]) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	instance._push_party_action_choice_layout()
	var idx: int = await instance._show_choices(options)
	instance._pop_party_action_choice_layout()
	return idx


## Opciones con anclaje a una esquina del viewport (`ChoiceBox.ChoiceAnchor`; PARTY_MENU/BAG tienen flujo propio).
static func show_choices_corner(options: Array[String], anchor: ChoiceBox.ChoiceAnchor) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	if anchor == ChoiceBox.ChoiceAnchor.SCENE_DEFAULT:
		return await instance._show_choices(options)
	if anchor == ChoiceBox.ChoiceAnchor.PARTY_MENU or anchor == ChoiceBox.ChoiceAnchor.BAG_TOP_LEFT:
		push_error("DisplayManager.show_choices_corner: usa show_party_action_choices o el flujo de mochila.")
		return -1
	var saved: Dictionary = instance._snapshot_choice_box_layout()
	instance.choice_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	instance.choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	instance.choice_box.set_corner_anchor(anchor)
	var idx: int = await instance._show_choices(options)
	instance._restore_choice_box_layout(saved)
	instance.choice_box.clear_corner_anchor()
	return idx


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

	# Flag para indicar que estamos en modo choices
	var choices_mode_active = true

	# Conectar a la señal finishedAllText para mostrar opciones automáticamente al finalizar
	# sin esperar input adicional
	var finished_callback = func():
		if choices_mode_active and msg.messageHasFinished:
			# Finalizar sin cerrar y sin esperar input
			msg._finish_without_closing()

	if not msg.finishedAllText.is_connected(finished_callback):
		msg.finishedAllText.connect(finished_callback)

	# Mostrar el mensaje esperando input entre líneas (como ShowMessageCommand)
	# Con waitInput: true, el mensaje esperará input en cada salto de línea
	# closeAtEnd: false para mantener el mensaje visible cuando se muestren las opciones
	# Iniciar show_custom y esperar a que termine
	# frameStyle: HGSS (0) por defecto para aplicar el tema y mostrar el icono
	await msg.show_custom(text, {
		"waitInput": true,  # true para esperar input entre líneas
		"closeAtEnd": false,
		"waitTime": 0.0,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS  # Aplicar tema para mostrar el icono
	})

	# Si el mensaje terminó pero aún no se llamó a _finish_without_closing,
	# llamarlo ahora (por si la señal no se emitió o no se conectó correctamente)
	if choices_mode_active and msg.messageHasFinished and msg._is_processing_message:
		msg._finish_without_closing()

	# Desconectar la señal
	if msg.finishedAllText.is_connected(finished_callback):
		msg.finishedAllText.disconnect(finished_callback)
	choices_mode_active = false

	# Guardar la posición final del scroll antes de mostrar las opciones
	# Esto asegura que el texto se mantenga en la posición final
	var final_scroll_position = msg.scroll.scroll_vertical

	# Mostrar las opciones (el MessageBox permanece visible de fondo)
	var selected_index = await choice_box.show_choices(options)

	# Restaurar la posición del scroll después de mostrar las opciones
	# para asegurar que el texto se mantenga en la posición final
	msg.scroll.scroll_vertical = final_scroll_position

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
	return msg.visible || BattleNew.visible || choice_box.visible || (pause_menu != null && pause_menu.visible) || (_bag_ui != null and _bag_ui.visible) || (_party_ui != null and _party_ui.visible)

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
			if not BattleNew.visible and not msg.visible and not choice_box.visible and not (_bag_ui != null and _bag_ui.visible) and not (_party_ui != null and _party_ui.visible):
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
	if not msg.visible and not choice_box.visible and not (pause_menu != null && pause_menu.visible) and not (_bag_ui != null and _bag_ui.visible) and not (_party_ui != null and _party_ui.visible) and not (_current_portrait_box != null && _current_portrait_box.visible) and not battle_message_box_visible:
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
	if input_consumed and (msg.visible or choice_box.visible or (pause_menu != null && pause_menu.visible) or (_bag_ui != null and _bag_ui.visible) or (_party_ui != null and _party_ui.visible) or battle_message_box_visible):
		get_viewport().set_input_as_handled()

# === CALLBACKS DEL PAUSE MENU ===
func _on_pause_pokedex_requested() -> void:
	print("PauseMenu: Pokédex solicitado (placeholder)")

func _on_pause_party_requested() -> void:
	await _open_party_ui()

func _on_pause_bag_requested() -> void:
	await _open_bag_ui()


func _await_ui_control_hidden(ctrl: Control) -> void:
	if ctrl == null:
		return
	while ctrl.visible:
		await get_tree().process_frame


func _open_party_ui(with_screen_fade: bool = true) -> void:
	if _bag_ui != null and _bag_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _party_ui == null:
		push_error("DisplayManager: Nodo PartyUI no disponible en la escena.")
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close()

	var context := _resolve_overworld_context()
	_party_controller = PARTY_CONTROLLER_SCRIPT.new(context)
	_party_ui.setup(_party_controller)
	_party_ui.open()
	_on_ui_visibility_changed()

	if with_screen_fade:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _close_party_ui() -> void:
	if _party_ui == null:
		return
	_party_ui.close()


func _on_party_back_requested() -> void:
	await _transition_fade_party_to_pause_menu()


func _transition_fade_party_to_pause_menu() -> void:
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_party_ui()
	await _await_ui_control_hidden(_party_ui)
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _on_party_closed() -> void:
	if _skip_pause_open_on_party_close:
		_party_controller = null
		_resume_party_focus_slot = -1
		_on_ui_visibility_changed()
		return

	if _closing_party_to_open_bag_for_item:
		_party_controller = null
		_resume_party_focus_slot = -1
		_on_ui_visibility_changed()
		return

	_party_controller = null
	_resume_party_focus_slot = -1
	if pause_menu and not pause_menu.visible:
		pause_menu.open(1)
	_on_ui_visibility_changed()


## Party → mochila (cancelar objetivo o fin de sesión ítem): negro con party aún montado, cerrar, abrir bolsa, descubrir.
func _fade_close_party_reopen_bag_overworld() -> void:
	_skip_pause_open_on_party_close = true
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_party_ui()
	await _await_ui_control_hidden(_party_ui)
	_skip_pause_open_on_party_close = false
	_open_bag_ui(false)
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _on_party_use_item_requested(slot_index: int) -> void:
	_resume_party_focus_slot = slot_index
	await _transition_fade_party_to_bag_for_use_item()


func _transition_fade_party_to_bag_for_use_item() -> void:
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	# Leer slot antes de _close_party_ui: _on_party_closed pone _resume_party_focus_slot en -1.
	var slot := _resume_party_focus_slot
	_closing_party_to_open_bag_for_item = true
	_close_party_ui()
	await _await_ui_control_hidden(_party_ui)
	_closing_party_to_open_bag_for_item = false
	if pause_menu and pause_menu.visible:
		pause_menu.close()
	var context := _resolve_overworld_context()
	_bag_controller = BAG_CONTROLLER_SCRIPT.new(context)
	_bag_controller.configure_party_item_flow(slot)
	_bag_ui.setup(_bag_controller)
	_bag_ui.open()
	_on_ui_visibility_changed()
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _deferred_reopen_party_after_bag() -> void:
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	var slot := _resume_party_focus_slot
	_resume_party_focus_slot = -1
	if _party_ui != null and _party_ui.visible:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
		return
	if _bag_ui != null and _bag_ui.visible:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
		return
	if pause_menu and pause_menu.visible:
		pause_menu.close()
	var context := _resolve_overworld_context()
	_party_controller = PARTY_CONTROLLER_SCRIPT.new(context)
	_party_ui.setup(_party_controller)
	_party_ui.open(slot)
	_on_ui_visibility_changed()
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _open_bag_ui(with_screen_fade: bool = true) -> void:
	if _party_ui != null and _party_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return

	if _bag_ui == null:
		push_error("DisplayManager: Nodo BagUI no disponible en la escena.")
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close()

	var context := _resolve_overworld_context()
	_bag_controller = BAG_CONTROLLER_SCRIPT.new(context)
	_bag_controller.reset_list_context_to_overworld()

	_bag_ui.setup(_bag_controller)
	_bag_ui.open()
	_on_ui_visibility_changed()

	if with_screen_fade:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

func _close_bag_ui() -> void:
	if _bag_ui == null:
		return
	_bag_ui.close()

func _on_bag_back_requested() -> void:
	await _transition_fade_bag_to_pause_menu()


func _transition_fade_bag_to_pause_menu() -> void:
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_bag_ui()
	await _await_ui_control_hidden(_bag_ui)
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

func _on_bag_closed() -> void:
	var resume_party_slot := -1
	if _bag_controller != null and _bag_controller.party_target_slot >= 0:
		resume_party_slot = _bag_controller.party_target_slot
	_bag_controller = null
	if _pending_bag_item_id > 0:
		# La apertura del party con fundido la hace _run_bag_item_use_flow (evita 1 frame a juego con bolsa ya cerrada).
		_on_ui_visibility_changed()
		return
	if resume_party_slot >= 0:
		if _suppress_party_resume_after_bag_close:
			_on_ui_visibility_changed()
			return
		_resume_party_focus_slot = resume_party_slot
		call_deferred("_deferred_reopen_party_after_bag")
		_on_ui_visibility_changed()
		return
	if pause_menu and not pause_menu.visible:
		pause_menu.open(2) # Mantener cursor en "MOCHILA"
	_on_ui_visibility_changed()

func _on_bag_use_requested(item_id: int) -> void:
	await _run_bag_item_use_flow(item_id)


## Tras cerrar la bolsa bajo negro: abre party (mochila → party) y descubre. Sin fade_in previo (ya estamos a negro).
func _open_party_for_pending_bag_item_after_bag_close() -> void:
	if _pending_bag_item_id <= 0:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return

	if pause_menu and pause_menu.visible:
		pause_menu.close()

	var context := _resolve_overworld_context()
	_party_controller = PARTY_CONTROLLER_SCRIPT.new(context)
	_party_ui.setup(_party_controller)
	_party_ui.open_for_bag_item_target_pick(-1)
	_on_ui_visibility_changed()

	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _on_party_bag_item_target_cancelled() -> void:
	if _party_ui == null or not _party_ui.visible:
		return
	if _pending_bag_item_id <= 0:
		return
	if _party_ui.has_method("set_input_enabled"):
		_party_ui.set_input_enabled(false)
	_pending_bag_item_id = -1
	await _fade_close_party_reopen_bag_overworld()


func _on_party_bag_item_pick_slot(slot_index: int) -> void:
	await _finish_pending_bag_item_use(slot_index)


func _finish_pending_bag_item_use(slot_index: int) -> void:
	var item_id := _pending_bag_item_id
	if item_id <= 0:
		return
	if _party_ui != null:
		_party_ui.set_input_enabled(false)

	var bag = GameStateService.get_bag()
	if bag == null or bag.get_quantity(item_id) <= 0:
		await _finish_pending_bag_party_out_of_units()
		return

	var context := _resolve_overworld_context()
	var bc = BAG_CONTROLLER_SCRIPT.new(context)
	bc.configure_party_item_flow(slot_index)
	var use_result: Dictionary = bc.request_use_item(item_id)

	if _party_ui != null:
		_party_ui.refresh_slots_display()

	await _await_bag_use_feedback_messages(use_result)

	var qty_after: int = GameStateService.get_bag().get_quantity(item_id) if GameStateService.get_bag() != null else 0
	if qty_after <= 0:
		await _await_bag_use_feedback_messages({
			"message": "Ya no quedan más unidades.",
			"ok": true,
		})
		await _finish_pending_bag_party_session()
		return

	# Evitar que el mismo ui_accept que cierra el MSG dispare party/Choice en el frame siguiente.
	await get_tree().process_frame
	await get_tree().process_frame
	if _party_ui != null:
		_party_ui.set_input_enabled(true)


func _finish_pending_bag_party_out_of_units() -> void:
	await _await_bag_use_feedback_messages({
		"message": "Ya no quedan más unidades.",
		"ok": false,
	})
	await _finish_pending_bag_party_session()


func _finish_pending_bag_party_session() -> void:
	_pending_bag_item_id = -1
	await _fade_close_party_reopen_bag_overworld()


func _await_bag_use_feedback_messages(use_result: Dictionary) -> void:
	var feedback: String = str(use_result.get("message", "No se puede usar."))
	var popped_item_layout := false
	if not _bag_dialog_layout_saved:
		_push_item_feedback_msg_layout()
		popped_item_layout = true
	## Mismo comportamiento que diálogos de campo: typing + confirmar con input antes de seguir.
	await _show_message_with_config(feedback, {
		"waitInput": true,
		"closeAtEnd": true,
		"waitTime": 0.0,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": "typing",
	})
	if popped_item_layout:
		_pop_item_feedback_msg_layout()


func _execute_bag_item_use_with_controller(item_id: int) -> void:
	var use_result: Dictionary = _bag_controller.request_use_item(item_id)
	if _bag_ui != null and _bag_ui.has_method("refresh_from_controller"):
		_bag_ui.refresh_from_controller()
	await _await_bag_use_feedback_messages(use_result)


## Party → bolsa → elegir objeto: resultado sobre el party (cierra bolsa antes del MessageBox).
func _party_bag_flow_use_item_show_feedback_on_party(item_id: int, restore_bag_input: bool) -> void:
	var use_result: Dictionary = _bag_controller.request_use_item(item_id)
	if _bag_ui != null and _bag_ui.has_method("refresh_from_controller"):
		_bag_ui.refresh_from_controller()

	var resume_slot: int = -1
	if _bag_controller != null:
		resume_slot = _bag_controller.party_target_slot

	if msg.visible:
		_close_message()

	if restore_bag_input and _bag_ui != null and _bag_ui.visible and _bag_ui.has_method("set_input_enabled"):
		_bag_ui.set_input_enabled(true)

	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	_pop_bag_item_dialog_layout()

	_suppress_party_resume_after_bag_close = true
	_close_bag_ui()
	await _await_ui_control_hidden(_bag_ui)
	_suppress_party_resume_after_bag_close = false

	if resume_slot >= 0:
		if pause_menu and pause_menu.visible:
			pause_menu.close()
		var context_pb := _resolve_overworld_context()
		_party_controller = PARTY_CONTROLLER_SCRIPT.new(context_pb)
		_party_ui.setup(_party_controller)
		_party_ui.open(resume_slot)

	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
	await get_tree().process_frame

	if _party_ui != null:
		_party_ui.refresh_slots_display()

	await _await_bag_use_feedback_messages(use_result)


func _run_bag_item_use_flow(item_id: int) -> void:
	if _bag_controller == null or _bag_ui == null:
		return
	if not _bag_ui.visible:
		return

	var from_party_flow: bool = _bag_controller.party_target_slot >= 0

	_push_bag_item_dialog_layout()

	var restore_bag_input := false
	if _bag_ui.has_method("set_input_enabled"):
		restore_bag_input = true
		_bag_ui.set_input_enabled(false)

	if msg.visible:
		_close_message()

	var choice_index := 0
	if not from_party_flow:
		var debug_info: Dictionary = _bag_controller.get_item_selection_debug(item_id)
		var item_name: String = str(debug_info.get("display_name", "Objeto"))
		var message_text := "Has seleccionado %s." % item_name
		var options: Array[String] = ["Usar", "Tirar", "Salir"]
		choice_box.begin_coordinated_choice(options)
		await msg.show_custom(message_text, {
			"waitInput": false,
			"closeAtEnd": false,
			"waitTime": 0.0,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": "instant",
			"onTextVisibleReady": Callable(choice_box, "reveal_when_coordinated_message_visible")
		})
		choice_index = await choice_box.await_coordinated_choice_result()
	else:
		choice_index = 0

	var did_party_bag_feedback: bool = false
	match choice_index:
		0:
			var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
			if not from_party_flow and item_data != null and item_data.requires_target():
				_pending_bag_item_id = item_id
				_close_message()
				if restore_bag_input and _bag_ui != null and _bag_ui.visible and _bag_ui.has_method("set_input_enabled"):
					_bag_ui.set_input_enabled(true)
				# Fundir a negro con la bolsa aún visible; luego cerrar y abrir party (evita un frame a juego desnudo).
				await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
				_pop_bag_item_dialog_layout()
				_close_bag_ui()
				await _await_ui_control_hidden(_bag_ui)
				await _open_party_for_pending_bag_item_after_bag_close()
				return
			if from_party_flow:
				await _party_bag_flow_use_item_show_feedback_on_party(item_id, restore_bag_input)
				did_party_bag_feedback = true
			else:
				await _execute_bag_item_use_with_controller(item_id)
		1:
			await _show_message_with_config("Tirar: pendiente de implementar.", {
				"waitInput": false,
				"closeAtEnd": true,
				"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
				"typingMode": "instant"
			})
		2:
			pass
		_:
			pass

	_close_message()

	if restore_bag_input and _bag_ui != null and _bag_ui.visible and _bag_ui.has_method("set_input_enabled"):
		_bag_ui.set_input_enabled(true)

	if not did_party_bag_feedback:
		_pop_bag_item_dialog_layout()

func _snapshot_msg_panel_layout() -> Dictionary:
	return {
		"anchor_left": msg.anchor_left,
		"anchor_top": msg.anchor_top,
		"anchor_right": msg.anchor_right,
		"anchor_bottom": msg.anchor_bottom,
		"offset_left": msg.offset_left,
		"offset_top": msg.offset_top,
		"offset_right": msg.offset_right,
		"offset_bottom": msg.offset_bottom,
		"grow_horizontal": msg.grow_horizontal,
		"grow_vertical": msg.grow_vertical,
		"custom_minimum_size": msg.custom_minimum_size,
	}


func _restore_msg_panel_layout(saved: Dictionary) -> void:
	if msg == null:
		return
	msg.anchor_left = float(saved.get("anchor_left", 0.0))
	msg.anchor_top = float(saved.get("anchor_top", 1.0))
	msg.anchor_right = float(saved.get("anchor_right", 1.0))
	msg.anchor_bottom = float(saved.get("anchor_bottom", 1.0))
	msg.offset_left = float(saved.get("offset_left", 0.0))
	msg.offset_top = float(saved.get("offset_top", -96.0))
	msg.offset_right = float(saved.get("offset_right", 512.0))
	msg.offset_bottom = float(saved.get("offset_bottom", 0.0))
	msg.grow_horizontal = saved.get("grow_horizontal", Control.GROW_DIRECTION_BOTH)
	msg.grow_vertical = saved.get("grow_vertical", Control.GROW_DIRECTION_BEGIN)
	msg.custom_minimum_size = saved.get("custom_minimum_size", Vector2(512, 96))


## Barra inferior de mensaje con margen respecto al borde del viewport (left / right / bottom).
func _apply_msg_bottom_bar_viewport_inset() -> void:
	if msg == null:
		return
	var vw: float = _MSG_VIEWPORT_BASE.x
	var vh: float = _MSG_VIEWPORT_BASE.y
	var m: float = _MSG_BAR_SAFE_MARGIN_PX
	var bar_h: float = _MSG_BAR_HEIGHT_PX
	msg.anchor_left = 0.0
	msg.anchor_top = 0.0
	msg.anchor_right = 0.0
	msg.anchor_bottom = 0.0
	msg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	msg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	msg.custom_minimum_size = Vector2(vw - 2.0 * m, bar_h)
	msg.offset_left = m
	msg.offset_top = vh - m - bar_h
	msg.offset_right = vw - m
	msg.offset_bottom = vh - m


func _push_item_feedback_msg_layout() -> void:
	if _item_feedback_msg_layout_saved or msg == null:
		return
	_item_feedback_saved_msg_layout = _snapshot_msg_panel_layout()
	_apply_msg_bottom_bar_viewport_inset()
	_item_feedback_msg_layout_saved = true


func _pop_item_feedback_msg_layout() -> void:
	if not _item_feedback_msg_layout_saved or msg == null:
		return
	_restore_msg_panel_layout(_item_feedback_saved_msg_layout)
	_item_feedback_msg_layout_saved = false


func _push_bag_item_dialog_layout() -> void:
	if _bag_dialog_layout_saved:
		return
	if msg == null or choice_box == null:
		return

	_bag_dialog_saved_msg_layout = _snapshot_msg_panel_layout()

	_bag_dialog_saved_choice_layout = _snapshot_choice_box_layout()

	# Texto a ancho útil del tema FireRed (sin columna estrecha “mitad interior” del MSG).
	_apply_msg_bottom_bar_viewport_inset()

	# ChoiceBox: esquina superior izquierda fija (Y alineado tras ajustes del contenedor de opciones).
	const BAG_CHOICE_TOP_LEFT := Vector2(400.0, 244.0)
	choice_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choice_box.set_fixed_top_left_position(true, BAG_CHOICE_TOP_LEFT)

	_bag_dialog_layout_saved = true

func _pop_bag_item_dialog_layout() -> void:
	if not _bag_dialog_layout_saved:
		return
	if msg == null or choice_box == null:
		_bag_dialog_layout_saved = false
		return

	_restore_msg_panel_layout(_bag_dialog_saved_msg_layout)

	choice_box.set_fixed_top_left_position(false)
	_restore_choice_box_layout(_bag_dialog_saved_choice_layout)

	_bag_dialog_layout_saved = false

func _sync_choice_box_base_offsets_from_current() -> void:
	if choice_box == null:
		return
	# ChoiceBox._adjust_panel_size() ancla el tamaño a estos valores (se fijan en _ready()).
	choice_box._base_offset_right = choice_box.offset_right
	choice_box._base_offset_bottom = choice_box.offset_bottom


func _snapshot_choice_box_layout() -> Dictionary:
	return {
		"anchors_preset": choice_box.anchors_preset,
		"anchor_left": choice_box.anchor_left,
		"anchor_top": choice_box.anchor_top,
		"anchor_right": choice_box.anchor_right,
		"anchor_bottom": choice_box.anchor_bottom,
		"offset_left": choice_box.offset_left,
		"offset_top": choice_box.offset_top,
		"offset_right": choice_box.offset_right,
		"offset_bottom": choice_box.offset_bottom,
		"grow_horizontal": choice_box.grow_horizontal,
		"grow_vertical": choice_box.grow_vertical,
	}


func _restore_choice_box_layout(saved: Dictionary) -> void:
	if choice_box == null:
		return
	choice_box.anchor_left = float(saved.get("anchor_left", 0.0))
	choice_box.anchor_top = float(saved.get("anchor_top", 0.5))
	choice_box.anchor_right = float(saved.get("anchor_right", 0.0))
	choice_box.anchor_bottom = float(saved.get("anchor_bottom", 0.5))
	choice_box.offset_left = float(saved.get("offset_left", -144.0))
	choice_box.offset_top = float(saved.get("offset_top", 70.0))
	choice_box.offset_right = float(saved.get("offset_right", 0.0))
	choice_box.offset_bottom = float(saved.get("offset_bottom", 98.0))
	choice_box.grow_horizontal = saved.get("grow_horizontal", Control.GROW_DIRECTION_BEGIN)
	choice_box.grow_vertical = saved.get("grow_vertical", Control.GROW_DIRECTION_BEGIN)
	choice_box.set("anchors_preset", int(saved.get("anchors_preset", 6)))
	_sync_choice_box_base_offsets_from_current()


func _push_party_action_choice_layout() -> void:
	if _party_action_choice_layout_saved:
		return
	if choice_box == null:
		return
	_party_action_saved_choice_layout = _snapshot_choice_box_layout()
	choice_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choice_box.enter_party_menu_layout()
	_party_action_choice_layout_saved = true


func _pop_party_action_choice_layout() -> void:
	if not _party_action_choice_layout_saved:
		return
	if choice_box == null:
		_party_action_choice_layout_saved = false
		return
	choice_box.exit_party_menu_layout()
	_restore_choice_box_layout(_party_action_saved_choice_layout)
	_party_action_choice_layout_saved = false


func _resolve_overworld_context() -> OverworldContext:
	var nodes := get_tree().root.find_children("*", "OverworldCoordinator", true, false)
	if nodes.is_empty():
		return null

	var coordinator := nodes[0]
	if coordinator and coordinator.has_method("get_context"):
		return coordinator.get_context()
	return null

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
		(_bag_ui != null and _bag_ui.visible) or
		(_party_ui != null and _party_ui.visible) or
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
