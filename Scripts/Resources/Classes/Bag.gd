extends RefCounted
class_name Bag

const BAG_ENTRY_SCRIPT = preload("res://Scripts/Resources/Classes/BagEntry.gd")

var _items_by_pocket: Dictionary = {}

func clear() -> void:
	_items_by_pocket.clear()

func add_item(item_id: int, amount: int) -> int:
	if item_id <= 0 or amount <= 0:
		return 0

	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		push_warning("Bag: No se pudo agregar item_id=%d porque no existe en DatabaseService" % item_id)
		return 0

	var stack_limit := int(item_data.stack_limit)
	var current_quantity := get_quantity(item_id)
	var addable_amount := amount

	if stack_limit > 0:
		addable_amount = min(amount, max(0, stack_limit - current_quantity))

	if addable_amount <= 0:
		return 0

	var pocket := _normalize_pocket(item_data.pocket)
	var pocket_items := _get_or_create_pocket_items(pocket)
	pocket_items[item_id] = current_quantity + addable_amount
	return addable_amount

func remove_item(item_id: int, amount: int) -> int:
	if item_id <= 0 or amount <= 0:
		return 0

	var pocket := _find_pocket_containing_item(item_id)
	if pocket == -1:
		return 0

	var pocket_items: Dictionary = _items_by_pocket.get(pocket, {})
	var current_quantity := int(pocket_items.get(item_id, 0))
	var removed_amount: int = min(current_quantity, amount)
	if removed_amount <= 0:
		return 0

	var new_quantity: int = current_quantity - removed_amount
	if new_quantity > 0:
		pocket_items[item_id] = new_quantity
	else:
		pocket_items.erase(item_id)
		if pocket_items.is_empty():
			_items_by_pocket.erase(pocket)

	return removed_amount

func get_quantity(item_id: int) -> int:
	if item_id <= 0:
		return 0

	var pocket := _find_pocket_containing_item(item_id)
	if pocket == -1:
		return 0

	var pocket_items: Dictionary = _items_by_pocket.get(pocket, {})
	return int(pocket_items.get(item_id, 0))

func has_item(item_id: int, amount: int = 1) -> bool:
	if item_id <= 0 or amount <= 0:
		return false
	return get_quantity(item_id) >= amount

func get_items_in_pocket(pocket: ItemEnums.Pocket) -> Array:
	var normalized_pocket := _normalize_pocket(int(pocket))
	var pocket_items: Dictionary = _items_by_pocket.get(normalized_pocket, {})
	var item_ids := pocket_items.keys()
	item_ids.sort()

	var result: Array = []
	for item_id_variant in item_ids:
		var item_id := int(item_id_variant)
		var quantity := int(pocket_items.get(item_id, 0))
		if quantity <= 0:
			continue
		result.append(BAG_ENTRY_SCRIPT.new(item_id, quantity))
	return result

func to_serializable_data() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	var pocket_keys := _items_by_pocket.keys()
	pocket_keys.sort()

	for pocket in pocket_keys:
		var pocket_items: Dictionary = _items_by_pocket.get(pocket, {})
		var item_ids := pocket_items.keys()
		item_ids.sort()

		for item_id_variant in item_ids:
			var item_id := int(item_id_variant)
			var quantity := int(pocket_items.get(item_id, 0))
			if quantity <= 0:
				continue
			serialized.append({
				"item_id": item_id,
				"quantity": quantity
			})

	return serialized

func load_serializable_data(entries: Array[Dictionary]) -> void:
	clear()
	for entry in entries:
		var item_id := int(entry.get("item_id", 0))
		var quantity := int(entry.get("quantity", 0))
		if item_id <= 0 or quantity <= 0:
			continue
		add_item(item_id, quantity)

func _get_or_create_pocket_items(pocket: int) -> Dictionary:
	if not _items_by_pocket.has(pocket):
		_items_by_pocket[pocket] = {}
	return _items_by_pocket[pocket]

func _find_pocket_containing_item(item_id: int) -> int:
	for pocket_variant in _items_by_pocket.keys():
		var pocket := int(pocket_variant)
		var pocket_items: Dictionary = _items_by_pocket.get(pocket, {})
		if pocket_items.has(item_id):
			return pocket
	return -1

func _normalize_pocket(raw_pocket: int) -> int:
	if raw_pocket >= ItemEnums.Pocket.ITEMS and raw_pocket <= ItemEnums.Pocket.BATTLE_ITEMS:
		return raw_pocket
	return ItemEnums.Pocket.ITEMS
