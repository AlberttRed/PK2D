extends RefCounted
class_name TargetSelectionGrid

## Filas de spots: [0] rivales (izq/der), [1] aliados si existe (arriba/abajo entre filas).
var rows: Array = []
var field_index: int = 0
var column_index: int = 0


func _init(p_rows: Array) -> void:
	rows = p_rows
	field_index = 0
	column_index = 0


func can_switch_row() -> bool:
	return rows.size() > 1


func current_spot() -> BattleSpot:
	if rows.is_empty():
		return null
	var row: Array = rows[field_index]
	if row.is_empty():
		return null
	column_index = clampi(column_index, 0, row.size() - 1)
	return row[column_index] as BattleSpot


func move_column(delta: int) -> void:
	if rows.is_empty():
		return
	var row: Array = rows[field_index]
	if row.size() <= 1:
		return
	column_index = (column_index + delta + row.size()) % row.size()


func move_row(delta: int) -> void:
	if not can_switch_row():
		return
	field_index = clampi(field_index + delta, 0, rows.size() - 1)
	var row: Array = rows[field_index]
	column_index = clampi(column_index, 0, maxi(row.size() - 1, 0))


func all_spots() -> Array[BattleSpot]:
	var out: Array[BattleSpot] = []
	for row in rows:
		for spot in row:
			var bp_spot := spot as BattleSpot
			if bp_spot != null and not out.has(bp_spot):
				out.append(bp_spot)
	return out
