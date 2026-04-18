extends RefCounted
class_name PartyController

const SLOT_COUNT: int = 6

## Contexto del menú de party (AC-01). Por ahora solo overworld desde pausa.
const MENU_CTX_OVERWORLD := &"overworld"

var _context: OverworldContext = null
var menu_context: StringName = MENU_CTX_OVERWORLD


func _init(context: OverworldContext = null, p_menu_context: StringName = MENU_CTX_OVERWORLD) -> void:
	_context = context
	menu_context = p_menu_context


func get_context() -> OverworldContext:
	return _context


func get_slot_count() -> int:
	return SLOT_COUNT


func _party_model():
	return GameStateService.get_party()


## Lista densa del equipo (solo ocupados), orden de slot 0..n-1.
func get_party_members_ordered() -> Array[Pokemon]:
	var out: Array[Pokemon] = []
	out.assign(_party_model().get_all())
	return out


func _ensure_pokemon_ready(mon: Pokemon) -> void:
	if mon == null:
		return
	if mon.base == null:
		mon._post_init()


## Llamada desde PartyUI tras obtener un Pokémon del slot (p. ej. antes del Summary).
func touch_pokemon(mon: Pokemon) -> void:
	_ensure_pokemon_ready(mon)


## Vista de slot para la UI (sin exponer el modelo Party directamente).
func get_slot_view(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {"occupied": false}

	var members: Array = _party_model().get_all()
	if slot >= members.size():
		return {"occupied": false}

	var mon: Pokemon = members[slot]
	_ensure_pokemon_ready(mon)
	if mon == null or mon.base == null:
		return {"occupied": false}

	var max_hp := mon.get_final_stat(StatsEnum.Values.HP)
	var status := "—"
	if mon.fainted:
		status = "Debilitado"
	elif mon.major_status != CONST.STATUS.OK:
		status = AilmentData.major_status_display_name(mon.major_status)

	return {
		"occupied": true,
		"display_name": mon.get_display_name(),
		"species_name": mon.base.Name,
		"level": mon.level,
		"hp_current": mon.hp_actual,
		"hp_max": max_hp,
		"status_text": status,
		"icon": mon.get_icon_sprite(),
		"gender": mon.gender,
		"pokemon": mon
	}


func is_slot_occupied(slot: int) -> bool:
	return bool(get_slot_view(slot).get("occupied", false))


func can_show_switch_option() -> bool:
	return _party_model().count() >= 2


func can_show_use_item_option() -> bool:
	return menu_context == MENU_CTX_OVERWORLD


## Etiquetas del menú contextual en orden (AC-01). El último índice siempre es cancelar.
func build_action_menu_entries(slot: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_slot_occupied(slot):
		out.append({"id": &"cancel", "label": "Salir"})
		return out
	out.append({"id": &"summary", "label": "Datos"})
	if can_show_switch_option():
		out.append({"id": &"switch", "label": "Mover"})
	if can_show_use_item_option():
		out.append({"id": &"use_item", "label": "Objeto"})
	out.append({"id": &"cancel", "label": "Salir"})
	return out


## Comprueba si el intercambio es válido (sin mutar el modelo).
func can_swap_slots(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_a >= SLOT_COUNT or slot_b < 0 or slot_b >= SLOT_COUNT:
		return false
	if slot_a == slot_b:
		return true
	if not is_slot_occupied(slot_a) or not is_slot_occupied(slot_b):
		return false
	var party = _party_model()
	var n: int = party.count()
	if slot_a >= n or slot_b >= n:
		return false
	return true


## Intercambia dos slots ocupados en el modelo Party (AC-03, AC-06).
func try_swap_slots(slot_a: int, slot_b: int) -> Dictionary:
	if slot_a < 0 or slot_a >= SLOT_COUNT or slot_b < 0 or slot_b >= SLOT_COUNT:
		return {"ok": false, "message": "Índice de slot inválido."}
	if slot_a == slot_b:
		return {"ok": true, "message": ""}
	if not is_slot_occupied(slot_a) or not is_slot_occupied(slot_b):
		return {"ok": false, "message": "No puedes reordenar con un hueco vacío."}
	var party = _party_model()
	var n: int = party.count()
	if slot_a >= n or slot_b >= n:
		return {"ok": false, "message": "No se puede reordenar este Pokémon."}
	party.swap_slots(slot_a, slot_b)
	return {"ok": true, "message": ""}


func get_summary_bbcode(slot: int) -> String:
	var view := get_slot_view(slot)
	if not view.get("occupied", false):
		return "[i]Slot vacío[/i]"

	var mon: Pokemon = view.get("pokemon", null)
	if mon == null or mon.base == null:
		return ""

	_ensure_pokemon_ready(mon)

	var lines: Array[String] = []
	lines.append("[b]%s[/b] — Nv. %d" % [mon.get_display_name(), mon.level])
	var max_hp := int(view.get("hp_max", 0))
	lines.append("PS: %d / %d" % [mon.hp_actual, max_hp])

	lines.append("")
	lines.append("[b]Estadísticas[/b]")
	lines.append("Ataque: %d" % mon.get_final_stat(StatsEnum.Values.ATTACK))
	lines.append("Defensa: %d" % mon.get_final_stat(StatsEnum.Values.DEFENSE))
	lines.append("At. Esp.: %d" % mon.get_final_stat(StatsEnum.Values.SP_ATTACK))
	lines.append("Def. Esp.: %d" % mon.get_final_stat(StatsEnum.Values.SP_DEFENSE))
	lines.append("Velocidad: %d" % mon.get_final_stat(StatsEnum.Values.SPEED))

	lines.append("")
	lines.append("[b]Movimientos[/b]")
	for mvar in mon.movements:
		var mv: Move = mvar as Move
		if mv == null or mv.base == null:
			continue
		lines.append("· %s  (%d/%d PP)" % [mv.base.Name, mv.pp_actual, mv.pp])

	if mon.movements.is_empty():
		lines.append("—")

	return "\n".join(lines)
