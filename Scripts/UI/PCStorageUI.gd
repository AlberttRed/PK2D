extends Panel
class_name PCStorageUI

## UI de almacenamiento del PC (cajas). Modos Bill → #828.
## Iconos de caja + cursor de mano (idle point / grab / fist + hold).

signal closed()
signal back_requested()

enum Mode {
	WITHDRAW,
	DEPOSIT,
	MOVE,
	MOVE_ITEMS,
}

const COLS: int = 6
const ROWS: int = 5
const SLOT_COUNT: int = 30
## Selección fuera de la rejilla (Essentials: -1 nombre, -2 party, -3 close).
const SEL_BOX_NAME: int = -1
const SEL_PARTY: int = -2
const SEL_CLOSE: int = -3
## Sentinel interno para `_cursor_rest_position`.
const _SEL_USE_CURRENT: int = -100
const PARTY_SLOT_COUNT: int = 6
## Índice del botón SALIR dentro del panel Party (tras los 6 slots).
const SEL_PARTY_EXIT: int = 6
## Panel Marks: 0..5 formas, 6 confirmar, 7 cancelar.
const MARKS_SHAPE_COUNT: int = 6
const MARKS_SEL_CONFIRM: int = 6
const MARKS_SEL_CANCEL: int = 7
const MARKS_COLS: int = 3
const MARKINGS_TEX: Texture2D = preload("res://Sprites/UI/PC/markings.png")
## Separación horizontal entre iconos en Info/Markings.
const INFO_MARK_SPACING := 16.0
## Ajuste de la mano en el panel Marks (dedo sobre el símbolo / botón).
const MARKS_CURSOR_NUDGE := Vector2(16, 0)

## Centro del slot 0 — calibrado con el Sprite2D de ejemplo en la escena.
@export var grid_origin: Vector2 = Vector2(42, 62)
## Separación entre centros de slots (6 columnas × 5 filas).
@export var cell_size: Vector2 = Vector2(48, 48)
## Top-left del cursor respecto al centro del slot (fórmula Essentials: icon_tl + (0,-32)).
@export var cursor_offset: Vector2 = Vector2(-32, -64)

const CURSOR_POINT_1: Texture2D = preload("res://Sprites/UI/PC/cursor_point_1.png")
const CURSOR_POINT_2: Texture2D = preload("res://Sprites/UI/PC/cursor_point_2.png")
const CURSOR_GRAB: Texture2D = preload("res://Sprites/UI/PC/cursor_grab.png")
const CURSOR_FIST: Texture2D = preload("res://Sprites/UI/PC/cursor_fist.png")
const ICON_MALE: Texture2D = preload("res://Sprites/UI/Party/male_icon.png")
const ICON_FEMALE: Texture2D = preload("res://Sprites/UI/Party/female_icon.png")
const PC_ICON_OUTLINE_SHADER: Shader = preload("res://Shaders/UI/pc_icon_outline.gdshader")
const PARTY_SUMMARY_SCENE: PackedScene = preload("res://Scenes/UI/2 - Party/PartySummary.tscn")
## Essentials: alterna point1/point2 cada 0.5 s en idle.
const CURSOR_ANIM_PERIOD := 0.5
## Essentials PokemonBoxArrow::GRAB_TIME (aquí a mitad: 0.2 s).
const GRAB_TIME := 0.2
const GRAB_DIP_PX := 16.0
## Icono agarrado centrado respecto al top-left de la mano (hand.x, hand.y+16 en Essentials).
const HELD_ICON_FROM_CURSOR := Vector2(32, 48)
## Slide del panel Party (mitad de velocidad respecto a 0.28 s).
const PARTY_SLIDE_TIME := 0.56
## Viaje de la mano entre slots al sacar.
const WITHDRAW_HAND_TRAVEL := 0.3
## Viaje rápido box ↔ party (atajo izq/der en holding).
const PARTY_EDGE_HAND_TRAVEL := 0.15
const SUMMARY_FADE_DURATION := 0.35
## Slide horizontal al cambiar de caja (nombre CAJA ±).
const BOX_SLIDE_TIME := 0.56
## Icono de held item junto al mon (estilo FRLG: esquina inferior derecha).
const ITEM_PREVIEW_OFFSET := Vector2(14, 12)
const ITEM_PREVIEW_SCALE := 0.6
const ITEM_HELD_SCALE := 0.8
## Desplazamiento de la mano entre slots / chrome.
const CURSOR_SLIDE_TIME := 0.24
## Aparición / encogido del icono de objeto: mismo tiempo que el slide de la mano.
const ITEM_PREVIEW_POP_TIME := CURSOR_SLIDE_TIME
## Mantener dirección: espera antes del 1er repeat, luego slide + pequeño hueco.
const CURSOR_HOLD_INITIAL_DELAY := 0.40
const CURSOR_HOLD_REPEAT := 0.34
const ITEM_HAND_TRAVEL := 0.28
const ITEM_SWAP_TRAVEL := 0.4
const RELEASE_SHRINK_TIME := 1.5
const ITEM_BAG_SHRINK_TIME := 0.75
## Flechas del panel SALTAR / Box (cada una hacia su lado; al final teleport).
const CHOOSE_ARROW_BOB_PX := 6.0
## Segundos por ciclo (~25% más lento que el doble de velocidad).
const CHOOSE_ARROW_BOB_PERIOD := 0.367
## Nudge de ArrowL/R al cambiar de caja desde el nombre.
const BOX_ARROW_NUDGE_PX := 5.0
const BOX_ARROW_NUDGE_TIME := 0.12
const BOX_WALLPAPER_PATH := "res://Sprites/UI/PC/box_%d.png"
const INFO_DEPIXEL_SHADER: Shader = preload("res://Shaders/UI/pc_sprite_depixel.gdshader")
## Pasos de despixelado al enfocar un mon (FRLG).
const INFO_DEPIXEL_STEPS: Array[float] = [16.0, 8.0, 4.0, 2.0, 1.0]
const INFO_DEPIXEL_STEP_TIME := 0.055
## Empuje inicial abajo-derecha; vuelve al rest durante el despixelado.
const INFO_DEPIXEL_NUDGE := Vector2(4, 4)

## Centros de los 6 óvalos en overlay_party.png (medidos en el atlas).
const PARTY_ICON_POS: Array[Vector2] = [
	Vector2(48, 42), Vector2(124, 58),
	Vector2(48, 106), Vector2(124, 122),
	Vector2(48, 170), Vector2(124, 186),
]

const PKMN_MENU_OPTIONS: Array[String] = [
	"SACAR",
	"MOVER",
	"DATOS",
	"OBJETO",
	"MARCAR",
	"LIBERAR",
]

enum PkmnMenuAction {
	WITHDRAW = 0,
	MOVE = 1,
	SUMMARY = 2,
	ITEM = 3,
	MARK = 4,
	RELEASE = 5,
}

enum HandState {
	IDLE,
	GRABBING,
	HOLDING,
	RELEASING,
}

@onready var _box_name_label = $Box/Nombre
@onready var _slots_root: Control = $Box/Slots
@onready var _party_panel: Panel = $Party
@onready var _party_salir_label = $Party/Salir
@onready var _cursor: Sprite2D = $Box/Cursor
@onready var _box_arrow_l: Sprite2D = $Box/ArrowL
@onready var _box_arrow_r: Sprite2D = $Box/ArrowR
@onready var _box_panel: Panel = $Box
@onready var _info_nickname = $Info/Nickname
@onready var _info_gender: Sprite2D = $Info/Genero
@onready var _info_sprite: Sprite2D = $Info/Sprite
@onready var _info_level = $Info/Nivel
@onready var _info_lvl_icon: Sprite2D = $Info/lblNivel
@onready var _info_markings: Sprite2D = $Info/Markings
@onready var _marks_panel: Panel = $Marks
@onready var _marks_confirm_label = $Marks/Confirmar
@onready var _marks_cancel_label = $Marks/Cancelar
var _marks_shape_sprites: Array[Sprite2D] = []
@onready var _choose_panel: Panel = $Choose
@onready var _choose_caja_label = $Choose/Caja
@onready var _choose_espacio_label = $Choose/Espacio
@onready var _choose_arrow1: Sprite2D = $Choose/Arrow1
@onready var _choose_arrow2: Sprite2D = $Choose/Arrow2
@onready var _info_type1: Sprite2D = $Info/Tipo1/dTipo1
@onready var _info_type2_panel: Control = $Info/Tipo2
@onready var _info_type2: Sprite2D = $Info/Tipo2/dTipo2
@onready var _info_ability = $Info/Habilidad
@onready var _info_item = $Info/Objeto
@onready var _equipo_label = $Info/Equipo
@onready var _salir_label = $Info/Salir

var _mode: Mode = Mode.WITHDRAW
var _box_index: int = 0
var _slot_sprites: Array[Sprite2D] = []
var _party_slot_sprites: Array[Sprite2D] = []
var _input_enabled: bool = false
var _cursor_index: int = 0
var _cursor_anim_t: float = 0.0
var _hand_state: HandState = HandState.IDLE
var _grab_elapsed: float = 0.0
var _held_from_slot: int = -1
var _held_from_party: bool = false
var _held_from_box: int = -1
## Si > 0, la mano sostiene un objeto (no un Pokémon).
var _held_item_id: int = 0
var _held_sprite: Sprite2D = null
var _swap_sprite: Sprite2D = null
var _release_origin_slot: int = -1
var _release_target_slot: int = -1
var _release_origin_was_party: bool = false
var _release_origin_box: int = -1
var _release_to_party: bool = false
var _release_held_from: Vector2 = Vector2.ZERO
var _release_swap_from: Vector2 = Vector2.ZERO
var _release_commit_move: bool = false
## Soltar objeto en un mon (DAR/CAMBIO) con animación mano → slot.
var _item_releasing: bool = false
var _item_place_target: Pokemon = null
var _item_release_prev_id: int = 0
var _item_release_hand_to: Vector2 = Vector2.ZERO
var _item_release_slot_to: Vector2 = Vector2.ZERO
var _party_rest_position: Vector2 = Vector2.ZERO
var _party_open: bool = false
var _party_tween: Tween = null
var _party_sel: int = 0
var _selection_outline_root: Node2D = null
var _selection_outline_material: ShaderMaterial = null
var _selection_outline_target: Sprite2D = null
var _item_preview: Sprite2D = null
var _item_preview_tween: Tween = null
var _item_preview_key: String = ""
var _cursor_slide_tween: Tween = null
var _dir_hold_time: float = 0.0
var _dir_repeat_ready: bool = false
var _dir_hold_vec: Vector2i = Vector2i.ZERO
## Tras DAR un objeto: mostrar preview a tamaño final sin pop.
var _item_preview_suppress_pop: bool = false
var _summary: PartySummary = null
var _in_summary: bool = false
var _box_clip: Control = null
var _box_slide_tween: Tween = null
var _box_sliding: bool = false
## Editor de marcas (panel Marks).
var _marks_open: bool = false
var _marks_sel: int = 0
var _marks_col: int = 0
var _marks_draft: Array[int] = [0, 0, 0, 0, 0, 0]
var _marks_target: Pokemon = null
var _info_mark_sprites: Array[Sprite2D] = []
## Panel SALTAR (elegir caja).
var _choose_open: bool = false
var _choose_box_index: int = 0
var _choose_arrow_t: float = 0.0
var _choose_arrow1_rest: Vector2 = Vector2.ZERO
var _choose_arrow2_rest: Vector2 = Vector2.ZERO
## Cache de texturas de fondo de caja (wallpaper_id → Texture2D).
var _box_wallpaper_textures: Dictionary = {}
## Modo FONDO: elegir wallpaper con ArrowL/R del Box.
var _wallpaper_edit_open: bool = false
var _wallpaper_edit_original: int = 0
var _wallpaper_edit_current: int = 0
var _box_arrow_l_rest: Vector2 = Vector2.ZERO
var _box_arrow_r_rest: Vector2 = Vector2.ZERO
var _wallpaper_arrow_t: float = 0.0
var _box_arrow_nudge_tween: Tween = null
var _info_depixel_mat: ShaderMaterial = null
var _info_depixel_tween: Tween = null
var _info_sprite_focus_id: int = 0
var _info_sprite_rest: Vector2 = Vector2.ZERO
var _info_sprite_rest_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	_ensure_slots()
	_ensure_party_slots()
	_ensure_held_sprite()
	_ensure_swap_sprite()
	_ensure_item_preview()
	_ensure_summary()
	_ensure_info_mark_sprites()
	_setup_box_clip()
	_cache_marks_shape_sprites()
	if _party_panel:
		_party_rest_position = _party_panel.position
		_party_panel.z_as_relative = false
		_party_panel.z_index = 15
		_party_panel.visible = false
		_party_open = false
	if _marks_panel:
		_marks_panel.visible = false
		_marks_open = false
	if _choose_panel:
		_choose_panel.visible = false
		_choose_open = false
		if _choose_arrow1:
			_choose_arrow1_rest = _choose_arrow1.position
		if _choose_arrow2:
			_choose_arrow2_rest = _choose_arrow2.position
	if _cursor:
		_cursor.centered = false
		_cursor.z_index = 20
		_cursor.z_as_relative = false
		_cursor.hide()
	if _box_arrow_l:
		_box_arrow_l_rest = _box_arrow_l.position
	if _box_arrow_r:
		_box_arrow_r_rest = _box_arrow_r.position


func _cache_marks_shape_sprites() -> void:
	_marks_shape_sprites.clear()
	if _marks_panel == null:
		return
	for path in ["Circle", "Triangle", "Square", "Heart", "Star", "Diamond"]:
		var n: Node = _marks_panel.get_node_or_null(path)
		if n is Sprite2D:
			_marks_shape_sprites.append(n as Sprite2D)


func setup(_controller = null) -> void:
	# Controller dedicado en pasos siguientes.
	pass


func open(mode: Mode = Mode.WITHDRAW, box_index: int = 0) -> void:
	_mode = mode
	_box_index = clampi(box_index, 0, PCStorage.BOX_COUNT - 1)
	_kill_party_tween()
	_kill_box_slide_tween()
	_box_sliding = false
	if _box_clip != null and _box_panel:
		_box_panel.position = Vector2.ZERO
	if _party_panel:
		_party_panel.position = _party_rest_position
		_party_open = (_mode == Mode.DEPOSIT)
		_party_panel.visible = _party_open
		if _party_open:
			_party_panel.move_to_front()
	_release_held_visual(false)
	_close_marks_panel(false)
	_close_choose_panel(false)
	_close_wallpaper_edit(false)
	refresh()
	_cursor_index = 0
	_party_sel = 0
	_cursor_anim_t = 0.0
	_hand_state = HandState.IDLE
	_set_close_button_holding(false)
	_refresh_party_exit_label()
	if _party_open:
		_attach_hand_to(_party_panel)
	else:
		_attach_hand_to(_box_panel)
	_update_cursor_visual(false)
	_refresh_info_panel()
	show()
	_input_enabled = true
	_connect_input(true)
	set_process(true)


func close() -> void:
	if not visible:
		return
	_input_enabled = false
	_connect_input(false)
	set_process(false)
	_kill_party_tween()
	_kill_box_slide_tween()
	_clear_selection_outline()
	_close_marks_panel(false)
	_close_choose_panel(false)
	_close_wallpaper_edit(false)
	if _party_panel:
		_party_panel.visible = false
		_party_panel.position = _party_rest_position
		_party_open = false
	_attach_hand_to(_box_panel)
	_release_held_visual(true)
	_hide_item_preview()
	if _summary != null and _summary.visible:
		_summary.dismiss()
	_in_summary = false
	if _cursor:
		_cursor.hide()
	# No hide aquí: DisplayManager funde a negro con el PC aún montado.
	closed.emit()
	back_requested.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	if _choose_open:
		_process_choose_arrow_bob(delta)
	if _wallpaper_edit_open:
		_process_wallpaper_arrow_bob(delta)
	match _hand_state:
		HandState.GRABBING:
			_process_grab(delta)
		HandState.RELEASING:
			_process_release(delta)
		HandState.HOLDING:
			if _cursor:
				_cursor.texture = CURSOR_FIST
			_sync_held_to_cursor()
			_process_cursor_hold_repeat(delta)
		HandState.IDLE:
			if not _input_enabled:
				_reset_cursor_hold_repeat()
				return
			_cursor_anim_t += delta
			_update_cursor_frame()
			_process_cursor_hold_repeat(delta)


func _reset_cursor_hold_repeat() -> void:
	_dir_hold_time = 0.0
	_dir_repeat_ready = false
	_dir_hold_vec = Vector2i.ZERO


## Una sola dirección ortogonal (sin diagonales). Si hay dos ejes, gana el hold actual o el vertical.
func _read_orthogonal_move_dir() -> Vector2i:
	var dx := 0
	var dy := 0
	if Input.is_action_pressed("ui_left"):
		dx -= 1
	if Input.is_action_pressed("ui_right"):
		dx += 1
	if Input.is_action_pressed("ui_up"):
		dy -= 1
	if Input.is_action_pressed("ui_down"):
		dy += 1
	if dx != 0 and dy != 0:
		if _dir_hold_vec.x != 0 and _dir_hold_vec.y == 0:
			dy = 0
		elif _dir_hold_vec.y != 0 and _dir_hold_vec.x == 0:
			dx = 0
		else:
			# Sin hold previo: prioridad vertical.
			dx = 0
	return Vector2i(dx, dy)


func _process_cursor_hold_repeat(delta: float) -> void:
	if not _input_enabled or _in_summary or _box_sliding:
		_reset_cursor_hold_repeat()
		return
	if _hand_state == HandState.GRABBING or _hand_state == HandState.RELEASING:
		_reset_cursor_hold_repeat()
		return

	var dir := _read_orthogonal_move_dir()
	if dir == Vector2i.ZERO:
		_reset_cursor_hold_repeat()
		return

	# Primer frame de esta dirección: el signal ya movió; solo armar el hold.
	if dir != _dir_hold_vec:
		_dir_hold_vec = dir
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		return

	_dir_hold_time += delta
	var need := CURSOR_HOLD_INITIAL_DELAY if not _dir_repeat_ready else CURSOR_HOLD_REPEAT
	if _dir_hold_time < need:
		return
	_dir_hold_time = 0.0
	_dir_repeat_ready = true
	if _choose_open:
		_move_choose_box(dir.x)
	elif _wallpaper_edit_open:
		_move_wallpaper_edit(dir.x)
	elif _marks_open:
		_move_marks_cursor(dir.x, dir.y)
	else:
		_move_cursor(dir.x, dir.y)


func refresh() -> void:
	_ensure_slots()
	var storage: PCStorage = null
	if GameStateService != null:
		storage = GameStateService.get_pc_storage()
	if storage == null:
		_clear_all_slots()
		_set_box_name_text("CAJA")
		_set_equipo_count(0)
		_clear_info_panel()
		return

	_box_index = clampi(_box_index, 0, storage.get_box_count() - 1)
	_set_box_name_text(storage.get_box_name(_box_index))
	_apply_box_wallpaper(storage.get_box_wallpaper(_box_index))

	var party_count := 0
	if GameStateService != null:
		var party: Party = GameStateService.get_party()
		if party != null:
			party_count = party.count()
	_set_equipo_count(party_count)

	for i in range(SLOT_COUNT):
		var spr: Sprite2D = _slot_sprites[i]
		var mon: Pokemon = storage.get_pokemon(_box_index, i)
		if mon == null or _is_slot_visually_empty(i):
			spr.texture = null
			spr.modulate = Color.WHITE
			spr.hide()
			continue
		var icon: Texture2D = mon.get_icon_sprite()
		spr.texture = icon
		spr.hframes = 2
		spr.frame = 0
		spr.modulate = _icon_modulate_for_pokemon(mon)
		spr.show()
	_refresh_party_icons()


func _ensure_slots() -> void:
	if _slots_root == null:
		return
	if _slot_sprites.size() == SLOT_COUNT:
		_apply_slot_positions()
		return

	for child in _slots_root.get_children():
		child.queue_free()
	_slot_sprites.clear()

	for i in range(SLOT_COUNT):
		var spr := Sprite2D.new()
		spr.name = "Slot%d" % i
		spr.centered = true
		spr.hframes = 2
		spr.hide()
		_slots_root.add_child(spr)
		_slot_sprites.append(spr)
	_apply_slot_positions()


func _apply_slot_positions() -> void:
	for i in range(_slot_sprites.size()):
		var col: int = i % COLS
		var row: int = int(i / COLS)
		var center := grid_origin + Vector2(float(col) * cell_size.x, float(row) * cell_size.y)
		_slot_sprites[i].position = center


func _ensure_party_slots() -> void:
	if _party_panel == null:
		return
	if _party_slot_sprites.size() == PARTY_SLOT_COUNT:
		_apply_party_slot_positions()
		return
	for spr in _party_slot_sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	_party_slot_sprites.clear()
	for i in range(PARTY_SLOT_COUNT):
		var spr := Sprite2D.new()
		spr.name = "PartySlot%d" % i
		spr.centered = true
		spr.hframes = 2
		spr.z_index = 1
		spr.hide()
		_party_panel.add_child(spr)
		_party_slot_sprites.append(spr)
	_apply_party_slot_positions()


func _apply_party_slot_positions() -> void:
	for i in range(_party_slot_sprites.size()):
		_party_slot_sprites[i].position = PARTY_ICON_POS[i]


func _refresh_party_icons() -> void:
	_ensure_party_slots()
	var party: Party = null
	if GameStateService != null:
		party = GameStateService.get_party()
	for i in range(PARTY_SLOT_COUNT):
		var spr: Sprite2D = _party_slot_sprites[i]
		var mon: Pokemon = party.get_pokemon(i) if party != null else null
		if mon == null or _is_party_slot_visually_empty(i):
			spr.texture = null
			spr.modulate = Color.WHITE
			spr.hide()
			continue
		spr.texture = mon.get_icon_sprite()
		spr.hframes = 2
		spr.frame = 0
		spr.modulate = _icon_modulate_for_pokemon(mon)
		spr.show()


## En MOVER OBJETOS: sin objeto → semitransparente; con objeto → opaco.
## En FONDO: todos semitransparentes para ver el wallpaper.
func _icon_modulate_for_pokemon(mon: Pokemon) -> Color:
	if _wallpaper_edit_open:
		return Color(1, 1, 1, 0.4)
	if _mode != Mode.MOVE_ITEMS or mon == null:
		return Color.WHITE
	if mon.held_item_id > 0:
		return Color.WHITE
	return Color(1, 1, 1, 0.4)


func _clear_all_slots() -> void:
	for spr in _slot_sprites:
		spr.texture = null
		spr.hide()
	for spr in _party_slot_sprites:
		spr.texture = null
		spr.hide()


func _set_box_name_text(box_name: String) -> void:
	if _box_name_label == null:
		return
	if _box_name_label.has_method("setText"):
		_box_name_label.setText(box_name)
	else:
		_box_name_label.text = "[center]%s" % box_name


func _get_box_wallpaper_texture(wallpaper_id: int) -> Texture2D:
	var id := posmod(wallpaper_id, PCStorage.WALLPAPER_COUNT)
	if _box_wallpaper_textures.has(id):
		return _box_wallpaper_textures[id] as Texture2D
	var path := BOX_WALLPAPER_PATH % id
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_box_wallpaper_textures[id] = tex
	return tex


func _apply_box_wallpaper(wallpaper_id: int) -> void:
	if _box_panel == null:
		return
	var tex := _get_box_wallpaper_texture(wallpaper_id)
	if tex == null:
		return
	var current := _box_panel.get_theme_stylebox("panel")
	var style: StyleBoxTexture
	if current is StyleBoxTexture:
		style = (current as StyleBoxTexture).duplicate() as StyleBoxTexture
	else:
		style = StyleBoxTexture.new()
	style.texture = tex
	_box_panel.add_theme_stylebox_override("panel", style)


func _set_equipo_count(count: int) -> void:
	if _equipo_label == null:
		return
	var msg := "EQUIPO:  %d" % count
	if _equipo_label.has_method("setText"):
		_equipo_label.setText(msg)
	else:
		_equipo_label.text = "[center]%s" % msg


func _set_close_button_holding(holding: bool) -> void:
	if _salir_label == null:
		return
	var msg := "CANCELAR" if holding else "SALIR"
	if _salir_label.has_method("setText"):
		_salir_label.setText(msg)
	else:
		_salir_label.text = "[center]%s" % msg


func _refresh_party_exit_label() -> void:
	if _party_salir_label == null:
		return
	# DEJAR sale del PC; SACAR/MOVER solo cierran el panel.
	var msg := "SALIR" if _mode == Mode.DEPOSIT else "CERRAR"
	if _party_salir_label.has_method("setText"):
		_party_salir_label.setText(msg)
	else:
		_party_salir_label.text = "[center]%s" % msg


func _setup_box_clip() -> void:
	if _box_panel == null or _box_clip != null:
		return
	var parent := _box_panel.get_parent()
	if parent == null:
		return
	_box_clip = Control.new()
	_box_clip.name = "BoxClip"
	# Solo recortar durante el slide; si no, la mano en nombre/Equipo/Salir se corta.
	_box_clip.clip_contents = false
	_box_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_clip.position = _box_panel.position
	_box_clip.size = _box_panel.size
	if _box_panel.custom_minimum_size != Vector2.ZERO:
		_box_clip.custom_minimum_size = _box_panel.custom_minimum_size
	var idx := _box_panel.get_index()
	parent.add_child(_box_clip)
	parent.move_child(_box_clip, idx)
	_box_panel.reparent(_box_clip)
	_box_panel.position = Vector2.ZERO
	_detach_box_arrows_to_clip()


## ArrowL/R quedan fijos en BoxClip; solo el panel (fondo) hace slide.
func _detach_box_arrows_to_clip() -> void:
	if _box_clip == null:
		return
	for arrow in [_box_arrow_l, _box_arrow_r]:
		if arrow == null or not is_instance_valid(arrow):
			continue
		if arrow.get_parent() == _box_clip:
			continue
		# Misma posición local: Box está en (0,0) dentro del clip.
		var local_pos: Vector2 = arrow.position
		arrow.reparent(_box_clip, false)
		arrow.position = local_pos
		arrow.z_index = 5
		arrow.z_as_relative = false
	_raise_box_arrows()


func _raise_box_arrows() -> void:
	if _box_clip == null:
		return
	if _box_arrow_l != null and is_instance_valid(_box_arrow_l) and _box_arrow_l.get_parent() == _box_clip:
		_box_clip.move_child(_box_arrow_l, -1)
	if _box_arrow_r != null and is_instance_valid(_box_arrow_r) and _box_arrow_r.get_parent() == _box_clip:
		_box_clip.move_child(_box_arrow_r, -1)


func _kill_box_slide_tween() -> void:
	if _box_slide_tween != null and is_instance_valid(_box_slide_tween):
		_box_slide_tween.kill()
	_box_slide_tween = null


func _kill_party_tween() -> void:
	if _party_tween != null and is_instance_valid(_party_tween):
		_party_tween.kill()
	_party_tween = null


func _attach_hand_to(parent: Node) -> void:
	if parent == null:
		return
	if _cursor != null and is_instance_valid(_cursor) and _cursor.get_parent() != parent:
		_cursor.reparent(parent, false)
		_cursor.z_index = 20
		_cursor.z_as_relative = false
	if _held_sprite != null and is_instance_valid(_held_sprite) and _held_sprite.get_parent() != parent:
		_held_sprite.reparent(parent, false)
		_held_sprite.z_index = 9
	if _swap_sprite != null and is_instance_valid(_swap_sprite) and _swap_sprite.get_parent() != parent:
		_swap_sprite.reparent(parent, false)
		_swap_sprite.z_index = 8


func _party_arrow_position(sel: int) -> Vector2:
	# Misma ancla que en caja: top-left de la mano = centro del icono + cursor_offset.
	if sel == SEL_PARTY_EXIT:
		if _party_salir_label:
			var r: Rect2 = _party_salir_label.get_rect()
			return r.position + r.size * 0.5 + cursor_offset
		return Vector2(86, 257) + cursor_offset
	var idx := clampi(sel, 0, PARTY_SLOT_COUNT - 1)
	return PARTY_ICON_POS[idx] + cursor_offset


func _open_party_panel(
	restore_input: bool = true,
	keep_hand_pos: bool = false,
	slide_time: float = PARTY_SLIDE_TIME,
	attach_hand: bool = true,
	play_sfx: bool = true
) -> void:
	if _party_panel == null or _party_open:
		return
	_input_enabled = false
	if play_sfx:
		_play_cursor_sound()
	_kill_party_tween()
	_party_open = true
	_refresh_party_icons()
	var kept_global := Vector2.ZERO
	var has_kept := false
	if keep_hand_pos and _cursor != null:
		kept_global = _cursor.global_position
		has_kept = true
	else:
		_party_sel = 0
	var start_y: float = size.y
	_party_panel.position = Vector2(_party_rest_position.x, start_y)
	_party_panel.z_as_relative = false
	_party_panel.z_index = 15
	_party_panel.visible = true
	_party_panel.move_to_front()
	if attach_hand:
		_attach_hand_to(_party_panel)
		if has_kept:
			_cursor.global_position = kept_global
			if _hand_state == HandState.HOLDING:
				_sync_held_to_cursor()
			_update_cursor_frame()
			_cursor.show()
		else:
			_update_cursor_visual()
	_refresh_info_panel()
	_party_tween = create_tween()
	_party_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_party_tween.set_trans(Tween.TRANS_CUBIC)
	_party_tween.set_ease(Tween.EASE_OUT)
	_party_tween.tween_property(_party_panel, "position", _party_rest_position, slide_time)
	await _party_tween.finished
	_party_tween = null
	if not visible:
		return
	if restore_input:
		_input_enabled = true


func _close_party_panel(
	restore_input: bool = true,
	focus_after: int = SEL_PARTY,
	slide_time: float = PARTY_SLIDE_TIME,
	snap_cursor: bool = true,
	play_sfx: bool = true
) -> void:
	if _party_panel == null or not _party_open:
		return
	_input_enabled = false
	if play_sfx:
		_play_cursor_sound()
	_kill_party_tween()
	# La mano no debe bajar con el panel: anclarla al Box manteniendo su sitio en pantalla.
	if _box_panel:
		if _cursor != null and is_instance_valid(_cursor):
			_cursor.reparent(_box_panel, true)
			_cursor.z_index = 20
			_cursor.z_as_relative = false
		if _held_sprite != null and is_instance_valid(_held_sprite):
			_held_sprite.reparent(_box_panel, true)
			_held_sprite.z_index = 9
		if _swap_sprite != null and is_instance_valid(_swap_sprite):
			_swap_sprite.reparent(_box_panel, true)
			_swap_sprite.z_index = 8
	_party_tween = create_tween()
	_party_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_party_tween.set_trans(Tween.TRANS_CUBIC)
	_party_tween.set_ease(Tween.EASE_IN)
	var end_pos := Vector2(_party_rest_position.x, size.y)
	_party_tween.tween_property(_party_panel, "position", end_pos, slide_time)
	await _party_tween.finished
	_party_tween = null
	if not visible:
		return
	_party_panel.visible = false
	_party_panel.position = _party_rest_position
	_party_open = false
	_party_sel = 0
	_cursor_index = focus_after
	if snap_cursor:
		_attach_hand_to(_box_panel)
		_update_cursor_visual()
		_refresh_info_panel()
	if restore_input:
		_input_enabled = true


func _attach_hand_keep_global(parent: Node) -> void:
	if parent == null:
		return
	if _cursor != null and is_instance_valid(_cursor) and _cursor.get_parent() != parent:
		_cursor.reparent(parent, true)
		_cursor.z_index = 20
		_cursor.z_as_relative = false
	if _held_sprite != null and is_instance_valid(_held_sprite) and _held_sprite.get_parent() != parent:
		_held_sprite.reparent(parent, true)
		_held_sprite.z_index = 9
	if _swap_sprite != null and is_instance_valid(_swap_sprite) and _swap_sprite.get_parent() != parent:
		_swap_sprite.reparent(parent, true)
		_swap_sprite.z_index = 8


func _set_label_text(label, msg: String) -> void:
	if label == null:
		return
	if label.has_method("setText"):
		label.setText(msg)
	else:
		label.text = msg


func _is_slot_visually_empty(slot_index: int) -> bool:
	if _hand_state == HandState.IDLE:
		return false
	# Al quitar un objeto el mon sigue visible en el slot.
	if _held_item_id > 0:
		return false
	if (
		not _held_from_party
		and _held_from_box == _box_index
		and slot_index == _held_from_slot
	):
		return true
	# Durante place+swap el destino también va en vuelo.
	if (
		_hand_state == HandState.RELEASING
		and not _release_to_party
		and _swap_sprite != null
		and _swap_sprite.visible
		and slot_index == _release_target_slot
	):
		return true
	return false


func _is_party_slot_visually_empty(slot_index: int) -> bool:
	if _hand_state == HandState.IDLE:
		return false
	if _held_item_id > 0:
		return false
	if _held_from_party and slot_index == _held_from_slot:
		return true
	if (
		_hand_state == HandState.RELEASING
		and _release_to_party
		and _swap_sprite != null
		and _swap_sprite.visible
		and slot_index == _release_target_slot
	):
		return true
	return false


func _get_cursor_pokemon() -> Pokemon:
	if _party_open:
		return _get_party_pokemon_at(_party_sel)
	if _cursor_index < 0:
		return null
	if GameStateService == null:
		return null
	var storage: PCStorage = GameStateService.get_pc_storage()
	if storage == null:
		return null
	# Slot origen vacío visualmente mientras se agarra.
	if (
		_hand_state != HandState.IDLE
		and not _held_from_party
		and _held_from_box == _box_index
		and _cursor_index == _held_from_slot
	):
		return null
	return storage.get_pokemon(_box_index, _cursor_index)


func _get_party_pokemon_at(index: int) -> Pokemon:
	if index < 0 or index >= PARTY_SLOT_COUNT:
		return null
	if GameStateService == null:
		return null
	var party: Party = GameStateService.get_party()
	if party == null:
		return null
	if _hand_state != HandState.IDLE and _held_from_party and index == _held_from_slot:
		return null
	return party.get_pokemon(index)


func _get_held_pokemon() -> Pokemon:
	if _held_from_slot < 0 or GameStateService == null:
		return null
	if _held_from_party:
		var party: Party = GameStateService.get_party()
		if party == null:
			return null
		return party.get_pokemon(_held_from_slot)
	var storage: PCStorage = GameStateService.get_pc_storage()
	if storage == null:
		return null
	var from_box := _held_from_box if _held_from_box >= 0 else _box_index
	return storage.get_pokemon(from_box, _held_from_slot)


func _refresh_info_panel() -> void:
	var mon: Pokemon = null
	if _held_item_id > 0:
		# Con objeto en mano: info del mon bajo el cursor (o el origen al agarrar).
		if _hand_state == HandState.HOLDING:
			mon = _get_cursor_pokemon()
		else:
			mon = _get_held_source_pokemon()
	elif _hand_state == HandState.HOLDING or _hand_state == HandState.GRABBING or _hand_state == HandState.RELEASING:
		mon = _get_held_pokemon()
	else:
		mon = _get_cursor_pokemon()
	if mon == null:
		_clear_info_panel()
		return

	_set_label_text(_info_nickname, mon.get_display_name())
	_set_label_text(_info_level, str(mon.level))
	if _info_lvl_icon:
		_info_lvl_icon.show()
	_refresh_info_markings(mon)

	if _info_sprite:
		var tex: Texture2D = mon.get_battle_front_sprite()
		var focus_id := mon.get_instance_id()
		_info_sprite.texture = tex
		_info_sprite.visible = tex != null
		if tex != null and focus_id != _info_sprite_focus_id:
			_info_sprite_focus_id = focus_id
			_play_info_sprite_depixel()
		elif tex == null:
			_info_sprite_focus_id = 0
			_kill_info_depixel_tween()

	if _info_gender:
		match mon.gender:
			CONST.GENEROS.MACHO:
				_info_gender.texture = ICON_MALE
				_info_gender.show()
			CONST.GENEROS.HEMBRA:
				_info_gender.texture = ICON_FEMALE
				_info_gender.show()
			_:
				_info_gender.texture = null
				_info_gender.hide()

	var t1: TypeData = mon.get_type1()
	if _info_type1:
		if t1 != null and t1.image != null:
			_info_type1.vframes = 1
			_info_type1.frame = 0
			_info_type1.texture = t1.image
			_info_type1.show()
		else:
			_info_type1.hide()

	var t2: TypeData = mon.get_type2()
	if _info_type2_panel and _info_type2:
		if t2 != null and t2.image != null:
			_info_type2.vframes = 1
			_info_type2.frame = 0
			_info_type2.texture = t2.image
			_info_type2_panel.show()
			_info_type2.show()
		else:
			_info_type2_panel.hide()

	var ability_name := "—"
	var ab: AbilityData = mon.ability
	if ab == null and int(mon.ability_id) > 0 and DatabaseService != null:
		ab = DatabaseService.get_ability(int(mon.ability_id))
	if ab != null and ab.display_name != "":
		ability_name = ab.display_name
	elif int(mon.ability_id) >= 0 and int(mon.ability_id) < CONST.AbilitiesName.size():
		ability_name = str(CONST.AbilitiesName[int(mon.ability_id)])
	_set_label_text(_info_ability, ability_name)

	var item_name := "Sin objeto"
	var has_item := false
	# Siempre el objeto del mon mostrado; no el que llevas en la mano.
	if mon.held_item_id > 0 and DatabaseService != null:
		var item: ItemData = DatabaseService.get_item_by_id(mon.held_item_id)
		if item != null:
			item_name = item.get_display_name()
			has_item = true
	_set_label_text(_info_item, item_name)
	_set_item_label_style(has_item)


func _set_item_label_style(has_item: bool) -> void:
	if _info_item == null:
		return
	var fill: Color
	var shadow: Color
	if has_item:
		fill = Color(0.25098, 0.25098, 0.25098, 1)
		shadow = Color(0.690196, 0.690196, 0.690196, 1)
	else:
		fill = Color("#D2D2D2")
		shadow = Color("#E0E0E0")
	_info_item.set("theme_override_colors/default_color", fill)
	_info_item.set("theme_override_colors/font_shadow_color", shadow)


func _clear_info_panel() -> void:
	_info_sprite_focus_id = 0
	_kill_info_depixel_tween()
	_set_info_depixel_block(1.0)
	_reset_info_sprite_pos()
	_set_label_text(_info_nickname, "")
	_set_label_text(_info_level, "")
	_set_label_text(_info_ability, "")
	_set_label_text(_info_item, "")
	if _info_lvl_icon:
		_info_lvl_icon.hide()
	_hide_info_markings()
	if _info_sprite:
		_info_sprite.texture = null
		_info_sprite.hide()
	if _info_gender:
		_info_gender.texture = null
		_info_gender.hide()
	if _info_type1:
		_info_type1.hide()
	if _info_type2_panel:
		_info_type2_panel.hide()


func _ensure_info_sprite_rest() -> void:
	if _info_sprite_rest_ready or _info_sprite == null:
		return
	_info_sprite_rest = _info_sprite.position
	_info_sprite_rest_ready = true


func _reset_info_sprite_pos() -> void:
	_ensure_info_sprite_rest()
	if _info_sprite != null and _info_sprite_rest_ready:
		_info_sprite.position = _info_sprite_rest


func _ensure_info_depixel_material() -> void:
	if _info_sprite == null:
		return
	if _info_depixel_mat != null:
		if _info_sprite.material != _info_depixel_mat:
			_info_sprite.material = _info_depixel_mat
		return
	_info_depixel_mat = ShaderMaterial.new()
	_info_depixel_mat.shader = INFO_DEPIXEL_SHADER
	_info_depixel_mat.set_shader_parameter("block_size", 1.0)
	_info_sprite.material = _info_depixel_mat
	_info_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _set_info_depixel_block(block: float) -> void:
	_ensure_info_depixel_material()
	if _info_depixel_mat == null:
		return
	var b := maxf(block, 1.0)
	_info_depixel_mat.set_shader_parameter("block_size", b)
	# Sin mosaico: quitar material para muestreo nativo del AtlasTexture.
	if b <= 1.0 and _info_sprite != null:
		_info_sprite.material = null


func _kill_info_depixel_tween() -> void:
	if _info_depixel_tween != null and is_instance_valid(_info_depixel_tween):
		_info_depixel_tween.kill()
	_info_depixel_tween = null


func _play_info_sprite_depixel() -> void:
	_ensure_info_depixel_material()
	_ensure_info_sprite_rest()
	_kill_info_depixel_tween()
	if _info_sprite == null or _info_sprite.texture == null:
		_set_info_depixel_block(1.0)
		_reset_info_sprite_pos()
		return
	# Forzar material al arrancar (pudo haberse quitado al terminar el paso 1).
	_info_sprite.material = _info_depixel_mat
	_info_sprite.position = _info_sprite_rest + INFO_DEPIXEL_NUDGE
	_set_info_depixel_block(INFO_DEPIXEL_STEPS[0])
	var total_time := INFO_DEPIXEL_STEP_TIME * float(INFO_DEPIXEL_STEPS.size() - 1)
	_info_depixel_tween = create_tween()
	_info_depixel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_info_depixel_tween.set_parallel(true)
	_info_depixel_tween.tween_property(
		_info_sprite, "position", _info_sprite_rest, total_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in range(1, INFO_DEPIXEL_STEPS.size()):
		var block: float = INFO_DEPIXEL_STEPS[i]
		var delay := INFO_DEPIXEL_STEP_TIME * float(i)
		_info_depixel_tween.tween_callback(_set_info_depixel_block.bind(block)).set_delay(delay)


func _ensure_info_mark_sprites() -> void:
	if _info_markings == null:
		return
	if _info_mark_sprites.size() == MARKS_SHAPE_COUNT:
		return
	# El nodo Markings actúa de ancla (posición de escena = centro de la tira 96px).
	_info_markings.texture = null
	for c in _info_markings.get_children():
		if c is Sprite2D:
			c.queue_free()
	_info_mark_sprites.clear()
	var start_x := -((MARKS_SHAPE_COUNT - 1) * INFO_MARK_SPACING) * 0.5
	for i in range(MARKS_SHAPE_COUNT):
		var spr := Sprite2D.new()
		spr.name = "Mark%d" % i
		spr.centered = true
		spr.texture = MARKINGS_TEX
		spr.hframes = 6
		spr.vframes = 4
		spr.position = Vector2(start_x + float(i) * INFO_MARK_SPACING, 0.0)
		spr.frame = i
		_info_markings.add_child(spr)
		_info_mark_sprites.append(spr)


func _marking_frame(shape: int, color: int) -> int:
	return clampi(shape, 0, MARKS_SHAPE_COUNT - 1) + clampi(color, 0, Pokemon.MARKING_COLOR_COUNT - 1) * MARKS_SHAPE_COUNT


func _apply_marking_frames(sprites: Array[Sprite2D], colors: Array) -> void:
	for i in range(mini(sprites.size(), MARKS_SHAPE_COUNT)):
		var color := 0
		if i < colors.size():
			color = clampi(int(colors[i]), 0, Pokemon.MARKING_COLOR_COUNT - 1)
		sprites[i].frame = _marking_frame(i, color)


func _refresh_info_markings(mon: Pokemon) -> void:
	_ensure_info_mark_sprites()
	if _info_markings == null:
		return
	_info_markings.show()
	_apply_marking_frames(_info_mark_sprites, mon.get_markings_copy())


func _hide_info_markings() -> void:
	if _info_markings:
		_info_markings.hide()


func _apply_marks_panel_frames() -> void:
	_apply_marking_frames(_marks_shape_sprites, _marks_draft)


func _marks_cursor_position(sel: int = -1) -> Vector2:
	var s := _marks_sel if sel < 0 else sel
	var off := cursor_offset + MARKS_CURSOR_NUDGE
	if s >= 0 and s < MARKS_SHAPE_COUNT and s < _marks_shape_sprites.size():
		var spr: Sprite2D = _marks_shape_sprites[s]
		if spr != null:
			return spr.position + off
	if s == MARKS_SEL_CONFIRM and _marks_confirm_label:
		var r: Rect2 = _marks_confirm_label.get_rect()
		return r.position + r.size * 0.5 + off
	if s == MARKS_SEL_CANCEL and _marks_cancel_label:
		var r2: Rect2 = _marks_cancel_label.get_rect()
		return r2.position + r2.size * 0.5 + off
	return Vector2(52, 46) + off


func _open_marks_panel() -> void:
	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null or _marks_panel == null:
		return
	_input_enabled = false
	_reset_cursor_hold_repeat()
	_marks_target = mon
	_marks_draft = mon.get_markings_copy()
	_marks_sel = 0
	_marks_col = 0
	_marks_open = true
	_marks_panel.visible = true
	_marks_panel.move_to_front()
	_apply_marks_panel_frames()
	_refresh_info_panel()
	_attach_hand_to(_marks_panel)
	_update_cursor_visual(false)
	_input_enabled = true


func _close_marks_panel(restore_hand: bool = true) -> void:
	_marks_open = false
	_marks_target = null
	_marks_draft = [0, 0, 0, 0, 0, 0]
	_marks_sel = 0
	_marks_col = 0
	if _marks_panel:
		_marks_panel.visible = false
	if not restore_hand:
		return
	if _party_open:
		_attach_hand_to(_party_panel)
	else:
		_attach_hand_to(_box_panel)
	_update_cursor_visual(false)
	_refresh_info_panel()


func _confirm_marks_panel() -> void:
	_play_cursor_sound()
	if _marks_target != null:
		_marks_target.set_markings_from(_marks_draft)
	_close_marks_panel(true)


func _cancel_marks_panel() -> void:
	_play_cursor_sound()
	_close_marks_panel(true)


func _move_marks_cursor(dx: int, dy: int) -> void:
	var prev := _marks_sel
	var sel := _marks_sel
	if sel < MARKS_SHAPE_COUNT:
		_marks_col = sel % MARKS_COLS
		if dx < 0 and (sel % MARKS_COLS) > 0:
			sel -= 1
		elif dx > 0 and (sel % MARKS_COLS) < MARKS_COLS - 1:
			sel += 1
		if dy < 0 and sel >= MARKS_COLS:
			sel -= MARKS_COLS
		elif dy > 0:
			if sel < MARKS_COLS:
				sel += MARKS_COLS
			else:
				sel = MARKS_SEL_CONFIRM
	elif sel == MARKS_SEL_CONFIRM:
		if dy > 0:
			sel = MARKS_SEL_CANCEL
		elif dy < 0:
			sel = MARKS_COLS + clampi(_marks_col, 0, MARKS_COLS - 1)
	elif sel == MARKS_SEL_CANCEL:
		if dy < 0:
			sel = MARKS_SEL_CONFIRM
	_marks_sel = sel
	if _marks_sel < MARKS_SHAPE_COUNT:
		_marks_col = _marks_sel % MARKS_COLS
	_update_cursor_visual()
	if _marks_sel != prev:
		_play_cursor_sound()


func _on_marks_accept() -> void:
	if _marks_sel < MARKS_SHAPE_COUNT:
		var color := int(_marks_draft[_marks_sel]) if _marks_sel < _marks_draft.size() else 0
		color = (color + 1) % Pokemon.MARKING_COLOR_COUNT
		_marks_draft[_marks_sel] = color
		_apply_marks_panel_frames()
		return
	if _marks_sel == MARKS_SEL_CONFIRM:
		_confirm_marks_panel()
		return
	_cancel_marks_panel()


func _slot_center(index: int) -> Vector2:
	var col: int = index % COLS
	var row: int = int(index / COLS)
	return grid_origin + Vector2(float(col) * cell_size.x, float(row) * cell_size.y)


func _chrome_target_center(sel: int) -> Vector2:
	# Centros en espacio local de Box (el Cursor es hijo de Box).
	match sel:
		SEL_BOX_NAME:
			if _box_name_label:
				var r: Rect2 = _box_name_label.get_rect()
				return r.position + r.size * 0.5
			return Vector2(162, 25)
		SEL_PARTY:
			if _equipo_label and _box_panel:
				var center: Vector2 = _equipo_label.global_position + _equipo_label.size * 0.5
				return _box_panel.get_global_transform_with_canvas().affine_inverse() * center
			return Vector2(85, 323)
		SEL_CLOSE:
			if _salir_label and _box_panel:
				var center2: Vector2 = _salir_label.global_position + _salir_label.size * 0.5
				return _box_panel.get_global_transform_with_canvas().affine_inverse() * center2
			return Vector2(261, 323)
		_:
			return Vector2.ZERO


func _cursor_rest_position(sel: int = _SEL_USE_CURRENT) -> Vector2:
	if _marks_open:
		var ms := _marks_sel if sel == _SEL_USE_CURRENT else sel
		return _marks_cursor_position(ms)
	if _party_open:
		var ps := _party_sel if sel == _SEL_USE_CURRENT else sel
		return _party_arrow_position(ps)
	var s := _cursor_index if sel == _SEL_USE_CURRENT else sel
	if s >= 0:
		return _slot_center(s) + cursor_offset
	return _chrome_target_center(s) + cursor_offset


func _ensure_held_sprite() -> void:
	if _held_sprite != null and is_instance_valid(_held_sprite):
		return
	_held_sprite = Sprite2D.new()
	_held_sprite.name = "HeldIcon"
	_held_sprite.centered = true
	_held_sprite.z_index = 9
	_held_sprite.hframes = 2
	_held_sprite.hide()
	if _box_panel:
		_box_panel.add_child(_held_sprite)
	else:
		add_child(_held_sprite)


func _ensure_swap_sprite() -> void:
	if _swap_sprite != null and is_instance_valid(_swap_sprite):
		return
	_swap_sprite = Sprite2D.new()
	_swap_sprite.name = "SwapIcon"
	_swap_sprite.centered = true
	_swap_sprite.z_index = 8
	_swap_sprite.hframes = 2
	_swap_sprite.hide()
	if _box_panel:
		_box_panel.add_child(_swap_sprite)
	else:
		add_child(_swap_sprite)


func _ensure_item_preview() -> void:
	if _item_preview != null and is_instance_valid(_item_preview):
		return
	_item_preview = Sprite2D.new()
	_item_preview.name = "ItemPreview"
	_item_preview.centered = true
	_item_preview.z_index = 5
	_item_preview.scale = Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE)
	_item_preview.hide()
	if _slots_root:
		_slots_root.add_child(_item_preview)
	elif _box_panel:
		_box_panel.add_child(_item_preview)
	else:
		add_child(_item_preview)


func _kill_item_preview_tween() -> void:
	if _item_preview_tween != null and is_instance_valid(_item_preview_tween):
		_item_preview_tween.kill()
	_item_preview_tween = null


## Ocultación inmediata (QUITAR / CAMBIO / cerrar UI).
func _hide_item_preview() -> void:
	_kill_item_preview_tween()
	_item_preview_key = ""
	if _item_preview != null and is_instance_valid(_item_preview):
		_item_preview.hide()
		_item_preview.texture = null
		_item_preview.scale = Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE)


func _item_preview_anchor() -> Vector2:
	if _party_open:
		if _party_sel >= 0 and _party_sel < PARTY_SLOT_COUNT:
			return PARTY_ICON_POS[_party_sel] + ITEM_PREVIEW_OFFSET
		return Vector2.ZERO
	if _cursor_index >= 0:
		return _slot_center(_cursor_index) + ITEM_PREVIEW_OFFSET
	return Vector2.ZERO


## Encoge una copia en el slot al salir a vacío / chrome.
func _spawn_item_preview_shrink_ghost() -> void:
	if _item_preview == null or not is_instance_valid(_item_preview):
		return
	if not _item_preview.visible or _item_preview.texture == null:
		return
	var parent := _item_preview.get_parent()
	if parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.name = "ItemPreviewGhost"
	ghost.centered = true
	ghost.z_index = _item_preview.z_index
	ghost.texture = _item_preview.texture
	ghost.hframes = _item_preview.hframes
	ghost.frame = _item_preview.frame
	ghost.position = _item_preview.position
	var from_scale: Vector2 = _item_preview.scale
	if from_scale.x < 0.05:
		from_scale = Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE)
	ghost.scale = from_scale
	parent.add_child(ghost)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "scale", Vector2(0.05, 0.05), ITEM_PREVIEW_POP_TIME)
	tw.tween_callback(ghost.queue_free)


func _dismiss_item_preview_animated() -> void:
	if _item_preview != null and is_instance_valid(_item_preview) and _item_preview.visible:
		_spawn_item_preview_shrink_ghost()
	_hide_item_preview()


func _show_item_preview(key: String, texture: Texture2D, pos: Vector2, parent: Node) -> void:
	_ensure_item_preview()
	if parent != null and _item_preview.get_parent() != parent:
		_item_preview.reparent(parent, false)
	_item_preview_key = key
	_item_preview.texture = texture
	_item_preview.position = pos
	_item_preview.show()
	_kill_item_preview_tween()
	if _item_preview_suppress_pop:
		_item_preview_suppress_pop = false
		_item_preview.scale = Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE)
		return
	_item_preview.scale = Vector2(0.05, 0.05)
	_item_preview_tween = create_tween()
	_item_preview_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_item_preview_tween.set_trans(Tween.TRANS_CUBIC)
	_item_preview_tween.set_ease(Tween.EASE_OUT)
	_item_preview_tween.tween_property(
		_item_preview, "scale", Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE), ITEM_PREVIEW_POP_TIME
	)


func _await_item_preview_pop() -> void:
	if _item_preview_tween != null and is_instance_valid(_item_preview_tween):
		await _item_preview_tween.finished


func _refresh_item_preview() -> void:
	_ensure_item_preview()
	# También con objeto en mano: ver el del mon bajo el cursor (p. ej. antes de CAMBIO).
	if _hand_state != HandState.IDLE and _hand_state != HandState.HOLDING:
		_hide_item_preview()
		return
	if _party_open and (_party_sel < 0 or _party_sel >= PARTY_SLOT_COUNT):
		_dismiss_item_preview_animated()
		return
	if not _party_open and _cursor_index < 0:
		_dismiss_item_preview_animated()
		return
	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null or mon.held_item_id <= 0 or DatabaseService == null:
		_dismiss_item_preview_animated()
		return
	var item: ItemData = DatabaseService.get_item_by_id(mon.held_item_id)
	if item == null or item.icon == null:
		_dismiss_item_preview_animated()
		return

	var parent: Node = _party_panel if _party_open else _slots_root
	if parent == null:
		parent = _box_panel
	var key := ("%s:%d:%d" % ["p" if _party_open else "b",
		_party_sel if _party_open else _cursor_index, mon.held_item_id])
	var pos := _item_preview_anchor()

	if key == _item_preview_key and _item_preview.visible:
		# Mismo foco: si no hay tween, fijar pos.
		if _item_preview_tween == null or not is_instance_valid(_item_preview_tween):
			_item_preview.position = pos
		return

	# Otro slot: dejar el icono anterior encogiendo en su sitio y pop en el nuevo.
	# (sin deslizar el sprite con el cursor)
	if _item_preview.visible and not _item_preview_key.is_empty() and not _item_preview_suppress_pop:
		_spawn_item_preview_shrink_ghost()
		_hide_item_preview()

	_show_item_preview(key, item.icon, pos, parent)


func _kill_cursor_slide_tween() -> void:
	if _cursor_slide_tween != null and is_instance_valid(_cursor_slide_tween):
		_cursor_slide_tween.kill()
	_cursor_slide_tween = null


func _update_cursor_visual(animate: bool = true) -> void:
	if _cursor == null:
		return
	if _hand_state == HandState.GRABBING or _hand_state == HandState.RELEASING:
		# Posición animada en _process_grab / _process_release.
		_kill_cursor_slide_tween()
		_update_cursor_frame()
		_cursor.show()
		_refresh_item_preview()
		return
	var rest := _cursor_rest_position()
	_update_cursor_frame()
	_cursor.show()
	var need_slide := (
		animate
		and _cursor.visible
		and _cursor.position.distance_squared_to(rest) > 0.25
	)
	if need_slide:
		_kill_cursor_slide_tween()
		_cursor_slide_tween = create_tween()
		_cursor_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_cursor_slide_tween.set_trans(Tween.TRANS_SINE)
		_cursor_slide_tween.set_ease(Tween.EASE_IN_OUT)
		_cursor_slide_tween.tween_property(_cursor, "position", rest, CURSOR_SLIDE_TIME)
		# Con HOLDING, _process sincroniza el held al cursor cada frame.
	else:
		_kill_cursor_slide_tween()
		_cursor.position = rest
		if _hand_state == HandState.HOLDING:
			_sync_held_to_cursor()
	_refresh_item_preview()


func _update_cursor_frame() -> void:
	if _cursor == null:
		return
	match _hand_state:
		HandState.HOLDING:
			_cursor.texture = CURSOR_FIST
		HandState.GRABBING, HandState.RELEASING:
			pass  # Textura en el process de animación.
		HandState.IDLE:
			var use_point2 := int(_cursor_anim_t / CURSOR_ANIM_PERIOD) % 2 == 1
			_cursor.texture = CURSOR_POINT_2 if use_point2 else CURSOR_POINT_1


func _play_cursor_sound() -> void:
	AudioManager.play_ui_cursor()


func _sync_held_to_cursor() -> void:
	if _held_sprite == null or not _held_sprite.visible or _cursor == null:
		return
	_held_sprite.position = _item_hold_hand_pos() if _held_item_id > 0 else (_cursor.position + HELD_ICON_FROM_CURSOR)


func _item_hold_hand_pos() -> Vector2:
	if _cursor == null:
		return Vector2.ZERO
	return _cursor.position + HELD_ICON_FROM_CURSOR + Vector2(0, 4)


func _process_grab(delta: float) -> void:
	_grab_elapsed += delta
	var is_item := _held_item_id > 0
	var travel := ITEM_HAND_TRAVEL if is_item else GRAB_TIME
	var half := travel * 0.5
	var rest := _cursor_rest_position()
	var origin_pos := _held_origin_hand_pos()
	if _grab_elapsed <= half:
		# Baja con mano abierta; el icono sigue en el slot (ya oculto → held fijo abajo).
		var t := clampf(_grab_elapsed / half, 0.0, 1.0)
		_cursor.texture = CURSOR_GRAB
		_cursor.position = rest + Vector2(0.0, GRAB_DIP_PX * t)
		if _held_sprite:
			if is_item:
				_update_item_grab_visual(origin_pos, travel)
			else:
				_held_sprite.position = origin_pos
	else:
		# Puño y sube; el ítem sigue interpolando hacia la mano (sin teleport).
		var t2 := clampf((_grab_elapsed - half) / half, 0.0, 1.0)
		_cursor.texture = CURSOR_FIST
		_cursor.position = rest + Vector2(0.0, GRAB_DIP_PX * (1.0 - t2))
		if _held_sprite:
			if is_item:
				_update_item_grab_visual(origin_pos, travel)
			else:
				_sync_held_to_cursor()
		if t2 >= 1.0:
			_hand_state = HandState.HOLDING
			_set_close_button_holding(true)
			_cursor.position = rest
			_cursor.texture = CURSOR_FIST
			if is_item and _held_sprite:
				_held_sprite.scale = Vector2(ITEM_HELD_SCALE, ITEM_HELD_SCALE)
			_sync_held_to_cursor()


func _update_item_grab_visual(origin_pos: Vector2, travel: float) -> void:
	if _held_sprite == null:
		return
	var t_all := clampf(_grab_elapsed / travel, 0.0, 1.0)
	_held_sprite.position = origin_pos.lerp(_item_hold_hand_pos(), t_all)
	var s := lerpf(ITEM_PREVIEW_SCALE, ITEM_HELD_SCALE, t_all)
	_held_sprite.scale = Vector2(s, s)


func _hand_parent() -> Node:
	if _cursor != null and is_instance_valid(_cursor):
		return _cursor.get_parent()
	return _box_panel


func _to_hand_local(global_pos: Vector2) -> Vector2:
	var parent := _hand_parent()
	if parent is CanvasItem:
		return (parent as CanvasItem).get_global_transform_with_canvas().affine_inverse() * global_pos
	return global_pos


func _box_slot_hand_pos(slot: int) -> Vector2:
	var local := _slot_center(slot)
	if _hand_parent() == _box_panel:
		return local
	if _box_panel == null:
		return local
	var g: Vector2 = _box_panel.get_global_transform_with_canvas() * local
	return _to_hand_local(g)


func _party_slot_hand_pos(slot: int) -> Vector2:
	var idx := clampi(slot, 0, PARTY_SLOT_COUNT - 1)
	var local: Vector2 = PARTY_ICON_POS[idx]
	if _hand_parent() == _party_panel:
		return local
	if _party_panel == null:
		return local
	var g: Vector2 = _party_panel.get_global_transform_with_canvas() * local
	return _to_hand_local(g)


func _held_origin_hand_pos() -> Vector2:
	if _held_item_id > 0:
		return _item_held_origin_hand_pos()
	if _held_from_party:
		return _party_slot_hand_pos(_held_from_slot)
	return _box_slot_hand_pos(_held_from_slot)


func _item_held_origin_hand_pos() -> Vector2:
	return _item_slot_to_hand_pos(_held_from_slot, _held_from_party)


func _item_slot_to_hand_pos(slot: int, from_party: bool) -> Vector2:
	var local := _item_anchor_for_slot(slot, from_party)
	if from_party:
		if _hand_parent() == _party_panel:
			return local
		if _party_panel == null:
			return local
		var g: Vector2 = _party_panel.get_global_transform_with_canvas() * local
		return _to_hand_local(g)
	if _hand_parent() == _box_panel:
		return local
	if _box_panel == null:
		return local
	var g2: Vector2 = _box_panel.get_global_transform_with_canvas() * local
	return _to_hand_local(g2)


func _item_anchor_for_slot(slot: int, from_party: bool) -> Vector2:
	if from_party:
		var idx := clampi(slot, 0, PARTY_SLOT_COUNT - 1)
		return PARTY_ICON_POS[idx] + ITEM_PREVIEW_OFFSET
	if slot >= 0:
		return _slot_center(slot) + ITEM_PREVIEW_OFFSET
	return Vector2.ZERO


func _try_start_release() -> void:
	if _held_item_id > 0:
		await _confirm_put_held_item_in_bag()
		return
	# Cancel: suelta de vuelta al slot origen (vuelve a su caja si hace falta).
	if not _held_from_party and _held_from_box >= 0 and _held_from_box != _box_index:
		_box_index = _held_from_box
		refresh()
	_start_release(_held_from_slot, false, _held_from_party)


## Holding un objeto + cancelar: preguntar si va a la mochila (no vuelve al mon).
func _confirm_put_held_item_in_bag() -> void:
	if _held_item_id <= 0 or _hand_state != HandState.HOLDING:
		return
	_input_enabled = false
	await DisplayManager.show_message("¿Colocar en la MOCHILA?", {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	DisplayManager.hide_message_wait_indicator()

	var dm := DisplayManager.instance
	if dm != null and dm.choice_box != null:
		dm.choice_box.set_next_initial_index(1)  # No
	var choice: int = await DisplayManager.show_choices_corner(
		["Sí", "No"],
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	DisplayManager.close_message()

	if not visible:
		return
	if choice != 0:
		_input_enabled = true
		return

	await _put_held_item_in_bag()
	if visible:
		_input_enabled = true


func _put_held_item_in_bag() -> void:
	if _held_item_id <= 0 or GameStateService == null:
		return
	var bag = GameStateService.get_bag()
	if bag == null or DatabaseService == null:
		return
	var item_id := _held_item_id
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		return
	# Capacidad del bolsillo/stack antes de animar.
	var stack_limit := int(item_data.stack_limit)
	if stack_limit > 0 and bag.get_quantity(item_id) >= stack_limit:
		return

	# Congelar sync de mano mientras el icono se encoge.
	_hand_state = HandState.IDLE
	if _cursor != null:
		_cursor.texture = CURSOR_GRAB
	await _animate_release_shrink(_held_sprite, ITEM_BAG_SHRINK_TIME)
	if not visible:
		return

	# add_item coloca el objeto en el bolsillo que indica ItemData.pocket.
	if bag.add_item(item_id, 1) <= 0:
		_held_item_id = item_id
		_hand_state = HandState.HOLDING
		if _held_sprite != null and item_data.icon != null:
			_held_sprite.texture = item_data.icon
			_held_sprite.hframes = 1
			_held_sprite.frame = 0
			_held_sprite.scale = Vector2(ITEM_HELD_SCALE, ITEM_HELD_SCALE)
			_held_sprite.show()
			_sync_held_to_cursor()
		if _cursor != null:
			_cursor.texture = CURSOR_FIST
		return

	_held_item_id = 0
	_release_held_visual(false)
	refresh()
	_update_cursor_visual()
	_refresh_info_panel()


## Holding desde party + panel cerrado: B / CANCELAR reabre el party (no suelta).
func _return_held_to_party_panel() -> void:
	if _hand_state != HandState.HOLDING or not _held_from_party:
		return
	if _party_open:
		return
	_input_enabled = false
	await _open_party_panel(false, false, PARTY_SLIDE_TIME, false, false)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return
	_party_sel = 0
	_attach_hand_keep_global(_party_panel)
	await _animate_hand_to(_party_arrow_position(_party_sel), PARTY_EDGE_HAND_TRAVEL)
	if not visible:
		return
	_update_cursor_visual()
	_refresh_info_panel()
	_input_enabled = true


## Holding desde box + party abierto: B / CANCELAR vuelve al box (no suelta).
func _return_held_to_box_panel() -> void:
	if _hand_state != HandState.HOLDING or _held_from_party:
		return
	if not _party_open:
		return
	_input_enabled = false
	var dest_box: int = _held_from_box if _held_from_box >= 0 else _box_index
	var dest_slot: int = _held_from_slot if _held_from_slot >= 0 else 0
	await _close_party_panel(false, dest_slot, PARTY_SLIDE_TIME, false, false)
	if not visible:
		return
	if dest_box != _box_index:
		_box_index = dest_box
		refresh()
	_cursor_index = dest_slot
	await _animate_hand_to(_cursor_rest_position(dest_slot), PARTY_EDGE_HAND_TRAVEL)
	if not visible:
		return
	_update_cursor_visual()
	_refresh_info_panel()
	_input_enabled = true


func _try_start_place() -> void:
	if _hand_state != HandState.HOLDING:
		return
	if _held_item_id > 0:
		await _open_held_item_place_menu()
		return
	if _party_open:
		if _party_sel == SEL_PARTY_EXIT:
			if _held_from_party:
				await _try_start_release()
			else:
				await _return_held_to_box_panel()
			return
		if _held_from_party and _party_sel == _held_from_slot:
			_start_release(_held_from_slot, false, true)
			return
		_start_release(_party_sel, true, true)
		return
	if _cursor_index == SEL_CLOSE:
		if _held_from_party:
			await _return_held_to_party_panel()
		else:
			await _try_start_release()
		return
	if _cursor_index < 0:
		# No se coloca en Equipo/nombre de caja.
		return
	if not _held_from_party and _cursor_index == _held_from_slot and _held_from_box == _box_index:
		_start_release(_held_from_slot, false, false)
		return
	_start_release(_cursor_index, true, false)


func _start_release(target_slot: int, commit_move: bool, to_party: bool) -> void:
	if _hand_state != HandState.HOLDING:
		return
	_play_cursor_sound()
	_release_origin_slot = _held_from_slot
	_release_origin_was_party = _held_from_party
	_release_origin_box = _held_from_box if not _held_from_party else -1
	_release_target_slot = target_slot
	_release_to_party = to_party
	var same_slot := (
		_release_origin_was_party == to_party
		and target_slot == _held_from_slot
		and (to_party or _release_origin_box == _box_index)
	)
	_release_commit_move = commit_move and not same_slot
	_release_held_from = _held_sprite.position if _held_sprite else _held_origin_hand_pos()
	_grab_elapsed = 0.0

	_hide_swap_sprite()
	if _release_commit_move and GameStateService != null:
		var dest_mon: Pokemon = null
		if to_party:
			var party: Party = GameStateService.get_party()
			dest_mon = party.get_pokemon(target_slot) if party else null
			if dest_mon != null:
				_ensure_swap_sprite()
				if _party_panel and _swap_sprite.get_parent() != _party_panel:
					_swap_sprite.reparent(_party_panel, false)
					_swap_sprite.z_index = 8
				_swap_sprite.texture = dest_mon.get_icon_sprite()
				_swap_sprite.hframes = 2
				_swap_sprite.frame = 0
				_release_swap_from = _party_slot_hand_pos(target_slot)
				_swap_sprite.position = _release_swap_from
				_swap_sprite.show()
				if target_slot < _party_slot_sprites.size() and _party_slot_sprites[target_slot]:
					_party_slot_sprites[target_slot].hide()
		else:
			var storage: PCStorage = GameStateService.get_pc_storage()
			dest_mon = storage.get_pokemon(_box_index, target_slot) if storage else null
			if dest_mon != null:
				_ensure_swap_sprite()
				if _box_panel and _swap_sprite.get_parent() != _box_panel:
					_swap_sprite.reparent(_box_panel, false)
					_swap_sprite.z_index = 8
				_swap_sprite.texture = dest_mon.get_icon_sprite()
				_swap_sprite.hframes = 2
				_swap_sprite.frame = 0
				_release_swap_from = _box_slot_hand_pos(target_slot)
				_swap_sprite.position = _release_swap_from
				_swap_sprite.show()
				if target_slot < _slot_sprites.size() and _slot_sprites[target_slot]:
					_slot_sprites[target_slot].hide()

	# El icono de objeto del destino se va con el mon (no al terminar el swap).
	_hide_item_preview()
	_hand_state = HandState.RELEASING
	if _cursor:
		_cursor.texture = CURSOR_GRAB
		_cursor.position = _cursor_rest_position()


func _process_release(delta: float) -> void:
	if _item_releasing:
		_process_item_release(delta)
		return
	_grab_elapsed += delta
	var t := clampf(_grab_elapsed / GRAB_TIME, 0.0, 1.0)
	var held_target: Vector2
	if _release_to_party:
		held_target = _party_slot_hand_pos(_release_target_slot)
	else:
		held_target = _box_slot_hand_pos(_release_target_slot)
	if _cursor:
		_cursor.texture = CURSOR_GRAB
		_cursor.position = _cursor_rest_position()
	if _held_sprite:
		_held_sprite.position = _release_held_from.lerp(held_target, t)
	if _swap_sprite != null and _swap_sprite.visible:
		var swap_target: Vector2
		if _release_origin_was_party:
			swap_target = _party_slot_hand_pos(_release_origin_slot)
		else:
			swap_target = _box_slot_hand_pos(_release_origin_slot)
		_swap_sprite.position = _release_swap_from.lerp(swap_target, t)
	if t >= 1.0:
		_finish_release()


func _process_item_release(delta: float) -> void:
	var is_swap := _item_release_prev_id > 0
	var travel := ITEM_SWAP_TRAVEL if is_swap else ITEM_HAND_TRAVEL
	_grab_elapsed += delta
	var t := clampf(_grab_elapsed / travel, 0.0, 1.0)
	if _cursor:
		_cursor.texture = CURSOR_GRAB
		_cursor.position = _cursor_rest_position()
	if _held_sprite:
		if is_swap:
			_held_sprite.position = _arc_lerp_ccw(_release_held_from, _item_release_slot_to, t)
			var s_held := lerpf(ITEM_HELD_SCALE, ITEM_PREVIEW_SCALE, t)
			_held_sprite.scale = Vector2(s_held, s_held)
		else:
			_held_sprite.position = _release_held_from.lerp(_item_release_slot_to, t)
			var s := lerpf(ITEM_HELD_SCALE, ITEM_PREVIEW_SCALE, t)
			_held_sprite.scale = Vector2(s, s)
	if is_swap and _swap_sprite != null and _swap_sprite.visible:
		_swap_sprite.position = _arc_lerp_ccw(_release_swap_from, _item_release_hand_to, t)
		var s_swap := lerpf(ITEM_PREVIEW_SCALE, ITEM_HELD_SCALE, t)
		_swap_sprite.scale = Vector2(s_swap, s_swap)
	if t >= 1.0:
		_finish_item_release()


## Media vuelta antihoraria alrededor del punto medio (y-down → ángulo negativo).
func _arc_lerp_ccw(from: Vector2, to: Vector2, t: float) -> Vector2:
	var center := (from + to) * 0.5
	var rel := from - center
	if rel.length_squared() < 0.0001:
		return from.lerp(to, t)
	return center + rel.rotated(-PI * clampf(t, 0.0, 1.0))


func _finish_release() -> void:
	if _release_commit_move:
		_commit_held_move()

	_hand_state = HandState.IDLE
	_grab_elapsed = 0.0
	_held_from_slot = -1
	_held_from_party = false
	_held_from_box = -1
	_held_item_id = 0
	_release_origin_slot = -1
	_release_target_slot = -1
	_release_origin_was_party = false
	_release_origin_box = -1
	_release_to_party = false
	_release_commit_move = false
	if _held_sprite:
		_held_sprite.hide()
		_held_sprite.texture = null
		_held_sprite.hframes = 2
		_held_sprite.scale = Vector2.ONE
	_hide_swap_sprite()
	_set_close_button_holding(false)
	refresh()
	_update_cursor_visual()
	_refresh_info_panel()


func _commit_held_move() -> void:
	if GameStateService == null:
		return
	var storage: PCStorage = GameStateService.get_pc_storage()
	var party: Party = GameStateService.get_party()
	var from_s := _release_origin_slot
	var to_s := _release_target_slot
	var from_party := _release_origin_was_party
	var to_party := _release_to_party
	var from_box := _release_origin_box if _release_origin_box >= 0 else _box_index

	if not from_party and not to_party:
		if storage != null:
			storage.move_pokemon(from_box, from_s, _box_index, to_s)
		return

	if not from_party and to_party:
		# Caja → party (depositar / intercambiar).
		if storage == null or party == null:
			return
		var dest: Pokemon = party.get_pokemon(to_s)
		var held: Pokemon = storage.remove_pokemon(from_box, from_s)
		if held == null:
			return
		if dest == null:
			if not party.add_pokemon(held):
				storage.set_pokemon(from_box, from_s, held)
		else:
			var prev: Pokemon = party.replace_pokemon(to_s, held)
			if prev != null:
				storage.set_pokemon(from_box, from_s, prev)
		return

	if from_party and not to_party:
		# Party → caja.
		if storage == null or party == null:
			return
		var dest2: Pokemon = storage.get_pokemon(_box_index, to_s)
		var held2: Pokemon = party.get_pokemon(from_s)
		if held2 == null:
			return
		if dest2 == null:
			var mon: Pokemon = party.remove_pokemon(from_s)
			if mon != null:
				storage.set_pokemon(_box_index, to_s, mon)
		else:
			var box_mon: Pokemon = storage.remove_pokemon(_box_index, to_s)
			party.replace_pokemon(from_s, box_mon)
			storage.set_pokemon(_box_index, to_s, held2)
		return

	# Party → party.
	if party != null:
		party.swap_slots(from_s, to_s)


func _hide_swap_sprite() -> void:
	if _swap_sprite == null:
		return
	_swap_sprite.hide()
	_swap_sprite.texture = null


func _try_start_grab() -> void:
	if _hand_state != HandState.IDLE:
		return
	if _held_item_id > 0:
		return
	var mon := _get_cursor_pokemon()
	if mon == null:
		return
	_ensure_held_sprite()
	_held_item_id = 0
	_held_from_party = _party_open
	if _held_from_party:
		_held_from_slot = _party_sel
		_held_from_box = -1
		if _party_panel and _held_sprite.get_parent() != _party_panel:
			_held_sprite.reparent(_party_panel, false)
			_held_sprite.z_index = 9
		_held_sprite.texture = mon.get_icon_sprite()
		_held_sprite.hframes = 2
		_held_sprite.frame = 0
		_held_sprite.scale = Vector2.ONE
		_held_sprite.position = _party_slot_hand_pos(_held_from_slot)
		_held_sprite.show()
		if _held_from_slot < _party_slot_sprites.size() and _party_slot_sprites[_held_from_slot]:
			_party_slot_sprites[_held_from_slot].hide()
	else:
		_held_from_slot = _cursor_index
		_held_from_box = _box_index
		if _box_panel and _held_sprite.get_parent() != _box_panel:
			_held_sprite.reparent(_box_panel, false)
			_held_sprite.z_index = 9
		var slot_spr: Sprite2D = _slot_sprites[_cursor_index] if _cursor_index < _slot_sprites.size() else null
		_held_sprite.texture = mon.get_icon_sprite()
		_held_sprite.hframes = 2
		_held_sprite.frame = 0
		_held_sprite.scale = Vector2.ONE
		_held_sprite.position = _slot_center(_held_from_slot)
		_held_sprite.show()
		if slot_spr:
			slot_spr.hide()
	_grab_elapsed = 0.0
	_hand_state = HandState.GRABBING
	_cursor.texture = CURSOR_GRAB
	_hide_item_preview()
	_refresh_info_panel()
	_play_cursor_sound()


## MOVER OBJETOS → QUITAR: agarra el icono del item (el mon permanece).
func _try_start_take_item() -> void:
	if _hand_state != HandState.IDLE or _mode != Mode.MOVE_ITEMS:
		return
	var mon := _get_cursor_pokemon()
	if mon == null or mon.held_item_id <= 0 or DatabaseService == null:
		return
	var item: ItemData = DatabaseService.get_item_by_id(mon.held_item_id)
	if item == null or item.icon == null:
		return

	_ensure_held_sprite()
	_hide_item_preview()
	_held_item_id = mon.held_item_id
	_held_from_party = _party_open
	if _held_from_party:
		_held_from_slot = _party_sel
		_held_from_box = -1
		if _party_panel and _held_sprite.get_parent() != _party_panel:
			_held_sprite.reparent(_party_panel, false)
			_held_sprite.z_index = 9
	else:
		_held_from_slot = _cursor_index
		_held_from_box = _box_index
		if _box_panel and _held_sprite.get_parent() != _box_panel:
			_held_sprite.reparent(_box_panel, false)
			_held_sprite.z_index = 9

	# Quitar el objeto del mon al iniciar el agarre.
	mon.held_item_id = 0
	refresh()

	_held_sprite.texture = item.icon
	_held_sprite.hframes = 1
	_held_sprite.frame = 0
	_held_sprite.scale = Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE)
	_held_sprite.position = _item_held_origin_hand_pos()
	_held_sprite.show()

	_grab_elapsed = 0.0
	_hand_state = HandState.GRABBING
	_cursor.texture = CURSOR_GRAB
	_refresh_info_panel()


func _cancel_held_item() -> void:
	if _held_item_id <= 0:
		return
	var mon := _get_held_source_pokemon()
	if mon != null:
		mon.held_item_id = _held_item_id
	_release_held_visual(true)
	refresh()
	_update_cursor_visual()
	_refresh_info_panel()


func _get_held_source_pokemon() -> Pokemon:
	if _held_from_slot < 0 or GameStateService == null:
		return null
	if _held_from_party:
		var party: Party = GameStateService.get_party()
		if party == null:
			return null
		return party.get_pokemon(_held_from_slot)
	var storage: PCStorage = GameStateService.get_pc_storage()
	if storage == null:
		return null
	var from_box := _held_from_box if _held_from_box >= 0 else _box_index
	return storage.get_pokemon(from_box, _held_from_slot)


func _try_place_held_item() -> void:
	if _hand_state != HandState.HOLDING or _held_item_id <= 0:
		return
	var target: Pokemon = _get_cursor_pokemon()
	if target == null:
		return
	# Mismo mon origen: devolver (cancel visual).
	var source := _get_held_source_pokemon()
	if target == source:
		_cancel_held_item()
		return
	_start_item_release(target)


func _start_item_release(target: Pokemon) -> void:
	if target == null or _held_sprite == null:
		return
	_item_releasing = true
	_item_place_target = target
	_item_release_prev_id = target.held_item_id
	_release_target_slot = _party_sel if _party_open else _cursor_index
	_release_to_party = _party_open
	_release_held_from = _held_sprite.position
	_item_release_slot_to = _item_slot_to_hand_pos(_release_target_slot, _release_to_party)
	_item_release_hand_to = _item_hold_hand_pos()
	_grab_elapsed = 0.0
	_hand_state = HandState.RELEASING
	_hide_item_preview()
	_hide_swap_sprite()

	# CAMBIO: el objeto del slot sale a la vez hacia la mano (arco antihorario).
	if _item_release_prev_id > 0 and DatabaseService != null:
		var other: ItemData = DatabaseService.get_item_by_id(_item_release_prev_id)
		if other != null and other.icon != null:
			_ensure_swap_sprite()
			var parent := _held_sprite.get_parent()
			if parent != null and _swap_sprite.get_parent() != parent:
				_swap_sprite.reparent(parent, false)
			_swap_sprite.z_index = 8
			_swap_sprite.texture = other.icon
			_swap_sprite.hframes = 1
			_swap_sprite.frame = 0
			_swap_sprite.scale = Vector2(ITEM_PREVIEW_SCALE, ITEM_PREVIEW_SCALE)
			_release_swap_from = _item_release_slot_to
			_swap_sprite.position = _release_swap_from
			_swap_sprite.show()
			_held_sprite.z_index = 9

	if _cursor:
		_cursor.texture = CURSOR_GRAB
		_cursor.position = _cursor_rest_position()


func _finish_item_release() -> void:
	var target: Pokemon = _item_place_target
	var giving_id := _held_item_id
	var prev_id := _item_release_prev_id
	_item_releasing = false
	_item_place_target = null
	_item_release_prev_id = 0
	_grab_elapsed = 0.0

	if target != null and giving_id > 0:
		target.held_item_id = giving_id

	if prev_id > 0:
		# CAMBIO: el icono del swap ya está en la mano; asumir su sitio.
		_held_item_id = prev_id
		_hand_state = HandState.HOLDING
		if _held_sprite != null:
			if DatabaseService != null:
				var item: ItemData = DatabaseService.get_item_by_id(prev_id)
				if item != null and item.icon != null:
					_held_sprite.texture = item.icon
			_held_sprite.hframes = 1
			_held_sprite.frame = 0
			_held_sprite.scale = Vector2(ITEM_HELD_SCALE, ITEM_HELD_SCALE)
			_held_sprite.z_index = 9
			_held_sprite.position = _item_release_hand_to
			_held_sprite.show()
		_hide_swap_sprite()
		_sync_held_to_cursor()
		if _cursor:
			_cursor.texture = CURSOR_FIST
		_item_preview_suppress_pop = true
		refresh()
		_refresh_info_panel()
		_refresh_item_preview()
		return

	_hide_swap_sprite()
	# DAR: soltar la mano.
	_held_item_id = 0
	_hand_state = HandState.IDLE
	_held_from_slot = -1
	_held_from_party = false
	_held_from_box = -1
	_set_close_button_holding(false)
	if _held_sprite:
		_held_sprite.hide()
		_held_sprite.texture = null
		_held_sprite.hframes = 2
		_held_sprite.scale = Vector2.ONE
	_item_preview_suppress_pop = true
	refresh()
	_update_cursor_visual()
	_refresh_info_panel()


func _release_held_visual(restore_to_slot: bool) -> void:
	var from := _held_from_slot
	var from_party := _held_from_party
	_hand_state = HandState.IDLE
	_grab_elapsed = 0.0
	_held_from_slot = -1
	_held_from_party = false
	_held_from_box = -1
	_held_item_id = 0
	_release_origin_slot = -1
	_release_target_slot = -1
	_release_origin_was_party = false
	_release_origin_box = -1
	_release_to_party = false
	_release_commit_move = false
	_item_releasing = false
	_item_place_target = null
	_item_release_prev_id = 0
	_kill_cursor_slide_tween()
	if _held_sprite:
		_held_sprite.hide()
		_held_sprite.texture = null
		_held_sprite.hframes = 2
		_held_sprite.scale = Vector2.ONE
	_hide_swap_sprite()
	_set_close_button_holding(false)
	if restore_to_slot and from >= 0:
		if from_party or from < _slot_sprites.size():
			refresh()
	_update_cursor_frame()


func _move_cursor(dx: int, dy: int) -> void:
	if _hand_state == HandState.GRABBING or _hand_state == HandState.RELEASING:
		return
	if _box_sliding:
		return
	# Sin diagonales aunque lleguen ambos ejes.
	if dx != 0 and dy != 0:
		dx = 0
	if _marks_open:
		_move_marks_cursor(dx, dy)
		return
	if _choose_open:
		if dx != 0:
			_move_choose_box(dx)
		return
	if _wallpaper_edit_open:
		if dx != 0:
			_move_wallpaper_edit(dx)
		return
	if _party_open:
		_move_party_cursor(dx, dy)
		return
	var prev_sel := _cursor_index
	var sel := _cursor_index
	if dy < 0:
		# UP
		match sel:
			SEL_BOX_NAME:
				sel = SEL_PARTY
			SEL_PARTY:
				sel = SLOT_COUNT - 1 - int((COLS * 2) / 3)  # 25
			SEL_CLOSE:
				sel = SLOT_COUNT - int(COLS / 3)  # 28
			_:
				sel -= COLS
				if sel < 0:
					sel = SEL_BOX_NAME
	elif dy > 0:
		# DOWN
		match sel:
			SEL_BOX_NAME:
				sel = int(COLS / 3)  # 2
			SEL_PARTY, SEL_CLOSE:
				sel = SEL_BOX_NAME
			_:
				sel += COLS
				if sel >= SLOT_COUNT:
					if sel < SLOT_COUNT + int(COLS / 2):
						sel = SEL_PARTY
					else:
						sel = SEL_CLOSE
	if dx != 0:
		match sel:
			SEL_BOX_NAME:
				await _shift_box(dx)
			SEL_PARTY:
				sel = SEL_CLOSE
			SEL_CLOSE:
				sel = SEL_PARTY
			_:
				if sel >= 0:
					var col: int = sel % COLS
					var row: int = int(sel / COLS)
					col = posmod(col + dx, COLS)
					sel = row * COLS + col
	_cursor_index = sel
	_update_cursor_visual()
	_refresh_info_panel()
	if _cursor_index != prev_sel:
		_play_cursor_sound()


func _shift_box(dx: int) -> void:
	if dx == 0 or _box_sliding:
		return
	var count: int = _box_count()
	if count <= 1:
		return
	var new_index: int = posmod(_box_index + dx, count)
	if new_index == _box_index:
		return
	_play_cursor_sound()
	await _animate_box_change(new_index, dx)


## Salto a una caja concreta; `slide_dir` >0 derecha, <0 izquierda.
func _jump_to_box(target_index: int, slide_dir: int) -> void:
	if _box_sliding:
		return
	var count := _box_count()
	if count <= 1:
		return
	target_index = posmod(target_index, count)
	if target_index == _box_index:
		return
	if slide_dir == 0:
		slide_dir = 1 if target_index > _box_index else -1
	await _animate_box_change(target_index, slide_dir)


func _animate_box_change(new_index: int, slide_dir: int) -> void:
	if slide_dir == 0 or _box_sliding:
		return
	if _box_panel == null:
		_box_index = new_index
		refresh()
		return

	_setup_box_clip()
	_box_sliding = true
	_input_enabled = false
	_hide_item_preview()
	_kill_box_slide_tween()
	_kill_cursor_slide_tween()
	_reset_cursor_hold_repeat()
	_nudge_box_name_arrow(slide_dir)

	# Clip solo durante el slide; mano en PCStorageUI para no recortarla.
	if _box_clip:
		_box_clip.clip_contents = true
	_attach_hand_keep_global(self)
	# Fijar la mano en el chrome de nombre (coords del PCStorageUI) para que no viaje con el panel.
	if _cursor != null and _box_panel != null:
		var name_local := _cursor_rest_position(SEL_BOX_NAME)
		var g: Vector2 = _box_panel.get_global_transform_with_canvas() * name_local
		_cursor.global_position = g
		if _hand_state == HandState.HOLDING:
			_sync_held_to_cursor()

	var width: float = maxf(_box_panel.size.x, _box_panel.custom_minimum_size.x)
	if width <= 0.0 and _box_clip:
		width = _box_clip.size.x
	if width <= 0.0:
		width = 324.0
	# slide_dir > 0 (caja derecha): actual sale a la izq, nueva entra desde la der.
	var slide_sign: float = -1.0 if slide_dir > 0 else 1.0

	var outgoing: Panel = _box_panel.duplicate() as Panel
	if _box_clip:
		_box_clip.add_child(outgoing)
	else:
		add_child(outgoing)
	outgoing.position = Vector2.ZERO
	outgoing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child_name in ["Cursor", "HeldIcon", "SwapIcon", "ItemPreview", "ArrowL", "ArrowR"]:
		var n: Node = outgoing.get_node_or_null(child_name)
		if n is CanvasItem:
			(n as CanvasItem).hide()

	_box_index = new_index
	refresh()
	_box_panel.position = Vector2(-slide_sign * width, 0.0)
	_box_panel.move_to_front()
	_raise_box_arrows()

	_box_slide_tween = create_tween()
	_box_slide_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_box_slide_tween.set_parallel(true)
	_box_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_box_slide_tween.set_ease(Tween.EASE_IN_OUT)
	_box_slide_tween.tween_property(outgoing, "position:x", slide_sign * width, BOX_SLIDE_TIME)
	_box_slide_tween.tween_property(_box_panel, "position:x", 0.0, BOX_SLIDE_TIME)
	await _box_slide_tween.finished
	_box_slide_tween = null

	if is_instance_valid(outgoing):
		outgoing.queue_free()
	if _box_panel:
		_box_panel.position = Vector2.ZERO
		# Mantener posición global al volver al panel (evita el “salto” desde la derecha).
		_attach_hand_keep_global(_box_panel)
	if _box_clip:
		_box_clip.clip_contents = false
	_box_sliding = false
	if not _wallpaper_edit_open:
		_reset_box_arrows_to_rest()
	if visible and not _in_summary:
		_input_enabled = true
		_update_cursor_visual(false)
		_refresh_info_panel()


func _move_party_cursor(dx: int, dy: int) -> void:
	var prev := _party_sel
	var sel := _party_sel
	if sel == SEL_PARTY_EXIT:
		if dy < 0:
			# Sube al último par de slots (columna según dx o izquierda).
			sel = 4 if dx <= 0 else 5
		elif dx != 0:
			pass
	else:
		var col: int = sel % 2
		var row: int = int(sel / 2)
		if dx != 0:
			col = clampi(col + dx, 0, 1)
			sel = row * 2 + col
		if dy > 0:
			if row >= 2:
				sel = SEL_PARTY_EXIT
			else:
				sel = (row + 1) * 2 + col
		elif dy < 0:
			if row > 0:
				sel = (row - 1) * 2 + col
	_party_sel = sel
	_update_cursor_visual()
	_refresh_info_panel()
	if _party_sel != prev:
		_play_cursor_sound()


func _connect_input(enabled: bool) -> void:
	var dm := DisplayManager.instance
	if dm == null:
		return
	if enabled:
		if not dm.input_cancel.is_connected(_on_input_cancel):
			dm.input_cancel.connect(_on_input_cancel)
		if not dm.input_accept.is_connected(_on_input_accept):
			dm.input_accept.connect(_on_input_accept)
		if not dm.input_up.is_connected(_on_input_up):
			dm.input_up.connect(_on_input_up)
		if not dm.input_down.is_connected(_on_input_down):
			dm.input_down.connect(_on_input_down)
		if not dm.input_left.is_connected(_on_input_left):
			dm.input_left.connect(_on_input_left)
		if not dm.input_right.is_connected(_on_input_right):
			dm.input_right.connect(_on_input_right)
	else:
		if dm.input_cancel.is_connected(_on_input_cancel):
			dm.input_cancel.disconnect(_on_input_cancel)
		if dm.input_accept.is_connected(_on_input_accept):
			dm.input_accept.disconnect(_on_input_accept)
		if dm.input_up.is_connected(_on_input_up):
			dm.input_up.disconnect(_on_input_up)
		if dm.input_down.is_connected(_on_input_down):
			dm.input_down.disconnect(_on_input_down)
		if dm.input_left.is_connected(_on_input_left):
			dm.input_left.disconnect(_on_input_left)
		if dm.input_right.is_connected(_on_input_right):
			dm.input_right.disconnect(_on_input_right)


func _on_input_cancel() -> void:
	if not _input_enabled or not visible or _in_summary:
		return
	if _wallpaper_edit_open:
		_cancel_wallpaper_edit()
		return
	if _choose_open:
		_play_cursor_sound()
		_close_choose_panel(true)
		return
	if _marks_open:
		_cancel_marks_panel()
		return
	if _hand_state == HandState.GRABBING or _hand_state == HandState.RELEASING:
		return
	if _hand_state == HandState.HOLDING:
		# Retroceder sin soltar: party↔box según origen del holding.
		if _held_from_party and not _party_open:
			await _return_held_to_party_panel()
			return
		if not _held_from_party and _party_open:
			await _return_held_to_box_panel()
			return
		await _try_start_release()
		return
	if _party_open:
		if _party_sel == SEL_PARTY_EXIT:
			# DEJAR: Salir vuelve al menú de BILL; resto: cierra el panel.
			if _mode == Mode.DEPOSIT:
				_play_cursor_sound()
				close()
			else:
				await _close_party_panel()
			return
		_party_sel = SEL_PARTY_EXIT
		_update_cursor_visual()
		_refresh_info_panel()
		_play_cursor_sound()
		return
	# En modo cursor: B salta a SALIR; si ya estás ahí, cierra.
	if _cursor_index == SEL_CLOSE:
		close()
		return
	_cursor_index = SEL_CLOSE
	_update_cursor_visual()
	_refresh_info_panel()
	_play_cursor_sound()


func _on_input_accept() -> void:
	if not _input_enabled or not visible or _in_summary:
		return
	if _wallpaper_edit_open:
		_confirm_wallpaper_edit()
		return
	if _choose_open:
		await _confirm_choose_panel()
		return
	if _marks_open:
		_on_marks_accept()
		return
	if _hand_state == HandState.GRABBING or _hand_state == HandState.RELEASING:
		return
	if _party_open:
		if _party_sel == SEL_PARTY_EXIT:
			# Con holding desde box: retrocede al box.
			if _hand_state == HandState.HOLDING and not _held_from_party:
				await _return_held_to_box_panel()
				return
			# DEJAR: Salir vuelve al menú de BILL; resto: cierra el panel.
			if _mode == Mode.DEPOSIT:
				_play_cursor_sound()
				close()
			else:
				await _close_party_panel()
			return
		if _hand_state == HandState.HOLDING:
			await _try_start_place()
			return
		if _get_cursor_pokemon() == null:
			return
		await _on_pokemon_selected()
		return
	if _hand_state == HandState.HOLDING:
		# A en CANCELAR: si venía del party, retrocede; si no, suelta.
		if _cursor_index == SEL_CLOSE:
			if _held_from_party:
				await _return_held_to_party_panel()
			else:
				await _try_start_release()
			return
		if _cursor_index == SEL_PARTY:
			await _open_party_panel()
			return
		await _try_start_place()
		return
	match _cursor_index:
		SEL_CLOSE:
			close()
			return
		SEL_PARTY:
			await _open_party_panel()
			return
		SEL_BOX_NAME:
			await _open_box_name_menu()
			return
	if _get_cursor_pokemon() == null:
		return
	await _on_pokemon_selected()


func _open_box_name_menu() -> void:
	if _hand_state != HandState.IDLE:
		return
	_play_cursor_sound()
	_input_enabled = false
	var idx: int = await DisplayManager.show_choices_corner(
		["SALTAR", "FONDO", "NOMBRE", "SALIR"],
		ChoiceBox.ChoiceAnchor.MIDDLE_RIGHT
	)
	_input_enabled = true
	if not visible or idx < 0:
		return
	match idx:
		0:
			_open_choose_panel()
		1:
			await _open_wallpaper_edit()
		2:
			# NOMBRE: pendientes.
			pass
		_:
			pass  # SALIR


func _open_wallpaper_edit() -> void:
	if _wallpaper_edit_open or _hand_state != HandState.IDLE:
		return
	_input_enabled = false
	_reset_cursor_hold_repeat()
	_hide_item_preview()

	var storage: PCStorage = null
	if GameStateService != null:
		storage = GameStateService.get_pc_storage()
	_wallpaper_edit_original = 0
	if storage != null:
		_wallpaper_edit_original = storage.get_box_wallpaper(_box_index)
	_wallpaper_edit_current = _wallpaper_edit_original

	await DisplayManager.show_message("Selecciona un fondo.", {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	DisplayManager.hide_message_wait_indicator()
	if not visible:
		return

	_wallpaper_edit_open = true
	_kill_box_arrow_nudge_tween()
	_reset_box_arrows_to_rest()
	_wallpaper_arrow_t = 0.0
	_apply_box_wallpaper(_wallpaper_edit_current)
	refresh()  # aplica semitransparencia a iconos
	_input_enabled = true


func _close_wallpaper_edit(restore_original: bool) -> void:
	if not _wallpaper_edit_open:
		_reset_box_arrows_to_rest()
		return
	_wallpaper_edit_open = false
	_wallpaper_arrow_t = 0.0
	_reset_box_arrows_to_rest()
	DisplayManager.close_message()
	if restore_original:
		_apply_box_wallpaper(_wallpaper_edit_original)
	elif GameStateService != null:
		var storage: PCStorage = GameStateService.get_pc_storage()
		if storage != null:
			storage.set_box_wallpaper(_box_index, _wallpaper_edit_current)
	refresh()


func _confirm_wallpaper_edit() -> void:
	if not _wallpaper_edit_open:
		return
	_play_cursor_sound()
	_close_wallpaper_edit(false)


func _cancel_wallpaper_edit() -> void:
	if not _wallpaper_edit_open:
		return
	_play_cursor_sound()
	_close_wallpaper_edit(true)


func _move_wallpaper_edit(dx: int) -> void:
	if dx == 0 or not _wallpaper_edit_open:
		return
	_wallpaper_edit_current = posmod(
		_wallpaper_edit_current + dx, PCStorage.WALLPAPER_COUNT
	)
	_apply_box_wallpaper(_wallpaper_edit_current)
	_play_cursor_sound()


func _reset_box_arrows_to_rest() -> void:
	_kill_box_arrow_nudge_tween()
	if _box_arrow_l:
		_box_arrow_l.position = _box_arrow_l_rest
	if _box_arrow_r:
		_box_arrow_r.position = _box_arrow_r_rest


func _kill_box_arrow_nudge_tween() -> void:
	if _box_arrow_nudge_tween != null and is_instance_valid(_box_arrow_nudge_tween):
		_box_arrow_nudge_tween.kill()
	_box_arrow_nudge_tween = null


## Pequeño empujón HGSS al cambiar de caja desde el nombre.
func _nudge_box_name_arrow(dx: int) -> void:
	if dx == 0 or _wallpaper_edit_open:
		return
	var arrow: Sprite2D = _box_arrow_r if dx > 0 else _box_arrow_l
	var rest: Vector2 = _box_arrow_r_rest if dx > 0 else _box_arrow_l_rest
	if arrow == null:
		return
	_kill_box_arrow_nudge_tween()
	arrow.position = rest
	var out_x := rest.x + (BOX_ARROW_NUDGE_PX if dx > 0 else -BOX_ARROW_NUDGE_PX)
	_box_arrow_nudge_tween = create_tween()
	_box_arrow_nudge_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_box_arrow_nudge_tween.set_trans(Tween.TRANS_SINE)
	_box_arrow_nudge_tween.tween_property(arrow, "position:x", out_x, BOX_ARROW_NUDGE_TIME) \
		.set_ease(Tween.EASE_OUT)
	_box_arrow_nudge_tween.tween_property(arrow, "position:x", rest.x, BOX_ARROW_NUDGE_TIME) \
		.set_ease(Tween.EASE_IN)


func _process_wallpaper_arrow_bob(delta: float) -> void:
	if _box_arrow_l == null or _box_arrow_r == null:
		return
	_wallpaper_arrow_t += delta
	var phase := fposmod(_wallpaper_arrow_t / CHOOSE_ARROW_BOB_PERIOD, 1.0)
	var left1 := _box_arrow_l_rest.x - CHOOSE_ARROW_BOB_PX
	var right1 := _box_arrow_l_rest.x + CHOOSE_ARROW_BOB_PX
	var left2 := _box_arrow_r_rest.x - CHOOSE_ARROW_BOB_PX
	var right2 := _box_arrow_r_rest.x + CHOOSE_ARROW_BOB_PX
	# ArrowL ← ; ArrowR →
	_box_arrow_l.position = Vector2(lerpf(right1, left1, phase), _box_arrow_l_rest.y)
	_box_arrow_r.position = Vector2(lerpf(left2, right2, phase), _box_arrow_r_rest.y)


func _box_count() -> int:
	if GameStateService != null:
		var storage: PCStorage = GameStateService.get_pc_storage()
		if storage != null:
			return storage.get_box_count()
	return PCStorage.BOX_COUNT


func _open_choose_panel() -> void:
	if _choose_panel == null or _choose_open:
		return
	_input_enabled = false
	_reset_cursor_hold_repeat()
	_choose_box_index = _box_index
	_choose_open = true
	_choose_panel.visible = true
	_choose_panel.move_to_front()
	_refresh_choose_panel()
	_start_choose_arrow_bob()
	_input_enabled = true


func _close_choose_panel(_restore_hand: bool = true) -> void:
	_choose_open = false
	_stop_choose_arrow_bob()
	if _choose_panel:
		_choose_panel.visible = false


func _refresh_choose_panel() -> void:
	var storage: PCStorage = null
	if GameStateService != null:
		storage = GameStateService.get_pc_storage()
	var box_name := "CAJA"
	var used_n := 0
	var total_n := PCStorage.SLOTS_PER_BOX
	if storage != null:
		_choose_box_index = clampi(_choose_box_index, 0, storage.get_box_count() - 1)
		box_name = storage.get_box_name(_choose_box_index)
		used_n = storage.get_box_occupied_count(_choose_box_index)
		total_n = storage.get_slots_per_box()
	_set_label_text(_choose_caja_label, box_name)
	_set_label_text(_choose_espacio_label, "%d/%d" % [used_n, total_n])


func _move_choose_box(dx: int) -> void:
	if dx == 0 or not _choose_open:
		return
	var count := _box_count()
	if count <= 1:
		return
	var prev := _choose_box_index
	_choose_box_index = posmod(_choose_box_index + dx, count)
	_refresh_choose_panel()
	if _choose_box_index != prev:
		_play_cursor_sound()


func _confirm_choose_panel() -> void:
	if not _choose_open:
		return
	_play_cursor_sound()
	var target := _choose_box_index
	_close_choose_panel(false)
	if target == _box_index:
		return
	# Índice mayor → derecha; menor → izquierda (sin wrap corto).
	var slide_dir := 1 if target > _box_index else -1
	await _jump_to_box(target, slide_dir)


func _start_choose_arrow_bob() -> void:
	if _choose_arrow1 == null or _choose_arrow2 == null:
		return
	_choose_arrow1_rest = _choose_arrow1.position
	_choose_arrow2_rest = _choose_arrow2.position
	_choose_arrow_t = 0.0


func _stop_choose_arrow_bob() -> void:
	_choose_arrow_t = 0.0
	if _choose_arrow1:
		_choose_arrow1.position = _choose_arrow1_rest
	if _choose_arrow2:
		_choose_arrow2.position = _choose_arrow2_rest


func _process_choose_arrow_bob(delta: float) -> void:
	if _choose_arrow1 == null or _choose_arrow2 == null:
		return
	_choose_arrow_t += delta
	# 0→1: cada flecha hacia su lado; al reiniciar, teleport al origen.
	var phase := fposmod(_choose_arrow_t / CHOOSE_ARROW_BOB_PERIOD, 1.0)
	var left1 := _choose_arrow1_rest.x - CHOOSE_ARROW_BOB_PX
	var right1 := _choose_arrow1_rest.x + CHOOSE_ARROW_BOB_PX
	var left2 := _choose_arrow2_rest.x - CHOOSE_ARROW_BOB_PX
	var right2 := _choose_arrow2_rest.x + CHOOSE_ARROW_BOB_PX
	# Arrow1 (izq): se mueve hacia la izquierda.
	_choose_arrow1.position = Vector2(lerpf(right1, left1, phase), _choose_arrow1_rest.y)
	# Arrow2 (der): se mueve hacia la derecha.
	_choose_arrow2.position = Vector2(lerpf(left2, right2, phase), _choose_arrow2_rest.y)


func _on_pokemon_selected() -> void:
	# MOVER POKéMON: agarre directo para organizar sin menú de acciones.
	if _mode == Mode.MOVE:
		_try_start_grab()
		return
	if _mode == Mode.MOVE_ITEMS:
		await _open_move_items_menu()
		return
	await _open_pokemon_action_menu()


func _open_move_items_menu() -> void:
	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null:
		return
	_input_enabled = false
	_play_cursor_sound()
	var outline_spr: Sprite2D = _get_focused_mon_sprite()
	_set_selection_outline(outline_spr, true)

	var has_item := mon.held_item_id > 0
	var options: Array[String]
	if has_item:
		options = ["QUITAR", "MOCHILA", "INFO.", "SALIR"]
		await _show_item_selected_message(mon.held_item_id)
	else:
		options = ["DAR", "SALIR"]

	var idx: int = await DisplayManager.show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.MIDDLE_RIGHT
	)
	DisplayManager.close_message()
	_set_selection_outline(outline_spr, false)
	_input_enabled = true
	if not visible or idx < 0:
		return

	if has_item:
		match idx:
			0:
				_try_start_take_item()
			1:
				await _send_mon_item_to_bag(mon)
			2:
				await _show_held_item_info(mon)
			_:
				pass  # SALIR
	else:
		match idx:
			0:
				await _give_held_item_from_bag()
			_:
				pass  # SALIR


## MOVE_ITEMS → MOCHILA: held del mon → bag (encoge + "Ya está en la MOCHILA.").
func _send_mon_item_to_bag(mon: Pokemon) -> void:
	if mon == null or mon.held_item_id <= 0:
		return
	if GameStateService == null or DatabaseService == null:
		return
	var item_id := mon.held_item_id
	_input_enabled = false

	var bag: Bag = GameStateService.get_bag()
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if bag == null or item_data == null:
		_input_enabled = true
		return

	var stack_limit := int(item_data.stack_limit)
	if stack_limit > 0 and bag.get_quantity(item_id) >= stack_limit:
		await DisplayManager.show_message("La MOCHILA está llena.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
		})
		if visible:
			_input_enabled = true
		return

	# Encoger el icono del objeto en el slot (mismo feel que soltar a la mochila).
	_item_preview_suppress_pop = true
	_refresh_item_preview()
	if _item_preview != null and is_instance_valid(_item_preview) and _item_preview.visible:
		await _animate_release_shrink(_item_preview, ITEM_BAG_SHRINK_TIME)
	if not visible:
		return

	if bag.add_item(item_id, 1) <= 0:
		await DisplayManager.show_message("La MOCHILA está llena.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
		})
		_refresh_item_preview()
		if visible:
			_input_enabled = true
		return

	mon.held_item_id = 0
	_hide_item_preview()
	refresh()
	_refresh_info_panel()
	_refresh_item_preview()

	await DisplayManager.show_message("Ya está en la MOCHILA.", {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"playConfirmSound": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	if visible:
		_input_enabled = true


## Abre la mochila, elige un objeto y se lo asigna al mon bajo el cursor (OBJETO / DAR).
func _give_held_item_from_bag() -> void:
	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null or GameStateService == null:
		return
	_input_enabled = false
	# En MOVER OBJETOS, DAR ya implica la mochila; el prompt solo en OBJETO del menú.
	if _mode != Mode.MOVE_ITEMS:
		await DisplayManager.show_message(
			"¿Qué objeto le das a %s?" % mon.get_display_name(),
			{
				"waitInput": true,
				"closeAtEnd": true,
				"showIconAtEnd": false,
				"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"expandHeight": true,
			}
		)
		if not visible:
			return
	_hide_overlays_for_bag()
	var item_id: int = await DisplayManager.pick_held_item_from_bag()
	if not visible:
		return
	if item_id <= 0:
		_restore_overlays_after_bag()
		_input_enabled = true
		_refresh_info_panel()
		_refresh_item_preview()
		return

	var bag: Bag = GameStateService.get_bag()
	if bag == null:
		_restore_overlays_after_bag()
		_input_enabled = true
		return
	var removed: int = bag.remove_item(item_id, 1)
	if removed < 1:
		_restore_overlays_after_bag()
		await DisplayManager.show_message("No tienes ese objeto.", {
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
		})
		if visible:
			_input_enabled = true
		return

	# Si ya llevaba algo, vuelve a la mochila.
	if mon.held_item_id > 0:
		bag.add_item(mon.held_item_id, 1)
	mon.held_item_id = item_id
	_restore_overlays_after_bag()
	refresh()
	_refresh_info_panel()
	_refresh_item_preview()
	await _await_item_preview_pop()

	var mon_name := mon.get_display_name()
	var given_name := _item_display_name(item_id)
	await DisplayManager.show_message("¡%s ahora lleva %s!" % [mon_name, given_name], {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	if visible:
		_input_enabled = true


func _hide_overlays_for_bag() -> void:
	_clear_selection_outline()
	_kill_cursor_slide_tween()
	if _cursor:
		_cursor.hide()
	_hide_item_preview()
	if _held_sprite:
		_held_sprite.hide()


func _restore_overlays_after_bag() -> void:
	if not visible:
		return
	_update_cursor_visual(false)
	if _cursor:
		_cursor.show()


## Holding un objeto: al elegir un mon, menú DAR/CAMBIO (no coloca solo).
func _open_held_item_place_menu() -> void:
	if _hand_state != HandState.HOLDING or _held_item_id <= 0:
		return
	var target: Pokemon = _get_cursor_pokemon()
	if target == null:
		return
	var source := _get_held_source_pokemon()
	if target == source:
		_cancel_held_item()
		return

	_input_enabled = false
	var outline_spr: Sprite2D = _get_focused_mon_sprite()
	_set_selection_outline(outline_spr, true)

	await _show_item_selected_message(_held_item_id)

	var has_item := target.held_item_id > 0
	var options: Array[String]
	if has_item:
		options = ["CAMBIO", "SALIR"]
	else:
		options = ["DAR", "SALIR"]
	var idx: int = await DisplayManager.show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.MIDDLE_RIGHT
	)
	DisplayManager.close_message()
	_set_selection_outline(outline_spr, false)
	_input_enabled = true
	if not visible or idx != 0:
		return
	_try_place_held_item()


func _show_item_selected_message(item_id: int) -> void:
	var item_name := _item_display_name(item_id).to_upper()
	if item_name.is_empty():
		return
	await DisplayManager.show_message("%s seleccionado." % item_name, {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	DisplayManager.hide_message_wait_indicator()


func _item_display_name(item_id: int) -> String:
	if item_id <= 0 or DatabaseService == null:
		return ""
	var item: ItemData = DatabaseService.get_item_by_id(item_id)
	if item == null:
		return ""
	return item.get_display_name()


func _held_item_display_name(mon: Pokemon) -> String:
	if mon == null:
		return ""
	return _item_display_name(mon.held_item_id)


func _show_held_item_info(mon: Pokemon) -> void:
	if mon == null or mon.held_item_id <= 0 or DatabaseService == null:
		return
	var item: ItemData = DatabaseService.get_item_by_id(mon.held_item_id)
	if item == null:
		return
	var text := item.description.strip_edges()
	if text.is_empty():
		text = item.get_display_name()
	_input_enabled = false
	await DisplayManager.show_message(text, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	if visible:
		_input_enabled = true


func _open_pokemon_action_menu() -> void:
	_input_enabled = false
	_play_cursor_sound()
	var outline_spr: Sprite2D = _get_focused_mon_sprite()
	_set_selection_outline(outline_spr, true)
	var options: Array[String] = _pokemon_menu_options()
	var idx: int = await DisplayManager.show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.MIDDLE_RIGHT
	)
	_set_selection_outline(outline_spr, false)
	_input_enabled = true
	if not visible:
		return
	if idx < 0:
		return
	match idx:
		PkmnMenuAction.MOVE:
			_try_start_grab()
		PkmnMenuAction.WITHDRAW:
			if _party_open:
				await _run_deposit_sequence()
			else:
				await _run_withdraw_sequence()
		PkmnMenuAction.SUMMARY:
			await _open_summary_for_selection()
		PkmnMenuAction.RELEASE:
			await _run_release_sequence()
		PkmnMenuAction.ITEM:
			await _on_objeto_selected()
		PkmnMenuAction.MARK:
			_open_marks_panel()
		_:
			pass


## OBJETO: sin held → mochila; con held → confirmar quitar a la mochila.
func _on_objeto_selected() -> void:
	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null:
		return
	if mon.held_item_id > 0:
		await _confirm_remove_held_item_to_bag(mon)
	else:
		await _give_held_item_from_bag()


## Si el mon ya lleva objeto: Sí → a la mochila; No → cancelar.
func _confirm_remove_held_item_to_bag(mon: Pokemon) -> void:
	if mon == null or mon.held_item_id <= 0:
		return
	var item_id := mon.held_item_id
	var mon_name := mon.get_display_name()
	var item_name := _item_display_name(item_id)
	_input_enabled = false
	var outline_spr: Sprite2D = _get_focused_mon_sprite()
	_set_selection_outline(outline_spr, true)

	await DisplayManager.show_message(
		"%s tiene %s.\n¿Quieres quitárselo?" % [mon_name, item_name],
		{
			"waitInput": false,
			"closeAtEnd": false,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
		}
	)
	DisplayManager.hide_message_wait_indicator()

	var dm := DisplayManager.instance
	if dm != null and dm.choice_box != null:
		dm.choice_box.set_next_initial_index(1)  # No
	var choice: int = await DisplayManager.show_choices_corner(
		["Sí", "No"],
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	DisplayManager.close_message()

	if not visible:
		return
	if choice != 0:
		_set_selection_outline(outline_spr, false)
		_input_enabled = true
		return

	if GameStateService == null or DatabaseService == null:
		_set_selection_outline(outline_spr, false)
		_input_enabled = true
		return
	var bag: Bag = GameStateService.get_bag()
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if bag == null or item_data == null:
		_set_selection_outline(outline_spr, false)
		_input_enabled = true
		return
	var stack_limit := int(item_data.stack_limit)
	if stack_limit > 0 and bag.get_quantity(item_id) >= stack_limit:
		await DisplayManager.show_message("La MOCHILA está llena.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
		})
		_set_selection_outline(outline_spr, false)
		if visible:
			_input_enabled = true
		return
	if bag.add_item(item_id, 1) <= 0:
		await DisplayManager.show_message("La MOCHILA está llena.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
			"expandHeight": true,
		})
		_set_selection_outline(outline_spr, false)
		if visible:
			_input_enabled = true
		return

	# Encoger el icono en el slot antes de quitarlo del mon.
	_item_preview_suppress_pop = true
	_refresh_item_preview()
	_dismiss_item_preview_animated()
	await get_tree().create_timer(ITEM_PREVIEW_POP_TIME, true, false, true).timeout

	mon.held_item_id = 0
	_set_selection_outline(outline_spr, false)
	refresh()
	_refresh_info_panel()
	_refresh_item_preview()
	if visible:
		_input_enabled = true


func _run_release_sequence() -> void:
	if _hand_state != HandState.IDLE:
		return
	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null:
		return
	var from_party := _party_open
	var slot := _party_sel if from_party else _cursor_index
	if slot < 0:
		return

	_input_enabled = false
	var outline_spr: Sprite2D = _get_focused_mon_sprite()
	_set_selection_outline(outline_spr, true)

	# Último del equipo: no se puede liberar.
	if from_party and GameStateService != null:
		var party: Party = GameStateService.get_party()
		if party != null and party.count() <= 1:
			await DisplayManager.show_message("¡Es tu último POKéMON!", {
				"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"expandHeight": true,
			})
			_set_selection_outline(outline_spr, false)
			if visible:
				_input_enabled = true
			return

	var nickname := mon.get_display_name()
	await DisplayManager.show_message("¿Liberas este POKéMON?", {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	DisplayManager.hide_message_wait_indicator()

	var dm := DisplayManager.instance
	if dm != null and dm.choice_box != null:
		dm.choice_box.set_next_initial_index(1)  # No
	var choice: int = await DisplayManager.show_choices_corner(
		["Sí", "No"],
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	DisplayManager.close_message()

	if not visible:
		return
	if choice != 0:
		_set_selection_outline(outline_spr, false)
		_input_enabled = true
		return

	# Sí: quitar borde rojo, luego empequeñecer y borrar.
	_set_selection_outline(outline_spr, false)
	_hide_item_preview()
	# Esperar a que el borde desaparezca del árbol antes del shrink.
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate_release_shrink(outline_spr)

	if from_party:
		var party2: Party = GameStateService.get_party() if GameStateService else null
		if party2 != null:
			party2.remove_pokemon(slot)
	else:
		var storage: PCStorage = GameStateService.get_pc_storage() if GameStateService else null
		if storage != null:
			storage.remove_pokemon(_box_index, slot)

	refresh()
	_clear_info_panel()

	await DisplayManager.show_message("Soltaste a %s." % nickname, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	if not visible:
		return
	await DisplayManager.show_message("¡Adiós, %s!" % nickname, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"expandHeight": true,
	})
	if visible:
		_input_enabled = true
		_update_cursor_visual()
		_refresh_info_panel()


func _animate_release_shrink(spr: Sprite2D, duration: float = RELEASE_SHRINK_TIME) -> void:
	if spr == null or not is_instance_valid(spr) or not spr.visible:
		return
	var start_scale := spr.scale
	var start_pos := spr.position
	# Los iconos suelen tener el mon más abajo del centro del frame; al escalar
	# desde el pivote geométrico parece subir. Compensamos bajando la posición.
	var pivot_down := 10.0
	if spr.texture != null:
		var frame_h := float(spr.texture.get_height()) / maxf(float(spr.vframes), 1.0)
		pivot_down = frame_h * 0.18
	spr.centered = true
	spr.show()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		_apply_release_shrink.bind(spr, start_pos, start_scale, pivot_down),
		1.0,
		0.05,
		maxf(duration, 0.05)
	)
	await tw.finished
	if is_instance_valid(spr):
		spr.hide()
		spr.texture = null
		spr.scale = start_scale
		spr.position = start_pos


func _apply_release_shrink(
	s: float,
	spr: Sprite2D,
	start_pos: Vector2,
	start_scale: Vector2,
	pivot_down: float
) -> void:
	if spr == null or not is_instance_valid(spr):
		return
	spr.scale = Vector2(s, s) * start_scale
	spr.position = start_pos + Vector2(0.0, pivot_down * (1.0 - s))


func _ensure_summary() -> void:
	if _summary != null and is_instance_valid(_summary):
		return
	_summary = PARTY_SUMMARY_SCENE.instantiate() as PartySummary
	if _summary == null:
		push_error("PCStorageUI: no se pudo instanciar PartySummary.")
		return
	_summary.name = "SUMMARY"
	_summary.hide()
	_summary.z_index = 50
	_summary.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_summary)


func _build_summary_members() -> Array[Pokemon]:
	var members: Array[Pokemon] = []
	if GameStateService == null:
		return members
	if _party_open:
		var party: Party = GameStateService.get_party()
		if party != null:
			members.assign(party.get_all())
		return members
	var storage: PCStorage = GameStateService.get_pc_storage()
	if storage == null:
		return members
	for i in range(SLOT_COUNT):
		var mon: Pokemon = storage.get_pokemon(_box_index, i)
		if mon != null:
			members.append(mon)
	return members


func _summary_index_for_selection(members: Array[Pokemon]) -> int:
	var focused: Pokemon = _get_cursor_pokemon()
	if focused == null:
		return 0
	for i in range(members.size()):
		if members[i] == focused:
			return i
	return 0


func _open_summary_for_selection() -> void:
	_ensure_summary()
	if _summary == null:
		return
	var members := _build_summary_members()
	if members.is_empty():
		return
	var idx := _summary_index_for_selection(members)
	var mon: Pokemon = members[idx]
	if mon == null:
		return
	if mon.base == null and mon.has_method("_post_init"):
		mon._post_init()

	_in_summary = true
	_input_enabled = false
	_hide_item_preview()

	await DisplayManager.fade_in(SUMMARY_FADE_DURATION)
	_summary.loadedParty = members
	_summary.movingIndex = idx
	_summary.loadPokemonInfo(mon)
	_summary.showSummary(PartySummary.DATA)
	await DisplayManager.fade_out(SUMMARY_FADE_DURATION)
	_summary.reveal_with_cry()

	await _summary.close_requested

	await DisplayManager.fade_in(SUMMARY_FADE_DURATION)
	_summary.dismiss()
	await DisplayManager.fade_out(SUMMARY_FADE_DURATION)

	_in_summary = false
	if visible:
		_input_enabled = true
		_update_cursor_visual()
		_refresh_info_panel()


func _get_focused_mon_sprite() -> Sprite2D:
	if _party_open:
		if _party_sel >= 0 and _party_sel < _party_slot_sprites.size():
			return _party_slot_sprites[_party_sel]
		return null
	if _cursor_index >= 0 and _cursor_index < _slot_sprites.size():
		return _slot_sprites[_cursor_index]
	return null


func _ensure_selection_outline_material() -> ShaderMaterial:
	if _selection_outline_material != null and is_instance_valid(_selection_outline_material):
		return _selection_outline_material
	_selection_outline_material = ShaderMaterial.new()
	_selection_outline_material.shader = PC_ICON_OUTLINE_SHADER
	_selection_outline_material.set_shader_parameter("outline_color", Color(0.973, 0.282, 0.282, 1.0))
	_selection_outline_material.set_shader_parameter("outline_size", 2)
	return _selection_outline_material


func _clear_selection_outline() -> void:
	if _selection_outline_root != null and is_instance_valid(_selection_outline_root):
		_selection_outline_root.queue_free()
	_selection_outline_root = null
	_selection_outline_target = null


func _set_selection_outline(spr: Sprite2D, enabled: bool) -> void:
	_clear_selection_outline()
	if not enabled or spr == null or not is_instance_valid(spr):
		return
	# Una capa con shader de anillo (sin relleno) detrás del icono.
	var root := Node2D.new()
	root.name = "SelectionOutline"
	root.show_behind_parent = true
	spr.add_child(root)
	var mat := _ensure_selection_outline_material()
	var layer := Sprite2D.new()
	layer.centered = spr.centered
	layer.texture = spr.texture
	layer.hframes = spr.hframes
	layer.vframes = spr.vframes
	layer.frame = spr.frame
	layer.flip_h = spr.flip_h
	layer.flip_v = spr.flip_v
	layer.material = mat
	root.add_child(layer)
	_selection_outline_root = root
	_selection_outline_target = spr


func _pokemon_menu_options() -> Array[String]:
	var opts: Array[String] = PKMN_MENU_OPTIONS.duplicate()
	if _party_open:
		opts[PkmnMenuAction.WITHDRAW] = "DEJAR"
	return opts


func _run_withdraw_sequence() -> void:
	if _hand_state != HandState.IDLE or _party_open:
		return
	if GameStateService == null:
		return
	var party: Party = GameStateService.get_party()
	if party == null:
		return
	if party.is_full():
		_input_enabled = false
		await DisplayManager.show_message("¡Tu equipo está completo!", {
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": "instant",
			"expandHeight": true,
		})
		_input_enabled = true
		return
	var origin_slot := _cursor_index
	if origin_slot < 0:
		return
	var free_slot: int = party.count()
	if free_slot < 0 or free_slot >= PARTY_SLOT_COUNT:
		return

	_input_enabled = false
	_try_start_grab()
	if _hand_state != HandState.GRABBING:
		_input_enabled = true
		return
	await _await_hand_state(HandState.HOLDING)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return

	# Party sube solo; la mano se queda en el slot hasta que el panel esté listo.
	var withdraw_slide := PARTY_SLIDE_TIME * 0.5
	await _open_party_panel(false, false, withdraw_slide, false, false)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return

	_attach_hand_keep_global(_party_panel)
	_party_sel = free_slot
	await _animate_hand_to(_party_arrow_position(free_slot), WITHDRAW_HAND_TRAVEL)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return

	_start_release(free_slot, true, true)
	await _await_hand_state(HandState.IDLE)
	if not visible:
		return

	# Panel baja; la mano se queda quieta y luego vuelve andando al slot origen.
	await _close_party_panel(false, origin_slot, withdraw_slide, false, false)
	if not visible:
		return
	_cursor_index = origin_slot
	await _animate_hand_to(_cursor_rest_position(origin_slot), WITHDRAW_HAND_TRAVEL)
	if not visible:
		return
	_update_cursor_visual()
	_refresh_info_panel()
	_input_enabled = true


func _run_deposit_sequence() -> void:
	if _hand_state != HandState.IDLE or not _party_open:
		return
	if GameStateService == null:
		return
	var party: Party = GameStateService.get_party()
	var storage: PCStorage = GameStateService.get_pc_storage()
	if party == null or storage == null:
		return
	if party.count() <= 1:
		_input_enabled = false
		await DisplayManager.show_message("¡Es tu último POKéMON!", {
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": "instant",
			"expandHeight": true,
		})
		_input_enabled = true
		return
	var free: Vector2i = storage.find_first_free_slot(_box_index)
	if free.x < 0:
		_input_enabled = false
		await DisplayManager.show_message("¡No hay sitio en las CAJAS!", {
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": "instant",
			"expandHeight": true,
		})
		_input_enabled = true
		return

	var mon: Pokemon = _get_cursor_pokemon()
	if mon == null:
		return
	var dest_box: int = free.x
	var dest_slot: int = free.y
	var switched_box: bool = dest_box != _box_index
	var deposit_slide := PARTY_SLIDE_TIME * 0.5

	_input_enabled = false
	_try_start_grab()
	if _hand_state != HandState.GRABBING:
		_input_enabled = true
		return
	await _await_hand_state(HandState.HOLDING)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return

	# Party baja; la mano se queda y luego va al hueco libre de la caja.
	await _close_party_panel(false, dest_slot, deposit_slide, false, false)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return

	if switched_box:
		_box_index = dest_box
		refresh()
	_cursor_index = dest_slot
	_attach_hand_keep_global(_box_panel)
	await _animate_hand_to(_cursor_rest_position(dest_slot), WITHDRAW_HAND_TRAVEL)
	if not visible or _hand_state != HandState.HOLDING:
		_input_enabled = true
		return

	_start_release(dest_slot, true, false)
	await _await_hand_state(HandState.IDLE)
	if not visible:
		return

	# Vuelve al party en el primer slot.
	await _open_party_panel(false, false, deposit_slide, true, false)
	if not visible:
		return
	_party_sel = 0
	_update_cursor_visual()
	_refresh_info_panel()
	_input_enabled = true


func _await_hand_state(wanted: HandState) -> void:
	while visible and _hand_state != wanted:
		await get_tree().process_frame


func _animate_hand_to(target: Vector2, duration: float) -> void:
	if _cursor == null:
		return
	_kill_cursor_slide_tween()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cursor, "position", target, duration)
	# HOLDING: el held sigue al cursor en _process. Si no, animar el icono a mano.
	if (
		_held_sprite != null
		and _held_sprite.visible
		and _hand_state != HandState.HOLDING
	):
		var held_off := HELD_ICON_FROM_CURSOR
		if _held_item_id > 0:
			held_off = HELD_ICON_FROM_CURSOR + Vector2(0, 4)
		tw.parallel().tween_property(_held_sprite, "position", target + held_off, duration)
	await tw.finished
	if _hand_state == HandState.HOLDING:
		_sync_held_to_cursor()


func _on_input_up() -> void:
	if not _input_enabled or not visible:
		return
	if _choose_open or _wallpaper_edit_open:
		return
	if _read_orthogonal_move_dir() != Vector2i(0, -1):
		return
	_dir_hold_vec = Vector2i(0, -1)
	_dir_hold_time = 0.0
	_dir_repeat_ready = false
	await _move_cursor(0, -1)


func _on_input_down() -> void:
	if not _input_enabled or not visible:
		return
	if _choose_open or _wallpaper_edit_open:
		return
	if _read_orthogonal_move_dir() != Vector2i(0, 1):
		return
	_dir_hold_vec = Vector2i(0, 1)
	_dir_hold_time = 0.0
	_dir_repeat_ready = false
	await _move_cursor(0, 1)


func _on_input_left() -> void:
	if not _input_enabled or not visible:
		return
	if _wallpaper_edit_open:
		if _read_orthogonal_move_dir() != Vector2i(-1, 0):
			return
		_dir_hold_vec = Vector2i(-1, 0)
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		_move_wallpaper_edit(-1)
		return
	if _choose_open:
		if _read_orthogonal_move_dir() != Vector2i(-1, 0):
			return
		_dir_hold_vec = Vector2i(-1, 0)
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		_move_choose_box(-1)
		return
	if _marks_open:
		if _read_orthogonal_move_dir() != Vector2i(-1, 0):
			return
		_dir_hold_vec = Vector2i(-1, 0)
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		_move_marks_cursor(-1, 0)
		return
	# Holding en columna izquierda del box → abrir party (inverso de salir del party).
	if (
		not _party_open
		and _hand_state == HandState.HOLDING
		and _cursor_index >= 0
		and (_cursor_index % COLS) == 0
		and _read_orthogonal_move_dir().x < 0
	):
		_input_enabled = false
		_reset_cursor_hold_repeat()
		# Party sube solo; la mano se queda y luego va al slot (como SACAR).
		await _open_party_panel(false, false, PARTY_SLIDE_TIME, false, false)
		if not visible or _hand_state != HandState.HOLDING:
			_input_enabled = true
			return
		var box_row: int = int(_cursor_index / COLS)
		var party_row: int = clampi(box_row, 0, 2)
		_party_sel = party_row * 2 + 1  # columna derecha del party
		_attach_hand_keep_global(_party_panel)
		await _animate_hand_to(_party_arrow_position(_party_sel), PARTY_EDGE_HAND_TRAVEL)
		if not visible:
			return
		_update_cursor_visual()
		_refresh_info_panel()
		_input_enabled = true
		return
	if _read_orthogonal_move_dir() != Vector2i(-1, 0):
		return
	_dir_hold_vec = Vector2i(-1, 0)
	_dir_hold_time = 0.0
	_dir_repeat_ready = false
	await _move_cursor(-1, 0)


func _on_input_right() -> void:
	if not _input_enabled or not visible:
		return
	if _wallpaper_edit_open:
		if _read_orthogonal_move_dir() != Vector2i(1, 0):
			return
		_dir_hold_vec = Vector2i(1, 0)
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		_move_wallpaper_edit(1)
		return
	if _choose_open:
		if _read_orthogonal_move_dir() != Vector2i(1, 0):
			return
		_dir_hold_vec = Vector2i(1, 0)
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		_move_choose_box(1)
		return
	if _marks_open:
		if _read_orthogonal_move_dir() != Vector2i(1, 0):
			return
		_dir_hold_vec = Vector2i(1, 0)
		_dir_hold_time = 0.0
		_dir_repeat_ready = false
		_move_marks_cursor(1, 0)
		return
	# Holding en columna derecha del party → salir al box (sin pulsar SALIR).
	if (
		_party_open
		and _hand_state == HandState.HOLDING
		and _party_sel != SEL_PARTY_EXIT
		and (_party_sel % 2) == 1
		and _read_orthogonal_move_dir().x > 0
	):
		_input_enabled = false
		_reset_cursor_hold_repeat()
		var box_row: int = clampi(int(_party_sel / 2), 0, ROWS - 1)
		var box_slot: int = box_row * COLS
		await _close_party_panel(false, box_slot, PARTY_SLIDE_TIME, false, false)
		if not visible or _hand_state != HandState.HOLDING:
			_input_enabled = true
			return
		_cursor_index = box_slot
		_attach_hand_keep_global(_box_panel)
		await _animate_hand_to(_cursor_rest_position(), PARTY_EDGE_HAND_TRAVEL)
		if not visible:
			return
		_update_cursor_visual()
		_refresh_info_panel()
		_input_enabled = true
		return
	if _read_orthogonal_move_dir() != Vector2i(1, 0):
		return
	_dir_hold_vec = Vector2i(1, 0)
	_dir_hold_time = 0.0
	_dir_repeat_ready = false
	await _move_cursor(1, 0)
