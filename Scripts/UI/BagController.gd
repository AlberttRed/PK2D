extends RefCounted
class_name BagController

var _context: OverworldContext = null
## Filtro de lista: qué contexto debe cumplir cada item (AC-05 PARTY_MENU).
var list_use_context: ItemEnums.UseContext = ItemEnums.UseContext.OVERWORLD
## Slot del party desde el que se abrió “Usar objeto” (-1 = flujo normal de pausa).
var party_target_slot: int = -1

const BAG_LIST_ENTRY_SCRIPT = preload("res://Scripts/UI/BagListEntry.gd")

const _POCKET_ORDER: Array[int] = [
	ItemEnums.Pocket.ITEMS,
	ItemEnums.Pocket.MEDICINE,
	ItemEnums.Pocket.BALLS,
	ItemEnums.Pocket.TM_HM,
	ItemEnums.Pocket.BERRIES,
	ItemEnums.Pocket.MACHINES,
	ItemEnums.Pocket.BATTLE_ITEMS,
	ItemEnums.Pocket.KEY_ITEMS
]

const _POCKET_NAMES := {
	ItemEnums.Pocket.ITEMS: "Objetos",
	ItemEnums.Pocket.MEDICINE: "Medicinas",
	ItemEnums.Pocket.BALLS: "Poké Balls",
	ItemEnums.Pocket.TM_HM: "MTs / MOs",
	ItemEnums.Pocket.BERRIES: "Bayas",
	ItemEnums.Pocket.KEY_ITEMS: "Obj. Claves",
	ItemEnums.Pocket.MACHINES: "Cartas",
	ItemEnums.Pocket.BATTLE_ITEMS: "Obj. Batallas"
}

func _init(context: OverworldContext = null) -> void:
	_context = context


## Abre la mochila en contexto menú party: filtra objetos usables en PARTY_MENU y guarda el slot objetivo.
func configure_party_item_flow(target_slot: int) -> void:
	list_use_context = ItemEnums.UseContext.PARTY_MENU
	party_target_slot = target_slot


func reset_list_context_to_overworld() -> void:
	list_use_context = ItemEnums.UseContext.OVERWORLD
	party_target_slot = -1

func get_pockets() -> Array[int]:
	return _POCKET_ORDER.duplicate()

func get_pocket_name(pocket: int) -> String:
	return _POCKET_NAMES.get(pocket, "Objetos")

func get_items_in_pocket(pocket: int) -> Array:
	var bag = GameStateService.get_bag()
	var ui_items: Array = []
	if bag == null:
		ui_items.append(BAG_LIST_ENTRY_SCRIPT.create_exit_entry())
		return ui_items

	var entries: Array = bag.get_items_in_pocket(pocket)
	var item_entries: Array = []

	for entry in entries:
		if entry == null:
			continue

		var item_id := int(entry.item_id)
		var quantity := int(entry.quantity)
		if quantity <= 0:
			continue

		var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
		if item_data == null:
			continue

		var usable_here := item_data.can_use_in_context(list_use_context)
		# Hasta que los datos marquen PARTY_MENU en allowed_contexts, admitir también overworld en este flujo.
		if list_use_context == ItemEnums.UseContext.PARTY_MENU and not usable_here:
			usable_here = item_data.can_use_in_context(ItemEnums.UseContext.OVERWORLD)
		item_entries.append(BAG_LIST_ENTRY_SCRIPT.create_item_entry(
			item_id,
			quantity,
			item_data.get_display_name(),
			item_data.description,
			item_data.icon,
			usable_here
		))

	item_entries.sort_custom(func(a, b) -> bool:
		var name_a := str(a.display_name).to_lower()
		var name_b := str(b.display_name).to_lower()
		if name_a == name_b:
			return int(a.item_id) < int(b.item_id)
		return name_a < name_b
	)

	ui_items.append_array(item_entries)
	ui_items.append(BAG_LIST_ENTRY_SCRIPT.create_exit_entry())
	return ui_items

func get_item_description(item_id: int) -> String:
	if item_id <= 0:
		return ""
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		return ""
	return item_data.description

func get_item_selection_debug(item_id: int) -> Dictionary:
	if item_id <= 0:
		return {
			"found": false,
			"display_name": "",
			"quantity": 0
		}

	var quantity: int = GameStateService.get_bag().get_quantity(item_id)
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		return {
			"found": false,
			"display_name": "Item #%d" % item_id,
			"quantity": quantity
		}

	return {
		"found": true,
		"display_name": item_data.get_display_name(),
		"quantity": quantity
	}

func request_use_item(item_id: int) -> Dictionary:
	if item_id <= 0:
		return {
			"ok": false,
			"message": "No hay objeto seleccionado."
		}

	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		return {
			"ok": false,
			"message": "El objeto seleccionado no existe en la base de datos."
		}

	var allowed_here := item_data.can_use_in_context(list_use_context)
	if list_use_context == ItemEnums.UseContext.PARTY_MENU and not allowed_here:
		allowed_here = item_data.can_use_in_context(ItemEnums.UseContext.OVERWORLD)
	if not allowed_here:
		return {
			"ok": false,
			"message": "Este objeto no se puede usar aqui."
		}

	var ctx_note := "overworld"
	if list_use_context == ItemEnums.UseContext.PARTY_MENU:
		ctx_note = "party_menu"
		if party_target_slot >= 0:
			ctx_note += " (slot=%d)" % party_target_slot

	return {
		"ok": true,
		"message": "Objeto usable en contexto %s. Efecto real en PBI posterior." % ctx_note
	}
