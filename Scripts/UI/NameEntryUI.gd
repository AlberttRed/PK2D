extends Panel
class_name NameEntryUI

## Pantalla de entrada de nombre (estilo Gen 3 / Essentials).
## Navegación por flechas entre letras, pestañas (Mayus/Minus/Otros) y acciones (BACK/OK).
## El panel de letras solo cambia al confirmar una pestaña con ui_accept (con animación).
## OK confirma; nombre en blanco (solo espacios) → "". El caller asigna species/caja si "".

signal confirmed(result: String)

enum Zone { LETTERS, OPTIONS, ACTIONS }

const LETTER_ORIGIN := Vector2(38, 26)
const LETTER_STEP := Vector2(32, 38)
## Tamaño típico de un Label de letra (para cursor en celdas vacías).
const LETTER_CELL_SIZE := Vector2(12, 23)
## Ajuste fino del cursor de letra respecto al centro del Label (calibrado en escena).
const LETTER_CURSOR_NUDGE := Vector2(-2, -2)
## Por debajo de este X (coords Panel) al subir desde letras → pestañas; si no → acciones.
const ACTIONS_X_THRESHOLD := 290.0

const PAGE_SLIDE_SEC := 0.56
const PAGE_SLIDE_DOWN_PX := 240.0
const PAGE_SLIDE_FROM_LEFT_PX := 480.0
const OPCIONES_SHAKE_PX := 10.0
const OPCIONES_SHAKE_STEP_SEC := 0.05
const MAX_NAME_LEN := 10
const UNDERSCORE_BOB_PX := 2.0
const UNDERSCORE_BOB_SEC := 0.125
## Salto del icono: sin slide; snap arriba y vuelta a reposo (solo frame 0).
## En el suelo se mantiene un poco más (delay) antes del siguiente salto.
const ICON_HOP_PX := 8.0
const ICON_HOP_AIR_SEC := 0.1333
const ICON_HOP_GROUND_SEC := 0.35
## Cursores blancos + modulate: rojo ↔ amarillo (mismo hold en ambos).
const CURSOR_COLOR_RED := Color("EF3100")
const CURSOR_COLOR_YELLOW := Color("EFC600")
const CURSOR_FLASH_BLEND_SEC := 0.22
const CURSOR_FLASH_HOLD_SEC := 0.2
## Cursor de letra: abrir/cerrar vía scale (aproxima los 2 frames del original).
const LETTER_CURSOR_CLOSED_SCALE := 0.78
const LETTER_CURSOR_PULSE_HALF_SEC := 0.2

@onready var _panel: Control = $Panel
@onready var _opciones: Panel = $Panel/Opciones
@onready var _page_mayus: Panel = $Panel/Mayus
@onready var _page_minus: Panel = $Panel/Minus
@onready var _page_otros: Panel = $Panel/Otros
@onready var _select_letra: Sprite2D = $Panel/SelectLetra
@onready var _select_opcion: Sprite2D = $Panel/SelectOpcion
@onready var _select_accion: Sprite2D = $Panel/SelectAccion
@onready var _option_mode: Sprite2D = $Panel/Option
@onready var _caracters_root: Control = $Caracters
@onready var _icon: Sprite2D = $icon
@onready var _gender: Sprite2D = $gender

## Pestañas navegables: UPPER / lower / Others.
## El spritesheet Option tiene 4 frames (0 Upper, 1 lower, 2 aeiou, 3 others); aeiou aún no tiene página.
var _option_positions: Array[Vector2] = [
	Vector2(58, 46),
	Vector2(120, 46),
	Vector2(244, 46),
]
## page_index → frame de `Option` (salta el 2 = aeiou).
const OPTION_MODE_FRAMES: Array[int] = [0, 1, 3]
var _action_positions: Array[Vector2] = [
	Vector2(335, 46), ## BACK
	Vector2(415, 46), ## OK
]

var _pages: Array[Panel] = []
var _page_rest_pos: Vector2 = Vector2.ZERO
var _opciones_rest_pos: Vector2 = Vector2.ZERO
## Página de letras visible ahora.
var _active_page_index: int = 0
## Cursor sobre pestaña (puede diferir de `_active_page_index` hasta ui_accept).
var _option_index: int = 0
var _zone: Zone = Zone.LETTERS
var _action_index: int = 0
var _letter_col: int = 0
var _letter_row: int = 0
## [row][col] -> Label o null
var _letter_grid: Array = []
var _input_enabled: bool = true
var _animating: bool = false

## Slots del nombre: cada uno es { "slot": Label (_), "letra": Label, "rest_y": float }.
var _name_slots: Array[Dictionary] = []
var _name_cursor: int = 0
var _name_chars: PackedStringArray = PackedStringArray()
var _underscore_tween: Tween = null

var _icon_hop_phase: float = 0.0
var _icon_hop_up: bool = false
var _cursor_flash_tween: Tween = null
var _letter_cursor_pulse_tween: Tween = null
## Identidad de la selección actual (zona + índices) para reiniciar el flash solo al cambiar.
var _cursor_flash_key: String = ""
var _species_name: String = ""
var _awaiting_confirm: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pages = [_page_mayus, _page_minus, _page_otros]
	_page_rest_pos = _page_mayus.position
	_opciones_rest_pos = _opciones.position
	_setup_name_slots()
	_show_page_immediate(0)
	_zone = Zone.LETTERS
	_letter_col = 0
	_letter_row = 0
	hide()
	set_process(false)
	## Prueba F6 / “Run Current Scene”: abrir sola sin DisplayManager.
	if get_tree().current_scene == self:
		call_deferred("open")


## Abre la pantalla. `icon_texture` opcional; género visible solo si `show_gender`.
func open(
	species_name: String = "",
	icon_texture: Texture2D = null,
	show_gender: bool = false,
	is_female: bool = false
) -> void:
	_species_name = species_name
	_awaiting_confirm = true
	_input_enabled = true
	_animating = false
	_name_chars.clear()
	_name_cursor = 0
	_zone = Zone.LETTERS
	_letter_col = 0
	_letter_row = 0
	_option_index = 0
	_action_index = 0
	_cursor_flash_key = ""
	_show_page_immediate(0)
	_refresh_name_slots_visual()
	_start_underscore_bob()
	if icon_texture != null:
		_icon.texture = icon_texture
		_icon.hframes = 1 if icon_texture is AtlasTexture else 2
		_icon.vframes = 1
		_icon.frame = 0
		_icon.visible = true
	else:
		_icon.visible = false
	_gender.visible = show_gender
	if show_gender:
		_gender.texture = (
			preload("res://Sprites/UI/Party/female_icon.png")
			if is_female
			else preload("res://Sprites/UI/Party/male_icon.png")
		)
	_reset_icon_hop()
	show()
	move_to_front()
	set_process(true)
	_refresh_cursor()


func close() -> void:
	_input_enabled = false
	_awaiting_confirm = false
	_stop_underscore_bob()
	if _cursor_flash_tween != null and is_instance_valid(_cursor_flash_tween):
		_cursor_flash_tween.kill()
	_cursor_flash_tween = null
	if _letter_cursor_pulse_tween != null and is_instance_valid(_letter_cursor_pulse_tween):
		_letter_cursor_pulse_tween.kill()
	_letter_cursor_pulse_tween = null
	hide()
	set_process(false)


func get_entered_name() -> String:
	var raw := ""
	for i in range(_name_chars.size()):
		raw += _name_chars[i]
	return raw.strip_edges()


func _process(delta: float) -> void:
	if not visible or not _icon.visible:
		return
	_icon_hop_phase += delta
	var hold := ICON_HOP_AIR_SEC if _icon_hop_up else ICON_HOP_GROUND_SEC
	if _icon_hop_phase < hold:
		return
	_icon_hop_phase = 0.0
	_icon_hop_up = not _icon_hop_up
	_apply_icon_hop()


func _input(event: InputEvent) -> void:
	if not _input_enabled or not visible or _animating:
		return
	if not event.is_pressed() or event.is_echo():
		return
	var handled := false
	if event.is_action_pressed("ui_up"):
		_move(Vector2i(0, -1))
		handled = true
	elif event.is_action_pressed("ui_down"):
		_move(Vector2i(0, 1))
		handled = true
	elif event.is_action_pressed("ui_left"):
		_move(Vector2i(-1, 0))
		handled = true
	elif event.is_action_pressed("ui_right"):
		_move(Vector2i(1, 0))
		handled = true
	elif event.is_action_pressed("ui_accept"):
		await _on_accept()
		handled = true
	elif event.is_action_pressed("ui_cancel"):
		_delete_previous_letter()
		handled = true
	elif event.is_action_pressed("ui_start"):
		_jump_to_ok()
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _on_accept() -> void:
	match _zone:
		Zone.OPTIONS:
			if _option_index != _active_page_index:
				await _animate_page_change(_option_index)
		Zone.LETTERS:
			_type_selected_letter()
		Zone.ACTIONS:
			if _action_index == 0:
				_delete_previous_letter()
			else:
				_confirm_ok()


func _jump_to_ok() -> void:
	_zone = Zone.ACTIONS
	_action_index = 1
	_refresh_cursor()


func _confirm_ok() -> void:
	if not _awaiting_confirm:
		return
	_awaiting_confirm = false
	_input_enabled = false
	var result := get_entered_name()
	close()
	confirmed.emit(result)


func _move(delta: Vector2i) -> void:
	match _zone:
		Zone.LETTERS:
			_move_letters(delta)
		Zone.OPTIONS:
			_move_options(delta)
		Zone.ACTIONS:
			_move_actions(delta)
	_refresh_cursor()


func _move_letters(delta: Vector2i) -> void:
	if _letter_grid.is_empty():
		return
	if delta.y < 0 and _letter_row <= 0:
		var x: float = _letter_cell_center(_letter_col, _letter_row).x
		if x >= ACTIONS_X_THRESHOLD:
			_zone = Zone.ACTIONS
			_action_index = 0 if x < 380.0 else 1
		else:
			_zone = Zone.OPTIONS
			_option_index = _nearest_option_index(x)
		return
	if delta.x != 0:
		_step_letter_horizontal(delta.x)
		return
	if delta.y != 0:
		_step_letter_vertical(delta.y)


func _step_letter_horizontal(dir: int) -> void:
	var row: Array = _letter_grid[_letter_row]
	if row.is_empty():
		return
	var next := _letter_col + dir
	if next < 0 or next >= row.size():
		return
	_letter_col = next


func _step_letter_vertical(dir: int) -> void:
	var target_row := _letter_row + dir
	if target_row < 0 or target_row >= _letter_grid.size():
		return
	_letter_row = target_row
	var row: Array = _letter_grid[_letter_row]
	if row.is_empty():
		_letter_col = 0
		return
	_letter_col = clampi(_letter_col, 0, row.size() - 1)


func _move_options(delta: Vector2i) -> void:
	if delta.x != 0:
		var next := _option_index + delta.x
		if next < 0:
			return
		if next >= _option_positions.size():
			_zone = Zone.ACTIONS
			_action_index = 0
			return
		_option_index = next
		return
	if delta.y > 0:
		_zone = Zone.LETTERS
		_snap_letter_to_x(_option_positions[_option_index].x)
		return


func _move_actions(delta: Vector2i) -> void:
	if delta.x != 0:
		var next := _action_index + delta.x
		if next >= _action_positions.size():
			return
		if next < 0:
			_zone = Zone.OPTIONS
			_option_index = _option_positions.size() - 1
			return
		_action_index = next
		return
	if delta.y > 0:
		_zone = Zone.LETTERS
		_snap_letter_to_x(_action_positions[_action_index].x)
		return


func _snap_letter_to_x(panel_x: float) -> void:
	if _letter_grid.is_empty():
		return
	_letter_row = 0
	var best_col := 0
	var best_dist := 99999.0
	var row: Array = _letter_grid[0]
	for c in range(row.size()):
		var d: float = absf(_letter_cell_center(c, 0).x - panel_x)
		if d < best_dist:
			best_dist = d
			best_col = c
	_letter_col = best_col


func _nearest_option_index(panel_x: float) -> int:
	var best := 0
	var best_dist := 99999.0
	for i in _option_positions.size():
		var d: float = absf(_option_positions[i].x - panel_x)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _show_page_immediate(index: int) -> void:
	_active_page_index = clampi(index, 0, _pages.size() - 1)
	_option_index = _active_page_index
	for i in _pages.size():
		var page: Panel = _pages[i]
		page.position = _page_rest_pos
		page.visible = (i == _active_page_index)
	_opciones.position = _opciones_rest_pos
	_rebuild_letter_grid()
	_clamp_letter_cursor()
	_refresh_option_mode()


## Salida hacia abajo + entrada desde la izquierda; luego shake horizontal de Opciones.
func _animate_page_change(new_index: int) -> void:
	new_index = clampi(new_index, 0, _pages.size() - 1)
	if new_index == _active_page_index or _animating:
		return
	_animating = true
	_input_enabled = false

	var old_index := _active_page_index
	var old_page: Panel = _pages[old_index]
	var new_page: Panel = _pages[new_index]

	## Resaltado del modo al confirmar, sin esperar al slide de paneles.
	_active_page_index = new_index
	_refresh_option_mode()

	old_page.position = _page_rest_pos
	old_page.visible = true
	new_page.visible = true
	new_page.position = Vector2(_page_rest_pos.x - PAGE_SLIDE_FROM_LEFT_PX, _page_rest_pos.y)

	var slide := create_tween()
	slide.set_parallel(true)
	slide.set_ease(Tween.EASE_IN_OUT)
	slide.set_trans(Tween.TRANS_CUBIC)
	slide.tween_property(
		old_page,
		"position",
		_page_rest_pos + Vector2(0.0, PAGE_SLIDE_DOWN_PX),
		PAGE_SLIDE_SEC
	)
	slide.tween_property(new_page, "position", _page_rest_pos, PAGE_SLIDE_SEC)
	await slide.finished

	old_page.visible = false
	old_page.position = _page_rest_pos

	# Shake horizontal del panel Opciones (derecha → izquierda → reposo).
	var shake := create_tween()
	shake.set_trans(Tween.TRANS_SINE)
	shake.tween_property(
		_opciones,
		"position",
		_opciones_rest_pos + Vector2(OPCIONES_SHAKE_PX, 0.0),
		OPCIONES_SHAKE_STEP_SEC
	).set_ease(Tween.EASE_OUT)
	shake.tween_property(
		_opciones,
		"position",
		_opciones_rest_pos - Vector2(OPCIONES_SHAKE_PX, 0.0),
		OPCIONES_SHAKE_STEP_SEC * 2.0
	).set_ease(Tween.EASE_IN_OUT)
	shake.tween_property(
		_opciones,
		"position",
		_opciones_rest_pos,
		OPCIONES_SHAKE_STEP_SEC
	).set_ease(Tween.EASE_IN_OUT)
	await shake.finished

	_rebuild_letter_grid()
	_clamp_letter_cursor()
	_refresh_cursor()

	_animating = false
	_input_enabled = true


func _page_panel() -> Panel:
	return _pages[_active_page_index]


func _rebuild_letter_grid() -> void:
	_letter_grid.clear()
	var page := _page_panel()
	var max_col := 0
	var max_row := 0
	var cells: Dictionary = {} # Vector2i -> Label
	for child in page.get_children():
		if not (child is Label):
			continue
		var label := child as Label
		var col := int(round((label.offset_left - LETTER_ORIGIN.x) / LETTER_STEP.x))
		var row := int(round((label.offset_top - LETTER_ORIGIN.y) / LETTER_STEP.y))
		if col < 0 or row < 0:
			continue
		cells[Vector2i(col, row)] = label
		max_col = maxi(max_col, col)
		max_row = maxi(max_row, row)
	for r in range(max_row + 1):
		var row_arr: Array = []
		row_arr.resize(max_col + 1)
		for c in range(max_col + 1):
			row_arr[c] = cells.get(Vector2i(c, r), null)
		_letter_grid.append(row_arr)


func _clamp_letter_cursor() -> void:
	if _letter_grid.is_empty():
		_letter_col = 0
		_letter_row = 0
		return
	_letter_row = clampi(_letter_row, 0, _letter_grid.size() - 1)
	var row: Array = _letter_grid[_letter_row]
	if row.is_empty():
		_letter_col = 0
		return
	_letter_col = clampi(_letter_col, 0, row.size() - 1)


func _in_letter_grid(col: int, row: int) -> bool:
	if row < 0 or row >= _letter_grid.size():
		return false
	var row_arr: Array = _letter_grid[row]
	return col >= 0 and col < row_arr.size()


func _get_letter_at(col: int, row: int) -> Label:
	if not _in_letter_grid(col, row):
		return null
	return _letter_grid[row][col] as Label


func _letter_cell_center(col: int, row: int) -> Vector2:
	var page := _page_panel()
	var label := _get_letter_at(col, row)
	if label != null:
		return page.position + label.position + label.size * 0.5
	var local := (
		LETTER_ORIGIN
		+ Vector2(float(col) * LETTER_STEP.x, float(row) * LETTER_STEP.y)
		+ LETTER_CELL_SIZE * 0.5
	)
	return page.position + local


func _refresh_option_mode() -> void:
	if _option_mode == null:
		return
	var idx := clampi(_active_page_index, 0, OPTION_MODE_FRAMES.size() - 1)
	_option_mode.visible = true
	_option_mode.position = _option_positions[idx]
	_option_mode.frame = OPTION_MODE_FRAMES[idx]


func _refresh_cursor() -> void:
	_select_letra.visible = (_zone == Zone.LETTERS)
	_select_opcion.visible = (_zone == Zone.OPTIONS)
	_select_accion.visible = (_zone == Zone.ACTIONS)
	match _zone:
		Zone.LETTERS:
			if _in_letter_grid(_letter_col, _letter_row):
				_select_letra.position = (
					_letter_cell_center(_letter_col, _letter_row) + LETTER_CURSOR_NUDGE
				)
		Zone.OPTIONS:
			_select_opcion.position = _option_positions[_option_index]
		Zone.ACTIONS:
			_select_accion.position = _action_positions[_action_index]
	var key := _cursor_selection_key()
	if key != _cursor_flash_key:
		_cursor_flash_key = key
		_start_cursor_flash()
		_start_letter_cursor_pulse()


func _cursor_selection_key() -> String:
	match _zone:
		Zone.LETTERS:
			return "L:%d:%d" % [_letter_col, _letter_row]
		Zone.OPTIONS:
			return "O:%d" % _option_index
		Zone.ACTIONS:
			return "A:%d" % _action_index
	return ""


func _active_select() -> Sprite2D:
	match _zone:
		Zone.LETTERS:
			return _select_letra
		Zone.OPTIONS:
			return _select_opcion
		Zone.ACTIONS:
			return _select_accion
	return null


func _start_cursor_flash() -> void:
	if _cursor_flash_tween != null and is_instance_valid(_cursor_flash_tween):
		_cursor_flash_tween.kill()
	_cursor_flash_tween = null
	for spr in [_select_letra, _select_opcion, _select_accion]:
		spr.modulate = CURSOR_COLOR_RED
	var active := _active_select()
	if active == null or not active.visible:
		return
	_cursor_flash_tween = create_tween()
	_cursor_flash_tween.set_loops()
	## Empieza en rojo (hold) → amarillo → hold igual → vuelta a rojo.
	_cursor_flash_tween.tween_interval(CURSOR_FLASH_HOLD_SEC)
	_cursor_flash_tween.tween_property(
		active, "modulate", CURSOR_COLOR_YELLOW, CURSOR_FLASH_BLEND_SEC
	).set_trans(Tween.TRANS_LINEAR)
	_cursor_flash_tween.tween_interval(CURSOR_FLASH_HOLD_SEC)
	_cursor_flash_tween.tween_property(
		active, "modulate", CURSOR_COLOR_RED, CURSOR_FLASH_BLEND_SEC
	).set_trans(Tween.TRANS_LINEAR)


func _start_letter_cursor_pulse() -> void:
	if _letter_cursor_pulse_tween != null and is_instance_valid(_letter_cursor_pulse_tween):
		_letter_cursor_pulse_tween.kill()
	_letter_cursor_pulse_tween = null
	_select_letra.scale = Vector2.ONE
	if _zone != Zone.LETTERS or not _select_letra.visible:
		return
	var closed := Vector2(LETTER_CURSOR_CLOSED_SCALE, LETTER_CURSOR_CLOSED_SCALE)
	_letter_cursor_pulse_tween = create_tween()
	_letter_cursor_pulse_tween.set_loops()
	_letter_cursor_pulse_tween.tween_property(
		_select_letra, "scale", closed, LETTER_CURSOR_PULSE_HALF_SEC
	).set_trans(Tween.TRANS_LINEAR)
	_letter_cursor_pulse_tween.tween_property(
		_select_letra, "scale", Vector2.ONE, LETTER_CURSOR_PULSE_HALF_SEC
	).set_trans(Tween.TRANS_LINEAR)


func _setup_name_slots() -> void:
	_name_slots.clear()
	_name_chars.clear()
	_name_cursor = 0
	for i in range(1, MAX_NAME_LEN + 1):
		var slot := _caracters_root.get_node("Caracter%d" % i) as Label
		var letra := slot.get_node("Letra") as Label
		letra.visible = false
		letra.text = ""
		slot.text = "_"
		_name_slots.append({
			"slot": slot,
			"letra": letra,
			"rest_pos": slot.position,
		})


func _type_selected_letter() -> void:
	if _name_cursor >= MAX_NAME_LEN:
		return
	if not _in_letter_grid(_letter_col, _letter_row):
		return
	var source := _get_letter_at(_letter_col, _letter_row)
	## Celda vacía o Label sin texto → espacio (nombre en blanco en ese slot).
	var ch := " "
	if source != null and not source.text.is_empty():
		ch = source.text
	_name_chars.append(ch)
	_name_cursor += 1
	_refresh_name_slots_visual()
	_start_underscore_bob()


func _delete_previous_letter() -> void:
	if _name_chars.is_empty():
		return
	_name_chars.remove_at(_name_chars.size() - 1)
	_name_cursor = _name_chars.size()
	_refresh_name_slots_visual()
	_start_underscore_bob()


func _refresh_name_slots_visual() -> void:
	_stop_underscore_bob()
	for i in range(_name_slots.size()):
		var entry: Dictionary = _name_slots[i]
		var slot: Label = entry["slot"]
		var letra: Label = entry["letra"]
		slot.position = entry["rest_pos"]
		slot.text = "_"
		if i < _name_chars.size():
			letra.text = _name_chars[i]
			letra.visible = true
		else:
			letra.visible = false
			letra.text = ""


func _stop_underscore_bob() -> void:
	if _underscore_tween != null and is_instance_valid(_underscore_tween):
		_underscore_tween.kill()
	_underscore_tween = null
	for entry in _name_slots:
		(entry["slot"] as Label).position = entry["rest_pos"]


func _start_underscore_bob() -> void:
	_stop_underscore_bob()
	if _name_cursor < 0 or _name_cursor >= _name_slots.size():
		return
	var entry: Dictionary = _name_slots[_name_cursor]
	var slot: Label = entry["slot"]
	var rest: Vector2 = entry["rest_pos"]
	slot.position = rest
	_underscore_tween = create_tween()
	_underscore_tween.set_loops()
	_underscore_tween.tween_property(
		slot, "position:y", rest.y + UNDERSCORE_BOB_PX, UNDERSCORE_BOB_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_underscore_tween.tween_property(
		slot, "position:y", rest.y, UNDERSCORE_BOB_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_icon_hop() -> void:
	_icon_hop_phase = 0.0
	_icon_hop_up = false
	_apply_icon_hop()


func _apply_icon_hop() -> void:
	## Offset (no position): la sombra hija se queda en el suelo. Solo frame 0.
	_icon.frame = 0
	_icon.offset.y = -ICON_HOP_PX if _icon_hop_up else 0.0
