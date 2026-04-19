extends RefCounted

class_name MoveLearningFlowController

enum OriginContext {
	BATTLE,
	BAG_TM,
	OTHER,
}

class FlowResult extends RefCounted:
	var learned: bool = false
	var declined: bool = false
	var replaced_old_move: Move = null
	var learned_move: Move = null


## `show_message_fn(texto)` y `show_choices_fn(texto, opciones:Array[String]) -> int` se inyectan por contexto.
func start_move_learning_flow(
	pokemon: Pokemon,
	move: Move,
	_origin_context: int,
	show_message_fn: Callable,
	show_choices_fn: Callable,
	select_forget_move_fn: Callable = Callable()
) -> FlowResult:
	var r := FlowResult.new()
	if pokemon == null or move == null or move.base == null:
		return r
	r.learned_move = move

	if pokemon.knows_move_id(move.base.id):
		return r

	if pokemon.movements.size() < 4:
		pokemon.movements.append(move)
		r.learned = true
		await _show(show_message_fn, "¡%s aprendió %s!" % [pokemon.get_display_name(), move.get_move_name()])
		return r

	while true:
		await _show(show_message_fn, "%s intenta aprender %s." % [pokemon.get_display_name(), move.get_move_name()])
		await _show(show_message_fn, "Pero %s no puede aprender más de cuatro movimientos." % pokemon.get_display_name())
		var ask_text := "¿Quieres sustituir uno de esos movimientos por %s?" % move.get_move_name()
		var yes_no: int = await _choose(show_choices_fn, ask_text, ["Sí", "No"])
		if yes_no != 0:
			var stop_learning_text := "¿Prefieres que no aprenda %s?" % move.get_move_name()
			var confirm_no_learn: int = await _choose(show_choices_fn, stop_learning_text, ["Sí", "No"])
			if confirm_no_learn == 0:
				r.declined = true
				await _show(show_message_fn, "¡%s no aprendió %s!" % [pokemon.get_display_name(), move.get_move_name()])
				return r
			continue

		var selected_index: int = -1
		if select_forget_move_fn.is_valid():
			selected_index = int(await select_forget_move_fn.call(pokemon, move))
		else:
			var option_names: Array[String] = []
			for mv_var in pokemon.movements:
				var mv: Move = mv_var as Move
				option_names.append(mv.get_move_name() if mv != null else "---")
			selected_index = await _choose(show_choices_fn, "Elige el movimiento que olvidar.", option_names)
		if selected_index < 0 or selected_index >= pokemon.movements.size():
			var stop_learning_text2 := "¿Prefieres que no aprenda %s?" % move.get_move_name()
			var confirm_no_learn2: int = await _choose(show_choices_fn, stop_learning_text2, ["Sí", "No"])
			if confirm_no_learn2 == 0:
				r.declined = true
				await _show(show_message_fn, "¡%s no aprendió %s!" % [pokemon.get_display_name(), move.get_move_name()])
				return r
			continue

		var old_move: Move = pokemon.replace_move_at(selected_index, move)
		r.learned = true
		r.replaced_old_move = old_move
		await _show(show_message_fn, "1, 2 y ... ... ... ¡puf!")
		if old_move != null:
			await _show(show_message_fn, "%s olvidó %s." % [pokemon.get_display_name(), old_move.get_move_name()])
		await _show(show_message_fn, "Y...")
		await _show(show_message_fn, "¡%s aprendió %s!" % [pokemon.get_display_name(), move.get_move_name()])
		return r
	return r


func _show(show_message_fn: Callable, text: String) -> void:
	if show_message_fn.is_valid():
		await show_message_fn.call(text)


func _choose(show_choices_fn: Callable, text: String, options: Array[String]) -> int:
	if not show_choices_fn.is_valid():
		return -1
	return int(await show_choices_fn.call(text, options))
