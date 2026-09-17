extends Panel
class_name PCUI

## UI de almacenamiento del PC (cajas). Modos Bill → #828.
## Paso 1: pintar iconos de la caja actual (rejilla 6×5).

signal closed()
signal back_requested()

enum Mode {
	WITHDRAW,
	DEPOSIT,
	MOVE,
	MOVE_ITEMS,
}

const COLS: int = 6
const ROWS: int = 5
const SLOT_COUNT: int = 30

## Centro del slot 0 — calibrado con el Sprite2D de ejemplo en la escena.
@export var grid_origin: Vector2 = Vector2(42, 62)
## Separación entre centros de slots (6 columnas × 5 filas).
@export var cell_size: Vector2 = Vector2(48, 48)

@onready var _box_name_label = $Box/Nombre
@onready var _slots_root: Control = $Box/Slots
@onready var _party_panel: Panel = $Party

var _mode: Mode = Mode.WITHDRAW
var _box_index: int = 0
var _slot_sprites: Array[Sprite2D] = []
var _input_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_ensure_slots()
	if _party_panel:
		_party_panel.visible = false


func setup(_controller = null) -> void:
	# Controller dedicado en pasos siguientes.
	pass


func open(mode: Mode = Mode.WITHDRAW, box_index: int = 0) -> void:
	_mode = mode
	_box_index = clampi(box_index, 0, PCStorage.BOX_COUNT - 1)
	if _party_panel:
		_party_panel.visible = (_mode == Mode.DEPOSIT)
	refresh()
	show()
	_input_enabled = true
	_connect_input(true)


func close() -> void:
	if not visible:
		return
	_input_enabled = false
	_connect_input(false)
	hide()
	closed.emit()
	back_requested.emit()


func refresh() -> void:
	_ensure_slots()
	var storage: PCStorage = null
	if GameStateService != null:
		storage = GameStateService.get_pc_storage()
	if storage == null:
		_clear_all_slots()
		_set_box_name_text("CAJA")
		return

	_box_index = clampi(_box_index, 0, storage.get_box_count() - 1)
	_set_box_name_text(storage.get_box_name(_box_index))

	for i in range(SLOT_COUNT):
		var spr: Sprite2D = _slot_sprites[i]
		var mon: Pokemon = storage.get_pokemon(_box_index, i)
		if mon == null:
			spr.texture = null
			spr.hide()
			continue
		var icon: Texture2D = mon.get_icon_sprite()
		spr.texture = icon
		spr.hframes = 2
		spr.frame = 0
		spr.show()


func _ensure_slots() -> void:
	if _slots_root == null:
		return
	if _slot_sprites.size() == SLOT_COUNT:
		_apply_slot_positions()
		return

	for child in _slots_root.get_children():
		child.queue_free()
	_slot_sprites.clear()

	for i in range(SLOT_COUNT):
		var spr := Sprite2D.new()
		spr.name = "Slot%d" % i
		spr.centered = true
		spr.hframes = 2
		spr.hide()
		_slots_root.add_child(spr)
		_slot_sprites.append(spr)
	_apply_slot_positions()


func _apply_slot_positions() -> void:
	for i in range(_slot_sprites.size()):
		var col: int = i % COLS
		var row: int = int(i / COLS)
		_slot_sprites[i].position = grid_origin + Vector2(float(col) * cell_size.x, float(row) * cell_size.y)


func _clear_all_slots() -> void:
	for spr in _slot_sprites:
		spr.texture = null
		spr.hide()


func _set_box_name_text(box_name: String) -> void:
	if _box_name_label == null:
		return
	_box_name_label.text = "[center]%s" % box_name


func _connect_input(enabled: bool) -> void:
	var dm := DisplayManager.instance
	if dm == null:
		return
	if enabled:
		if not dm.input_cancel.is_connected(_on_input_cancel):
			dm.input_cancel.connect(_on_input_cancel)
	else:
		if dm.input_cancel.is_connected(_on_input_cancel):
			dm.input_cancel.disconnect(_on_input_cancel)


func _on_input_cancel() -> void:
	if not _input_enabled or not visible:
		return
	close()
