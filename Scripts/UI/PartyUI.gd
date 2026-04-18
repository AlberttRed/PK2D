extends Panel
class_name PartyUI

signal back_requested()
signal closed()
## Hook AC-05: solicitud de abrir mochila en contexto PARTY_MENU para el slot indicado.
signal use_item_requested(slot_index: int)

const SLOT_COUNT: int = 6
const CANCEL_INDEX: int = 6

@export var style_salir: StyleBox
@export var style_salir_sel: StyleBox

@onready var pokemon_panels: Array[PartyPokemonPanel] = [
	$PKMN_0, $PKMN_1, $PKMN_2, $PKMN_3, $PKMN_4, $PKMN_5
]
@onready var summary: PartySummary = $SUMMARY
@onready var salir: Panel = $Salir
@onready var fixed_msg: Panel = $FIXED_MSG

var _controller = null
var _input_enabled: bool = false
var _suppress_input: bool = false
var _choice_in_flight: bool = false
var _in_hgss_summary: bool = false
var _switch_mode: bool = false
var _switch_origin_slot: int = -1
var _open_focus_slot: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	for panel: PartyPokemonPanel in pokemon_panels:
		if not panel.selected.is_connected(_on_panel_selected):
			panel.selected.connect(_on_panel_selected)


func setup(controller) -> void:
	if controller == null:
		push_error("PartyUI: setup(controller) requiere un PartyController.")
		return
	_controller = controller


func open(initial_focus_slot: int = -1) -> void:
	if _controller == null:
		push_error("PartyUI: Abre con setup(controller) antes.")
		return
	_open_focus_slot = initial_focus_slot
	_exit_switch_mode()
	_in_hgss_summary = false
	summary.hide()
	_refresh_slots()
	_apply_menu_mode_all_panels()
	for panel: PartyPokemonPanel in pokemon_panels:
		panel.enableFocus()
	_wire_salir_neighbors()
	_focus_first_occupied_or_salir()
	if _open_focus_slot >= 0 and _open_focus_slot < SLOT_COUNT and _controller.is_slot_occupied(_open_focus_slot):
		pokemon_panels[_open_focus_slot].grab_focus()
	_open_focus_slot = -1
	_set_help_text("Elige a un Pokémon.")
	show()
	_enable_input()
	_block_player_control()


func close() -> void:
	if not visible:
		return
	if summary.visible:
		summary.hide()
	_disable_input()
	for panel: PartyPokemonPanel in pokemon_panels:
		panel.disableFocus()
	hide()
	_unblock_player_control()
	closed.emit()


func set_input_enabled(value: bool) -> void:
	if value:
		_enable_input()
	else:
		_disable_input()


func _on_panel_selected(_order: int) -> void:
	pass


func _set_help_text(text: String) -> void:
	var lbl := fixed_msg.get_node_or_null("Label") if fixed_msg else null
	if lbl == null:
		return
	if lbl.has_method("setText"):
		lbl.setText(text)
	elif lbl is Label:
		(lbl as Label).text = text


func _apply_menu_mode_all_panels() -> void:
	for p: PartyPokemonPanel in pokemon_panels:
		p.setMode(PartyPanelModes.Modes.MENU)
		p.setSwapping(false)


func _enter_switch_mode(origin_slot: int) -> void:
	_switch_mode = true
	_switch_origin_slot = origin_slot
	_set_help_text("¿Con qué Pokémon quieres cambiar de lugar?")
	for i in SLOT_COUNT:
		var p: PartyPokemonPanel = pokemon_panels[i]
		p.setMode(PartyPanelModes.Modes.SWAP)
		p.setSwapping(i == origin_slot)


func _exit_switch_mode() -> void:
	_switch_mode = false
	_switch_origin_slot = -1
	_apply_menu_mode_all_panels()


func _refresh_slots() -> void:
	if _controller == null:
		return
	for i in SLOT_COUNT:
		var view: Dictionary = _controller.get_slot_view(i)
		pokemon_panels[i].order = i
		if view.get("occupied", false):
			var mon: Pokemon = view.get("pokemon", null) as Pokemon
			if mon != null:
				_controller.touch_pokemon(mon)
				pokemon_panels[i].loadPokemon(mon)
		else:
			pokemon_panels[i].apply_empty_slot(i)


func _wire_salir_neighbors() -> void:
	if pokemon_panels.size() < 6:
		return
	salir.set_focus_neighbor(SIDE_TOP, pokemon_panels[5].get_path())
	pokemon_panels[5].set_focus_neighbor(SIDE_BOTTOM, salir.get_path())


func _focus_first_occupied_or_salir() -> void:
	if _controller == null:
		return
	for i in SLOT_COUNT:
		if _controller.is_slot_occupied(i):
			pokemon_panels[i].grab_focus()
			return
	salir.grab_focus()


func _get_party_slot_from_focus() -> int:
	var fo: Control = get_viewport().gui_get_focus_owner() as Control
	if fo == null:
		return -1
	if fo == salir or salir.is_ancestor_of(fo):
		return CANCEL_INDEX
	var cur: Node = fo
	while cur != null:
		if cur is PartyPokemonPanel:
			return (cur as PartyPokemonPanel).order
		cur = cur.get_parent()
	return -1


## Rejilla HGSS (mismos enlaces que PartyUI.tscn). CANCEL_INDEX = Salir.
func _party_grid_step(from_slot: int, side: Side) -> int:
	match from_slot:
		0:
			if side == SIDE_RIGHT:
				return 1
			if side == SIDE_BOTTOM:
				return 2
			return -1
		1:
			if side == SIDE_LEFT:
				return 0
			if side == SIDE_BOTTOM:
				return 3
			return -1
		2:
			if side == SIDE_TOP:
				return 0
			if side == SIDE_RIGHT:
				return 3
			if side == SIDE_BOTTOM:
				return 4
			return -1
		3:
			if side == SIDE_LEFT:
				return 2
			if side == SIDE_TOP:
				return 1
			if side == SIDE_BOTTOM:
				return 5
			return -1
		4:
			if side == SIDE_TOP:
				return 2
			if side == SIDE_RIGHT:
				return 5
			if side == SIDE_BOTTOM:
				return CANCEL_INDEX
			return -1
		5:
			if side == SIDE_LEFT:
				return 4
			if side == SIDE_TOP:
				return 3
			if side == SIDE_BOTTOM:
				return CANCEL_INDEX
			return -1
		_:
			return -1


func _navigate_from_party_slot(from_slot: int, side: Side) -> int:
	if _controller == null:
		return from_slot
	var cur := from_slot
	var step := _party_grid_step(cur, side)
	while step != -1:
		if step == CANCEL_INDEX:
			return CANCEL_INDEX
		if _controller.is_slot_occupied(step):
			return step
		cur = step
		step = _party_grid_step(cur, side)
	if side == SIDE_RIGHT or side == SIDE_BOTTOM:
		return CANCEL_INDEX
	return from_slot


func _first_occupied_salir_up() -> int:
	if _controller == null:
		return -1
	var cur: int = 5
	for _i in 8:
		if _controller.is_slot_occupied(cur):
			return cur
		var up: int = _party_grid_step(cur, SIDE_TOP)
		if up != -1:
			cur = up
			continue
		if cur == 1 or cur == 3 or cur == 5:
			var left_p: int = cur - 1
			if _controller.is_slot_occupied(left_p):
				return left_p
		return -1
	return -1


## Desde Salir hacia la izquierda: entrar al equipo por la columna derecha (5→0), simétrico a ir a Salir con derecha/abajo.
func _first_occupied_salir_left() -> int:
	if _controller == null:
		return -1
	for s: int in range(5, -1, -1):
		if _controller.is_slot_occupied(s):
			return s
	return -1


func _focus_move(side: Side) -> void:
	if _controller == null:
		return
	var fo: Control = get_viewport().gui_get_focus_owner() as Control
	if fo == null or not is_ancestor_of(fo):
		_focus_first_occupied_or_salir()
		return
	if fo == salir or salir.is_ancestor_of(fo):
		if side == SIDE_TOP:
			var up_slot: int = _first_occupied_salir_up()
			if up_slot >= 0:
				pokemon_panels[up_slot].grab_focus()
		elif side == SIDE_LEFT:
			var left_slot: int = _first_occupied_salir_left()
			if left_slot >= 0:
				pokemon_panels[left_slot].grab_focus()
		return
	var slot: int = _get_party_slot_from_focus()
	if slot < 0 or slot >= SLOT_COUNT:
		_focus_first_occupied_or_salir()
		return
	var target: int = _navigate_from_party_slot(slot, side)
	if target == slot:
		return
	if target == CANCEL_INDEX:
		salir.grab_focus()
	else:
		pokemon_panels[target].grab_focus()


func _on_Salir_focus_entered() -> void:
	if style_salir_sel:
		salir.add_theme_stylebox_override("panel", style_salir_sel)


func _on_salir_focus_exited() -> void:
	if style_salir:
		salir.add_theme_stylebox_override("panel", style_salir)


func _enable_input() -> void:
	if _input_enabled:
		return
	_input_enabled = true
	var dm := DisplayManager.instance
	if dm == null:
		push_error("PartyUI: DisplayManager no disponible.")
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


func _can_handle_party_input() -> bool:
	return _input_enabled and visible and not _suppress_input and not _in_hgss_summary


func _on_input_up() -> void:
	if not _can_handle_party_input():
		return
	_focus_move(SIDE_TOP)


func _on_input_down() -> void:
	if not _can_handle_party_input():
		return
	_focus_move(SIDE_BOTTOM)


func _on_input_left() -> void:
	if not _can_handle_party_input():
		return
	_focus_move(SIDE_LEFT)


func _on_input_right() -> void:
	if not _can_handle_party_input():
		return
	_focus_move(SIDE_RIGHT)


func _on_input_accept() -> void:
	if not _input_enabled or not visible or _suppress_input:
		return
	if _in_hgss_summary:
		return
	if _choice_in_flight:
		return
	_choice_in_flight = true
	await _handle_accept_async()
	_choice_in_flight = false


func _on_input_cancel() -> void:
	if not _input_enabled or not visible:
		return
	if _suppress_input:
		return
	if _switch_mode:
		_exit_switch_mode()
		_set_help_text("Elige a un Pokémon.")
		return
	back_requested.emit()


func _on_input_start() -> void:
	if _switch_mode and _can_handle_party_input():
		_exit_switch_mode()
		_set_help_text("Elige a un Pokémon.")
		return
	if _can_handle_party_input():
		back_requested.emit()


func _handle_accept_async() -> void:
	var slot := _get_party_slot_from_focus()

	if _switch_mode:
		if slot == CANCEL_INDEX:
			_exit_switch_mode()
			_set_help_text("Elige a un Pokémon.")
			return
		if slot < 0 or slot >= SLOT_COUNT:
			return
		if not _controller.is_slot_occupied(slot):
			return
		if slot == _switch_origin_slot:
			_exit_switch_mode()
			_set_help_text("Elige a un Pokémon.")
			return
		var swap_res: Dictionary = _controller.try_swap_slots(_switch_origin_slot, slot)
		if not swap_res.get("ok", false):
			push_warning("PartyUI: %s" % str(swap_res.get("message", "No se pudo reordenar.")))
		_exit_switch_mode()
		_refresh_slots()
		_set_help_text("Elige a un Pokémon.")
		if _controller.is_slot_occupied(slot):
			pokemon_panels[slot].grab_focus()
		else:
			_focus_first_occupied_or_salir()
		return

	if slot == CANCEL_INDEX:
		back_requested.emit()
		return
	if slot < 0 or slot >= SLOT_COUNT:
		return
	if not _controller.is_slot_occupied(slot):
		return

	var entries: Array[Dictionary] = _controller.build_action_menu_entries(slot)
	if entries.is_empty():
		return
	var labels: Array[String] = []
	for e: Dictionary in entries:
		labels.append(str(e.get("label", "")))

	_suppress_input = true
	var idx: int = await DisplayManager.show_choices(labels)
	_suppress_input = false

	if idx < 0 or idx >= entries.size():
		return
	var action: StringName = entries[idx].get("id", &"") as StringName
	match action:
		&"summary":
			await _open_hgss_summary(slot)
		&"switch":
			_enter_switch_mode(slot)
		&"use_item":
			use_item_requested.emit(slot)
		&"cancel":
			pass


func _open_hgss_summary(slot: int) -> void:
	if _controller == null or summary == null:
		return
	var members: Array[Pokemon] = _controller.get_party_members_ordered()
	if slot < 0 or slot >= members.size():
		return
	var mon: Pokemon = members[slot]
	_controller.touch_pokemon(mon)

	_in_hgss_summary = true
	_disable_input()
	summary.loadedParty = members
	summary.movingIndex = slot
	summary.loadPokemonInfo(mon)
	summary.showSummary(PartySummary.DATA)
	await summary.closed
	_in_hgss_summary = false
	_suppress_input = false
	_refresh_slots()
	_apply_menu_mode_all_panels()
	_enable_input()
	_focus_first_occupied_or_salir()
	_set_help_text("Elige a un Pokémon.")


func _block_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_blocked.emit()


func _unblock_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_unblocked.emit()
