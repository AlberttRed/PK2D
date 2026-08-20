class_name StatChangeEffect
extends ImmediateBattleEffect

var stat_changes: Array[StatChange] = []

var _has_stat_up: bool = false
var _has_stat_down: bool = false

func _init(_target: BattlePokemon, _stats_changes_list: Dictionary[StatsEnum.Values, int]):
	target = _target
	# Convertir el diccionario a array de StatChange
	for stat in _stats_changes_list:
		stat_changes.append(StatChange.new(stat, _stats_changes_list[stat]))

func apply() -> void:
	for stat_change in stat_changes:
		if stat_change.amount > 0:
			stat_change.applied = target.stat_stages.increase(stat_change.stat, stat_change.amount)
			if stat_change.applied:
				_has_stat_up = true
		else:
			if _should_validate_stat_change(user, target):
				var ctx := BattlePhaseContext.for_stat_change(
					target, user, stat_change.stat, stat_change.amount
				)
				BattleEffectController.run_apply_phase(
					target, BattleEffect.Phases.ON_VALIDATE_STAT, ctx
				)
				if ctx.validation != null and ctx.validation.rejected:
					stat_change.block_reason = ctx.validation.block_reason
					stat_change.rejection_message = ctx.validation.rejection_message
					stat_change.applied = false
					continue
			stat_change.applied = target.stat_stages.decrease(
				stat_change.stat, abs(stat_change.amount)
			)
			if stat_change.applied:
				_has_stat_down = true


func _should_validate_stat_change(source: BattlePokemon, change_target: BattlePokemon) -> bool:
	if source == null or change_target == null:
		return false
	if source.side == null or change_target.side == null:
		return false
	return source.side != change_target.side

func visualize(ui: BattleUI):
	# Determinar el tipo de situación
	var is_single_stat = stat_changes.size() == 1
	var is_all_failed = stat_changes.all(func(stat_change): return not stat_change.applied)
	
	# Animación de stats que suben (solo una vez si alguno se aplicó)
	if _has_stat_up:
		await target.battle_spot.play_stat_up_animation()
	
	# Mensajes para stats que suben
	# - Si es un solo stat: siempre mostrar mensaje (aplicado o no)
	# - Si son múltiples stats: solo mostrar los que se aplicaron
	for stat_change in stat_changes.filter(func(stat_change): return stat_change.amount > 0):
		if stat_change.applied or is_single_stat:
			await ui.show_stat_stage_change_message(target, stat_change.stat, stat_change.amount, stat_change.applied)
	
	# Animación de stats que bajan (solo una vez si alguno se aplicó)
	if _has_stat_down:
		await target.battle_spot.play_stat_down_animation()
	
	# Mensajes para stats que bajan
	# - Si es un solo stat: siempre mostrar mensaje (aplicado o no)
	# - Si son múltiples stats: solo mostrar los que se aplicaron
	for stat_change in stat_changes.filter(func(stat_change): return stat_change.amount < 0):
		if not stat_change.rejection_message.is_empty():
			await ui.show_message_from_dict(stat_change.rejection_message)
		elif stat_change.applied or is_single_stat:
			await ui.show_stat_stage_change_message(target, stat_change.stat, stat_change.amount, stat_change.applied)
	
	# Mensaje genérico cuando múltiples stats intentan cambiar pero TODOS fallan
	# Ejemplo: Danza Dragón cuando Ataque y Velocidad ya están al máximo
	if is_all_failed and !is_single_stat:
		await ui.show_generic_stat_stage_failed_message(target, stat_changes[0].amount > 0)
