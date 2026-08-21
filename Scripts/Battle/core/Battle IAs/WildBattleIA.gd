extends BattleIA

class_name WildBattleIA

## Sub-base tipada para perfiles de IA de Pokémon salvaje.
##
## Contrato (ver README_BattleIA.md):
## - Contenido actual: BattleIA_WildBasic (random legal; sin items/switch).
## - El random legal no es un nivel de dificultad de diseñador: es wild + fallback técnico.
## - Futuro: subclases especiales (p. ej. roaming).


static func resolve(ai: BattleIA, context: String = "") -> WildBattleIA:
	if ai is WildBattleIA:
		return ai as WildBattleIA
	if ai == null:
		return BattleIA_WildBasic.new()
	var ctx := context if not context.is_empty() else "wild"
	push_warning(
		"BattleIA inválida para wild [%s]: esperada WildBattleIA, recibida '%s'. Aplicando fallback BattleIA_WildBasic."
		% [ctx, _describe_ai(ai)]
	)
	return BattleIA_WildBasic.new()


static func _describe_ai(ai: BattleIA) -> String:
	if ai == null:
		return "null"
	var script_path := ""
	var script = ai.get_script()
	if script != null and script.resource_path:
		script_path = script.resource_path.get_file()
	if not ai.difficulty_name.is_empty():
		if script_path.is_empty():
			return ai.difficulty_name
		return "%s (%s)" % [ai.difficulty_name, script_path]
	if not script_path.is_empty():
		return script_path
	return str(ai)
