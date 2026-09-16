extends RefCounted
class_name PCStorage

## Almacenamiento Pokémon del PC (cajas + slots). Solo modelo en memoria (PBI #825).
## Persistencia → #826. UI → #828.

## Gen 3/4: 14 cajas × 30 slots.
const BOX_COUNT: int = 14
const SLOTS_PER_BOX: int = 30

## Cada entrada: { "name": String, "slots": Array } con `slots.size() == SLOTS_PER_BOX`
## (elementos `Pokemon` o `null`).
var _boxes: Array[Dictionary] = []


func _init() -> void:
	_ensure_boxes()


func clear() -> void:
	_boxes.clear()
	_ensure_boxes()


func get_box_count() -> int:
	return BOX_COUNT


func get_slots_per_box() -> int:
	return SLOTS_PER_BOX


func get_capacity() -> int:
	return BOX_COUNT * SLOTS_PER_BOX


func get_occupied_count() -> int:
	var n := 0
	for box in _boxes:
		var slots: Array = box.get("slots", [])
		for mon in slots:
			if mon != null:
				n += 1
	return n


func get_free_slot_count() -> int:
	return get_capacity() - get_occupied_count()


func has_space() -> bool:
	return get_free_slot_count() > 0


func get_box_name(box_index: int) -> String:
	if not _is_valid_box(box_index):
		return ""
	return str(_boxes[box_index].get("name", ""))


func set_box_name(box_index: int, new_name: String) -> bool:
	if not _is_valid_box(box_index):
		return false
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		trimmed = "CAJA %d" % (box_index + 1)
	_boxes[box_index]["name"] = trimmed
	return true


func get_pokemon(box_index: int, slot_index: int) -> Pokemon:
	if not _is_valid_slot(box_index, slot_index):
		return null
	var slots: Array = _boxes[box_index]["slots"]
	var mon = slots[slot_index]
	return mon as Pokemon if mon != null else null


## Primer hueco libre. `Vector2i(box, slot)` o `Vector2i(-1, -1)` si está lleno.
func find_first_free_slot(start_box: int = 0) -> Vector2i:
	var start := clampi(start_box, 0, BOX_COUNT - 1)
	for b in range(start, BOX_COUNT):
		var slot := _find_free_in_box(b)
		if slot >= 0:
			return Vector2i(b, slot)
	for b in range(0, start):
		var slot := _find_free_in_box(b)
		if slot >= 0:
			return Vector2i(b, slot)
	return Vector2i(-1, -1)


## Deposita en el primer hueco libre (desde `preferred_box` si es válido).
func add_pokemon(pokemon: Pokemon, preferred_box: int = 0) -> bool:
	if pokemon == null:
		push_warning("PCStorage.add_pokemon: pokemon es null")
		return false
	if pokemon.base == null:
		push_warning("PCStorage.add_pokemon: Pokémon sin inicializar (base == null)")
		return false
	var free := find_first_free_slot(preferred_box)
	if free.x < 0:
		return false
	return set_pokemon(free.x, free.y, pokemon)


## Coloca en un slot concreto. Falla si el slot está ocupado (usar `move_pokemon` para intercambiar).
func set_pokemon(box_index: int, slot_index: int, pokemon: Pokemon) -> bool:
	if pokemon == null:
		push_warning("PCStorage.set_pokemon: pokemon es null")
		return false
	if pokemon.base == null:
		push_warning("PCStorage.set_pokemon: Pokémon sin inicializar (base == null)")
		return false
	if not _is_valid_slot(box_index, slot_index):
		return false
	var slots: Array = _boxes[box_index]["slots"]
	if slots[slot_index] != null:
		return false
	slots[slot_index] = pokemon
	return true


## Quita y devuelve el Pokémon del slot (o null).
func remove_pokemon(box_index: int, slot_index: int) -> Pokemon:
	if not _is_valid_slot(box_index, slot_index):
		return null
	var slots: Array = _boxes[box_index]["slots"]
	var mon = slots[slot_index]
	slots[slot_index] = null
	return mon as Pokemon if mon != null else null


## Mueve entre slots. Si el destino está ocupado, intercambia.
func move_pokemon(from_box: int, from_slot: int, to_box: int, to_slot: int) -> bool:
	if not _is_valid_slot(from_box, from_slot) or not _is_valid_slot(to_box, to_slot):
		return false
	if from_box == to_box and from_slot == to_slot:
		return true
	var from_slots: Array = _boxes[from_box]["slots"]
	var to_slots: Array = _boxes[to_box]["slots"]
	var src = from_slots[from_slot]
	if src == null:
		return false
	var dst = to_slots[to_slot]
	from_slots[from_slot] = dst
	to_slots[to_slot] = src
	return true


func _ensure_boxes() -> void:
	while _boxes.size() < BOX_COUNT:
		var i := _boxes.size()
		_boxes.append({
			"name": "CAJA %d" % (i + 1),
			"slots": _make_empty_slots(),
		})
	# Normalizar por si quedó estado corrupto.
	for i in range(_boxes.size()):
		var box: Dictionary = _boxes[i]
		if not box.has("name") or str(box["name"]).is_empty():
			box["name"] = "CAJA %d" % (i + 1)
		var slots: Array = box.get("slots", [])
		if slots.size() != SLOTS_PER_BOX:
			var fixed := _make_empty_slots()
			for s in range(mini(slots.size(), SLOTS_PER_BOX)):
				fixed[s] = slots[s]
			box["slots"] = fixed
		_boxes[i] = box


func _make_empty_slots() -> Array:
	var slots: Array = []
	slots.resize(SLOTS_PER_BOX)
	for i in range(SLOTS_PER_BOX):
		slots[i] = null
	return slots


func _is_valid_box(box_index: int) -> bool:
	return box_index >= 0 and box_index < _boxes.size()


func _is_valid_slot(box_index: int, slot_index: int) -> bool:
	return _is_valid_box(box_index) and slot_index >= 0 and slot_index < SLOTS_PER_BOX


func _find_free_in_box(box_index: int) -> int:
	if not _is_valid_box(box_index):
		return -1
	var slots: Array = _boxes[box_index]["slots"]
	for s in range(slots.size()):
		if slots[s] == null:
			return s
	return -1
