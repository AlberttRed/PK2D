extends RefCounted
class_name PCItemStorage

## Depósito de ítems del PC (separado del Bag). Persistencia vía GameStateService (#830).
## UI → #831.

const BAG_ENTRY_SCRIPT = preload("res://Scripts/Resources/Classes/BagEntry.gd")

## item_id (int) → quantity (int). Sin pockets: el Bag reparte al retirar.
var _items: Dictionary = {}


func clear() -> void:
	_items.clear()


func get_quantity(item_id: int) -> int:
	if item_id <= 0:
		return 0
	return int(_items.get(item_id, 0))


func has_item(item_id: int, amount: int = 1) -> bool:
	if item_id <= 0 or amount <= 0:
		return false
	return get_quantity(item_id) >= amount


func get_occupied_count() -> int:
	var n := 0
	for qty_any in _items.values():
		if int(qty_any) > 0:
			n += 1
	return n


## Entradas ordenadas por item_id (BagEntry).
func get_entries() -> Array:
	var ids: Array = _items.keys()
	ids.sort()
	var out: Array = []
	for id_any in ids:
		var item_id := int(id_any)
		var qty := int(_items.get(item_id, 0))
		if qty <= 0:
			continue
		out.append(BAG_ENTRY_SCRIPT.new(item_id, qty))
	return out


## Añade al depósito. Respeta stack_limit del ItemData si > 0. Devuelve cantidad añadida.
func add_item(item_id: int, amount: int) -> int:
	if item_id <= 0 or amount <= 0:
		return 0
	if DatabaseService == null:
		return 0
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		push_warning("PCItemStorage: item_id=%d no existe en DatabaseService" % item_id)
		return 0

	var stack_limit := int(item_data.stack_limit)
	var current := get_quantity(item_id)
	var addable := amount
	if stack_limit > 0:
		addable = mini(amount, maxi(0, stack_limit - current))
	if addable <= 0:
		return 0

	_items[item_id] = current + addable
	return addable


## Quita del depósito. Devuelve cantidad retirada.
func remove_item(item_id: int, amount: int) -> int:
	if item_id <= 0 or amount <= 0:
		return 0
	var current := get_quantity(item_id)
	var removed := mini(current, amount)
	if removed <= 0:
		return 0
	var new_qty := current - removed
	if new_qty > 0:
		_items[item_id] = new_qty
	else:
		_items.erase(item_id)
	return removed


## Bag → PC. Devuelve cantidad transferida.
func deposit_from_bag(bag: Bag, item_id: int, amount: int) -> int:
	if bag == null or item_id <= 0 or amount <= 0:
		return 0
	var available := bag.get_quantity(item_id)
	if available <= 0:
		return 0
	var want := mini(amount, available)
	# Capacidad del depósito (stack).
	var room := want
	if DatabaseService != null:
		var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
		if item_data != null:
			var stack_limit := int(item_data.stack_limit)
			if stack_limit > 0:
				room = mini(want, maxi(0, stack_limit - get_quantity(item_id)))
	if room <= 0:
		return 0
	var removed := bag.remove_item(item_id, room)
	if removed <= 0:
		return 0
	var added := add_item(item_id, removed)
	if added < removed:
		# Devolver sobrante al bag si el depósito no aceptó todo (no debería).
		bag.add_item(item_id, removed - added)
	return added


## PC → Bag. Devuelve cantidad transferida.
func withdraw_to_bag(bag: Bag, item_id: int, amount: int) -> int:
	if bag == null or item_id <= 0 or amount <= 0:
		return 0
	var available := get_quantity(item_id)
	if available <= 0:
		return 0
	var want := mini(amount, available)
	var added := bag.add_item(item_id, want)
	if added <= 0:
		return 0
	remove_item(item_id, added)
	return added


func to_serializable_data() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	var ids: Array = _items.keys()
	ids.sort()
	for id_any in ids:
		var item_id := int(id_any)
		var qty := int(_items.get(item_id, 0))
		if qty <= 0:
			continue
		serialized.append({
			"item_id": item_id,
			"quantity": qty,
		})
	return serialized


func load_serializable_data(entries: Array) -> void:
	clear()
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var item_id := int(entry.get("item_id", 0))
		var quantity := int(entry.get("quantity", 0))
		if item_id <= 0 or quantity <= 0:
			continue
		add_item(item_id, quantity)
