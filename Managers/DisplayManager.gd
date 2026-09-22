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
const EvolutionOriginContext := preload("res://Scripts/Runtime/EvolutionOriginContext.gd")
const EvolutionControllerScr := preload("res://Scripts/UI/EvolutionController.gd")
const BAG_CONTROLLER_SCRIPT = preload("res://Scripts/UI/BagController.gd")
const PARTY_CONTROLLER_SCRIPT = preload("res://Scripts/UI/PartyController.gd")
const POKEDEX_CONTROLLER_SCRIPT = preload("res://Scripts/UI/PokedexController.gd")
const SAVE_MENU_CONTROLLER_SCRIPT = preload("res://Scripts/UI/SaveMenuController.gd")
# === VARIABLES ===
var fading: bool = false
## Hold: EventSystem no arranca páginas nuevas hasta soltarlo (blanqueo → tras fade_out).
var _hold_overworld_events: bool = false
var next = false
var input_locked := false
var pressed_actions := {}
var choices_options = null
var _mo_animation_count: int = 0  # Contador de animaciones MO activas (puede haber múltiples simultáneas)
var _current_portrait_box: PortraitBox = null  # Referencia al PortraitBox actual
var _bag_controller = null
var _party_controller = null
var _pokedex_controller = null
var _save_menu_controller = null
var _reopen_pause_after_save_ui_close: bool = true
## Flujo party → mochila (Usar objeto) y vuelta al party.
var _resume_party_focus_slot: int = -1
## Mientras cerramos el party para abrir la mochila «Usar objeto»: no reabrir menú pausa en _on_party_closed.
var _closing_party_to_open_bag_for_item: bool = false
var _bag_dialog_layout_saved: bool = false
var _bag_dialog_saved_msg_layout: Dictionary = {}
var _bag_dialog_saved_choice_layout: Dictionary = {}
var _party_action_choice_layout_saved: bool = false
var _party_action_saved_choice_layout: Dictionary = {}
## Layout de esquina pendiente de restaurar tras `show_choices_corner(..., close_at_end=false)`.
var _corner_choice_layout_saved: bool = false
var _corner_choice_saved_layout: Dictionary = {}
## Mochila (pausa) → «Usar» ítem que requiere Pokémon: id pendiente hasta elegir objetivo en party.
var _pending_bag_item_id: int = -1
## Estado de navegación de mochila (bolsillo + índice) al pasar a selección de objetivo en Party.
var _pending_bag_ui_navigation_state: Dictionary = {}
## Party cerrado bajo fundido para reabrir mochila: no abrir menú pausa en _on_party_closed.
var _skip_pause_open_on_party_close: bool = false
## Party → bolsa → usar ítem: cerramos bolsa y mostramos feedback con party visible (no reapertura diferida duplicada).
var _suppress_party_resume_after_bag_close: bool = false
## Cierre interno de mochila (reapertura tras party): no ejecutar lógica de _on_bag_closed.
var _suppress_bag_closed_effects: bool = false
## PC → DAR/OBJETO: elegir un ítem de la mochila para held.
var _bag_hold_pick_active: bool = false
var _bag_hold_pick_result: int = -1
## PC → DEJAR OBJETO: sesión de depósito desde la mochila.
var _bag_pc_deposit_active: bool = false
## Tienda → Vender: sesión de venta desde la mochila (#834; command → #836).
var _bag_sell_active: bool = false
## PC ítems → DAR: elegir Pokémon del party para held desde el depósito.
var _party_give_pick_active: bool = false
var _party_give_pick_result: int = -1
## QuantityPicker compartido (PC ítems / mochila depósito).
signal _quantity_picked(value: int)
var _qty_pick_active: bool = false
var _qty_prompt_layout_active: bool = false
var _qty_pick_value: int = 1
var _qty_pick_max: int = 1
var _qty_unit_price: int = 0
var _qty_arrow_anim_time: float = 0.0
const _QTY_ARROW_ANIM_FPS: float = 18.0
const _QTY_DEFAULT_OFFSET_LEFT := -145.0
const _QTY_DEFAULT_OFFSET_TOP := -95.0
const _QTY_DEFAULT_OFFSET_RIGHT := -1.0
const _QTY_DEFAULT_OFFSET_BOTTOM := 0.0
const _QTY_DEFAULT_MIN_WIDTH := 144.0
## Mart: picker encima de la franja verde, alineado por abajo con Llevas (y=278 → −106).
const _QTY_MART_OFFSET_LEFT := -240.0
const _QTY_MART_OFFSET_RIGHT := -8.0
const _QTY_MART_OFFSET_BOTTOM := -106.0
const _QTY_MART_HEIGHT := 94.0
const _QTY_PRICE_MIN_WIDTH := 240.0
const _QTY_DEFAULT_ARROW_X := 72.0
## Con precio: flechas centradas sobre la cantidad (izquierda).
const _QTY_PRICE_ARROW_X := 42.0
## Mensaje de resultado de ítem sin diálogo de bolsa activo (p. ej. party → aplicar): snapshot del MSG.
var _item_feedback_msg_layout_saved: bool = false
var _item_feedback_saved_msg_layout: Dictionary = {}
## MessageBox estrecho al ancho de la caja mientras el PC está abierto.
var _pc_msg_layout_saved: bool = false
var _pc_msg_saved_layout: Dictionary = {}
var _pc_msg_saved_scroll: Dictionary = {}
## Party abierto: MessageBox en el rect del antiguo FIXED_MSG (ayuda + diálogos).
var _party_msg_layout_saved: bool = false
var _party_msg_saved_layout: Dictionary = {}
var _party_msg_saved_scroll: Dictionary = {}
var _party_help_text: String = ""

## Viewport base del UI overworld/pausa (MessageBox anclado en píxeles de escena).
const _MSG_VIEWPORT_BASE := Vector2(512.0, 384.0)
const _MSG_BAR_SAFE_MARGIN_PX := 2.0
const _MSG_BAR_HEIGHT_PX := 96.0
## Altura del MessageBox PC ítems cuando el texto cabe en una sola línea.
const _MSG_BAR_HEIGHT_ONE_LINE_PX := 64.0
## Inset inferior del ScrollContainer respecto al panel (96 − 79 en MessageBox.tscn).
const _MSG_SCROLL_BOTTOM_INSET_PX := 17.0
## Ancho del panel Box en PCStorageUI.tscn (offset_left/right 185→509).
const _PC_MSG_LEFT_PX := 185.0
const _PC_MSG_RIGHT_PX := 509.0
## PC ítems: mensaje a la izquierda; reserva a la derecha = ancho del ChoiceBox o QuantityPicker.
const _PC_ITEMS_MSG_LEFT_PX := 8.0
const _PC_ITEMS_SIDE_GAP_PX := 4.0
const _PC_ITEMS_QTY_RESERVE_PX := 145.0
const _PC_CHOICE_GAP_ABOVE_MSG_PX := 8.0
## Party: mismo rect que FIXED_MSG en PartyUI.tscn (0,313)-(370,379).
const _PARTY_MSG_LEFT_PX := 0.0
const _PARTY_MSG_RIGHT_PX := 370.0
const _PARTY_MSG_BOTTOM_PX := 379.0
const _PARTY_MSG_HEIGHT_PX := 66.0
## Mismos insets que MessageBox.tscn (16 / 96−79=17) para centrar 1 línea en el marco.
const _PARTY_MSG_SCROLL_TOP_PX := 16.0
const _PARTY_MSG_SCROLL_BOTTOM_INSET_PX := 17.0
## Reserva horizontal actual a la derecha del MessageBox en PC ítems (0 = default qty).
var _pc_items_side_reserve_px: float = 0.0
const _UI_SCREEN_FADE_DURATION: float = 0.2
## Por encima de MSG (200) / ChoiceBox (210) al restaurar menús bajo el negro del PC.
const _UI_FADE_COVER_Z: int = 220
## Bag sobre PC (sprites del party/cursor usan z_index > 0 y quedarían encima si Bag=0).
const _BAG_OVER_PC_Z: int = 50

# === NODOS ===
@onready var msg: MessageBox = $MSG
@onready var choice_box: ChoiceBox = $ChoiceBox
@onready var BattleNew: BattleScene = $BattleNew
@onready var pause_menu = $PauseMenu
@onready var _bag_ui = $BagUI
@onready var _party_ui = $PartyUI
@onready var _pokedex_ui = $PokedexUI
@onready var _save_ui = $SaveUI
@onready var _evolution_ui = $EvolutionUI
@onready var _pc_storage_ui = $PCStorageUI
@onready var _pc_items_ui = $PCItemsUI
@onready var _poke_mart_ui = $PokeMartUI
@onready var _quantity_picker: Control = $QuantityPicker
@onready var overlay_layer: OverlayLayer = $OverlayLayer
@onready var fade_layer: ColorRect = $FadeLayer

@onready var _qty_amount_label: RichTextLabel = $QuantityPicker/Container/LabelHGSS
@onready var _qty_price_label: RichTextLabel = $QuantityPicker/Container/Price
@onready var _qty_up_arrow: Sprite2D = $QuantityPicker/QtyUp
@onready var _qty_down_arrow: Sprite2D = $QuantityPicker/QtyDown

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
	if _pokedex_ui:
		_pokedex_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _save_ui:
		_save_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _pc_storage_ui:
		_pc_storage_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _pc_items_ui:
		_pc_items_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _poke_mart_ui:
		_poke_mart_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	if _quantity_picker:
		_quantity_picker.process_mode = Node.PROCESS_MODE_ALWAYS
		_quantity_picker.hide()
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

	if _pokedex_ui:
		_pokedex_ui.back_requested.connect(_on_pokedex_back_requested)
		_pokedex_ui.closed.connect(_on_pokedex_closed)
		if _pokedex_ui.has_signal("visibility_changed"):
			_pokedex_ui.visibility_changed.connect(_on_ui_visibility_changed)

	if _save_ui:
		_save_ui.closed.connect(_on_save_ui_closed)
		if _save_ui.has_signal("visibility_changed"):
			_save_ui.visibility_changed.connect(_on_ui_visibility_changed)

	if _pc_storage_ui:
		_pc_storage_ui.closed.connect(_on_pc_storage_ui_closed)
		if _pc_storage_ui.has_signal("visibility_changed"):
			_pc_storage_ui.visibility_changed.connect(_on_ui_visibility_changed)

	if _pc_items_ui:
		_pc_items_ui.closed.connect(_on_pc_items_ui_closed)
		if _pc_items_ui.has_signal("visibility_changed"):
			_pc_items_ui.visibility_changed.connect(_on_ui_visibility_changed)

	if _poke_mart_ui:
		_poke_mart_ui.closed.connect(_on_poke_mart_ui_closed)
		if _poke_mart_ui.has_signal("visibility_changed"):
			_poke_mart_ui.visibility_changed.connect(_on_ui_visibility_changed)

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

## Muestra opciones y devuelve el índice seleccionado.
## close_at_end: si false, el ChoiceBox permanece abierto (cerrar con `close_choices`).
static func show_choices(options: Array[String], close_at_end: bool = true) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._show_choices(options, close_at_end)


## Menú de acciones del party: borde derecho alineado al viewport (diseño 512×384), crece hacia la izquierda.
static func show_party_action_choices(options: Array[String], close_at_end: bool = true) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	instance._push_party_action_choice_layout()
	var idx: int = await instance._show_choices(options, close_at_end)
	if close_at_end:
		instance._pop_party_action_choice_layout()
	return idx


## Opciones con anclaje a una esquina del viewport (`ChoiceBox.ChoiceAnchor`; PARTY_MENU/BAG tienen flujo propio).
## close_at_end: si false, permanece abierto; el layout de esquina se restaura en `close_choices`.
static func show_choices_corner(options: Array[String], anchor: ChoiceBox.ChoiceAnchor, close_at_end: bool = true) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	if anchor == ChoiceBox.ChoiceAnchor.SCENE_DEFAULT:
		return await instance._show_choices(options, close_at_end)
	if anchor == ChoiceBox.ChoiceAnchor.PARTY_MENU or anchor == ChoiceBox.ChoiceAnchor.BAG_TOP_LEFT:
		push_error("DisplayManager.show_choices_corner: usa show_party_action_choices o el flujo de mochila.")
		return -1
	instance._push_corner_choice_layout(anchor)
	# Misma distancia mensaje↔panel que con QuantityPicker (reserve = inset + ancho).
	if instance._is_pc_items_ui_open():
		set_pc_items_message_side_reserve(estimate_choice_panel_width(options) + 4.0)
	var idx: int = await instance._show_choices(options, close_at_end)
	if close_at_end:
		instance._pop_corner_choice_layout()
	return idx


## Espera otra selección sobre un ChoiceBox ya abierto (tras `close_at_end=false`).
static func await_choices(close_at_end: bool = true) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._await_choices(close_at_end)


## Cierra el ChoiceBox si está abierto y restaura layout pendiente (esquina / party action).
static func close_choices() -> void:
	if instance == null:
		return
	instance._close_choices()


## Activa/desactiva el input del ChoiceBox visible (p. ej. mientras un mensaje espera A).
static func set_choice_input_enabled(enabled: bool) -> void:
	if instance == null or instance.choice_box == null:
		return
	instance.choice_box.set_menu_input_enabled(enabled)


## Muestra un mensaje seguido de opciones.
## close_at_end: cierra el MessageBox tras la selección.
## close_choices_at_end: cierra el ChoiceBox tras la selección (si false, usar `close_choices`).
static func show_message_with_choices(text: String, options: Array[String], close_at_end: bool = true, close_choices_at_end: bool = true) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._show_message_with_choices(text, options, close_at_end, close_choices_at_end)


## Menú de acción de objeto de mochila (Usar/Tirar/Salir) con el mismo layout coordinado de overworld.
static func show_bag_item_action_menu(item_name: String) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._show_bag_item_action_menu(item_name)

## Cierra el MessageBox del overworld si está visible
static func close_message() -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	instance._close_message()

## Cambia el texto del MessageBox de golpe (sin efecto de escritura). Para ayudas de menú.
static func set_message_help_instant(text: String) -> void:
	if instance == null or instance.msg == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	instance.msg.set_help_text_instant(text)
	if instance._is_party_ui_open():
		instance._adapt_party_msg_height_to_lines()
	else:
		instance._adapt_pc_msg_height_to_lines()


## Ayuda del party (sustituye al FIXED_MSG): MessageBox en el rect del party, sin esperar input.
static func set_party_help_instant(text: String) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	instance._set_party_help_instant(text)

## Oculta el indicador de espera del MessageBox (p. ej. ayudas estáticas del PC).
static func hide_message_wait_indicator() -> void:
	if instance == null or instance.msg == null:
		return
	instance.msg.hide_wait_indicator()

## Abre la UI del PC (cajas). `mode` = PCStorageUI.Mode. Espera hasta cerrar.
## `prepare_before_reveal`: Callable async; en negro tras cerrar el PC (p. ej. restaurar menú BILL).
## `cleanup_under_cover`: Callable async; en negro al abrir, antes de montar el PC (p. ej. cerrar choices).
static func open_pc(
	mode: int = 0,
	box_index: int = 0,
	prepare_before_reveal: Callable = Callable(),
	cleanup_under_cover: Callable = Callable()
) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._open_pc_storage_ui(mode, box_index, prepare_before_reveal, cleanup_under_cover)


## Abre la UI de ítems del PC (depósito). `mode` = PCItemsUI.Mode.
## Misma transición/SFX que `open_pc` (máscara CRT).
static func open_pc_items(
	mode: int = 0,
	prepare_before_reveal: Callable = Callable(),
	cleanup_under_cover: Callable = Callable()
) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._open_pc_items_ui(mode, prepare_before_reveal, cleanup_under_cover)


## PC → DEJAR OBJETO: abre la mochila para depositar ítems. Misma máscara CRT que `open_pc_items`.
static func open_bag_for_pc_deposit(
	prepare_before_reveal: Callable = Callable(),
	cleanup_under_cover: Callable = Callable()
) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._open_bag_for_pc_deposit(prepare_before_reveal, cleanup_under_cover)


## Abre la UI de tienda (compra) con un `ShopData`. Espera hasta cerrar.
## Venta → `open_bag_for_sell`. Menú raíz Comprar/Vender/Salir → #836.
static func open_poke_mart(shop: ShopData, with_screen_fade: bool = true) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._open_poke_mart_ui(shop, with_screen_fade)


## Abre la mochila en modo venta (misma UI que el menú). Espera hasta cerrar. (#834 → #836)
static func open_bag_for_sell(with_screen_fade: bool = true) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._open_bag_for_sell(with_screen_fade)


## QuantityPicker: cantidad 1..max, o 0 si cancela.
## Sin `unit_price`: si max<=1 no pregunta. Con precio (mart) siempre muestra el picker + total.
static func prompt_quantity(
	max_qty: int,
	prompt: String = "¿Qué cantidad?",
	unit_price: int = 0,
	frame_style: MessageBoxFrameStyle.Values = MessageBoxFrameStyle.Values.FIRERED
) -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return 0
	return await instance._prompt_quantity(max_qty, prompt, unit_price, frame_style)


## PC: abre la mochila para elegir un objeto a dar (held). Devuelve item_id o -1 si cancela.
static func pick_held_item_from_bag() -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._pick_held_item_from_bag()


## Party → Objeto → DAR: mochila sobre el party; al elegir aplica held y mensajes (party permanece).
static func party_give_held_from_bag(slot_index: int) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._party_give_held_from_bag(slot_index)


## Party → Objeto → QUITAR: quita held a la mochila (o mensaje si no lleva nada).
static func party_take_held_item(slot_index: int) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._party_take_held_item(slot_index)


## PC ítems → DAR: abre el party para elegir a quién dar. Devuelve slot o -1 si cancela.
## Si hay slot, el party sigue abierto (mensaje de resultado encima); luego `close_party_give_held()`.
static func pick_party_slot_for_give_held() -> int:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return -1
	return await instance._pick_party_slot_for_give_held()


## Cierra party + mensaje tras DAR (fundido de vuelta al PC ítems).
static func close_party_give_held() -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._close_party_give_held()


## Refresco visual del party abierto (p. ej. icono de held tras DAR).
static func refresh_party_slots_display() -> void:
	if instance == null or instance._party_ui == null:
		return
	if instance._party_ui.visible and instance._party_ui.has_method("refresh_slots_display"):
		instance._party_ui.refresh_slots_display()


## Si `one_line` cabe en el MessageBox actual (p. ej. PC ítems), lo usa; si no, `two_line`.
static func pick_message_line_break(one_line: String, two_line: String) -> String:
	if instance == null:
		return one_line
	if instance._message_text_fits_one_line(one_line):
		return one_line
	return two_line


## Abre el ChoiceBox en esquina sin esperar selección (`close_choices` / `await_choices` después).
static func open_choices_corner(options: Array[String], anchor: ChoiceBox.ChoiceAnchor) -> bool:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return false
	if options.is_empty():
		push_error("DisplayManager.open_choices_corner: opciones vacías")
		return false
	if anchor == ChoiceBox.ChoiceAnchor.PARTY_MENU or anchor == ChoiceBox.ChoiceAnchor.BAG_TOP_LEFT:
		push_error("DisplayManager.open_choices_corner: usa el flujo de party/mochila.")
		return false
	if anchor != ChoiceBox.ChoiceAnchor.SCENE_DEFAULT:
		instance._push_corner_choice_layout(anchor)
	return await instance.choice_box.open_choices_keep_open(options)

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


## Fade con máscara de pantalla.
## to_black=true: cubrir a negro (como FadeCommand IN). to_black=false: revelar (OUT).
## DOOR usa wipe horizontal + velo oscuro→claro. Si falla la máscara, fallback a fade sólido.
static func fade_with_mask(to_black: bool, mask: ScreenTransitionEnum.Type, duration: float = 0.5) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	var ok: bool
	if ScreenTransitionEnum.is_door(mask):
		ok = await instance.fade_layer.play_door_transition(to_black, duration)
	else:
		var path := ScreenTransitionEnum.to_mask_path(mask)
		ok = await instance.fade_layer.play_mask_transition(path, to_black, duration)
	if ok:
		return
	if to_black:
		await instance.fade_layer.fade_in(duration)
	else:
		await instance.fade_layer.fade_out(duration)

## Verifica si está en fade
static func is_fading() -> bool:
	if instance == null:
		return false
	return instance._is_fading()


## True mientras hay hold de arranque de eventos (p. ej. derrota hasta revelar el mapa).
static func blocks_event_start() -> bool:
	return instance != null and instance._hold_overworld_events


## True mientras la escena de combate está activa (intro, turnos, submenús de batalla).
static func is_battle_active() -> bool:
	return instance != null and instance.BattleNew.visible


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

## Entrada única para el flujo de evolución (party / post-batalla / mundo).
static func start_evolution(
	pokemon: Pokemon,
	target_species_id: int,
	origin_context: EvolutionOriginContext.Kind,
	evolution_method: int = CONST.EVOL_LVL_UP
) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible para start_evolution")
		return
	await instance._start_evolution_impl(pokemon, target_species_id, origin_context, evolution_method)


## Revela la escena de batalla con efecto de transición inversa (Gen 3: mitad → pausa → abrir).
static func reveal_battle(duration: float = 0.4, staged: bool = true) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance.fade_layer.reveal_battle(duration, staged)


static func battle_reveal_total_duration() -> float:
	return preload("res://Scripts/UI/FadeLayer.gd").battle_reveal_total_duration()

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

static func play_mo_overlay(pokemon_visual: Variant = null, pokemon: Pokemon = null) -> void:
	if instance == null:
		push_error("DisplayManager: No hay instancia disponible")
		return
	await instance._play_mo_overlay(pokemon_visual, pokemon)

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
	var cfg := config.duplicate()
	if not "frameStyle" in cfg:
		cfg["frameStyle"] = MessageBoxFrameStyle.Values.HGSS
	# fullWidth: mensaje a pantalla completa aunque haya PC ítems/cajas abierto.
	var force_full_width: bool = bool(cfg.get("fullWidth", false))
	var want_expand: bool = bool(cfg.get("expandHeight", false))
	var use_party_layout: bool = _is_party_ui_open()
	if use_party_layout and _pc_msg_layout_saved:
		_pop_pc_msg_layout()
	if force_full_width and _pc_msg_layout_saved:
		_pop_pc_msg_layout()
	var used_pc_layout := false
	var used_party_layout := false
	if use_party_layout:
		# Party: rect FIXED_MSG. Sin expandHeight interno (rompe offsets/altura).
		cfg["expandHeight"] = false
		want_expand = false
		if msg.has_method("restore_expanded_height"):
			msg.restore_expanded_height()
		var est_h: float = _estimate_party_msg_bar_height_for_text(text)
		if _party_msg_layout_saved:
			_apply_party_msg_box_rect(est_h)
			used_party_layout = true
		else:
			used_party_layout = _push_party_msg_layout_if_needed(est_h)
		if not "frameStyle" in config:
			cfg["frameStyle"] = MessageBoxFrameStyle.Values.FIRERED
	elif not force_full_width:
		# Altura correcta ANTES de pintar (evita flash 2 líneas → 1).
		var est_h: float = _estimate_pc_msg_bar_height_for_text(text)
		if _pc_msg_layout_saved:
			_apply_pc_msg_box_rect(est_h)
			used_pc_layout = true
		else:
			used_pc_layout = _push_pc_msg_layout_if_needed(est_h)
	# Si hay choices abiertos, no deben consumir el mismo ui_accept que el MessageBox.
	var paused_choices := false
	if choice_box != null and choice_box.visible:
		choice_box.set_menu_input_enabled(false)
		paused_choices = true
	await msg.show_custom(text, cfg)
	if paused_choices and choice_box != null and choice_box.visible:
		choice_box.set_menu_input_enabled(true)
	# Si el mensaje se cerró solo (closeAtEnd), restaurar layout.
	if msg != null and not msg.visible:
		if used_pc_layout:
			_pop_pc_msg_layout()
		if used_party_layout:
			_pop_party_msg_layout()
	elif msg != null and msg.visible:
		# Refinar tras layout real (2 frames: RTL ya tiene ancho y wraps).
		await get_tree().process_frame
		await get_tree().process_frame
		if used_party_layout:
			_adapt_party_msg_height_to_lines()
		elif used_pc_layout:
			_adapt_pc_msg_height_to_lines()
		elif force_full_width or want_expand:
			_fit_visible_msg_height_to_content()


func _show_choices(options: Array[String], close_at_end: bool = true) -> int:
	if options.is_empty():
		push_error("DisplayManager._show_choices: Array de opciones vacío")
		return -1

	if close_at_end:
		return await choice_box.show_choices(options)

	if not await choice_box.open_choices_keep_open(options):
		return -1
	return await choice_box.await_choice_keep_open()


func _await_choices(close_at_end: bool = true) -> int:
	if choice_box == null or not choice_box.visible:
		push_error("DisplayManager._await_choices: no hay ChoiceBox abierto")
		return -1
	var selected_index: int = await choice_box.await_choice_keep_open()
	if close_at_end:
		_close_choices()
	return selected_index


func _close_choices() -> void:
	if choice_box != null:
		choice_box.close_choices()
	_pop_corner_choice_layout()
	if _party_action_choice_layout_saved:
		_pop_party_action_choice_layout()


func _push_corner_choice_layout(anchor: ChoiceBox.ChoiceAnchor) -> void:
	if _corner_choice_layout_saved:
		_pop_corner_choice_layout()
	_corner_choice_saved_layout = _snapshot_choice_box_layout()
	_corner_choice_layout_saved = true
	choice_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Solo el PC de cajas necesita subir el ChoiceBox por encima del MessageBox.
	# En PC ítems el menú va a la altura del texto, junto al mensaje.
	if _is_pc_storage_ui_open():
		choice_box.set_extra_bottom_inset(_pc_choice_bottom_clearance())
	elif (_poke_mart_ui != null and _poke_mart_ui.visible) or _bag_sell_active:
		# Misma altura inferior que el QuantityPicker del mart.
		choice_box.set_extra_bottom_inset(
			absf(_QTY_MART_OFFSET_BOTTOM) - ChoiceBox.CORNER_INSET_BOTTOM
		)
	elif _is_pc_items_ui_open():
		choice_box.clear_extra_bottom_inset()
	choice_box.set_corner_anchor(anchor)


func _pop_corner_choice_layout() -> void:
	if not _corner_choice_layout_saved:
		return
	_restore_choice_box_layout(_corner_choice_saved_layout)
	if choice_box != null:
		choice_box.clear_corner_anchor()
		choice_box.clear_extra_bottom_inset()
	_corner_choice_saved_layout = {}
	_corner_choice_layout_saved = false


func _is_pc_storage_ui_open() -> bool:
	return _pc_storage_ui != null and _pc_storage_ui.visible


func _is_pc_items_ui_open() -> bool:
	return _pc_items_ui != null and _pc_items_ui.visible


func _is_any_pc_screen_open() -> bool:
	return _is_pc_storage_ui_open() or _is_pc_items_ui_open()


func _pc_choice_bottom_clearance() -> float:
	var gap: float = _PC_CHOICE_GAP_ABOVE_MSG_PX
	if msg != null and msg.visible and msg.size.y > 8.0:
		return msg.size.y + gap
	return _MSG_BAR_HEIGHT_PX + gap


func _push_pc_msg_layout_if_needed(bar_h: float = -1.0) -> bool:
	if not (_is_any_pc_screen_open() or _qty_prompt_layout_active) or msg == null:
		return _pc_msg_layout_saved
	if _pc_msg_layout_saved:
		# Reajustar ancho; altura = pedida o la actual (no forzar 96).
		var keep_h: float = bar_h
		if keep_h < 0.0:
			keep_h = msg.size.y if msg.size.y > 8.0 else _MSG_BAR_HEIGHT_PX
		_apply_pc_msg_box_rect(keep_h)
		return true
	_pc_msg_saved_layout = _snapshot_msg_panel_layout()
	if msg.scroll != null:
		_pc_msg_saved_scroll = {
			"left": msg.scroll.offset_left,
			"right": msg.scroll.offset_right,
			"top": msg.scroll.offset_top,
			"bottom": msg.scroll.offset_bottom,
		}
	_apply_pc_msg_box_rect(bar_h if bar_h > 0.0 else _MSG_BAR_HEIGHT_PX)
	_pc_msg_layout_saved = true
	return true


## Estima altura del panel PC ítems según saltos explícitos / si cabe en una línea.
func _estimate_pc_msg_bar_height_for_text(text: String) -> float:
	var plain := String(text).replace("\r", "")
	if plain.find("\n") >= 0:
		return _MSG_BAR_HEIGHT_PX
	# Asegurar ancho de layout para medir sin imponer altura de 2 líneas.
	if not _pc_msg_layout_saved:
		_push_pc_msg_layout_if_needed(_MSG_BAR_HEIGHT_ONE_LINE_PX)
	else:
		_apply_pc_msg_box_rect(msg.size.y if msg.size.y > 8.0 else _MSG_BAR_HEIGHT_ONE_LINE_PX)
	if _message_text_fits_one_line_at_current_width(plain):
		return _MSG_BAR_HEIGHT_ONE_LINE_PX
	return _MSG_BAR_HEIGHT_PX


func _message_text_fits_one_line_at_current_width(text: String) -> bool:
	if msg == null or msg.label == null:
		return true
	msg.fit_scroll_width_to_panel()
	var rtl: RichTextLabel = msg.label
	var font: Font = rtl.get_theme_font("normal_font")
	var font_size: int = rtl.get_theme_font_size("normal_font_size")
	if font == null:
		return true
	var avail: float = rtl.size.x
	if avail < 8.0:
		avail = rtl.custom_minimum_size.x
	if avail < 8.0 and msg.scroll != null:
		avail = maxf(1.0, msg.scroll.offset_right - msg.scroll.offset_left)
	var measured: float = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	return measured <= avail + 0.5


func _apply_pc_msg_box_rect(bar_h: float = -1.0) -> void:
	if msg == null:
		return
	var vh: float = _MSG_VIEWPORT_BASE.y
	if bar_h < 0.0:
		bar_h = _MSG_BAR_HEIGHT_PX
	var left_x: float = _PC_MSG_LEFT_PX
	var right_x: float = _PC_MSG_RIGHT_PX
	if _is_pc_items_ui_open() or _qty_prompt_layout_active:
		left_x = _PC_ITEMS_MSG_LEFT_PX
		var reserve: float = _pc_items_side_reserve_px
		if reserve <= 0.0:
			reserve = _PC_ITEMS_QTY_RESERVE_PX
		right_x = _MSG_VIEWPORT_BASE.x - reserve - _PC_ITEMS_SIDE_GAP_PX
		right_x = maxf(right_x, left_x + 64.0)
	var bar_w: float = right_x - left_x
	msg.anchor_left = 0.0
	msg.anchor_top = 0.0
	msg.anchor_right = 0.0
	msg.anchor_bottom = 0.0
	msg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	msg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	msg.custom_minimum_size = Vector2(bar_w, bar_h)
	msg.offset_left = left_x
	msg.offset_top = vh - bar_h
	msg.offset_right = right_x
	msg.offset_bottom = vh
	msg.size = Vector2(bar_w, bar_h)
	if msg.scroll != null:
		msg.scroll.offset_bottom = maxf(msg.scroll.offset_top + 8.0, bar_h - _MSG_SCROLL_BOTTOM_INSET_PX)
	msg.fit_scroll_width_to_panel()
	if msg.has_method("_adjust_container_size"):
		msg._adjust_container_size()


## Tras pintar texto: 1 línea → panel bajo; 2 → 96px; 3+ → crece para no clipar.
func _adapt_pc_msg_height_to_lines() -> void:
	if msg == null or not _pc_msg_layout_saved:
		return
	if msg.label == null:
		_apply_pc_msg_box_rect(_MSG_BAR_HEIGHT_PX)
		return
	# Mostrar todo el texto (sin paginar) antes de medir.
	msg.label.visible_characters = -1
	msg.fit_scroll_width_to_panel()
	if msg.has_method("_adjust_container_size"):
		msg._adjust_container_size()
	var lines: int = maxi(1, msg.label.get_line_count())
	msg.label.nextLineStop = lines

	var bar_h: float = _MSG_BAR_HEIGHT_PX
	if lines <= 1:
		bar_h = _MSG_BAR_HEIGHT_ONE_LINE_PX
	else:
		var top_m: float = 16.0
		if msg.scroll != null:
			top_m = msg.scroll.offset_top
		var content_h: float = float(msg.label.get_content_height())
		if content_h < 8.0:
			var fs: int = msg.label.get_theme_font_size("normal_font_size")
			if fs <= 0:
				fs = 26
			content_h = float(lines) * float(fs + 8)
		bar_h = top_m + content_h + _MSG_SCROLL_BOTTOM_INSET_PX
		bar_h = maxf(bar_h, _MSG_BAR_HEIGHT_PX)
	_apply_pc_msg_box_rect(bar_h)
	if msg.scroll != null:
		msg.scroll.scroll_vertical = 0


## Full width / expand: mide tras layout y ajusta alto (no deja texto cortado).
func _fit_visible_msg_height_to_content() -> void:
	if msg == null or msg.label == null or not msg.visible:
		return
	msg.label.visible_characters = -1
	if msg.has_method("fit_scroll_width_to_panel"):
		msg.fit_scroll_width_to_panel()
	if msg.has_method("_adjust_container_size"):
		msg._adjust_container_size()
	var lines: int = maxi(1, msg.label.get_line_count())
	msg.label.nextLineStop = lines
	if msg.has_method("_fit_panel_height_to_all_lines"):
		msg._fit_panel_height_to_all_lines()
	# Si el fit encogió de más (1 línea reportada antes del wrap), forzar al menos 2 líneas.
	lines = maxi(1, msg.label.get_line_count())
	if lines >= 2 and msg.size.y + 0.5 < _MSG_BAR_HEIGHT_PX:
		msg._fit_panel_height_to_all_lines()


## Ancho útil del RTL del MessageBox (tras layout PC si aplica).
func _message_text_fits_one_line(text: String) -> bool:
	if msg == null or msg.label == null:
		return true
	if not _pc_msg_layout_saved:
		_push_pc_msg_layout_if_needed(_MSG_BAR_HEIGHT_ONE_LINE_PX)
	else:
		_apply_pc_msg_box_rect(msg.size.y if msg.size.y > 8.0 else _MSG_BAR_HEIGHT_ONE_LINE_PX)
	return _message_text_fits_one_line_at_current_width(text)


## Reserva horizontal a la derecha del MessageBox en PC ítems (ancho del ChoiceBox o QuantityPicker).
## El hueco entre mensaje y panel lateral es siempre `_PC_ITEMS_SIDE_GAP_PX`.
## Solo reajusta el ancho; la altura la fija el siguiente `show_message` (evita flash).
static func set_pc_items_message_side_reserve(width_px: float) -> void:
	if instance == null:
		return
	instance._pc_items_side_reserve_px = maxf(0.0, width_px)
	if instance._pc_msg_layout_saved and (instance._is_pc_items_ui_open() or instance._qty_prompt_layout_active) and instance.msg != null:
		var keep_h: float = instance.msg.size.y if instance.msg.size.y > 8.0 else instance._MSG_BAR_HEIGHT_PX
		instance._apply_pc_msg_box_rect(keep_h)


static func clear_pc_items_message_side_reserve() -> void:
	set_pc_items_message_side_reserve(0.0)


## Ancho estimado del ChoiceBox para las opciones dadas (misma fórmula que ChoiceBox).
static func estimate_choice_panel_width(options: Array[String]) -> float:
	var font: Font = load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf") as Font
	var max_text_w := 0.0
	if font != null:
		for opt in options:
			var sz: Vector2 = font.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
			max_text_w = maxf(max_text_w, sz.x)
	return max_text_w + 58.0


func _pop_pc_msg_layout() -> void:
	if not _pc_msg_layout_saved or msg == null:
		_pc_msg_layout_saved = false
		_pc_items_side_reserve_px = 0.0
		return
	_restore_msg_panel_layout(_pc_msg_saved_layout)
	if msg.scroll != null and not _pc_msg_saved_scroll.is_empty():
		msg.scroll.offset_left = float(_pc_msg_saved_scroll.get("left", 32.0))
		msg.scroll.offset_right = float(_pc_msg_saved_scroll.get("right", 465.0))
		msg.scroll.offset_top = float(_pc_msg_saved_scroll.get("top", 16.0))
		msg.scroll.offset_bottom = float(_pc_msg_saved_scroll.get("bottom", 79.0))
		if msg.has_method("_sync_text_container_width_to_scroll"):
			msg._sync_text_container_width_to_scroll()
	_pc_msg_saved_layout = {}
	_pc_msg_saved_scroll = {}
	_pc_msg_layout_saved = false
	_pc_items_side_reserve_px = 0.0


func _show_message_with_choices(text: String, options: Array[String], close_at_end: bool = true, close_choices_at_end: bool = true) -> int:
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
	_push_pc_msg_layout_if_needed()
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
	var selected_index = await _show_choices(options, close_choices_at_end)

	# Restaurar la posición del scroll después de mostrar las opciones
	# para asegurar que el texto se mantenga en la posición final
	msg.scroll.scroll_vertical = final_scroll_position

	# Cerrar el MessageBox después de la selección solo si close_at_end es true
	if close_at_end:
		msg.hide()
		msg.clear()
		msg.restore_expanded_height()
		_pop_pc_msg_layout()
		_pop_party_msg_layout()

	return selected_index

func _close_message() -> void:
	if msg.visible:
		msg.hide()
		msg.clear()
		msg.restore_expanded_height()
	_pop_pc_msg_layout()
	_pop_party_msg_layout()


func _is_party_ui_open() -> bool:
	return _party_ui != null and _party_ui.visible


func _set_party_help_instant(text: String) -> void:
	_party_help_text = text
	if not _is_party_ui_open() or msg == null:
		return
	# Tras un diálogo de 2 líneas, resetear expansión y forzar altura FIXED_MSG (66).
	if msg.has_method("restore_expanded_height"):
		msg.restore_expanded_height()
	# La ayuda del party es siempre 1 línea en el rect FIXED_MSG (no escalar a 96).
	var bar_h: float = _PARTY_MSG_HEIGHT_PX
	_push_party_msg_layout_if_needed(bar_h)
	_apply_party_msg_box_rect(bar_h)
	msg.set_frame_style(MessageBoxFrameStyle.Values.FIRERED)
	# Ayuda estática: no consumir ui_accept ni mostrar indicador.
	msg.waitInput = false
	msg.closeAtEnd = false
	msg.showIconAtEnd = false
	msg._expand_height = false
	msg.set_help_text_instant(text)
	hide_message_wait_indicator()
	# Reaplicar tras pintar (set_help / adjust_container no deben cambiar el alto del panel).
	_apply_party_msg_box_rect(bar_h)


func _push_party_msg_layout_if_needed(bar_h: float = -1.0) -> bool:
	if not _is_party_ui_open() or msg == null:
		return _party_msg_layout_saved
	if _party_msg_layout_saved:
		var keep_h: float = bar_h
		if keep_h < 0.0:
			keep_h = msg.size.y if msg.size.y > 8.0 else _PARTY_MSG_HEIGHT_PX
		_apply_party_msg_box_rect(keep_h)
		return true
	_party_msg_saved_layout = _snapshot_msg_panel_layout()
	if msg.scroll != null:
		_party_msg_saved_scroll = {
			"left": msg.scroll.offset_left,
			"right": msg.scroll.offset_right,
			"top": msg.scroll.offset_top,
			"bottom": msg.scroll.offset_bottom,
		}
	_apply_party_msg_box_rect(bar_h if bar_h > 0.0 else _PARTY_MSG_HEIGHT_PX)
	_party_msg_layout_saved = true
	return true


func _pop_party_msg_layout() -> void:
	if not _party_msg_layout_saved or msg == null:
		_party_msg_layout_saved = false
		return
	_restore_msg_panel_layout(_party_msg_saved_layout)
	if msg.scroll != null and not _party_msg_saved_scroll.is_empty():
		msg.scroll.offset_left = float(_party_msg_saved_scroll.get("left", 32.0))
		msg.scroll.offset_right = float(_party_msg_saved_scroll.get("right", 465.0))
		msg.scroll.offset_top = float(_party_msg_saved_scroll.get("top", 16.0))
		msg.scroll.offset_bottom = float(_party_msg_saved_scroll.get("bottom", 79.0))
		if msg.has_method("_sync_text_container_width_to_scroll"):
			msg._sync_text_container_width_to_scroll()
	_party_msg_saved_layout = {}
	_party_msg_saved_scroll = {}
	_party_msg_layout_saved = false


func _apply_party_msg_box_rect(bar_h: float = -1.0) -> void:
	if msg == null:
		return
	if bar_h < 0.0:
		bar_h = _PARTY_MSG_HEIGHT_PX
	var left_x: float = _PARTY_MSG_LEFT_PX
	var right_x: float = _PARTY_MSG_RIGHT_PX
	var bottom_y: float = _PARTY_MSG_BOTTOM_PX
	var top_y: float = bottom_y - bar_h
	var bar_w: float = right_x - left_x
	msg.anchor_left = 0.0
	msg.anchor_top = 0.0
	msg.anchor_right = 0.0
	msg.anchor_bottom = 0.0
	msg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	msg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Forzar alto exacto (el MSG de escena trae min 96 y no debe ganar).
	msg.custom_minimum_size = Vector2(bar_w, bar_h)
	msg.size = Vector2(bar_w, bar_h)
	msg.offset_left = left_x
	msg.offset_top = top_y
	msg.offset_right = right_x
	msg.offset_bottom = bottom_y
	# Reasignar size tras offsets (algunos Control crecen con min_size previo).
	msg.size = Vector2(bar_w, bar_h)
	if msg.scroll != null:
		msg.scroll.offset_top = _PARTY_MSG_SCROLL_TOP_PX
		msg.scroll.offset_bottom = maxf(
			msg.scroll.offset_top + 8.0,
			bar_h - _PARTY_MSG_SCROLL_BOTTOM_INSET_PX
		)
	msg.fit_scroll_width_to_panel()
	if msg.has_method("_adjust_container_size"):
		msg._adjust_container_size()
	# Por si _adjust_container_size / fit alteran el panel.
	msg.custom_minimum_size = Vector2(bar_w, bar_h)
	msg.size = Vector2(bar_w, bar_h)
	msg.offset_left = left_x
	msg.offset_top = top_y
	msg.offset_right = right_x
	msg.offset_bottom = bottom_y


func _estimate_party_msg_bar_height_for_text(text: String) -> float:
	var plain := String(text).replace("\r", "")
	if plain.find("\n") >= 0:
		return maxf(_PARTY_MSG_HEIGHT_PX, _MSG_BAR_HEIGHT_PX)
	if not _party_msg_layout_saved:
		_push_party_msg_layout_if_needed(_PARTY_MSG_HEIGHT_PX)
	else:
		_apply_party_msg_box_rect(_PARTY_MSG_HEIGHT_PX)
	if _message_text_fits_one_line_at_current_width(plain):
		return _PARTY_MSG_HEIGHT_PX
	return maxf(_PARTY_MSG_HEIGHT_PX, _MSG_BAR_HEIGHT_PX)


func _adapt_party_msg_height_to_lines() -> void:
	if msg == null or not _party_msg_layout_saved:
		return
	var plain := ""
	if msg.label != null:
		plain = String(msg.label.get_parsed_text() if msg.label.has_method("get_parsed_text") else msg.label.text)
	plain = plain.replace("\r", "")
	var bar_h: float = _PARTY_MSG_HEIGHT_PX
	if plain.find("\n") >= 0 or not _message_text_fits_one_line_at_current_width(plain):
		bar_h = maxf(_PARTY_MSG_HEIGHT_PX, _MSG_BAR_HEIGHT_PX)
	_apply_party_msg_box_rect(bar_h)

func _is_fading() -> bool:
	return fading or (fade_layer != null and fade_layer.is_fade_active())

func _is_visible() -> bool:
	return msg.visible || BattleNew.visible || choice_box.visible || (pause_menu != null && pause_menu.visible) || (_bag_ui != null and _bag_ui.visible) || (_party_ui != null and _party_ui.visible) || (_pokedex_ui != null and _pokedex_ui.visible) || (_save_ui != null and _save_ui.visible) || (_pc_storage_ui != null and _pc_storage_ui.visible) or (_pc_items_ui != null and _pc_items_ui.visible) or (_poke_mart_ui != null and _poke_mart_ui.visible)


func _start_evolution_impl(
	pokemon: Pokemon,
	target_species_id: int,
	origin_context: EvolutionOriginContext.Kind,
	evolution_method: int = CONST.EVOL_LVL_UP
) -> void:
	if _evolution_ui == null:
		push_warning("DisplayManager._start_evolution_impl: nodo EvolutionUI no disponible")
		return

	_evolution_ui.z_index = 100
	var ctrl = EvolutionControllerScr.new()
	await ctrl.call("run", _evolution_ui, pokemon, target_species_id, origin_context, evolution_method)


func _run_pending_evolutions_post_battle() -> void:
	if GameStateService == null:
		return
	var party: Party = GameStateService.get_party()
	if party == null:
		return
	for i in range(party.count()):
		var mon: Pokemon = party.get_pokemon(i)
		if mon == null:
			continue
		while not mon.pending_evolution.is_empty():
			var tid: int = int(mon.pending_evolution.get("target_species_id", 0))
			var method: int = int(mon.pending_evolution.get("method", CONST.EVOL_LVL_UP))
			if tid <= 0:
				mon.pending_evolution.clear()
				break
			await _start_evolution_impl(mon, tid, EvolutionOriginContext.Kind.POST_BATTLE, method)


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
		if participant.belongs_to_player_side():
			player_participants.append(participant)
		else:
			enemy_participants.append(participant)

	AudioManager.play_battle_bgm(rules, enemy_participants)

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

	# Fundido a negro: oculta la batalla; mantenemos pantalla negra hasta evoluciones (si hay).
	await fade_layer.fade_in(1.0)

	BattleNew.cleanup_battle()

	if _winner_side == "enemy":
		_hold_overworld_events = true
		await _apply_defeat_respawn_warp()

	_restore_overworld_bgm()
	await get_tree().create_timer(AudioManager.BATTLE_EXIT_BGM_FADE).timeout

	await _run_pending_evolutions_post_battle()

	# Mantener negro un momento antes de revelar el overworld.
	await get_tree().create_timer(1.0).timeout

	# Revelar overworld solo cuando ya no hay evolución pendiente ni UI encima del negro.
	await fade_layer.fade_out(0.3)

	if _winner_side == "enemy":
		_hold_overworld_events = false
		_flush_overworld_event_queue()

	# Emitir señal de batalla terminada (señal de DisplayManager)
	battle_finished.emit(_winner_side)

	# Solo desbloquear control del jugador si el combate NO fue iniciado desde un evento
	# Si fue desde un evento, el EventController se encargará de desbloquear cuando termine
	# En derrota: si el autorun del CP ya bloqueó, no liberar aquí (lo hará al terminar la página).
	if not _battle_from_event:
		if _winner_side == "enemy" and _is_overworld_event_busy():
			print("DisplayManager: Derrota — autorun activo, no se desbloquea el control aquí")
		else:
			player_control_unblocked.emit()
			print("DisplayManager: Combate no iniciado desde evento, desbloqueando control del jugador")
	else:
		print("DisplayManager: Combate iniciado desde evento, NO desbloqueando control (EventController lo manejará)")

	# Marcar cleanup como completado
	_battle_cleanup_done = true


## Blanqueo: warp al `respawn_point` del guardado (no recarga el save; solo alinear overworld con GameState).
func _apply_defeat_respawn_warp() -> void:
	if GameStateService == null:
		return
	# Autorun del CP: con hold activo se encola y no arranca hasta soltar tras fade_out.
	GameStateService.set_variable(GameStateService.VAR_DEFEATED, true)
	# En Gen 3 el equipo se cura al blanquear (Casa / Centro).
	var party = GameStateService.get_party()
	if party != null and party.has_method("heal_all"):
		party.heal_all()
	var ctx := _resolve_overworld_context()
	if ctx == null:
		push_warning("DisplayManager._apply_defeat_respawn_warp: OverworldContext no disponible")
		return
	var rp: Dictionary = GameStateService.get_respawn_point()
	var map_id: String = str(rp.get("map_id", ""))
	if map_id.is_empty():
		push_warning("DisplayManager._apply_defeat_respawn_warp: map_id vacío tras normalizar; se omite")
		return
	var pos_any: Variant = rp.get("position", null)
	var tile: Vector2i
	if pos_any is Vector2i:
		tile = pos_any
	else:
		tile = Vector2i(1, 0)
	var fac_any: Variant = rp.get("facing", null)
	var fac: Vector2
	if fac_any is Vector2:
		fac = fac_any
	else:
		fac = Vector2.DOWN
	print("DisplayManager: derrota — respawn a mapa=%s tile=%s facing=%s" % [map_id, tile, fac])
	await ctx.request_warp(map_id, tile)
	var ws: Node = ctx.get_world_system()
	if ws == null:
		return
	var grid = ws.get_active_grid() if ws.has_method("get_active_grid") else null
	var player: Node = ctx.get_player()
	if grid and player and grid.has_method("set_player_facing_direction"):
		grid.set_player_facing_direction(fac, player)
	if ws.has_method("force_sync_to_gamestate"):
		ws.force_sync_to_gamestate()
	# Solo en blanqueo: alinear `indoor` con el mapa destino (no en warps de puerta,
	# que usan el flag temporalmente para la animación de salida).
	_sync_indoor_flag_after_defeat_respawn(ws)


## Sincroniza el flag global `indoor` con `MapScene.is_indoor` del mapa activo.
func _sync_indoor_flag_after_defeat_respawn(ws: Node) -> void:
	if ws == null or not ws.has_method("get_active_map"):
		return
	var active_map = ws.get_active_map()
	if active_map == null:
		return
	var is_indoor := false
	if "is_indoor" in active_map:
		is_indoor = bool(active_map.is_indoor)
	GameStateService.set_event_flag("indoor", is_indoor)
	print("DisplayManager: derrota — flag indoor=%s (mapa %s)" % [is_indoor, active_map.name])


func _is_overworld_event_busy() -> bool:
	var ctx := _resolve_overworld_context()
	if ctx == null:
		return false
	var es = ctx.get_event_system() if ctx.has_method("get_event_system") else null
	return es != null and es.has_method("is_any_controller_busy") and es.is_any_controller_busy()


func _flush_overworld_event_queue() -> void:
	var ctx := _resolve_overworld_context()
	if ctx == null:
		return
	var es = ctx.get_event_system() if ctx.has_method("get_event_system") else null
	if es != null and es.has_method("flush_queue"):
		es.flush_queue()


func _restore_overworld_bgm() -> void:
	var ctx := _resolve_overworld_context()
	if ctx == null:
		# No hay overworld (p.ej. TestBattle): parar el BGM de batalla directamente.
		AudioManager.stop_bgm(AudioManager.BATTLE_EXIT_BGM_FADE)
		return
	var ws: Node = ctx.get_world_system()
	if ws != null and ws.has_method("refresh_map_bgm"):
		ws.refresh_map_bgm()


func _play_mo_overlay(pokemon_visual: Variant, pokemon: Pokemon = null) -> void:
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

	await overlay.play(pokemon_visual, pokemon)

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
		var focused_battle_modal_visible := false
		if battle_ui and battle_ui.has_method("has_modal_ui_visible"):
			focused_battle_modal_visible = bool(battle_ui.call("has_modal_ui_visible"))
		if battle_ui != null and focus_owner != null and battle_ui.is_ancestor_of(focus_owner) and not focused_battle_modal_visible:
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
			if not BattleNew.visible and not msg.visible and not choice_box.visible and not (_bag_ui != null and _bag_ui.visible) and not (_party_ui != null and _party_ui.visible) and not (_pokedex_ui != null and _pokedex_ui.visible) and not (_save_ui != null and _save_ui.visible) and not ((_pc_storage_ui != null and _pc_storage_ui.visible) or (_pc_items_ui != null and _pc_items_ui.visible)) and not (_poke_mart_ui != null and _poke_mart_ui.visible):
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
	var battle_modal_ui_visible = false
	if BattleNew.visible:
		var battle_ui = BattleNew.get_node_or_null("BattleUI")
		if battle_ui and battle_ui.has_node("MessageBox"):
			var battle_msg = battle_ui.get_node("MessageBox")
			if battle_msg and battle_msg.visible:
				battle_message_box_visible = true
		if battle_ui and battle_ui.has_method("has_modal_ui_visible"):
			battle_modal_ui_visible = bool(battle_ui.call("has_modal_ui_visible"))

	# Si no hay menús visibles, no procesar ui_accept/ui_cancel aquí
	# Dejarlos pasar para que el Player pueda usarlos (interact)
	if not msg.visible and not choice_box.visible and not (pause_menu != null && pause_menu.visible) and not (_bag_ui != null and _bag_ui.visible) and not (_party_ui != null and _party_ui.visible) and not (_pokedex_ui != null and _pokedex_ui.visible) and not (_current_portrait_box != null && _current_portrait_box.visible) and not ((_pc_storage_ui != null and _pc_storage_ui.visible) or (_pc_items_ui != null and _pc_items_ui.visible)) and not (_poke_mart_ui != null and _poke_mart_ui.visible) and not battle_message_box_visible and not battle_modal_ui_visible:
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
	if input_consumed and (msg.visible or choice_box.visible or (pause_menu != null && pause_menu.visible) or (_bag_ui != null and _bag_ui.visible) or (_party_ui != null and _party_ui.visible) or (_pokedex_ui != null and _pokedex_ui.visible) or (_save_ui != null and _save_ui.visible) or (_pc_storage_ui != null and _pc_storage_ui.visible) or (_pc_items_ui != null and _pc_items_ui.visible) or (_poke_mart_ui != null and _poke_mart_ui.visible) or battle_message_box_visible or battle_modal_ui_visible):
		get_viewport().set_input_as_handled()

# === CALLBACKS DEL PAUSE MENU ===
func _on_pause_pokedex_requested() -> void:
	await _open_pokedex_ui()

func _on_pause_party_requested() -> void:
	await _open_party_ui()

func _open_pokedex_ui(with_screen_fade: bool = true) -> void:
	if _bag_ui != null and _bag_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _pokedex_ui != null and _pokedex_ui.visible:
		return
	if _pokedex_ui == null:
		push_error("DisplayManager: Nodo PokedexUI no disponible en la escena.")
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	_pokedex_controller = POKEDEX_CONTROLLER_SCRIPT.new()
	_pokedex_ui.setup(_pokedex_controller)
	_pokedex_ui.open()
	_on_ui_visibility_changed()

	if with_screen_fade:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

func _close_pokedex_ui() -> void:
	if _pokedex_ui == null:
		return
	_pokedex_ui.close()

func _on_pokedex_back_requested() -> void:
	await _transition_fade_pokedex_to_pause_menu()

func _transition_fade_pokedex_to_pause_menu() -> void:
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_pokedex_ui()
	await _await_ui_control_hidden(_pokedex_ui)
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

func _on_pokedex_closed() -> void:
	_pokedex_controller = null
	if pause_menu and not pause_menu.visible:
		pause_menu.open(0, false) # Mantener cursor en "POKéDEX"
	_on_ui_visibility_changed()

func _on_pause_bag_requested() -> void:
	await _open_bag_ui()


func _await_ui_control_hidden(ctrl: Control) -> void:
	if ctrl == null:
		return
	while ctrl.visible:
		await get_tree().process_frame


func _open_pc_storage_ui(
	mode: int = 0,
	box_index: int = 0,
	prepare_before_reveal: Callable = Callable(),
	cleanup_under_cover: Callable = Callable()
) -> void:
	if _pc_storage_ui == null:
		push_error("DisplayManager: Nodo PCStorageUI no disponible en la escena.")
		return
	if _pc_storage_ui.visible:
		return
	if _pc_items_ui != null and _pc_items_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return

	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	# Abrir: fade sólido a negro → revelar PC con máscara (inversa del cierre).
	const PC_MASK_CLOSE := "res://Sprites/Transiciones/PC/computertrclose.png"
	const PC_MASK_DUR := 0.8
	const PC_SOLID_FADE_DUR := 0.4
	await fade_layer.fade_in(PC_SOLID_FADE_DUR)
	if cleanup_under_cover.is_valid():
		await cleanup_under_cover.call()
	_pc_storage_ui.setup(null)
	_pc_storage_ui.open(mode as PCStorageUI.Mode, box_index)
	_on_ui_visibility_changed()
	AudioManager.play_ui_pc_access()
	if not await fade_layer.play_mask_transition(PC_MASK_CLOSE, false, PC_MASK_DUR):
		await fade_layer.fade_out(PC_SOLID_FADE_DUR)
	fade_layer.z_index = fade_z
	await _pc_storage_ui.closed
	# Cerrar: máscara PC a negro → fade sólido de vuelta al overworld.
	fade_layer.z_index = _UI_FADE_COVER_Z
	AudioManager.play_ui_pc_close()
	if not await fade_layer.play_mask_transition(PC_MASK_CLOSE, true, PC_MASK_DUR):
		await fade_layer.fade_in(PC_SOLID_FADE_DUR)
	_close_message()
	_close_choices()
	if _pc_storage_ui.visible:
		_pc_storage_ui.hide()
	_on_ui_visibility_changed()
	if prepare_before_reveal.is_valid():
		await prepare_before_reveal.call()
	await fade_layer.fade_out(PC_SOLID_FADE_DUR)
	fade_layer.z_index = fade_z
	_on_ui_visibility_changed()


func _on_pc_storage_ui_closed() -> void:
	_on_ui_visibility_changed()


func _open_pc_items_ui(
	mode: int = 0,
	prepare_before_reveal: Callable = Callable(),
	cleanup_under_cover: Callable = Callable()
) -> void:
	if _pc_items_ui == null:
		push_error("DisplayManager: Nodo PCItemsUI no disponible en la escena.")
		return
	if _pc_items_ui.visible:
		return
	if _pc_storage_ui != null and _pc_storage_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return

	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	const PC_MASK_CLOSE := "res://Sprites/Transiciones/PC/computertrclose.png"
	const PC_MASK_DUR := 0.8
	const PC_SOLID_FADE_DUR := 0.4
	await fade_layer.fade_in(PC_SOLID_FADE_DUR)
	if cleanup_under_cover.is_valid():
		await cleanup_under_cover.call()
	_pc_items_ui.open(mode)
	_on_ui_visibility_changed()
	AudioManager.play_ui_pc_access()
	if not await fade_layer.play_mask_transition(PC_MASK_CLOSE, false, PC_MASK_DUR):
		await fade_layer.fade_out(PC_SOLID_FADE_DUR)
	fade_layer.z_index = fade_z
	await _pc_items_ui.closed
	fade_layer.z_index = _UI_FADE_COVER_Z
	AudioManager.play_ui_pc_close()
	if not await fade_layer.play_mask_transition(PC_MASK_CLOSE, true, PC_MASK_DUR):
		await fade_layer.fade_in(PC_SOLID_FADE_DUR)
	_close_message()
	_close_choices()
	if _pc_items_ui.visible:
		_pc_items_ui.hide()
	if _pc_items_ui.has_method("_unblock_player_control"):
		_pc_items_ui._unblock_player_control()
	_on_ui_visibility_changed()
	if prepare_before_reveal.is_valid():
		await prepare_before_reveal.call()
	await fade_layer.fade_out(PC_SOLID_FADE_DUR)
	fade_layer.z_index = fade_z
	_on_ui_visibility_changed()


func _on_pc_items_ui_closed() -> void:
	_on_ui_visibility_changed()


func _open_poke_mart_ui(shop: ShopData, with_screen_fade: bool = true) -> void:
	if _poke_mart_ui == null:
		push_error("DisplayManager: Nodo PokeMartUI no disponible en la escena.")
		return
	if shop == null:
		push_error("DisplayManager: open_poke_mart requiere un ShopData.")
		return
	if _poke_mart_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _pc_storage_ui != null and _pc_storage_ui.visible:
		return
	if _pc_items_ui != null and _pc_items_ui.visible:
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	_poke_mart_ui.move_to_front()
	_poke_mart_ui.open(shop)
	_on_ui_visibility_changed()

	if with_screen_fade:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

	await _poke_mart_ui.closed
	_on_ui_visibility_changed()


func _on_poke_mart_ui_closed() -> void:
	_on_ui_visibility_changed()


## Mochila en modo venta (UI normal + panel dinero). Espera hasta cerrar.
func _open_bag_for_sell(with_screen_fade: bool = true) -> void:
	if _bag_ui == null:
		push_error("DisplayManager: Nodo BagUI no disponible en la escena.")
		return
	if _bag_ui.visible or _bag_sell_active:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _poke_mart_ui != null and _poke_mart_ui.visible:
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	_bag_sell_active = true
	var context := _resolve_overworld_context()
	_bag_controller = BAG_CONTROLLER_SCRIPT.new(context)
	_bag_controller.reset_list_context_to_overworld()
	_bag_ui.setup(_bag_controller)
	if _bag_ui.has_method("set_sell_mode"):
		_bag_ui.set_sell_mode(true)
	_bag_ui.move_to_front()
	_bag_ui.open()
	_on_ui_visibility_changed()

	if with_screen_fade:
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

	await _bag_ui.closed
	_bag_sell_active = false
	_bag_controller = null
	_on_ui_visibility_changed()


## QuantityPicker compartido. Devuelve 1..max o 0 si cancela.
## Sin precio: si max<=1 no pregunta. Con `unit_price` > 0 (mart) siempre muestra el picker.
## Mart: MSG a ancho completo abajo; picker a la altura de Llevas (cantidad izq, precio der).
func _prompt_quantity(
	max_qty: int,
	prompt: String,
	unit_price: int = 0,
	frame_style: MessageBoxFrameStyle.Values = MessageBoxFrameStyle.Values.FIRERED
) -> int:
	if max_qty <= 0:
		return 0
	if unit_price <= 0 and max_qty <= 1:
		return 1
	if _qty_pick_active:
		return 0
	if _quantity_picker == null:
		push_error("DisplayManager._prompt_quantity: QuantityPicker no disponible")
		return 0

	_qty_unit_price = maxi(unit_price, 0)
	var is_mart := _qty_unit_price > 0
	_apply_quantity_picker_price_layout(is_mart)

	if is_mart:
		# Mart/venta: mensaje full-width; tipado; picker fuera del MSG.
		await _show_message_with_config(prompt, {
			"waitInput": false,
			"closeAtEnd": false,
			"showIconAtEnd": false,
			"fullWidth": true,
			"frameStyle": frame_style,
			"typingMode": MessageBox.TypingMode.TYPING,
		})
	else:
		var qty_reserve := absf(_quantity_picker.offset_left)
		if qty_reserve < 8.0:
			qty_reserve = maxf(_quantity_picker.size.x, _quantity_picker.custom_minimum_size.x)
			if qty_reserve < 8.0:
				qty_reserve = _PC_ITEMS_QTY_RESERVE_PX
		_qty_prompt_layout_active = true
		set_pc_items_message_side_reserve(qty_reserve)
		await _show_message_with_config(prompt, {
			"waitInput": false,
			"closeAtEnd": false,
			"showIconAtEnd": false,
			"frameStyle": frame_style,
			"typingMode": MessageBox.TypingMode.INSTANT,
		})
	hide_message_wait_indicator()

	_qty_pick_max = max_qty
	_qty_pick_value = 1
	_qty_pick_active = true
	_qty_arrow_anim_time = 0.0
	_refresh_quantity_picker_label()
	_quantity_picker.show()
	_quantity_picker.move_to_front()
	if msg != null:
		msg.move_to_front()
		_quantity_picker.move_to_front()
	_connect_qty_picker_input()
	set_process(true)
	AudioManager.play_ui_cursor()

	var picked: int = await _quantity_picked
	_qty_pick_active = false
	_qty_unit_price = 0
	_disconnect_qty_picker_input()
	_quantity_picker.hide()
	_apply_quantity_picker_price_layout(false)
	_close_message()
	clear_pc_items_message_side_reserve()
	_qty_prompt_layout_active = false
	if _pc_msg_layout_saved and not _is_any_pc_screen_open():
		_pop_pc_msg_layout()
	set_process(false)
	return picked


func _apply_quantity_picker_price_layout(with_price: bool) -> void:
	if _quantity_picker == null:
		return
	var container: Control = _quantity_picker.get_node_or_null("Container") as Control
	if with_price:
		# Mart: cantidad izquierda, precio derecha; panel a altura Llevas.
		_quantity_picker.custom_minimum_size.x = _QTY_PRICE_MIN_WIDTH
		_quantity_picker.offset_left = _QTY_MART_OFFSET_LEFT
		_quantity_picker.offset_right = _QTY_MART_OFFSET_RIGHT
		_quantity_picker.offset_bottom = _QTY_MART_OFFSET_BOTTOM
		_quantity_picker.offset_top = _QTY_MART_OFFSET_BOTTOM - _QTY_MART_HEIGHT
		if container:
			container.offset_left = 12.0
			container.offset_right = _QTY_PRICE_MIN_WIDTH - 12.0
		if _qty_amount_label:
			_qty_amount_label.offset_left = 4.0
			_qty_amount_label.offset_right = 90.0
			_qty_amount_label.set("align", 0)
		if _qty_price_label:
			_qty_price_label.visible = true
			_qty_price_label.offset_left = 96.0
			_qty_price_label.offset_right = 200.0
			_qty_price_label.set("align", 2)
		if _qty_up_arrow:
			_qty_up_arrow.position.x = _QTY_PRICE_ARROW_X
		if _qty_down_arrow:
			_qty_down_arrow.position.x = _QTY_PRICE_ARROW_X
	else:
		_quantity_picker.custom_minimum_size.x = _QTY_DEFAULT_MIN_WIDTH
		_quantity_picker.offset_left = _QTY_DEFAULT_OFFSET_LEFT
		_quantity_picker.offset_right = _QTY_DEFAULT_OFFSET_RIGHT
		_quantity_picker.offset_top = _QTY_DEFAULT_OFFSET_TOP
		_quantity_picker.offset_bottom = _QTY_DEFAULT_OFFSET_BOTTOM
		if container:
			container.offset_left = 12.0
			container.offset_right = 132.0
		if _qty_amount_label:
			_qty_amount_label.offset_left = 35.0
			_qty_amount_label.offset_right = 134.0
		if _qty_price_label:
			_qty_price_label.visible = false
		if _qty_up_arrow:
			_qty_up_arrow.position.x = _QTY_DEFAULT_ARROW_X
		if _qty_down_arrow:
			_qty_down_arrow.position.x = _QTY_DEFAULT_ARROW_X


func _refresh_quantity_picker_label() -> void:
	if _qty_amount_label == null:
		return
	# Mart (con precio): x08 / x10. PC: x001.
	var text: String
	if _qty_unit_price > 0:
		text = "x%02d" % _qty_pick_value
	else:
		text = "x%03d" % _qty_pick_value
	if _qty_amount_label.has_method("setText"):
		_qty_amount_label.setText(text)
	else:
		_qty_amount_label.text = text
	_qty_amount_label.visible_characters = -1
	_qty_amount_label.visible_ratio = 1.0
	for child in _qty_amount_label.get_children():
		if child is RichTextLabel:
			(child as RichTextLabel).visible_characters = -1
			(child as RichTextLabel).visible_ratio = 1.0
	if _qty_amount_label.has_method("_sync_outline_visual_immediate"):
		_qty_amount_label._sync_outline_visual_immediate()

	if _qty_price_label != null and _qty_unit_price > 0:
		var total := _qty_unit_price * _qty_pick_value
		var price_text := "$%s" % _format_qty_thousands(total)
		if _qty_price_label.has_method("setText"):
			_qty_price_label.setText(price_text)
		else:
			_qty_price_label.text = price_text
		_qty_price_label.visible_characters = -1
		_qty_price_label.visible_ratio = 1.0
		for child in _qty_price_label.get_children():
			if child is RichTextLabel:
				(child as RichTextLabel).visible_characters = -1
				(child as RichTextLabel).visible_ratio = 1.0
		if _qty_price_label.has_method("_sync_outline_visual_immediate"):
			_qty_price_label._sync_outline_visual_immediate()


func _format_qty_thousands(amount: int) -> String:
	var n := absi(amount)
	var s := str(n)
	var out := ""
	var i := 0
	for c_i in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = "," + out
		out = s[c_i] + out
		i += 1
	if amount < 0:
		out = "-" + out
	return out


func _qty_change(delta: int) -> void:
	if not _qty_pick_active:
		return
	var next := _qty_pick_value + delta
	if next < 1:
		next = _qty_pick_max
	elif next > _qty_pick_max:
		next = 1
	if next == _qty_pick_value:
		return
	_qty_pick_value = next
	_refresh_quantity_picker_label()
	AudioManager.play_ui_cursor()


func _qty_confirm() -> void:
	if not _qty_pick_active:
		return
	AudioManager.play_ui_select()
	_quantity_picked.emit(_qty_pick_value)


func _qty_cancel() -> void:
	if not _qty_pick_active:
		return
	AudioManager.play_ui_cancel()
	_quantity_picked.emit(0)


func _connect_qty_picker_input() -> void:
	if not input_up.is_connected(_on_qty_input_up):
		input_up.connect(_on_qty_input_up)
	if not input_down.is_connected(_on_qty_input_down):
		input_down.connect(_on_qty_input_down)
	if not input_accept.is_connected(_on_qty_input_accept):
		input_accept.connect(_on_qty_input_accept)
	if not input_cancel.is_connected(_on_qty_input_cancel):
		input_cancel.connect(_on_qty_input_cancel)


func _disconnect_qty_picker_input() -> void:
	if input_up.is_connected(_on_qty_input_up):
		input_up.disconnect(_on_qty_input_up)
	if input_down.is_connected(_on_qty_input_down):
		input_down.disconnect(_on_qty_input_down)
	if input_accept.is_connected(_on_qty_input_accept):
		input_accept.disconnect(_on_qty_input_accept)
	if input_cancel.is_connected(_on_qty_input_cancel):
		input_cancel.disconnect(_on_qty_input_cancel)


func _on_qty_input_up() -> void:
	_qty_change(1)


func _on_qty_input_down() -> void:
	_qty_change(-1)


func _on_qty_input_accept() -> void:
	_qty_confirm()


func _on_qty_input_cancel() -> void:
	_qty_cancel()


func _process(delta: float) -> void:
	if not _qty_pick_active:
		return
	_qty_arrow_anim_time += delta
	var period := 1.0 / maxf(_QTY_ARROW_ANIM_FPS, 0.001)
	var frame := int(floor(_qty_arrow_anim_time / period)) % 8
	if _qty_up_arrow:
		_qty_up_arrow.frame = frame
	if _qty_down_arrow:
		_qty_down_arrow.frame = frame


func _open_bag_for_pc_deposit(
	prepare_before_reveal: Callable = Callable(),
	cleanup_under_cover: Callable = Callable()
) -> void:
	if _bag_ui == null:
		push_error("DisplayManager: Nodo BagUI no disponible en la escena.")
		return
	if _bag_ui.visible or _bag_pc_deposit_active:
		return
	if _pc_items_ui != null and _pc_items_ui.visible:
		return
	if _pc_storage_ui != null and _pc_storage_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return

	_bag_pc_deposit_active = true

	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	const PC_MASK_CLOSE := "res://Sprites/Transiciones/PC/computertrclose.png"
	const PC_MASK_DUR := 0.8
	const PC_SOLID_FADE_DUR := 0.4
	await fade_layer.fade_in(PC_SOLID_FADE_DUR)
	if cleanup_under_cover.is_valid():
		await cleanup_under_cover.call()

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	var context := _resolve_overworld_context()
	_bag_controller = BAG_CONTROLLER_SCRIPT.new(context)
	_bag_controller.reset_list_context_to_overworld()
	_bag_ui.setup(_bag_controller)
	if _bag_ui.has_method("set_pc_deposit_mode"):
		_bag_ui.set_pc_deposit_mode(true)
	_bag_ui.z_index = _BAG_OVER_PC_Z
	_bag_ui.move_to_front()
	_bag_ui.open()
	_on_ui_visibility_changed()
	AudioManager.play_ui_pc_access()
	if not await fade_layer.play_mask_transition(PC_MASK_CLOSE, false, PC_MASK_DUR):
		await fade_layer.fade_out(PC_SOLID_FADE_DUR)
	fade_layer.z_index = fade_z

	await _bag_ui.closed

	fade_layer.z_index = _UI_FADE_COVER_Z
	AudioManager.play_ui_pc_close()
	if not await fade_layer.play_mask_transition(PC_MASK_CLOSE, true, PC_MASK_DUR):
		await fade_layer.fade_in(PC_SOLID_FADE_DUR)
	_close_message()
	_close_choices()
	if _qty_pick_active:
		_qty_pick_active = false
		_quantity_picked.emit(0)
	if _quantity_picker:
		_quantity_picker.hide()
	_qty_prompt_layout_active = false
	clear_pc_items_message_side_reserve()
	if _bag_ui.visible:
		_bag_ui.hide()
	if _bag_ui.has_method("set_pc_deposit_mode"):
		_bag_ui.set_pc_deposit_mode(false)
	_bag_ui.z_index = 0
	_bag_controller = null
	_bag_pc_deposit_active = false
	_on_ui_visibility_changed()
	if prepare_before_reveal.is_valid():
		await prepare_before_reveal.call()
	await fade_layer.fade_out(PC_SOLID_FADE_DUR)
	fade_layer.z_index = fade_z
	_on_ui_visibility_changed()


func _open_party_ui(with_screen_fade: bool = true) -> void:
	if _bag_ui != null and _bag_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _pc_storage_ui != null and _pc_storage_ui.visible:
		return
	if _pc_items_ui != null and _pc_items_ui.visible:
		return
	if _party_ui == null:
		push_error("DisplayManager: Nodo PartyUI no disponible en la escena.")
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

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
	_close_message()
	_party_help_text = ""
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
		pause_menu.open(1, false)
	_on_ui_visibility_changed()


## Party → mochila (cancelar objetivo o fin de sesión ítem): negro con party aún montado, cerrar, abrir bolsa, descubrir.
func _fade_close_party_reopen_bag_overworld() -> void:
	_skip_pause_open_on_party_close = true
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_party_ui()
	await _await_ui_control_hidden(_party_ui)
	_skip_pause_open_on_party_close = false
	_reopen_bag_after_party_flow()
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _reopen_bag_after_party_flow() -> void:
	if _bag_ui == null:
		return
	_close_message()
	if choice_box != null and choice_box.visible:
		choice_box.hide()
	if pause_menu and pause_menu.visible:
		pause_menu.close(false)
	var nav_state: Dictionary = _pending_bag_ui_navigation_state.duplicate(true)
	_pending_bag_ui_navigation_state.clear()
	var context := _resolve_overworld_context()
	_bag_controller = BAG_CONTROLLER_SCRIPT.new(context)
	_bag_controller.reset_list_context_to_overworld()
	_bag_ui.setup(_bag_controller)
	_suppress_bag_closed_effects = true
	if _bag_ui.visible:
		_bag_ui.close()
	_suppress_bag_closed_effects = false
	_bag_ui.open()
	if not nav_state.is_empty():
		if _bag_ui.has_method("restore_navigation_state"):
			_bag_ui.restore_navigation_state(nav_state)
		if _bag_ui.has_method("refresh_from_controller"):
			_bag_ui.refresh_from_controller()
	_on_ui_visibility_changed()


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
		pause_menu.close(false)
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
		pause_menu.close(false)
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
		if _bag_ui.has_method("set_input_enabled"):
			_bag_ui.set_input_enabled(true)
		_on_ui_visibility_changed()
		return

	if _bag_ui == null:
		push_error("DisplayManager: Nodo BagUI no disponible en la escena.")
		return

	if with_screen_fade:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

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
	if _bag_hold_pick_active:
		if _bag_ui != null and _bag_ui.has_method("set_input_enabled"):
			_bag_ui.set_input_enabled(false)
		await _finish_bag_hold_pick(-1)
		return
	if _bag_pc_deposit_active:
		if _bag_ui != null and _bag_ui.has_method("set_input_enabled"):
			_bag_ui.set_input_enabled(false)
		# Mantener visible para la máscara CRT (igual que PCItemsUI).
		_bag_ui.close(true)
		return
	if _bag_sell_active:
		await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
		_close_bag_ui()
		await _await_ui_control_hidden(_bag_ui)
		await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
		return
	await _transition_fade_bag_to_pause_menu()


func _transition_fade_bag_to_pause_menu() -> void:
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_bag_ui()
	await _await_ui_control_hidden(_bag_ui)
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)

func _on_bag_closed() -> void:
	if _suppress_bag_closed_effects or _bag_hold_pick_active or _bag_pc_deposit_active or _bag_sell_active:
		_on_ui_visibility_changed()
		return
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
		pause_menu.open(2, false) # Mantener cursor en "MOCHILA"
	_on_ui_visibility_changed()

func _on_bag_use_requested(item_id: int) -> void:
	if _bag_hold_pick_active:
		if _bag_ui != null and _bag_ui.has_method("set_input_enabled"):
			_bag_ui.set_input_enabled(false)
		if not _can_give_as_held_item(item_id):
			if msg != null:
				msg.move_to_front()
			await _show_message_with_config("No se puede dar ese objeto.", {
				"waitInput": true,
				"closeAtEnd": true,
				"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"expandHeight": true,
			})
			if _bag_ui != null and _bag_ui.visible:
				_bag_ui.move_to_front()
				if _bag_ui.has_method("set_input_enabled"):
					_bag_ui.set_input_enabled(true)
			return
		await _finish_bag_hold_pick(item_id)
		return
	if _bag_pc_deposit_active:
		await _run_pc_deposit_item_flow(item_id)
		return
	if _bag_sell_active:
		await _run_bag_sell_item_flow(item_id)
		return
	await _run_bag_item_use_flow(item_id)


## True si el ítem puede depositarse en el PC (HGSS: todo excepto objetos clave).
func _can_deposit_item_to_pc(item_id: int) -> bool:
	if item_id <= 0 or DatabaseService == null:
		return false
	var item: ItemData = DatabaseService.get_item_by_id(item_id)
	if item == null:
		return false
	if int(item.pocket) == ItemEnums.Pocket.KEY_ITEMS:
		return false
	if int(item.kind) == ItemEnums.Kind.KEY:
		return false
	return true


func _run_pc_deposit_item_flow(item_id: int) -> void:
	if _bag_ui != null and _bag_ui.has_method("set_input_enabled"):
		_bag_ui.set_input_enabled(false)
	if msg != null:
		msg.move_to_front()

	if not _can_deposit_item_to_pc(item_id):
		await _show_message_with_config("No se puede dejar ese objeto.", {
			"waitInput": true,
			"closeAtEnd": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
			"fullWidth": true,
		})
		if _bag_ui != null and _bag_ui.visible and _bag_pc_deposit_active:
			_bag_ui.move_to_front()
			if _bag_ui.has_method("set_input_enabled"):
				_bag_ui.set_input_enabled(true)
		return

	if GameStateService == null:
		if _bag_ui != null and _bag_ui.visible and _bag_pc_deposit_active:
			if _bag_ui.has_method("set_input_enabled"):
				_bag_ui.set_input_enabled(true)
		return

	var bag: Bag = GameStateService.get_bag()
	var storage = GameStateService.get_pc_item_storage()
	if bag == null or storage == null:
		if _bag_ui != null and _bag_ui.visible and _bag_pc_deposit_active:
			if _bag_ui.has_method("set_input_enabled"):
				_bag_ui.set_input_enabled(true)
		return

	var available := bag.get_quantity(item_id)
	if available <= 0:
		if _bag_ui != null and _bag_ui.visible and _bag_pc_deposit_active:
			if _bag_ui.has_method("set_input_enabled"):
				_bag_ui.set_input_enabled(true)
		return

	var qty: int = 0
	if available <= 1:
		await _show_message_with_config("Has dejado 1 unidad.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playConfirmSound": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"fullWidth": true,
		})
		qty = 1
	else:
		qty = await _prompt_quantity(available, "¿Qué cantidad?")
		if qty <= 0:
			if _bag_ui != null and _bag_ui.visible and _bag_pc_deposit_active:
				_bag_ui.move_to_front()
				if _bag_ui.has_method("set_input_enabled"):
					_bag_ui.set_input_enabled(true)
			return
		await _show_message_with_config("Has dejado %d." % qty, {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playOpenSound": false,
			"playConfirmSound": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"fullWidth": true,
		})

	if not _bag_pc_deposit_active:
		return

	var moved: int = int(storage.deposit_from_bag(bag, item_id, qty))
	if moved <= 0:
		await _show_message_with_config("No se pudo guardar el objeto.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playConfirmSound": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"fullWidth": true,
		})
	elif _bag_ui != null and _bag_ui.has_method("refresh_from_controller"):
		_bag_ui.refresh_from_controller()

	if _bag_ui != null and _bag_ui.visible and _bag_pc_deposit_active:
		_bag_ui.move_to_front()
		if _bag_ui.has_method("set_input_enabled"):
			_bag_ui.set_input_enabled(true)


## Venta desde mochila (tienda). Mensajes FRLG; qty si hay más de 1 unidad.
func _run_bag_sell_item_flow(item_id: int) -> void:
	if _bag_ui != null and _bag_ui.has_method("set_input_enabled"):
		_bag_ui.set_input_enabled(false)
	if _bag_ui != null and _bag_ui.has_method("set_browse_details_visible"):
		_bag_ui.set_browse_details_visible(false)
	if _bag_ui != null and _bag_ui.has_method("set_money_panel_visible"):
		_bag_ui.set_money_panel_visible(true)
	if msg != null:
		msg.move_to_front()

	var item_data: ItemData = null
	if DatabaseService != null:
		item_data = DatabaseService.get_item_by_id(item_id)
	var item_name := "OBJETO"
	if item_data != null:
		item_name = item_data.get_display_name()

	if item_data == null or not item_data.is_sellable():
		await _show_message_with_config("¿%s? No, lo siento.\nNo puedo comprar eso." % item_name, {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playConfirmSound": true,
			"fullWidth": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.TYPING,
		})
		_restore_bag_after_sell_step()
		return

	if GameStateService == null:
		_restore_bag_after_sell_step()
		return
	var bag: Bag = GameStateService.get_bag()
	if bag == null:
		_restore_bag_after_sell_step()
		return

	var owned := int(bag.get_quantity(item_id))
	if owned <= 0:
		_restore_bag_after_sell_step()
		return

	var unit_price := int(item_data.sell_price)
	var qty := 1
	if owned > 1:
		qty = await _prompt_quantity(
			owned,
			"¿%s?\n¿Cuántas unidades quieres vender?" % item_name,
			unit_price,
			MessageBoxFrameStyle.Values.FIRERED
		)
		if qty <= 0 or not _bag_sell_active:
			_restore_bag_after_sell_step()
			return

	var total := unit_price * qty
	var total_text := _format_bag_sell_money(total)
	var confirm := "Puedo pagarte %s.\n¿Te parece bien?" % total_text
	var accepted := await _confirm_bag_sell_yes_no(confirm)
	if not accepted or not _bag_sell_active:
		_restore_bag_after_sell_step()
		return

	if not ShopData.sell_item(item_id, qty):
		await _show_message_with_config("No se pudo completar la venta.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playConfirmSound": true,
			"fullWidth": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.TYPING,
		})
		_restore_bag_after_sell_step()
		return

	if _bag_ui != null and _bag_ui.has_method("refresh_money"):
		_bag_ui.refresh_money()
	await _show_message_with_config("Recibiste %s por la venta." % total_text, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playConfirmSound": true,
		"fullWidth": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.TYPING,
	})
	if _bag_ui != null and _bag_ui.has_method("refresh_from_controller"):
		_bag_ui.refresh_from_controller()
	_restore_bag_after_sell_step()


func _confirm_bag_sell_yes_no(prompt: String) -> bool:
	var options: Array[String] = ["SÍ", "NO"]
	await _show_message_with_config(prompt, {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"fullWidth": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.TYPING,
	})
	hide_message_wait_indicator()
	var choice: int = await show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	_close_message()
	return choice == 0


func _format_bag_sell_money(amount: int) -> String:
	var n := absi(amount)
	var s := str(n)
	var out := ""
	var i := 0
	for c_i in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = "," + out
		out = s[c_i] + out
		i += 1
	if amount < 0:
		out = "-" + out
	return "$%s" % out


func _restore_bag_after_sell_step() -> void:
	if _bag_ui == null or not _bag_ui.visible or not _bag_sell_active:
		return
	if _bag_ui.has_method("set_money_panel_visible"):
		_bag_ui.set_money_panel_visible(false)
	if _bag_ui.has_method("set_browse_details_visible"):
		_bag_ui.set_browse_details_visible(true)
	_bag_ui.move_to_front()
	if _bag_ui.has_method("set_input_enabled"):
		_bag_ui.set_input_enabled(true)


## True si el ítem puede equiparse como held (no claves / MT-MO).
func _can_give_as_held_item(item_id: int) -> bool:
	if item_id <= 0 or DatabaseService == null:
		return false
	var item: ItemData = DatabaseService.get_item_by_id(item_id)
	if item == null:
		return false
	if int(item.pocket) == ItemEnums.Pocket.KEY_ITEMS:
		return false
	if int(item.pocket) == ItemEnums.Pocket.TM_HM:
		return false
	if int(item.kind) == ItemEnums.Kind.KEY:
		return false
	if int(item.kind) == ItemEnums.Kind.TM_HM:
		return false
	return true


## Abre mochila sobre el PC y espera selección (o cancelar). Devuelve item_id o -1.
func _pick_held_item_from_bag() -> int:
	if _bag_ui == null:
		push_error("DisplayManager._pick_held_item_from_bag: BagUI no disponible")
		return -1
	if _bag_ui.visible or _bag_hold_pick_active:
		return -1

	_bag_hold_pick_active = true
	_bag_hold_pick_result = -1

	# El MSG del party (z alto) taparía la mochila; cerrarlo bajo el fundido.
	if _is_party_ui_open():
		_close_message()

	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	var context := _resolve_overworld_context()
	_bag_controller = BAG_CONTROLLER_SCRIPT.new(context)
	_bag_controller.reset_list_context_to_overworld()
	_bag_ui.setup(_bag_controller)
	_bag_ui.set_hold_pick_mode(true)
	_bag_ui.z_index = _BAG_OVER_PC_Z
	_bag_ui.move_to_front()
	_bag_ui.open()
	_on_ui_visibility_changed()

	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
	fade_layer.z_index = fade_z

	while _bag_hold_pick_active:
		await get_tree().process_frame

	return _bag_hold_pick_result


func _finish_bag_hold_pick(item_id: int) -> void:
	_bag_hold_pick_result = item_id
	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_suppress_bag_closed_effects = true
	_close_bag_ui()
	await _await_ui_control_hidden(_bag_ui)
	_suppress_bag_closed_effects = false
	_bag_controller = null
	_bag_hold_pick_active = false
	if _bag_ui != null:
		_bag_ui.z_index = 0
	if _pc_items_ui != null and _pc_items_ui.visible:
		_pc_items_ui.move_to_front()
	elif _pc_storage_ui != null and _pc_storage_ui.visible:
		_pc_storage_ui.move_to_front()
	elif _party_ui != null and _party_ui.visible:
		_party_ui.move_to_front()
	_on_ui_visibility_changed()
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
	fade_layer.z_index = fade_z


## PC ítems → DAR: party sobre el depósito; mensaje «¿Dar a qué POKéMON?». Devuelve slot o -1.
func _pick_party_slot_for_give_held() -> int:
	if _party_ui == null:
		push_error("DisplayManager._pick_party_slot_for_give_held: PartyUI no disponible")
		return -1
	if _party_ui.visible or _party_give_pick_active:
		return -1

	_party_give_pick_active = true
	_party_give_pick_result = -1
	const GIVE_PROMPT := "¿Dar a qué POKéMON?"

	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	var context := _resolve_overworld_context()
	_party_controller = PARTY_CONTROLLER_SCRIPT.new(context)
	_party_ui.setup(_party_controller)
	_party_ui.z_index = _BAG_OVER_PC_Z
	_party_ui.move_to_front()
	_party_ui.open_for_bag_item_target_pick(-1, GIVE_PROMPT)
	if msg != null:
		msg.move_to_front()
	_on_ui_visibility_changed()

	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
	fade_layer.z_index = fade_z

	while _party_give_pick_active:
		await get_tree().process_frame

	return _party_give_pick_result


func _finish_party_give_pick(slot_index: int) -> void:
	_party_give_pick_result = slot_index
	if slot_index < 0:
		# Cancelar: fundido de vuelta al PC ítems.
		await _close_party_give_held()
	else:
		# Éxito: party sigue abierto para el mensaje «¡X lleva ahora Y!».
		if _party_ui != null and _party_ui.has_method("set_input_enabled"):
			_party_ui.set_input_enabled(false)
	_party_give_pick_active = false


func _close_party_give_held() -> void:
	var fade_z := fade_layer.z_index
	fade_layer.z_index = _UI_FADE_COVER_Z
	await fade_layer.fade_in(_UI_SCREEN_FADE_DURATION)
	_close_message()
	_skip_pause_open_on_party_close = true
	if _party_ui != null and _party_ui.visible:
		_close_party_ui()
		await _await_ui_control_hidden(_party_ui)
	_skip_pause_open_on_party_close = false
	_party_controller = null
	if _party_ui != null:
		_party_ui.z_index = 0
	if _pc_items_ui != null and _pc_items_ui.visible:
		_pc_items_ui.move_to_front()
	_on_ui_visibility_changed()
	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
	fade_layer.z_index = fade_z


## Party → DAR: pick en mochila y aplicar held (mensajes HGSS; el party sigue abierto).
func _party_give_held_from_bag(slot_index: int) -> void:
	if _party_ui == null or not _party_ui.visible:
		return
	if slot_index < 0 or GameStateService == null:
		return
	if _party_ui.has_method("set_input_enabled"):
		_party_ui.set_input_enabled(false)

	var item_id: int = await _pick_held_item_from_bag()
	if item_id <= 0:
		if _party_ui != null and _party_ui.visible and _party_ui.has_method("set_input_enabled"):
			_party_ui.set_input_enabled(true)
		return

	if not _party_ui.visible:
		return

	await _apply_give_held_from_bag_to_slot(slot_index, item_id)

	if _party_ui != null and _party_ui.visible:
		_party_ui.move_to_front()
		if _party_ui.has_method("set_input_enabled"):
			_party_ui.set_input_enabled(true)


func _apply_give_held_from_bag_to_slot(slot_index: int, item_id: int) -> void:
	if GameStateService == null or item_id <= 0:
		return
	var party: Party = GameStateService.get_party()
	var bag: Bag = GameStateService.get_bag()
	if party == null or bag == null:
		return
	var mon: Pokemon = party.get_pokemon(slot_index)
	if mon == null:
		return
	if bag.get_quantity(item_id) <= 0:
		return

	var mon_name := mon.get_display_name()
	var given_name := _item_display_name(item_id)
	var msg_cfg_wait := {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"playConfirmSound": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
	}

	if msg != null:
		msg.move_to_front()

	if mon.held_item_id > 0:
		var held_name := _item_display_name(mon.held_item_id)
		await _show_message_with_config(
			"¡%s ya lleva una unidad de %s!" % [mon_name, held_name],
			msg_cfg_wait
		)
		if _party_ui == null or not _party_ui.visible:
			return

		var swap_options: Array[String] = ["SI", "NO"]
		await _show_message_with_config("¿Quieres cambiar un objeto por otro?", {
			"waitInput": false,
			"closeAtEnd": false,
			"showIconAtEnd": false,
			"playOpenSound": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
		})
		hide_message_wait_indicator()
		if choice_box != null:
			choice_box.set_next_initial_index(1)  # NO
		var choice: int = await show_choices_corner(
			swap_options,
			ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
		)
		_close_message()
		if _party_ui == null or not _party_ui.visible or choice != 0:
			return

		var removed: int = bag.remove_item(item_id, 1)
		if removed < 1:
			await _show_message_with_config("No hay ese objeto.", msg_cfg_wait)
			return

		var old_id: int = mon.held_item_id
		var old_name := held_name
		bag.add_item(old_id, 1)
		mon.held_item_id = item_id
		refresh_party_slots_display()
		await _show_message_with_config(
			"¡Se ha sustituido %s por %s!" % [old_name, given_name],
			msg_cfg_wait
		)
		return

	var removed_empty: int = bag.remove_item(item_id, 1)
	if removed_empty < 1:
		await _show_message_with_config("No hay ese objeto.", msg_cfg_wait)
		return

	mon.held_item_id = item_id
	refresh_party_slots_display()
	await _show_message_with_config(
		"¡%s lleva ahora %s!" % [mon_name, given_name],
		msg_cfg_wait
	)


func _party_take_held_item(slot_index: int) -> void:
	if GameStateService == null or slot_index < 0:
		return
	var party: Party = GameStateService.get_party()
	var bag: Bag = GameStateService.get_bag()
	if party == null:
		return
	var mon: Pokemon = party.get_pokemon(slot_index)
	if mon == null:
		return

	var mon_name := mon.get_display_name()
	var msg_cfg := {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"playConfirmSound": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
	}

	if _party_ui != null and _party_ui.has_method("set_input_enabled"):
		_party_ui.set_input_enabled(false)
	if msg != null:
		msg.move_to_front()

	if mon.held_item_id <= 0:
		await _show_message_with_config("%s no lleva nada." % mon_name, msg_cfg)
	else:
		var item_id: int = mon.held_item_id
		var item_name := _item_display_name(item_id)
		if bag != null:
			bag.add_item(item_id, 1)
		mon.held_item_id = 0
		refresh_party_slots_display()
		await _show_message_with_config(
			"Recibiste %s de %s." % [item_name, mon_name],
			msg_cfg
		)

	if _party_ui != null and _party_ui.visible:
		_party_ui.move_to_front()
		if _party_ui.has_method("set_input_enabled"):
			_party_ui.set_input_enabled(true)


func _item_display_name(item_id: int) -> String:
	if item_id <= 0 or DatabaseService == null:
		return "???"
	var data: ItemData = DatabaseService.get_item_by_id(item_id)
	if data == null:
		return "???"
	return data.get_display_name()


## Tras cerrar la bolsa bajo negro: abre party (mochila → party) y descubre. Sin fade_in previo (ya estamos a negro).
func _open_party_for_pending_bag_item_after_bag_close() -> void:
	if _pending_bag_item_id <= 0:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	var context := _resolve_overworld_context()
	_party_controller = PARTY_CONTROLLER_SCRIPT.new(context)
	_party_ui.setup(_party_controller)
	_party_ui.open_for_bag_item_target_pick(-1)
	_on_ui_visibility_changed()

	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)


func _on_party_bag_item_target_cancelled() -> void:
	if _party_give_pick_active:
		if _party_ui != null and _party_ui.has_method("set_input_enabled"):
			_party_ui.set_input_enabled(false)
		await _finish_party_give_pick(-1)
		return
	if _party_ui == null or not _party_ui.visible:
		return
	if _pending_bag_item_id <= 0:
		return
	if _party_ui.has_method("set_input_enabled"):
		_party_ui.set_input_enabled(false)
	_pending_bag_item_id = -1
	await _fade_close_party_reopen_bag_overworld()


func _on_party_bag_item_pick_slot(slot_index: int) -> void:
	if _party_give_pick_active:
		if _party_ui != null and _party_ui.has_method("set_input_enabled"):
			_party_ui.set_input_enabled(false)
		await _finish_party_give_pick(slot_index)
		return
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
		await _party_ui.animate_item_hp_gain_for_slot(slot_index)
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
	# Con party abierto el MSG usa el rect FIXED_MSG; no forzar barra full-width.
	if not _bag_dialog_layout_saved and not _is_party_ui_open():
		_push_item_feedback_msg_layout()
		popped_item_layout = true
	## Mismo comportamiento que diálogos de campo: typing + confirmar con input antes de seguir.
	await _show_message_with_config(feedback, {
		"waitInput": true,
		"closeAtEnd": true,
		"waitTime": 0.0,
		"showIconAtEnd": true,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
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
			pause_menu.close(false)
		var context_pb := _resolve_overworld_context()
		_party_controller = PARTY_CONTROLLER_SCRIPT.new(context_pb)
		_party_ui.setup(_party_controller)
		_party_ui.open(resume_slot)

	await fade_layer.fade_out(_UI_SCREEN_FADE_DURATION)
	await get_tree().process_frame

	if _party_ui != null:
		await _party_ui.animate_item_hp_gain_for_slot(resume_slot)
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
		choice_index = await _show_bag_item_action_menu(item_name)
	else:
		choice_index = 0

	var did_party_bag_feedback: bool = false
	match choice_index:
		0:
			var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
			if not from_party_flow and item_data != null and item_data.requires_target():
				_pending_bag_item_id = item_id
				_pending_bag_ui_navigation_state = {}
				if _bag_ui != null and _bag_ui.has_method("get_navigation_state"):
					_pending_bag_ui_navigation_state = _bag_ui.get_navigation_state()
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


func _show_bag_item_action_menu(item_name: String) -> int:
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
	return await choice_box.await_coordinated_choice_result()

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
	await _open_save_ui()


func _open_save_ui() -> void:
	if _save_ui == null:
		push_error("DisplayManager: Nodo SaveUI no disponible en la escena.")
		return
	if _save_ui.visible:
		return
	if _bag_ui != null and _bag_ui.visible:
		return
	if _party_ui != null and _party_ui.visible:
		return
	if _pokedex_ui != null and _pokedex_ui.visible:
		return

	if pause_menu and pause_menu.visible:
		pause_menu.close(false)

	var context := _resolve_overworld_context()
	_save_menu_controller = SAVE_MENU_CONTROLLER_SCRIPT.new(context, 0)
	_reopen_pause_after_save_ui_close = true
	_save_ui.setup(_save_menu_controller)
	_save_ui.open()
	_on_ui_visibility_changed()

	await _run_save_flow()


func _close_save_ui() -> void:
	if _save_ui == null:
		return
	_save_ui.close()


func _run_save_flow() -> void:
	if _save_menu_controller == null or _save_ui == null:
		return
	var first_save_choice := await _show_message_with_choices(
		"¿Quieres guardar la partida?",
		["SI", "NO"],
		true
	)
	if first_save_choice != 0:
		_return_from_save_ui_to_pause_menu()
		return

	if _save_menu_controller.has_existing_save():
		var overwrite_choice := await _show_message_with_choices(
			"Ya hay una partida guardada.\n¿Quieres sobrescribirla?",
			["SI", "NO"],
			true
		)
		if overwrite_choice != 0:
			_return_from_save_ui_to_pause_menu()
			return

	if _save_menu_controller == null or _save_ui == null or not _save_ui.visible:
		_return_from_save_ui_to_pause_menu()
		return

	var player_name: String = _save_menu_controller.get_player_name()
	await _show_message_with_config("%s guardó la partida." % player_name, {
		"waitInput": false,
		"closeAtEnd": true,
		"waitTime": 0.6,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})

	var save_result: Dictionary = _save_menu_controller.save_game()
	if bool(save_result.get("ok", false)):
		_close_all_save_related_ui()
		return
	else:
		var reason := str(save_result.get("message", "No se pudo guardar."))
		await _show_message_with_config("No se pudo guardar.\n%s" % reason, {
			"waitInput": true,
			"closeAtEnd": true,
			"waitTime": 0.0,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		})
	_return_from_save_ui_to_pause_menu()


func _return_from_save_ui_to_pause_menu() -> void:
	if choice_box != null and choice_box.visible:
		choice_box.hide()
	if msg != null and msg.visible:
		_close_message()
	_reopen_pause_after_save_ui_close = true
	_close_save_ui()


func _close_all_save_related_ui() -> void:
	if choice_box != null and choice_box.visible:
		choice_box.hide()
	if msg != null and msg.visible:
		_close_message()
	_reopen_pause_after_save_ui_close = false
	_close_save_ui()
	if pause_menu != null and pause_menu.visible:
		pause_menu.close()


func _on_save_ui_closed() -> void:
	_save_menu_controller = null
	if _reopen_pause_after_save_ui_close and pause_menu and not pause_menu.visible:
		pause_menu.open(4, false)
	_reopen_pause_after_save_ui_close = true
	_on_ui_visibility_changed()

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
		(_pokedex_ui != null and _pokedex_ui.visible) or
		(_save_ui != null and _save_ui.visible) or
		(_pc_storage_ui != null and _pc_storage_ui.visible) or (_pc_items_ui != null and _pc_items_ui.visible) or
		(_poke_mart_ui != null and _poke_mart_ui.visible) or
		(_evolution_ui != null and _evolution_ui.visible) or
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
