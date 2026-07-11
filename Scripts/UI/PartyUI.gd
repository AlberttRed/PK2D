extends Panel
class_name PartyUI

signal back_requested()
signal closed()
## Hook AC-05: solicitud de abrir mochila en contexto PARTY_MENU para el slot indicado.
signal use_item_requested(slot_index: int)
## Flujo mochila → elegir Pokémon objetivo (sin menú de acciones).
signal bag_item_target_selected(slot_index: int)
signal bag_item_target_cancelled()
signal battle_switch_slot_selected(slot_index: int)
signal battle_switch_cancelled()
signal battle_switch_rejected(message: Dictionary)

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
var _bag_item_target_pick_mode: bool = false
var _battle_switch_pick_mode: bool = false
var _battle_force_switch: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	for panel: PartyPokemonPanel in pokemon_panels:
		if not panel.selected.is_connected(_on_panel_selected):
			panel.selected.connect(_on_panel_selected)
	_disable_mouse_on_party_main_ui()


## Solo mando/teclado (ui_*): el foco por clic en paneles desvirtúa el diseño tipo consola.
func _disable_mouse_on_party_main_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child == summary:
			continue
		if child is Control:
			_set_mouse_ignore_recursive(child as Control)


func _set_mouse_ignore_recursive(ctrl: Control) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in ctrl.get_children():
		if ch is Control:
			_set_mouse_ignore_recursive(ch as Control)


func setup(controller) -> void:
	if controller == null:
		push_error("PartyUI: setup(controller) requiere un PartyController.")
		return
	_controller = controller


func open(initial_focus_slot: int = -1) -> void:
	_open_party_common(initial_focus_slot, false)


## Tras elegir «Usar» en la mochila: solo elegir Pokémon objetivo (sin submenú Usar/Dar).
func open_for_bag_item_target_pick(initial_focus_slot: int = -1) -> void:
	_open_party_common(initial_focus_slot, true)


func open_for_battle_switch_pick(initial_focus_slot: int = -1, force_switch: bool = false) -> void:
	_open_party_common(initial_focus_slot, false)
	_battle_switch_pick_mode = true
	_battle_force_switch = force_switch
	if _battle_force_switch:
		_set_help_text(_get_battle_switch_default_help_text())
	else:
		_set_help_text("Elige el Pokémon al que cambiar.")


func _open_party_common(initial_focus_slot: int, bag_item_pick: bool) -> void:
	if _controller == null:
		push_error("PartyUI: Abre con setup(controller) antes.")
		return
	_bag_item_target_pick_mode = bag_item_pick
	_battle_switch_pick_mode = false
	_battle_force_switch = false
	var requested_focus_slot: int = initial_focus_slot
	_exit_switch_mode()
	_in_hgss_summary = false
	summary.hide()
	_refresh_slots()
	_apply_menu_mode_all_panels()
	for panel: PartyPokemonPanel in pokemon_panels:
		panel.enableFocus()
	_wire_salir_neighbors()
	show()
	_enable_input()
	_block_player_control()
	# Tras show(): si no, grab_focus con panel oculto no mantiene el slot (p. ej. vuelta mochila → party).
	if requested_focus_slot >= 0 and requested_focus_slot < SLOT_COUNT and _controller.is_slot_occupied(requested_focus_slot):
		pokemon_panels[requested_focus_slot].grab_focus()
	else:
		_focus_first_occupied_or_salir()
	if _bag_item_target_pick_mode:
		_set_help_text("¿Usar con qué Pokémon?")
	else:
		_set_help_text("Elige a un Pokémon.")


func close() -> void:
	if not visible:
		return
	_bag_item_target_pick_mode = false
	_battle_switch_pick_mode = false
	_battle_force_switch = false
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


## Refresco tras mutar Pokémon (objetos, estado) con la pantalla abierta.
func refresh_slots_display() -> void:
	_refresh_slots()


func animate_item_hp_gain_for_slot(slot: int) -> void:
	if _controller == null:
		return
	if slot < 0 or slot >= SLOT_COUNT:
		return
	if not _controller.is_slot_occupied(slot):
		return
	var panel: PartyPokemonPanel = pokemon_panels[slot]
	if panel == null or panel.health_bar == null:
		return
	var view: Dictionary = _controller.get_slot_view(slot)
	var max_hp: int = int(view.get("hp_max", panel.health_bar.max_value))
	var new_hp: int = int(view.get("hp_current", panel.health_bar.current_value))
	var old_hp: int = int(panel.health_bar.current_value)
	if max_hp > 0 and panel.health_bar.max_value != max_hp:
		panel.health_bar.set_values(old_hp, max_hp)
	if new_hp > old_hp:
		# Ítems en Party: animación de PS más ágil (x2).
		var original_duration: float = panel.health_bar.animate_duration
		panel.health_bar.animate_duration = maxf(0.05, original_duration * 0.5)
		await panel.health_bar.animate_to(new_hp)
		panel.health_bar.animate_duration = original_duration
	panel.loadPokemon(view.get("pokemon", null) as Pokemon)


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


func _get_battle_switch_default_help_text() -> String:
	if _battle_force_switch:
		return "Elegir un POKéMON."
	return "Elige el Pokémon al que cambiar."


func _reset_battle_switch_help_text() -> void:
	_set_help_text(_get_battle_switch_default_help_text())


func _apply_menu_mode_all_panels() -> void:
	for p: PartyPokemonPanel in pokemon_panels:
		p.setMode(PartyPanelModes.Modes.MENU)
		p.setSwapping(false)


func _enter_switch_mode(origin_slot: int) -> void:
	_switch_mode = true
	_switch_origin_slot = origin_slot
	_set_help_text("¿A qué posición mover?")
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
	if pokemon_panels.size() < 6 or _controller == null:
		return
	var up_slot: int = _first_occupied_salir_up()
	if up_slot < 0:
		return
	var top_path: NodePath = pokemon_panels[up_slot].get_path()
	salir.set_focus_neighbor(SIDE_TOP, top_path)
	pokemon_panels[up_slot].set_focus_neighbor(SIDE_BOTTOM, salir.get_path())


func _focus_first_occupied_or_salir() -> void:
	if _controller == null:
		return
	for i in SLOT_COUNT:
		if _controller.is_slot_occupied(i):
			pokemon_panels[i].grab_focus()
			return
	salir.grab_focus()


func _grab_slot_focus(slot: int) -> void:
	if _controller == null:
		return
	if slot >= 0 and slot < SLOT_COUNT and _controller.is_slot_occupied(slot):
		pokemon_panels[slot].grab_focus()
	else:
		_focus_first_occupied_or_salir()


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


func _party_await_both_swapped_out(a: PartyPokemonPanel, b: PartyPokemonPanel) -> void:
	var pending: Array[int] = [2]
	var decr := func():
		pending[0] -= 1
	a.swappedOut.connect(decr, CONNECT_ONE_SHOT)
	b.swappedOut.connect(decr, CONNECT_ONE_SHOT)
	a.swapOut()
	b.swapOut()
	while pending[0] > 0:
		await get_tree().process_frame


func _party_await_both_swapped_in(a: PartyPokemonPanel, b: PartyPokemonPanel) -> void:
	var pending: Array[int] = [2]
	var decr := func():
		pending[0] -= 1
	a.swappedIn.connect(decr, CONNECT_ONE_SHOT)
	b.swappedIn.connect(decr, CONNECT_ONE_SHOT)
	a.swapIn()
	b.swapIn()
	while pending[0] > 0:
		await get_tree().process_frame


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
	var dm := DisplayManager.instance
	if dm != null and dm.msg != null and dm.msg.visible:
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
	if _bag_item_target_pick_mode:
		# DisplayManager funde a negro y cierra (evita un frame a juego desnudo).
		bag_item_target_cancelled.emit()
		return
	if _battle_switch_pick_mode:
		if _battle_force_switch:
			return
		battle_switch_cancelled.emit()
		return
	if _switch_mode:
		_exit_switch_mode()
		_set_help_text("Elige a un Pokémon.")
		return
	back_requested.emit()


func _on_input_start() -> void:
	if _bag_item_target_pick_mode and _can_handle_party_input():
		bag_item_target_cancelled.emit()
		return
	if _battle_switch_pick_mode and _can_handle_party_input():
		if _battle_force_switch:
			return
			return
		battle_switch_cancelled.emit()
		return
	if _switch_mode and _can_handle_party_input():
		_exit_switch_mode()
		_set_help_text("Elige a un Pokémon.")
		return
	if _can_handle_party_input():
		back_requested.emit()


func _handle_accept_async() -> void:
	var slot := _get_party_slot_from_focus()

	if _bag_item_target_pick_mode:
		if slot == CANCEL_INDEX:
			bag_item_target_cancelled.emit()
			return
		if slot < 0 or slot >= SLOT_COUNT:
			return
		if not _controller.is_slot_occupied(slot):
			return
		bag_item_target_selected.emit(slot)
		return

	if _battle_switch_pick_mode:
		if slot == CANCEL_INDEX:
			if _battle_force_switch:
				return
			else:
				battle_switch_cancelled.emit()
			return
		if slot < 0 or slot >= SLOT_COUNT:
			return
		if not _controller.is_slot_occupied(slot):
			_set_help_text("No hay ningún Pokémon en ese slot.")
			return
		await _handle_battle_switch_choice_menu(slot)
		return

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
		var origin: int = _switch_origin_slot
		var target: int = slot
		if not _controller.can_swap_slots(origin, target):
			_exit_switch_mode()
			if not _controller.is_slot_occupied(origin) or not _controller.is_slot_occupied(target):
				_set_help_text("No puedes reordenar con un hueco vacío.")
			else:
				_set_help_text("No se puede reordenar este Pokémon.")
			_grab_slot_focus(target)
			return
		var pa: PartyPokemonPanel = pokemon_panels[origin]
		var pb: PartyPokemonPanel = pokemon_panels[target]
		_suppress_input = true
		await _party_await_both_swapped_out(pa, pb)
		var swap_res: Dictionary = _controller.try_swap_slots(origin, target)
		if not swap_res.get("ok", false):
			await _party_await_both_swapped_in(pa, pb)
			_refresh_slots()
			_suppress_input = false
			_exit_switch_mode()
			_set_help_text(str(swap_res.get("message", "No se pudo reordenar.")))
			_grab_slot_focus(target)
			return
		_refresh_slots()
		await _party_await_both_swapped_in(pa, pb)
		_suppress_input = false
		_exit_switch_mode()
		_set_help_text("Elige a un Pokémon.")
		_grab_slot_focus(target)
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

	var slot_view: Dictionary = _controller.get_slot_view(slot)
	var mon_name: String = str(slot_view.get("display_name", "Pokémon"))
	_set_help_text("¿Qué hacer con %s?" % mon_name)

	_suppress_input = true
	var idx: int = await DisplayManager.show_party_action_choices(labels)
	_suppress_input = false

	if idx < 0 or idx >= entries.size():
		_set_help_text("Elige a un Pokémon.")
		return
	var action: StringName = entries[idx].get("id", &"") as StringName
	match action:
		&"summary":
			await _open_hgss_summary(slot)
			return
		&"switch":
			_enter_switch_mode(slot)
			return
		&"use_item":
			_set_help_text("¿Qué quieres hacer con él?")
			_suppress_input = true
			var item_sub: Array[String] = ["Usar", "Dar", "Salir"]
			var sub_idx: int = await DisplayManager.show_party_action_choices(item_sub)
			_suppress_input = false
			if sub_idx < 0 or sub_idx >= item_sub.size():
				_set_help_text("Elige a un Pokémon.")
				return
			match sub_idx:
				0:
					use_item_requested.emit(slot)
				1:
					_suppress_input = true
					await DisplayManager.show_message("Dar: pendiente de implementar.", {
						"waitInput": false,
						"closeAtEnd": true,
						"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
						"typingMode": "instant"
					})
					_suppress_input = false
					_set_help_text("Elige a un Pokémon.")
				2:
					_set_help_text("Elige a un Pokémon.")
			return
		&"cancel":
			pass
	_set_help_text("Elige a un Pokémon.")


func _handle_battle_switch_choice_menu(slot: int) -> void:
	var slot_view: Dictionary = _controller.get_slot_view(slot)
	var mon_name: String = str(slot_view.get("display_name", "Pokémon"))
	_set_help_text("¿Qué hacer con %s?" % mon_name)
	_suppress_input = true
	var idx: int = await DisplayManager.show_party_action_choices(["Cambio", "Datos", "Salir"])
	_suppress_input = false

	match idx:
		0:
			if not _controller.is_selectable_switch_slot(slot):
				battle_switch_rejected.emit(_controller.get_invalid_switch_message(slot))
				_reset_battle_switch_help_text()
				return
			battle_switch_slot_selected.emit(slot)
			return
		1:
			await _open_hgss_summary(slot)
			return
		_:
			_reset_battle_switch_help_text()
			return


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
	if _controller != null and slot >= 0 and slot < SLOT_COUNT and _controller.is_slot_occupied(slot):
		pokemon_panels[slot].grab_focus()
	else:
		_focus_first_occupied_or_salir()
	if _battle_switch_pick_mode:
		_reset_battle_switch_help_text()
	else:
		_set_help_text("Elige a un Pokémon.")


func _block_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_blocked.emit()


func _unblock_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_unblocked.emit()
