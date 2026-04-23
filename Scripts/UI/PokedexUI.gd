extends Panel
class_name PokedexUI

signal back_requested()
signal closed()

const _VISIBLE_ROWS: int = 9
const _REGION_EXIT_INDEX: int = 3
const _SLIDER_MIN_POS: Vector2 = Vector2(488.0, 90.0)
const _SLIDER_MAX_POS: Vector2 = Vector2(488.0, 278.0)
const _ARROW_ANIM_FPS: float = 18.0
const _NAV_HOLD_INITIAL_DELAY: float = 0.28
const _NAV_HOLD_REPEAT_INTERVAL: float = 0.075
const _FORM_ICON_ANIM_FPS: float = 4.0
const _UNKNOWN_POKEMON_SPRITE: Texture2D = preload("res://Sprites/Pictures/000.png")
const _SEARCH_DATA_VISIBLE_ROWS: int = 6
const _SEARCH_DESCRIPTIONS: Array[String] = [
	"Listar por primera letra del nombre. Solamente los vistos.",
	"Listar por color del cuerpo. Solamente los vistos.",
	"Listar por tipo. Solamente atrapados.",
	"Listar por tipo. Solamente atrapados.",
	"Seleccionar el modo de listado.",
	"Ejecutar búsqueda.",
	"Seleccionar el modo de listado.",
	"Ejecutar ordenamiento.",
]
const _SEARCH_ORDER_MODE_DESCRIPTIONS: Array[String] = [
	"Los Pokémon se listan según su número.",
	"Los Pokémon vistos y atrapados se listan alfabéticamente.",
	"Los Pokémon vistos y atrapados se listan de pesado a ligero.",
	"Los Pokémon vistos y atrapados se listan de ligero a pesado.",
	"Vistos y atrapados: de mayor a menor altura.",
	"Vistos y atrapados: de menor a mayor altura.",
]

enum ViewMode {
	REGIONS,
	LIST,
	ENTRY,
	SEARCH,
}

enum DetailPanel {
	ENTRY,
	NEST,
	FORM,
}

var _controller = null
var _input_enabled: bool = false
var _selected_index: int = 0
var _selected_region_index: int = 0
var _view_mode: ViewMode = ViewMode.REGIONS
var _active_detail_panel: DetailPanel = DetailPanel.ENTRY

@onready var _regions_panel: VBoxContainer = $PokedexRegions
@onready var _regions_cursor: Sprite2D = $RegionCursor
@onready var _selection_cursor: Sprite2D = $PokedexList/Selection
@onready var _slider: Sprite2D = $PokedexList/Slider
@onready var _up_arrow: Sprite2D = $PokedexList/U_Arrow
@onready var _down_arrow: Sprite2D = $PokedexList/D_Arrow
@onready var _rows_container: VBoxContainer = $PokedexList/ListViewport/ListConainer
@onready var _row_template: HBoxContainer = $PokedexList/ListViewport/ListConainer/PokemonRow
@onready var _detail_name = $PokedexList/Nombre
@onready var _detail_sprite: Sprite2D = $PokedexList/Sprite
@onready var _seen_count = $PokedexList/dVistos
@onready var _caught_count = $PokedexList/dPropios
@onready var _title = $PokedexList/Titulo
@onready var _entry_panel: Panel = $PokedexEntry
@onready var _entry_name = $PokedexEntry/Nombre
@onready var _entry_category = $PokedexEntry/Categoria
@onready var _entry_description = $PokedexEntry/"Descripción"
@onready var _entry_height = $PokedexEntry/dAltura
@onready var _entry_weight = $PokedexEntry/dPeso
@onready var _entry_sprite: Sprite2D = $PokedexEntry/Sprite
@onready var _entry_type1: Sprite2D = $PokedexEntry/tipo1
@onready var _entry_type2: Sprite2D = $PokedexEntry/tipo2
@onready var _entry_footprint: Sprite2D = $PokedexEntry/Footprint
@onready var _entry_owned: Sprite2D = $PokedexEntry/Owned
@onready var _nest_panel: Panel = $PokedexNest
@onready var _nest_region = $PokedexNest/Region
@onready var _nest_title = $PokedexNest/Nido
@onready var _form_panel: Panel = $PokedexForm
@onready var _form_front: Sprite2D = $PokedexForm/front
@onready var _form_back: Sprite2D = $PokedexForm/front2back
@onready var _form_icon: Sprite2D = $PokedexForm/icono
@onready var _form_name = $PokedexForm/Nombre
@onready var _form_gender = $PokedexForm/Genero
@onready var _search_panel: Panel = $PokedexSearch
@onready var _search_cursor: Sprite2D = $PokedexSearch/SearchCursor
@onready var _search_description = $PokedexSearch/Descripcion
@onready var _search_data_cursor: Sprite2D = $PokedexSearch/Datos/DataCursor
@onready var _search_data_list: VBoxContainer = $PokedexSearch/Datos/ListDatos
@onready var _search_data_row_template: HBoxContainer = $PokedexSearch/Datos/ListDatos/RowDato
@onready var _search_data_up_arrow: Sprite2D = $PokedexSearch/Datos/U_Arrow
@onready var _search_data_down_arrow: Sprite2D = $PokedexSearch/Datos/D_Arrow
@onready var _search_d_nombre = $PokedexSearch/Busqueda/dNombre
@onready var _search_d_color = $PokedexSearch/Busqueda/dColor
@onready var _search_d_tipo1 = $PokedexSearch/Busqueda/dTipo1
@onready var _search_d_tipo2 = $PokedexSearch/Busqueda/dTIpo2
@onready var _search_d_orden_busqueda = $PokedexSearch/Busqueda/dOrden
@onready var _search_d_orden_ordenamiento = $PokedexSearch/Ordenamiento/dOrden

var _rows: Array[HBoxContainer] = []
var _region_rows: Array[HBoxContainer] = []
var _search_targets: Array[Control] = []
var _search_data_rows: Array[HBoxContainer] = []
var _region_cursor_base_x: float = 0.0
var _selection_base_y: float = 0.0
var _rows_base_pos: Vector2 = Vector2.ZERO
var _arrow_anim_time: float = 0.0
var _held_nav_dir: int = 0
var _held_nav_elapsed: float = 0.0
var _held_nav_next_repeat: float = _NAV_HOLD_INITIAL_DELAY
var _form_icon_anim_time: float = 0.0
var _form_gender_choice_open: bool = false
var _form_gender_options: Array[String] = []
var _form_gender_values: Array[int] = []
var _form_gender_preview_index: int = 0
var _owner_white_material: ShaderMaterial = null
var _selected_search_index: int = 0
var _search_data_options: Array[String] = []
var _selected_search_data_index: int = 0
var _search_data_focus: bool = false
var _search_selected_option_by_level: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	set_process(false)
	$PokedexRegions.show()
	$PokedexList.hide()
	_search_panel.hide()
	_entry_panel.hide()
	_form_panel.hide()
	_nest_panel.hide()
	_collect_rows()
	_collect_region_rows()
	_collect_search_targets()
	_collect_search_data_rows()
	if _regions_cursor != null:
		_region_cursor_base_x = _regions_cursor.position.x
	if _selection_cursor != null:
		_selection_base_y = _selection_cursor.position.y
	if _rows_container != null:
		_rows_base_pos = _rows_container.position
	if _title != null:
		if _title.has_method("setText"):
			_title.setText("Pokédex")
		else:
			_title.text = "Pokédex"
	_owner_white_material = _build_owner_white_material()


func setup(controller) -> void:
	_controller = controller


func open() -> void:
	if _controller == null:
		push_error("PokedexUI: No se puede abrir sin controller.")
		return
	show()
	set_process(true)
	_arrow_anim_time = 0.0
	_reset_held_navigation()
	_selected_index = 0
	_selected_region_index = 0
	_selected_search_index = 0
	_selected_search_data_index = 0
	_search_data_focus = false
	_view_mode = ViewMode.REGIONS
	_active_detail_panel = DetailPanel.ENTRY
	_controller.refresh()
	_render_regions()
	_enable_input()
	_block_player_control()


func close() -> void:
	if not visible:
		return
	_disable_input()
	set_process(false)
	_reset_arrow_frames()
	_reset_held_navigation()
	hide()
	_unblock_player_control()
	closed.emit()


func _collect_rows() -> void:
	_rows.clear()
	if _rows_container == null:
		return
	for child in _rows_container.get_children():
		if child is HBoxContainer:
			_rows.append(child as HBoxContainer)


func _collect_region_rows() -> void:
	_region_rows.clear()
	if _regions_panel == null:
		return
	for child in _regions_panel.get_children():
		if child is HBoxContainer:
			_region_rows.append(child as HBoxContainer)


func _render() -> void:
	if _view_mode != ViewMode.LIST:
		return
	var total: int = int(_controller.get_entry_count())
	if total <= 0:
		_render_rows(0)
		_update_list_scroll_arrows(0, 0)
		_update_selection_cursor()
		_update_slider(1)
		return
	var nav_total: int = int(_controller.get_navigation_limit_count())
	nav_total = clampi(nav_total, 1, total)
	_selected_index = clampi(_selected_index, 0, nav_total - 1)

	var seen_count: int = int(_controller.get_seen_count())
	var caught_count: int = int(_controller.get_caught_count())
	if _title != null:
		var title_text: String = str(_controller.get_active_dex_name())
		if _title.has_method("setText"):
			_title.setText(title_text)
		else:
			_title.text = title_text
	if _seen_count != null:
		if _seen_count.has_method("setText"):
			_seen_count.setText(str(seen_count))
		else:
			_seen_count.text = str(seen_count)
	if _caught_count != null:
		if _caught_count.has_method("setText"):
			_caught_count.setText(str(caught_count))
		else:
			_caught_count.text = str(caught_count)

	var scroll_top := _compute_scroll_top(total, _selected_index)
	_render_rows(scroll_top)
	_update_list_scroll_arrows(scroll_top, nav_total)
	_render_detail()
	_update_selection_cursor()
	_update_slider(nav_total)


func _input(event: InputEvent) -> void:
	if not _input_enabled or not visible:
		return
	if event.is_action_pressed("f5"):
		if _view_mode == ViewMode.LIST:
			_enter_search_mode()
			get_viewport().set_input_as_handled()
			return
		if _view_mode == ViewMode.SEARCH:
			_enter_list_mode(true)
			get_viewport().set_input_as_handled()
			return


func _render_rows(scroll_top: int) -> void:
	for row_idx in range(_rows.size()):
		var row: HBoxContainer = _rows[row_idx]
		var item_index := scroll_top + row_idx
		var label = row.get_node_or_null("Nombre")
		var owned_icon_rect := row.get_node_or_null("OwnedIcon") as TextureRect
		if item_index >= _controller.get_entry_count():
			if label != null:
				if label.has_method("setText"):
					label.setText("")
				else:
					label.text = ""
			if owned_icon_rect != null:
				owned_icon_rect.visible = true
				owned_icon_rect.material = null
				var c_empty := owned_icon_rect.self_modulate
				c_empty.a = 0.0
				owned_icon_rect.self_modulate = c_empty
			continue

		var item: Dictionary = _controller.get_list_entry(item_index)
		var dex_number := int(item.get("dex_number", 0))
		var seen := bool(item.get("seen", false))
		var caught := bool(item.get("caught", false))
		var display_name := str(item.get("name", "---------")) if seen else "---------"
		var row_text := "%03d %s" % [dex_number, display_name]
		if label != null:
			if label.has_method("setText"):
				label.setText(row_text)
			else:
				label.text = row_text
		if owned_icon_rect != null:
			owned_icon_rect.visible = true
			if caught:
				owned_icon_rect.material = null
				var c_caught := owned_icon_rect.self_modulate
				c_caught.a = 1.0
				owned_icon_rect.self_modulate = c_caught
			elif seen:
				owned_icon_rect.material = _owner_white_material
				var c_seen := owned_icon_rect.self_modulate
				c_seen.a = 1.0
				owned_icon_rect.self_modulate = c_seen
			else:
				owned_icon_rect.material = null
				var c := owned_icon_rect.self_modulate
				c.a = 0.0
				owned_icon_rect.self_modulate = c


func _render_detail() -> void:
	var detail: Dictionary = _controller.get_detail_for_index(_selected_index)
	var is_seen: bool = bool(detail.get("seen", false))
	var detail_text: String = str(detail.get("name", "---------")) if is_seen else "---------"
	if _detail_name != null:
		if _detail_name.has_method("setText"):
			_detail_name.setText(detail_text)
		else:
			_detail_name.text = detail_text
	if _detail_sprite != null:
		if is_seen:
			var sprite_tex: Texture2D = detail.get("sprite", null)
			_detail_sprite.texture = sprite_tex
			_detail_sprite.visible = sprite_tex != null
		else:
			_detail_sprite.texture = _UNKNOWN_POKEMON_SPRITE
			_detail_sprite.visible = _UNKNOWN_POKEMON_SPRITE != null


func _update_list_scroll_arrows(scroll_top: int, item_count: int) -> void:
	if _up_arrow == null or _down_arrow == null:
		return
	if item_count <= _VISIBLE_ROWS:
		_up_arrow.visible = false
		_down_arrow.visible = false
		_reset_arrow_frames()
		return
	var max_scroll_top: int = max(item_count - _VISIBLE_ROWS, 0)
	_up_arrow.visible = scroll_top > 0
	_down_arrow.visible = scroll_top < max_scroll_top
	if not _up_arrow.visible:
		_up_arrow.frame = 0
	if not _down_arrow.visible:
		_down_arrow.frame = 0


func _process(delta: float) -> void:
	if not visible:
		return
	_update_held_navigation(delta)
	_update_form_icon_animation(delta)
	var has_visible_arrows := (
		(_up_arrow != null and _up_arrow.visible)
		or (_down_arrow != null and _down_arrow.visible)
		or (_search_data_up_arrow != null and _search_data_up_arrow.visible)
		or (_search_data_down_arrow != null and _search_data_down_arrow.visible)
	)
	if not has_visible_arrows:
		return
	_arrow_anim_time += delta
	var frame_count := _get_arrow_frame_count()
	var period := 1.0 / max(_ARROW_ANIM_FPS, 0.001)
	var frame := int(floor(_arrow_anim_time / period)) % frame_count
	if _up_arrow and _up_arrow.visible:
		_up_arrow.frame = frame
	if _down_arrow and _down_arrow.visible:
		_down_arrow.frame = frame
	if _search_data_up_arrow and _search_data_up_arrow.visible:
		_search_data_up_arrow.frame = frame
	if _search_data_down_arrow and _search_data_down_arrow.visible:
		_search_data_down_arrow.frame = frame


func _get_arrow_frame_count() -> int:
	var counts: Array[int] = []
	if _up_arrow:
		counts.append(max(_up_arrow.hframes * _up_arrow.vframes, 1))
	if _down_arrow:
		counts.append(max(_down_arrow.hframes * _down_arrow.vframes, 1))
	if _search_data_up_arrow:
		counts.append(max(_search_data_up_arrow.hframes * _search_data_up_arrow.vframes, 1))
	if _search_data_down_arrow:
		counts.append(max(_search_data_down_arrow.hframes * _search_data_down_arrow.vframes, 1))
	if counts.is_empty():
		return 8
	var frame_count := counts[0]
	for c in counts:
		frame_count = max(frame_count, c)
	return frame_count


func _reset_arrow_frames() -> void:
	if _up_arrow:
		_up_arrow.frame = 0
	if _down_arrow:
		_down_arrow.frame = 0
	if _search_data_up_arrow:
		_search_data_up_arrow.frame = 0
	if _search_data_down_arrow:
		_search_data_down_arrow.frame = 0


func _update_slider(navigable_count: int) -> void:
	if _slider == null:
		return
	if navigable_count <= 1:
		_slider.position = _SLIDER_MIN_POS
		return
	var t: float = float(_selected_index) / float(navigable_count - 1)
	_slider.position = Vector2(
		lerpf(_SLIDER_MIN_POS.x, _SLIDER_MAX_POS.x, t),
		lerpf(_SLIDER_MIN_POS.y, _SLIDER_MAX_POS.y, t)
	)


func _update_selection_cursor() -> void:
	if _selection_cursor == null:
		return
	var spacing_y := _get_row_spacing()
	var row := mini(_selected_index, _VISIBLE_ROWS - 1)
	_selection_cursor.position.y = _selection_base_y + float(row) * spacing_y


func _get_row_spacing() -> float:
	if _row_template == null:
		return 32.0
	var row_height := float(_row_template.custom_minimum_size.y)
	var separation := float(_rows_container.get_theme_constant("separation", "VBoxContainer"))
	return row_height + separation


func _compute_scroll_top(item_count: int, selected_index: int) -> int:
	if item_count <= _VISIBLE_ROWS:
		return 0
	var max_top := item_count - _VISIBLE_ROWS
	var desired_top := selected_index - (_VISIBLE_ROWS - 1)
	return clampi(desired_top, 0, max_top)


func _navigate_up() -> void:
	if _view_mode == ViewMode.REGIONS:
		_selected_region_index -= 1
		if _selected_region_index < 0:
			_selected_region_index = _REGION_EXIT_INDEX
		_render_regions()
		return
	if _view_mode == ViewMode.ENTRY:
		_navigate_discovered_in_detail(-1)
		return
	if _view_mode == ViewMode.SEARCH:
		if _search_data_focus:
			_navigate_search_data(-1)
			return
		if not _search_targets.is_empty():
			_selected_search_index -= 1
			if _selected_search_index < 0:
				_selected_search_index = _search_targets.size() - 1
			_update_search_cursor_position()
		return
	var total: int = int(_controller.get_navigation_limit_count())
	if total <= 0:
		return
	_selected_index -= 1
	if _selected_index < 0:
		_selected_index = total - 1
	_render()


func _navigate_down() -> void:
	if _view_mode == ViewMode.REGIONS:
		_selected_region_index += 1
		if _selected_region_index > _REGION_EXIT_INDEX:
			_selected_region_index = 0
		_render_regions()
		return
	if _view_mode == ViewMode.ENTRY:
		_navigate_discovered_in_detail(1)
		return
	if _view_mode == ViewMode.SEARCH:
		if _search_data_focus:
			_navigate_search_data(1)
			return
		if not _search_targets.is_empty():
			_selected_search_index += 1
			if _selected_search_index >= _search_targets.size():
				_selected_search_index = 0
			_update_search_cursor_position()
		return
	var total: int = int(_controller.get_navigation_limit_count())
	if total <= 0:
		return
	_selected_index += 1
	if _selected_index >= total:
		_selected_index = 0
	_render()


func _request_back() -> void:
	back_requested.emit()


func _enable_input() -> void:
	if _input_enabled:
		return
	_input_enabled = true
	var dm := DisplayManager.instance
	if dm == null:
		push_error("PokedexUI: DisplayManager no disponible.")
		return
	dm.input_up.connect(_on_input_up)
	dm.input_down.connect(_on_input_down)
	dm.input_left.connect(_on_input_left)
	dm.input_right.connect(_on_input_right)
	dm.input_accept.connect(_on_input_accept)
	dm.input_cancel.connect(_on_input_cancel)
	dm.input_start.connect(_on_input_start)


func _disable_input() -> void:
	if not _input_enabled:
		return
	_input_enabled = false
	var dm := DisplayManager.instance
	if dm == null:
		return
	if dm.input_up.is_connected(_on_input_up):
		dm.input_up.disconnect(_on_input_up)
	if dm.input_down.is_connected(_on_input_down):
		dm.input_down.disconnect(_on_input_down)
	if dm.input_left.is_connected(_on_input_left):
		dm.input_left.disconnect(_on_input_left)
	if dm.input_right.is_connected(_on_input_right):
		dm.input_right.disconnect(_on_input_right)
	if dm.input_accept.is_connected(_on_input_accept):
		dm.input_accept.disconnect(_on_input_accept)
	if dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.disconnect(_on_input_cancel)
	if dm.input_start.is_connected(_on_input_start):
		dm.input_start.disconnect(_on_input_start)


func _on_input_up() -> void:
	if _input_enabled:
		_reset_held_navigation()
		_navigate_up()


func _on_input_down() -> void:
	if _input_enabled:
		_reset_held_navigation()
		_navigate_down()


func _on_input_left() -> void:
	if not _input_enabled:
		return
	if _view_mode == ViewMode.SEARCH:
		if _search_data_focus:
			_cancel_search_data_selection()
		return
	if _view_mode == ViewMode.ENTRY:
		_shift_detail_panel(-1)


func _on_input_right() -> void:
	if not _input_enabled:
		return
	if _view_mode == ViewMode.SEARCH:
		if _selected_search_index == 5 or _selected_search_index == 7:
			return
		if _search_data_focus:
			_commit_search_data_selection()
		else:
			_search_data_focus = true
			_load_search_data_options_for_current_level()
			_update_search_data_cursor_position()
		return
	if _view_mode == ViewMode.ENTRY:
		_shift_detail_panel(1)


func _on_input_accept() -> void:
	if not _input_enabled:
		return
	if _view_mode == ViewMode.REGIONS:
		_accept_region_selection()
		return
	if _view_mode == ViewMode.LIST:
		_accept_list_selection()
		return
	if _view_mode == ViewMode.SEARCH:
		if _selected_search_index == 5:
			await _execute_search_filters()
			return
		if _selected_search_index == 7:
			await _execute_search_sorting()
			return
		if _search_data_focus:
			_commit_search_data_selection()
		else:
			_search_data_focus = true
			_load_search_data_options_for_current_level()
			_update_search_data_cursor_position()
		return
	if _view_mode == ViewMode.ENTRY:
		if _active_detail_panel == DetailPanel.FORM:
			await _open_form_gender_choices()
		return


func _on_input_cancel() -> void:
	if not _input_enabled:
		return
	if _view_mode == ViewMode.ENTRY:
		_enter_list_mode(true)
		return
	if _view_mode == ViewMode.SEARCH:
		if _search_data_focus:
			_cancel_search_data_selection()
			return
		_enter_list_mode(true)
		return
	if _view_mode == ViewMode.LIST:
		if _controller != null and _controller.has_active_search_filters():
			_controller.clear_search_filters()
			_reset_search_filter_state()
			_selected_index = 0
			_render()
			return
		_enter_regions_mode()
		return
	_request_back()


func _on_input_start() -> void:
	if not _input_enabled:
		return
	if _view_mode == ViewMode.ENTRY:
		_enter_list_mode(true)
		return
	if _view_mode == ViewMode.SEARCH:
		if _search_data_focus:
			_cancel_search_data_selection()
			return
		_enter_list_mode(true)
		return
	if _view_mode == ViewMode.LIST:
		if _controller != null and _controller.has_active_search_filters():
			_controller.clear_search_filters()
			_reset_search_filter_state()
			_selected_index = 0
			_render()
			return
		_enter_regions_mode()
		return
	_request_back()


func _accept_region_selection() -> void:
	if _selected_region_index == _REGION_EXIT_INDEX:
		_request_back()
		return
	var result: Dictionary = _controller.try_select_region(_selected_region_index)
	if not bool(result.get("ok", false)):
		return
	_enter_list_mode()


func _accept_list_selection() -> void:
	var entry: Dictionary = _controller.get_list_entry(_selected_index)
	if entry.is_empty():
		return
	var seen: bool = bool(entry.get("seen", false))
	var caught: bool = bool(entry.get("caught", false))
	if not seen and not caught:
		return
	_enter_entry_mode()


func _enter_regions_mode() -> void:
	_view_mode = ViewMode.REGIONS
	$PokedexRegions.z_index = 0
	$PokedexList.z_index = -1
	_entry_panel.z_index = -1
	_nest_panel.z_index = -1
	_form_panel.z_index = -1
	$PokedexRegions.show()
	$PokedexList.hide()
	_search_panel.hide()
	_entry_panel.hide()
	_nest_panel.hide()
	_form_panel.hide()
	if _regions_cursor != null:
		_regions_cursor.show()
	if _up_arrow:
		_up_arrow.visible = false
	if _down_arrow:
		_down_arrow.visible = false
	_reset_arrow_frames()
	_render_regions()


func _enter_list_mode(keep_selection: bool = false) -> void:
	_view_mode = ViewMode.LIST
	$PokedexRegions.z_index = -1
	$PokedexList.z_index = 0
	_entry_panel.z_index = -1
	_nest_panel.z_index = -1
	_form_panel.z_index = -1
	$PokedexRegions.hide()
	$PokedexList.show()
	_search_panel.hide()
	_entry_panel.hide()
	_nest_panel.hide()
	_form_panel.hide()
	if _regions_cursor != null:
		_regions_cursor.hide()
	if _search_cursor != null:
		_search_cursor.hide()
	if _search_data_cursor != null:
		_search_data_cursor.hide()
	_search_data_focus = false
	_update_search_data_scroll_arrows()
	if not keep_selection:
		_selected_index = 0
	_render()


func _enter_entry_mode() -> void:
	_view_mode = ViewMode.ENTRY
	_active_detail_panel = DetailPanel.ENTRY
	$PokedexRegions.z_index = -1
	$PokedexList.z_index = -1
	_entry_panel.z_index = -1
	_nest_panel.z_index = -1
	_form_panel.z_index = -1
	$PokedexRegions.hide()
	$PokedexList.hide()
	_search_panel.hide()
	_entry_panel.hide()
	_nest_panel.hide()
	_form_panel.hide()
	if _regions_cursor != null:
		_regions_cursor.hide()
	if _search_cursor != null:
		_search_cursor.hide()
	if _search_data_cursor != null:
		_search_data_cursor.hide()
	_update_search_data_scroll_arrows()
	if _up_arrow:
		_up_arrow.visible = false
	if _down_arrow:
		_down_arrow.visible = false
	_reset_arrow_frames()
	_render_detail_panels()
	_apply_active_detail_panel()


func _enter_search_mode() -> void:
	_view_mode = ViewMode.SEARCH
	$PokedexRegions.z_index = -1
	$PokedexList.z_index = -1
	_search_panel.z_index = 0
	_entry_panel.z_index = -1
	_nest_panel.z_index = -1
	_form_panel.z_index = -1
	$PokedexRegions.hide()
	$PokedexList.hide()
	_search_panel.show()
	_entry_panel.hide()
	_nest_panel.hide()
	_form_panel.hide()
	if _regions_cursor != null:
		_regions_cursor.hide()
	if _search_cursor != null:
		_search_cursor.show()
	if _search_data_cursor != null:
		_search_data_cursor.show()
	_search_data_focus = false
	_update_search_data_scroll_arrows()
	_update_search_cursor_position()
	_update_search_data_cursor_position()
	if _up_arrow:
		_up_arrow.visible = false
	if _down_arrow:
		_down_arrow.visible = false
	_reset_arrow_frames()


func _render_entry() -> void:
	var list_entry: Dictionary = _controller.get_list_entry(_selected_index)
	if list_entry.is_empty():
		return
	var species_id: int = int(list_entry.get("species_id", 0))
	if species_id <= 0:
		return
	var data := DatabaseService.get_pokemon(species_id) as PokemonData
	if data == null:
		return
	var seen: bool = bool(list_entry.get("seen", false))
	var caught: bool = bool(list_entry.get("caught", false))
	if not seen and not caught:
		return

	_set_label_text(_entry_name, str(data.Name))
	var category_text := "Pokémon ?????"
	if caught:
		category_text = str(data.category).strip_edges()
		if category_text.is_empty():
			category_text = "Categoría desconocida"
	_set_label_text(_entry_category, category_text)
	if _entry_description != null:
		if caught:
			_set_label_text(_entry_description, _normalize_single_line_text(str(data.description)))
			_entry_description.visible = true
		else:
			_set_label_text(_entry_description, "")
			_entry_description.visible = false
	if caught:
		_set_label_text(_entry_height, _format_measure_value(float(data.height) / 10.0))
		_set_label_text(_entry_weight, _format_measure_value(float(data.weight) / 10.0))
	else:
		_set_label_text(_entry_height, "????.?")
		_set_label_text(_entry_weight, "????.?")
	_apply_entry_type_sprites(data, caught)

	if _entry_sprite != null:
		_entry_sprite.texture = data.battle_front_sprite
		_entry_sprite.visible = data.battle_front_sprite != null
	if _entry_footprint != null:
		_entry_footprint.texture = data.footprint_sprite
		_entry_footprint.visible = caught and _is_valid_footprint_texture(data.footprint_sprite)
	if _entry_owned != null:
		_entry_owned.visible = caught


func _render_nest(data: PokemonData) -> void:
	var dex_name: String = str(_controller.get_active_dex_name())
	var short_name := dex_name.replace("Pokédex ", "")
	_set_label_text(_nest_region, "Región de %s" % short_name)
	_set_label_text(_nest_title, "Nido de %s" % str(data.Name))


func _render_form(data: PokemonData) -> void:
	if _form_front != null:
		_form_front.texture = data.battle_front_sprite
		_form_front.visible = data.battle_front_sprite != null
	if _form_back != null:
		_form_back.texture = data.battle_back_sprite
		_form_back.visible = data.battle_back_sprite != null
	if _form_icon != null:
		_form_icon.texture = data.icon_sprite
		_form_icon.visible = data.icon_sprite != null
		_form_icon.frame = 0
		_form_icon_anim_time = 0.0
	_set_label_text(_form_name, str(data.Name))
	_setup_form_gender_options(data)
	_apply_form_gender_preview(_form_gender_preview_index)


func _render_detail_panels() -> void:
	var list_entry: Dictionary = _controller.get_list_entry(_selected_index)
	if list_entry.is_empty():
		return
	var species_id: int = int(list_entry.get("species_id", 0))
	if species_id <= 0:
		return
	var data := DatabaseService.get_pokemon(species_id) as PokemonData
	if data == null:
		return
	var seen: bool = bool(list_entry.get("seen", false))
	var caught: bool = bool(list_entry.get("caught", false))
	if not seen and not caught:
		return
	_render_entry()
	_render_nest(data)
	_render_form(data)


func _apply_active_detail_panel() -> void:
	_entry_panel.hide()
	_nest_panel.hide()
	_form_panel.hide()
	_entry_panel.z_index = -1
	_nest_panel.z_index = -1
	_form_panel.z_index = -1
	match _active_detail_panel:
		DetailPanel.ENTRY:
			_entry_panel.show()
			_entry_panel.z_index = 0
		DetailPanel.NEST:
			_nest_panel.show()
			_nest_panel.z_index = 0
		DetailPanel.FORM:
			_form_panel.show()
			_form_panel.z_index = 0


func _shift_detail_panel(direction: int) -> void:
	if _form_gender_choice_open:
		return
	var idx: int = int(_active_detail_panel) + direction
	idx = clampi(idx, int(DetailPanel.ENTRY), int(DetailPanel.FORM))
	_active_detail_panel = idx as DetailPanel
	_apply_active_detail_panel()


func _navigate_discovered_in_detail(direction: int) -> void:
	if _controller == null:
		return
	if _form_gender_choice_open:
		return
	var new_index := _selected_index
	if direction < 0:
		new_index = _controller.get_previous_discovered_index(_selected_index)
	else:
		new_index = _controller.get_next_discovered_index(_selected_index)
	if new_index < 0 or new_index == _selected_index:
		return
	_selected_index = new_index
	_render_detail_panels()
	_apply_active_detail_panel()


func _update_form_icon_animation(delta: float) -> void:
	if _form_icon == null:
		return
	if _view_mode != ViewMode.ENTRY:
		_form_icon.frame = 0
		_form_icon_anim_time = 0.0
		return
	if _active_detail_panel != DetailPanel.FORM:
		_form_icon.frame = 0
		_form_icon_anim_time = 0.0
		return
	if not _form_icon.visible:
		_form_icon.frame = 0
		_form_icon_anim_time = 0.0
		return
	var frame_count: int = maxi(int(_form_icon.hframes) * int(_form_icon.vframes), 1)
	if frame_count <= 1:
		_form_icon.frame = 0
		return
	_form_icon_anim_time += delta
	var period: float = 1.0 / maxf(_FORM_ICON_ANIM_FPS, 0.001)
	var frame: int = int(floor(_form_icon_anim_time / period)) % frame_count
	_form_icon.frame = frame


func _format_species_gender_text(data: PokemonData) -> String:
	if data == null:
		return "Desconocido"
	var rate: int = int(data.gender_rate)
	if rate < 0:
		return "Sin genero"
	if rate == 0:
		return "Solo macho"
	if rate >= 8:
		return "Solo hembra"
	return "Macho/Hembra"


func _apply_entry_type_sprites(data: PokemonData, show_types: bool) -> void:
	if data == null:
		return
	if not show_types:
		if _entry_type1 != null:
			_entry_type1.texture = null
			_entry_type1.visible = false
		if _entry_type2 != null:
			_entry_type2.texture = null
			_entry_type2.visible = false
		return
	var t1 := DatabaseService.get_type(data.type_a_id) as TypeData
	var t2 := DatabaseService.get_type(data.type_b_id) as TypeData
	if _entry_type1 != null:
		_entry_type1.texture = t1.image if t1 != null else null
		_entry_type1.visible = _entry_type1.texture != null
	if _entry_type2 != null:
		var show_type2 := t2 != null and (t1 == null or t2.id != t1.id)
		_entry_type2.texture = t2.image if show_type2 else null
		_entry_type2.visible = show_type2 and _entry_type2.texture != null


func _build_owner_white_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment(){ vec4 tex = texture(TEXTURE, UV); COLOR = vec4(1.0, 1.0, 1.0, tex.a); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _setup_form_gender_options(data: PokemonData) -> void:
	_form_gender_options.clear()
	_form_gender_values.clear()
	_form_gender_preview_index = 0
	if data == null:
		_form_gender_options = ["Sin genero"]
		_form_gender_values = [CONST.GENEROS.SIN_GENERO]
		return
	var rate: int = int(data.gender_rate)
	if rate < 0:
		_form_gender_options = ["Sin genero"]
		_form_gender_values = [CONST.GENEROS.SIN_GENERO]
	elif rate == 0:
		_form_gender_options = ["Macho"]
		_form_gender_values = [CONST.GENEROS.MACHO]
	elif rate >= 8:
		_form_gender_options = ["Hembra"]
		_form_gender_values = [CONST.GENEROS.HEMBRA]
	else:
		_form_gender_options = ["Macho", "Hembra"]
		_form_gender_values = [CONST.GENEROS.MACHO, CONST.GENEROS.HEMBRA]


func _apply_form_gender_preview(option_index: int) -> void:
	if option_index < 0 or option_index >= _form_gender_values.size():
		return
	_form_gender_preview_index = option_index
	var gender_value: int = _form_gender_values[option_index]
	match gender_value:
		CONST.GENEROS.MACHO:
			_set_label_text(_form_gender, "Macho")
		CONST.GENEROS.HEMBRA:
			_set_label_text(_form_gender, "Hembra")
		_:
			_set_label_text(_form_gender, "Sin genero")


func _open_form_gender_choices() -> void:
	if _form_gender_choice_open:
		return
	if _form_gender_options.is_empty():
		return
	var dm := DisplayManager.instance
	if dm == null or dm.choice_box == null:
		return
	_form_gender_choice_open = true
	var cb: ChoiceBox = dm.choice_box
	var on_change := func(idx: int) -> void:
		_apply_form_gender_preview(idx)
	if not cb.selection_changed.is_connected(on_change):
		cb.selection_changed.connect(on_change)
	_apply_form_gender_preview(_form_gender_preview_index)
	cb.set_next_initial_index(_form_gender_preview_index)
	var selected_idx: int = await DisplayManager.show_choices_corner(
		_form_gender_options,
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	if cb.selection_changed.is_connected(on_change):
		cb.selection_changed.disconnect(on_change)
	if selected_idx >= 0 and selected_idx < _form_gender_options.size():
		_apply_form_gender_preview(selected_idx)
	_form_gender_choice_open = false


func _is_valid_footprint_texture(tex: Texture2D) -> bool:
	if tex == null:
		return false
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var region: Rect2 = at.region
		if region.size.x <= 0.0 or region.size.y <= 0.0:
			return false
	return true


func _set_label_text(node: Node, text: String) -> void:
	if node == null:
		return
	if node.has_method("setText"):
		node.setText(text)
	elif node is Label:
		(node as Label).text = text
	elif node is RichTextLabel:
		(node as RichTextLabel).text = text


func _normalize_single_line_text(text: String) -> String:
	var out := text.replace("\r\n", " ").replace("\n", " ").replace("\r", " ")
	while out.find("  ") >= 0:
		out = out.replace("  ", " ")
	return out.strip_edges()


func _format_measure_value(value: float) -> String:
	if value <= 0.0:
		return "---"
	return "%.1f" % value


func _update_held_navigation(delta: float) -> void:
	if not _input_enabled:
		_reset_held_navigation()
		return
	if _view_mode == ViewMode.ENTRY:
		_reset_held_navigation()
		return

	var up_pressed: bool = Input.is_action_pressed("ui_up")
	var down_pressed: bool = Input.is_action_pressed("ui_down")
	var desired_dir: int = 0
	if up_pressed and not down_pressed:
		desired_dir = -1
	elif down_pressed and not up_pressed:
		desired_dir = 1

	if desired_dir == 0:
		_reset_held_navigation()
		return

	if desired_dir != _held_nav_dir:
		_held_nav_dir = desired_dir
		_held_nav_elapsed = 0.0
		_held_nav_next_repeat = _NAV_HOLD_INITIAL_DELAY
		return

	_held_nav_elapsed += delta
	if _held_nav_elapsed < _held_nav_next_repeat:
		return

	if _held_nav_dir < 0:
		_navigate_up()
	else:
		_navigate_down()
	_held_nav_next_repeat += _NAV_HOLD_REPEAT_INTERVAL


func _reset_held_navigation() -> void:
	_held_nav_dir = 0
	_held_nav_elapsed = 0.0
	_held_nav_next_repeat = _NAV_HOLD_INITIAL_DELAY


func _render_regions() -> void:
	var region_rows: Array[Dictionary] = _controller.get_region_rows()
	for i in range(_region_rows.size()):
		var row: HBoxContainer = _region_rows[i]
		var name_label = row.get_node_or_null("Nombre")
		var seen_label = row.get_node_or_null("Vistos")
		var caught_label = row.get_node_or_null("Propios")
		var row_text := ""
		var seen_text := ""
		var caught_text := ""
		if i == _REGION_EXIT_INDEX:
			row_text = "Salir"
		elif i < region_rows.size():
			var data: Dictionary = region_rows[i]
			var unlocked := bool(data.get("unlocked", false))
			var dex_name := str(data.get("display_name", "Pokédex"))
			if unlocked:
				row_text = dex_name
				seen_text = str(int(data.get("seen_count", 0)))
				caught_text = str(int(data.get("caught_count", 0)))
			else:
				row_text = "????"
				seen_text = "--"
				caught_text = "--"
		else:
			row_text = "????"
			seen_text = "--"
			caught_text = "--"
		if name_label != null:
			if name_label.has_method("setText"):
				name_label.setText(row_text)
			else:
				name_label.text = row_text
		if seen_label != null:
			if seen_label.has_method("setText"):
				seen_label.setText(seen_text)
			else:
				seen_label.text = seen_text
		if caught_label != null:
			if caught_label.has_method("setText"):
				caught_label.setText(caught_text)
			else:
				caught_label.text = caught_text
	_update_regions_cursor_position()


func _update_regions_cursor_position() -> void:
	if _regions_cursor == null:
		return
	if _selected_region_index < 0 or _selected_region_index >= _region_rows.size():
		return
	var row := _region_rows[_selected_region_index]
	if row == null:
		return
	var cursor_y := row.global_position.y + row.size.y * 0.5 - global_position.y + 2.0
	_regions_cursor.position = Vector2(_region_cursor_base_x, cursor_y)


func _collect_search_targets() -> void:
	_search_targets.clear()
	var names: Array[String] = [
		"lNombre",
		"lColor",
		"lTIpo1",
		"lTIpo2",
		"lOrden",
		"IniciarBusqueda",
		"lOrden2",
		"IniciarOrdenamiento",
	]
	for node_name in names:
		var node: Control = _search_panel.get_node_or_null("Busqueda/%s" % node_name) as Control
		if node == null:
			node = _search_panel.get_node_or_null("Ordenamiento/%s" % node_name) as Control
		if node != null:
			_search_targets.append(node)


func _collect_search_data_rows() -> void:
	_search_data_rows.clear()
	if _search_data_list == null or _search_data_row_template == null:
		return
	_search_data_rows.append(_search_data_row_template)
	while _search_data_rows.size() < _SEARCH_DATA_VISIBLE_ROWS:
		var clone := _search_data_row_template.duplicate() as HBoxContainer
		if clone == null:
			break
		_search_data_list.add_child(clone)
		_search_data_rows.append(clone)


func _update_search_cursor_position() -> void:
	if _search_cursor == null:
		return
	if _search_targets.is_empty():
		return
	_selected_search_index = clampi(_selected_search_index, 0, _search_targets.size() - 1)
	var target: Control = _search_targets[_selected_search_index]
	if target == null:
		return
	var cursor_y := target.global_position.y + target.size.y * 0.5 - _search_panel.global_position.y + 2.0
	_search_cursor.position = Vector2(_search_cursor.position.x, cursor_y)
	_update_search_description()
	_clear_search_data_options()


func _load_search_data_options_for_current_level() -> void:
	var options: Array[String] = []
	if _selected_search_index == 0:
		options = [
			"Sin especificar",
			"ABC",
			"DEF",
			"GHI",
			"JKL",
			"MNO",
			"PQR",
			"STU",
			"VWX",
			"XYZ",
		]
	elif _selected_search_index == 1:
		options = [
			"Sin especificar",
			"Rojo",
			"Azul",
			"Amarillo",
			"Verde",
			"Negro",
			"Marrón",
			"Morado",
			"Gris",
			"Blanco",
			"Rosa",
		]
	elif _selected_search_index == 2 or _selected_search_index == 3:
		options = _build_type_search_options()
	elif _selected_search_index == 4 or _selected_search_index == 6:
		options = [
			"Modo num.",
			"Modo alfab.",
			"Más pesado",
			"Más ligero",
			"Más alto",
			"Más bajo",
		]
	else:
		options = ["Sin especificar"]
	_search_data_options = options
	_selected_search_data_index = _find_selected_data_index_for_current_level(options)
	_render_search_data_rows()
	_update_search_data_scroll_arrows()
	_update_search_data_cursor_position()


func _clear_search_data_options() -> void:
	_search_data_options.clear()
	_selected_search_data_index = 0
	_search_data_focus = false
	_render_search_data_rows()
	_update_search_data_scroll_arrows()
	_update_search_data_cursor_position()


func _cancel_search_data_selection() -> void:
	_clear_search_data_options()


func _reset_search_filter_state() -> void:
	_search_selected_option_by_level.clear()
	_set_label_text(_search_d_nombre, "Sin espec.")
	_set_label_text(_search_d_color, "Sin espec.")
	_set_label_text(_search_d_tipo1, "Ninguno")
	_set_label_text(_search_d_tipo2, "Ninguno")
	_set_label_text(_search_d_orden_busqueda, "Modo num.")
	_set_label_text(_search_d_orden_ordenamiento, "Modo num.")


func _execute_search_filters() -> void:
	if _controller == null:
		return
	var filters := {
		"name_group": str(_search_selected_option_by_level.get(0, "Sin especificar")),
		"color_name": str(_search_selected_option_by_level.get(1, "Sin especificar")),
		"type1_name": str(_search_selected_option_by_level.get(2, "Ninguno")),
		"type2_name": str(_search_selected_option_by_level.get(3, "Ninguno")),
		"order_mode": str(_search_selected_option_by_level.get(4, "Modo num.")),
	}
	_controller.apply_search_filters(filters)
	if _controller.get_entry_count() <= 0:
		_controller.clear_search_filters()
		await _show_no_matches_message()
		return
	_selected_index = 0
	_enter_list_mode(true)


func _execute_search_sorting() -> void:
	if _controller == null:
		return
	var filters := {
		"name_group": str(_search_selected_option_by_level.get(0, "Sin especificar")),
		"color_name": str(_search_selected_option_by_level.get(1, "Sin especificar")),
		"type1_name": str(_search_selected_option_by_level.get(2, "Ninguno")),
		"type2_name": str(_search_selected_option_by_level.get(3, "Ninguno")),
		"order_mode": str(_search_selected_option_by_level.get(6, "Modo num.")),
	}
	_controller.apply_search_filters(filters)
	if _controller.get_entry_count() <= 0:
		_controller.clear_search_filters()
		await _show_no_matches_message()
		return
	_selected_index = 0
	_enter_list_mode(true)


func _show_no_matches_message() -> void:
	var was_input_enabled := _input_enabled
	if was_input_enabled:
		_disable_input()
	await DisplayManager.show_message("No se encontraron coincidencias", {
		"typingMode": "typing",
	})
	if was_input_enabled and visible:
		_enable_input()


func _commit_search_data_selection() -> void:
	if _search_data_options.is_empty():
		return
	var idx := clampi(_selected_search_data_index, 0, _search_data_options.size() - 1)
	var selected_text := _search_data_options[idx]
	_search_selected_option_by_level[_selected_search_index] = selected_text
	match _selected_search_index:
		0:
			_set_label_text(_search_d_nombre, selected_text)
		1:
			_set_label_text(_search_d_color, selected_text)
		2:
			_set_label_text(_search_d_tipo1, selected_text)
		3:
			_set_label_text(_search_d_tipo2, selected_text)
		4:
			_set_label_text(_search_d_orden_busqueda, selected_text)
		6:
			_set_label_text(_search_d_orden_ordenamiento, selected_text)
		_:
			pass
	_cancel_search_data_selection()


func _find_selected_data_index_for_current_level(options: Array[String]) -> int:
	var saved := str(_search_selected_option_by_level.get(_selected_search_index, ""))
	if saved.is_empty():
		return 0
	for i in range(options.size()):
		if options[i] == saved:
			return i
	return 0


func _navigate_search_data(dir: int) -> void:
	var total := _search_data_options.size()
	if total <= 0:
		return
	_selected_search_data_index += dir
	if _selected_search_data_index < 0:
		_selected_search_data_index = total - 1
	elif _selected_search_data_index >= total:
		_selected_search_data_index = 0
	_render_search_data_rows()
	_update_search_data_scroll_arrows()
	_update_search_data_cursor_position()


func _render_search_data_rows() -> void:
	if _search_data_rows.is_empty():
		return
	var total := _search_data_options.size()
	var scroll_top := _compute_scroll_top_for_visible_rows(total, _selected_search_data_index, _SEARCH_DATA_VISIBLE_ROWS)
	for row_idx in range(_search_data_rows.size()):
		var row: HBoxContainer = _search_data_rows[row_idx]
		var item_idx := scroll_top + row_idx
		var label = row.get_node_or_null("Texto")
		var text := ""
		if item_idx < total:
			text = _search_data_options[item_idx]
		_set_label_text(label, text)


func _update_search_data_scroll_arrows() -> void:
	if _search_data_up_arrow == null or _search_data_down_arrow == null:
		return
	if not _search_data_focus:
		_search_data_up_arrow.visible = false
		_search_data_down_arrow.visible = false
		_search_data_up_arrow.frame = 0
		_search_data_down_arrow.frame = 0
		return
	var item_count := _search_data_options.size()
	if item_count <= _SEARCH_DATA_VISIBLE_ROWS:
		_search_data_up_arrow.visible = false
		_search_data_down_arrow.visible = false
		_search_data_up_arrow.frame = 0
		_search_data_down_arrow.frame = 0
		return
	var scroll_top: int = _compute_scroll_top_for_visible_rows(item_count, _selected_search_data_index, _SEARCH_DATA_VISIBLE_ROWS)
	var max_scroll_top: int = maxi(item_count - _SEARCH_DATA_VISIBLE_ROWS, 0)
	_search_data_up_arrow.visible = scroll_top > 0
	_search_data_down_arrow.visible = scroll_top < max_scroll_top
	if not _search_data_up_arrow.visible:
		_search_data_up_arrow.frame = 0
	if not _search_data_down_arrow.visible:
		_search_data_down_arrow.frame = 0


func _update_search_data_cursor_position() -> void:
	if _search_data_cursor == null:
		return
	if _search_data_rows.is_empty() or _search_data_options.is_empty() or not _search_data_focus:
		_search_data_cursor.visible = false
		_update_search_description()
		return
	_search_data_cursor.visible = true
	var total := _search_data_options.size()
	var scroll_top := _compute_scroll_top_for_visible_rows(total, _selected_search_data_index, _SEARCH_DATA_VISIBLE_ROWS)
	var row_idx := clampi(_selected_search_data_index - scroll_top, 0, _search_data_rows.size() - 1)
	var row: HBoxContainer = _search_data_rows[row_idx]
	var y: float = row.position.y + (float(row.custom_minimum_size.y) * 0.5) + 2.0
	_search_data_cursor.position = Vector2(_search_data_cursor.position.x, y)
	_update_search_description()


func _compute_scroll_top_for_visible_rows(item_count: int, selected_index: int, visible_rows: int) -> int:
	if item_count <= visible_rows:
		return 0
	var max_top := item_count - visible_rows
	var desired_top := selected_index - (visible_rows - 1)
	return clampi(desired_top, 0, max_top)


func _build_type_search_options() -> Array[String]:
	var options: Array[String] = ["Ninguno"]
	var types := DatabaseService.get_all_types_sorted()
	for type_data in types:
		if type_data == null:
			continue
		var type_name := str(type_data.Name).strip_edges()
		if type_name.is_empty():
			type_name = str(type_data.internal_name).strip_edges().capitalize()
		if type_name.is_empty():
			continue
		options.append(type_name)
	return options


func _update_search_description() -> void:
	if _search_description == null:
		return
	if _SEARCH_DESCRIPTIONS.is_empty():
		_set_label_text(_search_description, "")
		return
	if _search_data_focus and (_selected_search_index == 4 or _selected_search_index == 6):
		if not _SEARCH_ORDER_MODE_DESCRIPTIONS.is_empty():
			var data_idx := clampi(_selected_search_data_index, 0, _SEARCH_ORDER_MODE_DESCRIPTIONS.size() - 1)
			_set_label_text(_search_description, _SEARCH_ORDER_MODE_DESCRIPTIONS[data_idx])
			return
	var idx := clampi(_selected_search_index, 0, _SEARCH_DESCRIPTIONS.size() - 1)
	_set_label_text(_search_description, _SEARCH_DESCRIPTIONS[idx])


func _block_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_blocked.emit()


func _unblock_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_unblocked.emit()
