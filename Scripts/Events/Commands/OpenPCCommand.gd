extends EventCommand
class_name OpenPCCommand

## Menú raíz del PC (estilo HGSS) + submenú PC de BILL.
## UI de cajas → #828.

enum RootOption {
	BILL = 0,
	PLAYER = 1,
	OAK = 2,
	HALL_OF_FAME = 3,
	LOG_OFF = 4,
}

enum BillOption {
	WITHDRAW = 0,
	DEPOSIT = 1,
	MOVE = 2,
	MOVE_ITEMS = 3,
	SEE_YA = 4,
}

enum PlayerOption {
	ITEM_STORAGE = 0,
	MAILBOX = 1,
	LOG_OFF = 2,
}

enum ItemStorageOption {
	WITHDRAW = 0,
	DEPOSIT = 1,
	EXIT = 2,
}

const BILL_OPTIONS: Array[String] = [
	"SACAR POKéMON",
	"DEJAR POKéMON",
	"MOVER POKéMON",
	"MOVER OBJETOS",
	"¡NOS VEMOS!",
]

const BILL_HELP: Array[String] = [
	"Pasar un POKéMON guardado en alguna CAJA a tu equipo.",
	"Guardar algun POKéMON de tu equipo en una CAJA.",
	"Ordenar los POKéMON de las CAJAS y de tu equipo.",
	"Mover los objetos de los POKéMON de las CAJAS o de tu equipo.",
	"¡Hasta otra!",
]

const PLAYER_OPTIONS: Array[String] = [
	"ALMACÉN OBJ.",
	"BUZÓN",
	"DESCONEXIÓN",
]

const PLAYER_HELP: Array[String] = [
	"Guardar o sacar objetos de tu PC.",
	"Leer el correo recibido.",
	"Apagar este PC.",
]

const ITEM_STORAGE_OPTIONS: Array[String] = [
	"SACAR OBJETO",
	"DEJAR OBJETO",
	"SALIR",
]

const ITEM_STORAGE_HELP: Array[String] = [
	"Sacar objetos del PC.",
	"Almacenar objetos en el PC.",
	"Volver al menú anterior.",
]


func execute(context: Node) -> void:
	var player_name := _resolve_player_name()

	await DisplayManager.show_message("%s encendió el PC." % player_name, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})

	while true:
		var choice: int = await _prompt_root_menu(player_name)
		if choice < 0 or choice == RootOption.LOG_OFF:
			break
		match choice:
			RootOption.BILL:
				await _open_bill_pc()
			RootOption.PLAYER:
				await _open_player_pc(player_name)
			RootOption.OAK:
				await _show_stub("PC del PROF. OAK")
			RootOption.HALL_OF_FAME:
				await _show_stub("HALL FAMA")

	DisplayManager.close_message()
	context.continue_execution()


func is_async() -> bool:
	return true


func is_safe_for_parallel() -> bool:
	return false


func _resolve_player_name() -> String:
	var player_name := "PLAYER"
	if GameStateService != null:
		player_name = str(GameStateService.get_variable("PLAYER_NAME", "PLAYER")).strip_edges()
	if player_name.is_empty():
		player_name = "PLAYER"
	return player_name


func _prompt_root_menu(player_name: String) -> int:
	var options: Array[String] = [
		"PC de BILL",
		"PC de %s" % player_name,
		"PC del PROF. OAK",
		"HALL FAMA",
		"Desconexión",
	]
	await DisplayManager.show_message("¿A qué PC quieres acceder?", {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})
	DisplayManager.hide_message_wait_indicator()
	var cb: ChoiceBox = null
	if DisplayManager.instance != null:
		cb = DisplayManager.instance.choice_box
	if cb != null:
		cb.suppress_confirm_sfx = true
	var choice: int = await DisplayManager.show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.TOP_LEFT
	)
	if cb != null:
		cb.suppress_confirm_sfx = false
	if choice == RootOption.BILL or choice == RootOption.PLAYER:
		AudioManager.play_ui_pc_access()
	elif choice >= 0:
		AudioManager.play_ui_select()
	elif choice < 0:
		AudioManager.play_ui_cancel()
	DisplayManager.close_message()
	return choice


func _open_player_pc(player_name: String) -> void:
	await DisplayManager.show_message("Accedió al PC de %s." % player_name, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})

	var dm := DisplayManager.instance
	if dm == null or dm.choice_box == null:
		return
	var cb: ChoiceBox = dm.choice_box

	var on_change := func(idx: int) -> void:
		if idx >= 0 and idx < PLAYER_HELP.size():
			DisplayManager.set_message_help_instant(PLAYER_HELP[idx])

	await _show_player_menu(cb, on_change, 0)
	var selected: int = await DisplayManager.await_choices(false)

	while true:
		if selected < 0 or selected == PlayerOption.LOG_OFF:
			break

		if selected == PlayerOption.MAILBOX:
			await DisplayManager.show_message("BUZÓN: pendiente.", {
				"waitInput": true,
				"closeAtEnd": false,
				"showIconAtEnd": false,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"frameStyle": MessageBoxFrameStyle.Values.HGSS,
			})
			DisplayManager.set_message_help_instant(PLAYER_HELP[selected])
			selected = await DisplayManager.await_choices(false)
			continue

		if selected == PlayerOption.ITEM_STORAGE:
			if cb.selection_changed.is_connected(on_change):
				cb.selection_changed.disconnect(on_change)
			await _open_item_storage_menu(cb)
			await _show_player_menu(cb, on_change, PlayerOption.ITEM_STORAGE)
			selected = await DisplayManager.await_choices(false)
			continue

		selected = await DisplayManager.await_choices(false)

	if cb.selection_changed.is_connected(on_change):
		cb.selection_changed.disconnect(on_change)
	DisplayManager.close_choices()
	DisplayManager.close_message()


func _open_item_storage_menu(cb: ChoiceBox) -> void:
	var on_change := func(idx: int) -> void:
		if idx >= 0 and idx < ITEM_STORAGE_HELP.size():
			DisplayManager.set_message_help_instant(ITEM_STORAGE_HELP[idx])

	await _show_item_storage_menu(cb, on_change, 0)
	var selected: int = await DisplayManager.await_choices(false)

	while true:
		if selected < 0 or selected == ItemStorageOption.EXIT:
			break

		if selected == ItemStorageOption.WITHDRAW and _is_pc_item_storage_empty():
			await DisplayManager.show_message("No hay objetos.", {
				"waitInput": true,
				"closeAtEnd": false,
				"showIconAtEnd": false,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"frameStyle": MessageBoxFrameStyle.Values.HGSS,
			})
			DisplayManager.set_message_help_instant(ITEM_STORAGE_HELP[selected])
			selected = await DisplayManager.await_choices(false)
			continue

		if cb.selection_changed.is_connected(on_change):
			cb.selection_changed.disconnect(on_change)
		var restore_idx := selected
		DisplayManager.set_choice_input_enabled(false)

		var cleanup := func() -> void:
			DisplayManager.close_choices()
			DisplayManager.close_message()

		var prepare := _prepare_item_storage_menu_after_pc.bind(cb, on_change, restore_idx)

		match selected:
			ItemStorageOption.WITHDRAW:
				await DisplayManager.open_pc_items(PCItemsUI.Mode.WITHDRAW, prepare, cleanup)
			ItemStorageOption.DEPOSIT:
				await DisplayManager.open_bag_for_pc_deposit(prepare, cleanup)

		selected = await DisplayManager.await_choices(false)

	if cb.selection_changed.is_connected(on_change):
		cb.selection_changed.disconnect(on_change)


func _prepare_item_storage_menu_after_pc(cb: ChoiceBox, on_change: Callable, restore_idx: int) -> void:
	await _show_item_storage_menu(cb, on_change, restore_idx)
	DisplayManager.set_choice_input_enabled(false)


func _is_pc_item_storage_empty() -> bool:
	if GameStateService == null:
		return true
	var storage = GameStateService.get_pc_item_storage()
	if storage == null:
		return true
	return int(storage.get_occupied_count()) <= 0


func _show_item_storage_menu(cb: ChoiceBox, on_change: Callable, initial_idx: int) -> void:
	var idx := clampi(initial_idx, 0, ITEM_STORAGE_OPTIONS.size() - 1)
	if not cb.selection_changed.is_connected(on_change):
		cb.selection_changed.connect(on_change)
	cb.set_next_initial_index(idx)
	await DisplayManager.show_message(ITEM_STORAGE_HELP[idx], {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})
	DisplayManager.set_message_help_instant(ITEM_STORAGE_HELP[idx])
	DisplayManager.hide_message_wait_indicator()
	await DisplayManager.open_choices_corner(ITEM_STORAGE_OPTIONS, ChoiceBox.ChoiceAnchor.TOP_LEFT)


func _show_player_menu(cb: ChoiceBox, on_change: Callable, initial_idx: int) -> void:
	var idx := clampi(initial_idx, 0, PLAYER_OPTIONS.size() - 1)
	if not cb.selection_changed.is_connected(on_change):
		cb.selection_changed.connect(on_change)
	cb.set_next_initial_index(idx)
	await DisplayManager.show_message(PLAYER_HELP[idx], {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})
	DisplayManager.set_message_help_instant(PLAYER_HELP[idx])
	DisplayManager.hide_message_wait_indicator()
	await DisplayManager.open_choices_corner(PLAYER_OPTIONS, ChoiceBox.ChoiceAnchor.TOP_LEFT)


func _open_bill_pc() -> void:
	await DisplayManager.show_message("Accedió al PC de BILL.", {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})
	await DisplayManager.show_message("Acceso al Sistema de Almacenamiento de POKéMON concedido.", {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": true,
		"playOpenSound": false,
		"playConfirmSound": true,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})

	var dm := DisplayManager.instance
	if dm == null or dm.choice_box == null:
		return
	var cb: ChoiceBox = dm.choice_box

	var on_change := func(idx: int) -> void:
		if idx >= 0 and idx < BILL_HELP.size():
			DisplayManager.set_message_help_instant(BILL_HELP[idx])

	await _show_bill_menu(cb, on_change, 0)
	var selected: int = await DisplayManager.await_choices(false)

	while true:
		if selected < 0 or selected == BillOption.SEE_YA:
			break

		if selected == BillOption.WITHDRAW and _is_party_full():
			await DisplayManager.show_message("¡Tu equipo está completo!", {
				"waitInput": true,
				"closeAtEnd": false,
				"showIconAtEnd": false,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"frameStyle": MessageBoxFrameStyle.Values.HGSS,
			})
			DisplayManager.set_message_help_instant(BILL_HELP[selected])
			selected = await DisplayManager.await_choices(false)
			continue

		# El ChoiceBox es único: cerrarlo bajo el negro al abrir el PC; restaurarlo al salir.
		if cb.selection_changed.is_connected(on_change):
			cb.selection_changed.disconnect(on_change)
		var restore_idx := selected
		DisplayManager.set_choice_input_enabled(false)

		var cleanup := func() -> void:
			DisplayManager.close_choices()
			DisplayManager.close_message()

		var prepare := _prepare_bill_menu_after_pc.bind(cb, on_change, restore_idx)

		match selected:
			BillOption.WITHDRAW:
				await DisplayManager.open_pc(PCStorageUI.Mode.WITHDRAW, 0, prepare, cleanup)
			BillOption.DEPOSIT:
				await DisplayManager.open_pc(PCStorageUI.Mode.DEPOSIT, 0, prepare, cleanup)
			BillOption.MOVE:
				await DisplayManager.open_pc(PCStorageUI.Mode.MOVE, 0, prepare, cleanup)
			BillOption.MOVE_ITEMS:
				await DisplayManager.open_pc(PCStorageUI.Mode.MOVE_ITEMS, 0, prepare, cleanup)

		selected = await DisplayManager.await_choices(false)

	if cb.selection_changed.is_connected(on_change):
		cb.selection_changed.disconnect(on_change)
	DisplayManager.close_choices()
	DisplayManager.close_message()


func _prepare_bill_menu_after_pc(cb: ChoiceBox, on_change: Callable, restore_idx: int) -> void:
	await _show_bill_menu(cb, on_change, restore_idx)
	DisplayManager.set_choice_input_enabled(false)


func _is_party_full() -> bool:
	if GameStateService == null:
		return false
	var party: Party = GameStateService.get_party()
	return party != null and party.is_full()


func _show_bill_menu(cb: ChoiceBox, on_change: Callable, initial_idx: int) -> void:
	var idx := clampi(initial_idx, 0, BILL_OPTIONS.size() - 1)
	if not cb.selection_changed.is_connected(on_change):
		cb.selection_changed.connect(on_change)
	cb.set_next_initial_index(idx)
	await DisplayManager.show_message(BILL_HELP[idx], {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})
	DisplayManager.set_message_help_instant(BILL_HELP[idx])
	DisplayManager.hide_message_wait_indicator()
	await DisplayManager.open_choices_corner(BILL_OPTIONS, ChoiceBox.ChoiceAnchor.TOP_LEFT)


func _show_stub(label: String) -> void:
	await DisplayManager.show_message("%s: pendiente." % label, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.HGSS,
	})
