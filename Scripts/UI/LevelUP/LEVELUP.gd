extends Panel

## Mismo orden que `StatsValues` en `LEVELUP.tscn` (PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad).
const _STAT_ORDER: Array[StatsEnum.Values] = [
	StatsEnum.Values.HP,
	StatsEnum.Values.ATTACK,
	StatsEnum.Values.DEFENSE,
	StatsEnum.Values.SP_ATTACK,
	StatsEnum.Values.SP_DEFENSE,
	StatsEnum.Values.SPEED,
]

var _value_labels: Array[LabelHGSS] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col: VBoxContainer = $HBoxContainer/StatsValues
	for c: Node in col.get_children():
		if c is LabelHGSS:
			var rtl: LabelHGSS = c as LabelHGSS
			rtl.bbcode_enabled = true
			# LabelHGSS.setText antepone [left]/[center]/[right] según `align`; no mezclar con BBCode manual.
			rtl.align = 2 # LabelHGSS.Right — números alineados a la derecha (una sola etiqueta).
			_value_labels.append(rtl)
	if _value_labels.size() < _STAT_ORDER.size():
		push_warning("LEVELUP: faltan etiquetas de valor (esperadas %d, hay %d)" % [
			_STAT_ORDER.size(), _value_labels.size()
		])


## Muestra el incremento por stat (fase 1, estilo juego antiguo: " + N").
func show_stats_increment(stat_changes: Object) -> void:
	if stat_changes == null or _value_labels.is_empty():
		return
	visible = true
	force_update_transform()
	for i: int in range(mini(_STAT_ORDER.size(), _value_labels.size())):
		var st: StatsEnum.Values = _STAT_ORDER[i]
		var before: int = int(stat_changes.stats_before.get(st, 0))
		var after: int = int(stat_changes.stats_after.get(st, 0))
		var d: int = after - before
		_value_labels[i].setText(" + %d" % d)
	await _wait_for_ui_confirm()
	visible = false


## Muestra los stats finales del Pokémon (fase 2).
func show_final_stats(stat_changes: Object) -> void:
	if stat_changes == null or _value_labels.is_empty():
		return
	visible = true
	force_update_transform()
	for i: int in range(mini(_STAT_ORDER.size(), _value_labels.size())):
		var st: StatsEnum.Values = _STAT_ORDER[i]
		var after: int = int(stat_changes.stats_after.get(st, 0))
		_value_labels[i].setText(str(after))
	await _wait_for_ui_confirm()
	visible = false


func _wait_for_ui_confirm() -> void:
	# Sustituye el antiguo `await GUI.accept` (mismo criterio que otras UIs con `ui_accept`)
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			return
