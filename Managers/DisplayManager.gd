extends CanvasLayer
class_name DisplayManager

## DisplayManager - Sistema centralizado para gestionar toda la UI del juego
## Reemplaza al antiguo GUI y actúa como singleton accesible globalmente

# === SINGLETON ===
static var instance: DisplayManager = null

# === SEÑALES ===
signal input
signal selected_choice

# === VARIABLES ===
var fading: bool = false
var next = false
var input_locked := false
var pressed_actions := {}
var choices_options = null

# === NODOS ===
@onready var msg: MessageBox = $MSG
@onready var choice_box: ChoiceBox = $ChoiceBox
@onready var BattleNew: BattleScene = $BattleNew
@onready var fade_layer: ColorRect = $FadeLayer

# === INICIALIZACIÓN ===
func _ready() -> void:
	# Registrar como singleton
	if instance != null:
		push_error("DisplayManager: Ya existe una instancia. Solo debe haber una.")
		queue_free()
		return

	instance = self
	print("DisplayManager: Inicializado como singleton")

	# Conectar señales del SignalManager (solo las que aún se usan)
	# SignalManager.message_requested.connect(_on_message_requested)  # DEPRECATED: Usar DisplayManager.show_message()
	SignalManager.messagebox_input_accept.connect(_on_messagebox_accept)
	SignalManager.messagebox_input_cancel.connect(_on_messagebox_cancel)
	SignalManager.battle_requested.connect(_on_battle_requested)
	SignalManager.battle_finished.connect(_on_battle_finished)
	SignalManager.hide_overworld_messagebox.connect(_on_hide_overworld_messagebox)

	# Conectar señales del MessageBox
	msg.finished.connect(_on_message_finished)

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
static func show_message_with_choices(text: String, options: Array[String]) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._show_message_with_choices(text, options)

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

func _show_message_with_choices(text: String, options: Array[String]) -> int:
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

	# Cerrar el MessageBox después de la selección
	msg.hide()
	msg.clear()

	return selected_index

func _is_fading() -> bool:
	return fading or (fade_layer != null and fade_layer.is_fade_active())

func _is_visible() -> bool:
	return msg.is_visible() || BattleNew.visible || choice_box.visible

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

# === SEÑALES DEL SIGNALMANAGER ===
## DEPRECATED: Esta función ya no se usa, las llamadas van directo a DisplayManager.show_message()
# func _on_message_requested(text: String, config: Dictionary = {}) -> void:
# 	await _show_message_with_config(text, config)
# 	SignalManager.message_finished.emit()

func _on_message_finished() -> void:
	# Asegurar que no queden flags de pulsación retenidos tras cerrar el mensaje
	pressed_actions.clear()

func _on_messagebox_accept() -> void:
	SignalManager.input_accept.emit()

func _on_messagebox_cancel() -> void:
	SignalManager.input_cancel.emit()

func _on_battle_requested(participants: Array[BattleParticipant], rules: BattleRules) -> void:
	# Bloquear control del jugador al iniciar batalla
	SignalManager.player_control_blocked.emit()

	# Separar participantes en player y enemy
	var player_participants: Array[BattleParticipant] = []
	var enemy_participants: Array[BattleParticipant] = []

	for participant in participants:
		if participant.is_player:
			player_participants.append(participant)
		else:
			enemy_participants.append(participant)

	# Emitir señal de inicio de batalla
	SignalManager.battle_started.emit()

	# Mostrar la escena de batalla
	BattleNew.visible = true

	# Iniciar el combate
	await BattleNew.start_battle(player_participants, enemy_participants, rules)

func _on_hide_overworld_messagebox() -> void:
	print("DisplayManager: Limpiando y ocultando MessageBox del overworld")
	msg.cleanup_and_hide()

func _on_battle_finished(_winner_side: String) -> void:
	print("DisplayManager: Batalla terminada, iniciando transición de salida...")

	# Hacer fade in (a negro) para ocultar la batalla
	await fade_layer.fade_in(0.3)

	# Ocultar la escena de batalla
	BattleNew.cleanup_battle()

	# Hacer fade out para revelar el overworld
	await fade_layer.fade_out(0.3)

	# Desbloquear control del jugador
	SignalManager.player_control_unblocked.emit()
	print("DisplayManager: Control del jugador desbloqueado")

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

	if input_locked or !isVisible() or isFading():
		return

	var input_consumed = false

	# Si el ChoiceBox está visible, solo emitir señales pero NO consumir input
	# Esto permite que el ChoiceBox reciba las señales y las procese
	var should_consume_input = !choice_box.visible

	# Evitar repeticiones automáticas
	if event.is_action_pressed("ui_accept") and !pressed_actions.has("ui_accept"):
		pressed_actions["ui_accept"] = true
		print("DisplayManager accept")
		SignalManager.input_accept.emit()
		SignalManager.messagebox_input_accept.emit()
		input_consumed = true

	if event.is_action_pressed("ui_cancel") and !pressed_actions.has("ui_cancel"):
		pressed_actions["ui_cancel"] = true
		print("DisplayManager cancel")
		SignalManager.input_cancel.emit()
		SignalManager.messagebox_input_cancel.emit()
		input_consumed = true

	if event.is_action_pressed("ui_start") and !pressed_actions.has("ui_start"):
		pressed_actions["ui_start"] = true
		print("DisplayManager start")
		SignalManager.input_start.emit()
		input_consumed = true

	if event.is_action_pressed("ui_up") and !pressed_actions.has("ui_up"):
		pressed_actions["ui_up"] = true
		print("DisplayManager up")
		SignalManager.input_up.emit()
		input_consumed = true

	if event.is_action_pressed("ui_down") and !pressed_actions.has("ui_down"):
		pressed_actions["ui_down"] = true
		print("DisplayManager down")
		SignalManager.input_down.emit()
		input_consumed = true

	if event.is_action_pressed("ui_right") and !pressed_actions.has("ui_right"):
		pressed_actions["ui_right"] = true
		print("DisplayManager right")
		SignalManager.input_right.emit()
		input_consumed = true

	if event.is_action_pressed("ui_left") and !pressed_actions.has("ui_left"):
		pressed_actions["ui_left"] = true
		print("DisplayManager left")
		SignalManager.input_left.emit()
		input_consumed = true

	# Consumir el input SOLO si ChoiceBox no está visible
	# Cuando ChoiceBox está visible, permitimos que el input pase a través
	if input_consumed and should_consume_input:
		get_viewport().set_input_as_handled()
