extends RefCounted
class_name BagController

var _context: OverworldContext = null
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

		item_entries.append(BAG_LIST_ENTRY_SCRIPT.create_item_entry(
			item_id,
			quantity,
			item_data.get_display_name(),
			item_data.description,
			item_data.icon,
			item_data.can_use_in_context(ItemEnums.UseContext.OVERWORLD)
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

	if not item_data.can_use_in_context(ItemEnums.UseContext.OVERWORLD):
		return {
			"ok": false,
			"message": "Este objeto no se puede usar aqui."
		}

	return {
		"ok": true,
		"message": "El objeto es usable en overworld. La ejecucion del efecto se implementara en otro PBI."
	}
