extends BattleIA

class_name TrainerBattleIA

## Sub-base tipada para perfiles de IA de entrenador.
## Solo instancias de esta jerarquía deben asignarse a TrainerData.ai_profile
## (o TrainerClassData.default_ai).
##
## Contrato de dificultad (ver README_BattleIA.md):
## - Contenido actual: BattleIA_TrainerEasy (solo tipos; sin items ni switch voluntario).
## - Futuro: TrainerMedium / TrainerHard (items + switch desde Medium).
## - No existe TrainerBasic de contenido; null/inválida → fallback TrainerEasy.


static func resolve(ai: BattleIA, context: String = "") -> TrainerBattleIA:
	if ai is TrainerBattleIA:
		return ai as TrainerBattleIA
	if ai == null:
		return BattleIA_TrainerEasy.new()
	var ctx := context if not context.is_empty() else "trainer"
	push_warning(
		"BattleIA inválida para trainer [%s]: esperada TrainerBattleIA, recibida '%s'. Aplicando fallback BattleIA_TrainerEasy."
		% [ctx, _describe_ai(ai)]
	)
	return BattleIA_TrainerEasy.new()


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
