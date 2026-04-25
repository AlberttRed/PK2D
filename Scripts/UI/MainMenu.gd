extends Panel
class_name MainMenuUI

signal continue_requested()
signal new_game_requested()
signal options_requested()
signal quit_requested()

const TEX_BIG := preload("res://Sprites/UI/Main Menu/loadPanels_big.png")
const TEX_SMALL := preload("res://Sprites/UI/Main Menu/loadPanels_small.png")

## Textura: mitad superior = inactivo, mitad inferior = activo (misma altura que el panel en pantalla).
const BIG_REGION := Vector2(408, 222)
const SMALL_REGION := Vector2(408, 46)
## Aire bajo el último panel al hacer scroll hacia abajo (px). También alarga ligeramente el rango de scroll.
const LIST_BOTTOM_INSET_PX: float = 28.0
## Misma idea que `party_animations/PARTY_pkmn_icon` (icono 0↔1); periodo aprox. para alternar `frame` en el Sprite2D.
const _PARTY_ICON_FLIP_SEC: float = 0.1333

@onready var _list_viewport: Control = $Control/MenuListViewport
@onready var _vbox: VBoxContainer = $Control/MenuListViewport/VBoxContainer
@onready var _continue_panel: Panel = $"Control/MenuListViewport/VBoxContainer/Continue"
@onready var _new_game_panel: Panel = $"Control/MenuListViewport/VBoxContainer/New game"
@onready var _options_panel: Panel = $Control/MenuListViewport/VBoxContainer/Options
@onready var _quit_panel: Panel = $Control/MenuListViewport/VBoxContainer/Quit

@onready var _route_label = $Control/MenuListViewport/VBoxContainer/Continue/Route
@onready var _name_label = $Control/MenuListViewport/VBoxContainer/Continue/Name
@onready var _medals_data_label = $Control/MenuListViewport/VBoxContainer/Continue/Stats/Medals/Data
@onready var _pokedex_data_label = $Control/MenuListViewport/VBoxContainer/Continue/Stats/Pokedex/Data
@onready var _time_data_label = $Control/MenuListViewport/VBoxContainer/Continue/Stats/Time/Data
@onready var _continue_sprite: AnimatedSprite2D = $Control/MenuListViewport/VBoxContainer/Continue/Sprite
@onready var _party_sprites: Array[Sprite2D] = [
	$"Control/MenuListViewport/VBoxContainer/Continue/Party/Row/pkmn1",
	$"Control/MenuListViewport/VBoxContainer/Continue/Party/Row/pkmn2",
	$"Control/MenuListViewport/VBoxContainer/Continue/Party/Row2/pkmn3",
	$"Control/MenuListViewport/VBoxContainer/Continue/Party/Row2/pkmn4",
	$"Control/MenuListViewport/VBoxContainer/Continue/Party/Row3/pkmn5",
	$"Control/MenuListViewport/VBoxContainer/Continue/Party/Row3/pkmn6",
]

var _style_big_inactive: StyleBoxTexture
var _style_big_active: StyleBoxTexture
var _style_small_inactive: StyleBoxTexture
var _style_small_active: StyleBoxTexture

## Panel ordenado en lista de menú; índice alineado con _selectable.
var _menu_panels: Array[Panel] = []
var _selected_index: int = 0
## true = región de textura "grande" (Continue); false = filas pequeñas.
var _panel_is_big: Array[bool] = []

## Scroll estilo mochila/Pokédex: lista más alta que el viewport, se desplaza con Y negativa (clip en MenuListViewport).
## El margen superior es la `position.y` del VBox en la escena (no se fuerza en código; así el editor refleja el layout).
var _list_scroll_y: float = 0.0
var _vbox_base_y: float = 0.0
var _party_icon_frame_phase: float = 0.0
var _party_icon_process_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vbox_base_y = _vbox.position.y
	set_process(false)
	if _list_viewport:
		_list_viewport.resized.connect(_on_list_viewport_resized)
		_list_viewport.gui_input.connect(_on_list_viewport_gui_input)
	_apply_mouse_filter_no_clicks()
	_build_styleboxes()
	refresh_continue_panel()
	call_deferred("_deferred_sync_list")


## Navegación solo teclado (HGSS): no hay selección con ratón. El root STOP bloquea clics al juego; filas en IGNORE.
func _apply_mouse_filter_no_clicks() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Rueda para el scroll; los paneles de opción no reaccionan al clic.
	if _list_viewport:
		_list_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	if _continue_panel:
		_continue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _new_game_panel:
		_new_game_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _options_panel:
		_options_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _quit_panel:
		_quit_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not _party_icon_process_active or not is_visible_in_tree():
		return
	_party_icon_frame_phase += delta
	if _party_icon_frame_phase < _PARTY_ICON_FLIP_SEC:
		return
	_party_icon_frame_phase = 0.0
	for s: Sprite2D in _party_sprites:
		if s.visible and s.texture != null and s.hframes > 1:
			s.frame = 1 - s.frame


func _on_list_viewport_resized() -> void:
	_list_scroll_y = clampf(_list_scroll_y, 0.0, _max_list_scroll())
	_apply_list_scroll()


func _on_list_viewport_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var step := 48.0
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_list_scroll_y -= step
			else:
				_list_scroll_y += step
			_apply_list_scroll()
			get_viewport().set_input_as_handled()


func _build_styleboxes() -> void:
	_style_big_inactive = _stylebox_split(TEX_BIG, BIG_REGION, 0)
	_style_big_active = _stylebox_split(TEX_BIG, BIG_REGION, 1)
	_style_small_inactive = _stylebox_split(TEX_SMALL, SMALL_REGION, 0)
	_style_small_active = _stylebox_split(TEX_SMALL, SMALL_REGION, 1)


func _stylebox_split(tex: Texture2D, cell: Vector2, row_index: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.region_rect = Rect2(0, float(row_index) * cell.y, cell.x, cell.y)
	return sb


func _apply_panel_selected(panel: Panel, selected: bool) -> void:
	var idx: int = _menu_panels.find(panel)
	if idx < 0:
		return
	var is_big: bool = _panel_is_big[idx] if idx < _panel_is_big.size() else false
	if is_big:
		panel.add_theme_stylebox_override("panel", _style_big_active if selected else _style_big_inactive)
	else:
		panel.add_theme_stylebox_override("panel", _style_small_active if selected else _style_small_inactive)


func _rebuild_menu_list() -> void:
	_menu_panels.clear()
	_panel_is_big.clear()
	if _continue_panel.visible:
		_menu_panels.append(_continue_panel)
		_panel_is_big.append(true)
	_menu_panels.append(_new_game_panel)
	_panel_is_big.append(false)
	_menu_panels.append(_options_panel)
	_panel_is_big.append(false)
	_menu_panels.append(_quit_panel)
	_panel_is_big.append(false)
	_selected_index = clampi(_selected_index, 0, max(0, _menu_panels.size() - 1))
	_refresh_all_panel_styles()
	call_deferred("_deferred_sync_list")
	_ensure_selection_visible()


func _refresh_all_panel_styles() -> void:
	for i in range(_menu_panels.size()):
		_apply_panel_selected(_menu_panels[i], i == _selected_index)


func _sync_vbox_min_width() -> void:
	if _vbox == null or _list_viewport == null:
		return
	var w: float = maxf(512.0, _list_viewport.size.x)
	_vbox.custom_minimum_size = Vector2(w, 0.0)


## Altura lógica de la columna: combined minimum del VBox o suma fija por filas.
func _get_list_content_height() -> float:
	_sync_vbox_min_width()
	var ms: float = _vbox.get_combined_minimum_size().y
	if ms > 1.0:
		return ms
	var h: float = 0.0
	if _continue_panel.visible:
		h += _continue_panel.custom_minimum_size.y
	h += _new_game_panel.custom_minimum_size.y
	h += _options_panel.custom_minimum_size.y
	h += _quit_panel.custom_minimum_size.y
	var row_count := 4 if _continue_panel.visible else 3
	var sep: float = float(_vbox.get_theme_constant("separation", "VBoxContainer"))
	h += sep * float(max(0, row_count - 1))
	return h


func _max_list_scroll() -> float:
	var h: float = _get_list_content_height()
	var view: float = _list_viewport.size.y
	# +LIST_BOTTOM_INSET: permite bajar un poco más y no pegar el último fila al borde inferior del clip.
	return maxf(0.0, _vbox_base_y + h + LIST_BOTTOM_INSET_PX - view)


func _apply_list_scroll() -> void:
	if _vbox == null or _list_viewport == null:
		return
	_list_scroll_y = clampf(_list_scroll_y, 0.0, _max_list_scroll())
	_vbox.position = Vector2(_vbox.position.x, _vbox_base_y - _list_scroll_y)


## Coloca el scroll para que el panel quede visible dentro del viewport (como listas con cursor en BAG).
## Con margen B en Y, el S válido para un panel va en [B + y1 − H,  B + y0] (intersectado con [0, max]).
## Antes, al "subir" al primer fila con y0=0, se hacía S = B+0, que pone el listado en y=0 y no vuelve al reposo (S=0, margen = position.y del VBox en la escena).
func _scroll_list_to_show_panel(panel: Control) -> void:
	if _list_viewport == null or panel == null:
		return
	var y0: float = panel.position.y
	var y1: float = y0 + panel.size.y
	var H: float = _list_viewport.size.y
	if H <= 0.0:
		return
	var B: float = _vbox_base_y
	# B − S + y0 ≥ 0  ⇔  S ≤ B + y0
	# B − S + y1 ≤ H − LIST_BOTTOM_INSET  ⇔  S ≥ B + y1 − H + LIST_BOTTOM_INSET
	var s_lo: float = B + y1 - H + LIST_BOTTOM_INSET_PX
	var s_hi: float = B + y0
	var s_new: float
	if s_lo <= s_hi:
		s_new = clampf(_list_scroll_y, s_lo, s_hi)
	else:
		# Toda la fila no cabe: prioridad al borde superior en coordenadas de lista
		s_new = s_hi
	# Primer fila (Continuar o primera opción): scroll 0 = posición "reposo" con margen; no reutilizar s_hi = B.
	if _menu_panels.size() > 0 and panel == _menu_panels[0] and (y1 - y0) <= H + 0.5:
		s_new = 0.0
	_list_scroll_y = clampf(s_new, 0.0, _max_list_scroll())
	_apply_list_scroll()


func _deferred_sync_list() -> void:
	_sync_vbox_min_width()
	await get_tree().process_frame
	_sync_vbox_min_width()
	_list_scroll_y = clampf(_list_scroll_y, 0.0, _max_list_scroll())
	_apply_list_scroll()


func _ensure_selection_visible() -> void:
	if _list_viewport == null or _menu_panels.is_empty():
		return
	if _selected_index < 0 or _selected_index >= _menu_panels.size():
		return
	await get_tree().process_frame
	_sync_vbox_min_width()
	await get_tree().process_frame
	var panel: Control = _menu_panels[_selected_index]
	_scroll_list_to_show_panel(panel)


func refresh_continue_panel() -> void:
	var metadata: Dictionary = GameStateService.get_save_metadata(0)
	var has_continue := bool(metadata.get("ok", false))
	_continue_panel.visible = has_continue
	if not has_continue:
		_set_label_text(_route_label, "—")
		_set_label_text(_name_label, "PLAYER")
		_set_label_text(_medals_data_label, "0")
		_set_label_text(_pokedex_data_label, "0")
		_set_label_text(_time_data_label, "00:00")
		_clear_party_sprites()
		_set_continue_sprite_active(false)
	else:
		_set_label_text(_route_label, str(metadata.get("route_text", "—")))
		_set_label_text(_name_label, str(metadata.get("player_name", "PLAYER")))
		_set_label_text(_medals_data_label, str(metadata.get("badges", "0")))
		_set_label_text(_pokedex_data_label, str(metadata.get("pokedex_caught", "0")))
		_set_label_text(_time_data_label, str(metadata.get("play_time", "00:00")))
		_apply_party_sprites_from_save()
		_set_continue_sprite_active(true)
	_rebuild_menu_list()


func _set_continue_sprite_active(active: bool) -> void:
	if _continue_sprite == null:
		return
	if active:
		if _continue_sprite.sprite_frames != null and _continue_sprite.sprite_frames.has_animation("default"):
			_continue_sprite.play("default")
		else:
			_continue_sprite.play()
	else:
		_continue_sprite.stop()

func _clear_party_sprites() -> void:
	_party_icon_process_active = false
	_party_icon_frame_phase = 0.0
	set_process(_party_icon_process_active)
	for s: Sprite2D in _party_sprites:
		s.visible = false
		s.texture = null


## Iconos 2f desde el guardado (mismo `get_icon_sprite()` y animación 0/1 que PartyPokemonPanel, sin depender de AnimationPlayer de la ficha).
func _apply_party_sprites_from_save() -> void:
	var mons: Array[Pokemon] = GameStateService.get_save_party_preview_pokemon(0)
	var any: bool = false
	for i: int in range(_party_sprites.size()):
		var s: Sprite2D = _party_sprites[i]
		if i < mons.size() and mons[i] != null:
			var at: Texture2D = mons[i].get_icon_sprite()
			s.texture = at
			s.hframes = 2
			s.vframes = 1
			s.frame = 0
			s.centered = false
			s.visible = true
			any = true
		else:
			s.visible = false
			s.texture = null
	_party_icon_process_active = any
	_party_icon_frame_phase = 0.0
	set_process(_party_icon_process_active)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _menu_panels.is_empty():
		return
	if event.is_action_pressed("ui_down"):
		_selected_index = (_selected_index + 1) % _menu_panels.size()
		_refresh_all_panel_styles()
		_ensure_selection_visible()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_selected_index = (_selected_index - 1 + _menu_panels.size()) % _menu_panels.size()
		_refresh_all_panel_styles()
		_ensure_selection_visible()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()


func _confirm_selection() -> void:
	if _selected_index < 0 or _selected_index >= _menu_panels.size():
		return
	var p: Panel = _menu_panels[_selected_index]
	if p == _continue_panel:
		continue_requested.emit()
	elif p == _new_game_panel:
		new_game_requested.emit()
	elif p == _options_panel:
		options_requested.emit()
	elif p == _quit_panel:
		quit_requested.emit()


func _set_label_text(node: Node, text: String) -> void:
	if node == null:
		return
	if node.has_method("setText"):
		node.setText(text)
	elif node is Label:
		(node as Label).text = text
