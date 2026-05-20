extends ImmediateBattleEffect
class_name CaptureEffect

## Balanceos mostrados al jugador (checks 0–2). El check 3 solo determina captura.
const MAX_VISIBLE_SHAKES := 3

var target: BattlePokemon
var ball_effect: PokeballItemEffect
var result: CaptureResult = null

var _ball_name: String = "Poké Ball"
var _thrower_name: String = ""


func _init(
	_target: BattlePokemon,
	_ball_effect: PokeballItemEffect,
	_ball_display_name: String = "Poké Ball",
	_thrower_display_name: String = ""
) -> void:
	target = _target
	ball_effect = _ball_effect
	_ball_name = _ball_display_name
	_thrower_name = _thrower_display_name
	result = CaptureResult.new()
	result.target_display_name = _target.get_display_name() if _target != null else "Pokémon"
	result.ball_display_name = _ball_name


func apply() -> void:
	result = CaptureResult.new()
	result.target_display_name = target.get_display_name() if target != null else "Pokémon"
	result.ball_display_name = _ball_name

	if target == null or target.base_data == null or ball_effect == null:
		result.success = false
		result.failure_kind = CaptureResult.FailureKind.EARLY_FAIL
		return

	if ball_effect.guaranteed_capture:
		result.success = true
		result.shakes = MAX_VISIBLE_SHAKES
		result.captured_pokemon = _clone_captured_pokemon(target)
		return

	var catch_rate: int = _resolve_species_capture_rate(target)
	var max_hp: int = maxi(target.total_hp, 1)
	var cur_hp: int = clampi(target.get_hp(), 1, max_hp)
	var ball_mod: float = maxf(ball_effect.capture_ball_modifier, 0.1)

	var a: float = (3.0 * float(max_hp) - 2.0 * float(cur_hp)) * float(catch_rate) * ball_mod
	a /= 3.0 * float(max_hp)
	a *= _status_capture_multiplier(target)

	if a >= 255.0:
		result.success = true
		result.shakes = MAX_VISIBLE_SHAKES
		result.captured_pokemon = _clone_captured_pokemon(target)
		return

	var b: int = _compute_shake_threshold(int(a))

	# Checks 0–2: cada éxito = una sacudida visible (máximo 3).
	for shake_idx in range(MAX_VISIBLE_SHAKES):
		if _shake_check_fails(b):
			result.success = false
			result.shakes = shake_idx
			result.failed_shake_index = shake_idx
			result.failure_kind = CaptureResult.FailureKind.SHAKE_FAIL if shake_idx > 0 else CaptureResult.FailureKind.EARLY_FAIL
			return

	result.shakes = MAX_VISIBLE_SHAKES

	# Check 3: determina si el Pokémon queda atrapado (sin 4.ª sacudida visual).
	if _shake_check_fails(b):
		result.success = false
		result.failed_shake_index = MAX_VISIBLE_SHAKES
		result.failure_kind = CaptureResult.FailureKind.SHAKE_FAIL
		return

	result.success = true
	result.captured_pokemon = _clone_captured_pokemon(target)


func visualize(ui: BattleUI) -> void:
	if ui == null or result == null:
		return

	await ui.show_message_from_dict({
		"type": "display",
		"text": "¡%s lanzó una %s!" % [_actor_name(), _ball_name],
		"wait_time": 0.9,
	})

	if ball_effect != null and ball_effect.guaranteed_capture:
		await _show_shake_message(ui, 1)
		await _show_shake_message(ui, 2)
		await _show_shake_message(ui, 3)
		await ui.show_message_from_dict({
			"type": "display",
			"text": "¡Ya está! ¡%s fue capturado!" % result.target_display_name,
			"wait_time": 1.2,
		})
		return

	if result.success:
		for i in range(result.shakes):
			await _show_shake_message(ui, i + 1)
		await ui.show_message_from_dict({
			"type": "display",
			"text": "¡Ya está! ¡%s fue capturado!" % result.target_display_name,
			"wait_time": 1.2,
		})
		return

	if result.is_early_fail():
		await ui.show_message_from_dict({
			"type": "display",
			"text": "¡Oh no! El Pokémon se escapó de la %s." % _ball_name,
			"wait_time": 1.0,
		})
		return

	for i in range(result.shakes):
		await _show_shake_message(ui, i + 1)
	var fail_text: String
	if result.failed_shake_index >= MAX_VISIBLE_SHAKES:
		fail_text = "¡Oh! ¡%s estuvo a punto de atraparse!" % result.target_display_name
	else:
		fail_text = "¡Vaya! ¡%s se escapó!" % result.target_display_name
	await ui.show_message_from_dict({
		"type": "display",
		"text": fail_text,
		"wait_time": 1.0,
	})


func _actor_name() -> String:
	if not _thrower_name.is_empty():
		return _thrower_name
	var player_name := str(GameStateService.get_variable("PLAYER_NAME", "")).strip_edges()
	if not player_name.is_empty():
		return player_name
	return "El jugador"


func _show_shake_message(ui: BattleUI, shake_number: int) -> void:
	var text := "¡La %s se balancea %d vez!" % [_ball_name, shake_number]
	if shake_number != 1:
		text = "¡La %s se balancea %d veces!" % [_ball_name, shake_number]
	await ui.show_message_from_dict({
		"type": "display",
		"text": text,
		"wait_time": 0.85,
	})


func _resolve_species_capture_rate(target_bp: BattlePokemon) -> int:
	if target_bp == null or target_bp.base_data == null or target_bp.base_data.base == null:
		return 45
	var rate: int = int(target_bp.base_data.base.capture_rate)
	if rate <= 0:
		return 45
	return clampi(rate, 1, 255)


func _status_capture_multiplier(target_bp: BattlePokemon) -> float:
	if target_bp == null or target_bp.base_data == null:
		return 1.0
	match target_bp.base_data.major_status:
		CONST.STATUS.SLEEP, CONST.STATUS.FROZEN:
			return 2.0
		CONST.STATUS.POISON, CONST.STATUS.BURN, CONST.STATUS.PARALYSIS:
			return 1.5
		_:
			return 1.0


func _shake_check_fails(threshold: int) -> bool:
	return randi() % 65536 >= threshold


## Umbral S de Gen VI: 65536 / (255/M)^0.1875 (comparado con rand 0–65535).
## La fórmula antigua (16711680 + mismo exponente) devolvía S > 65536 casi siempre → capturas triviales.
func _compute_shake_threshold(modified_rate: int) -> int:
	var m: int = clampi(modified_rate, 1, 255)
	var ratio: float = 255.0 / float(m)
	var denom: float = pow(ratio, 0.1875)
	if denom <= 0.0:
		return 65535
	return mini(int(65536.0 / denom), 65535)


func _clone_captured_pokemon(wild_bp: BattlePokemon) -> Pokemon:
	if wild_bp == null or wild_bp.base_data == null:
		return null
	var serde := PokemonRuntimeSerde.new()
	var data: Dictionary = wild_bp.base_data.to_serializable_state()
	data["is_wild"] = false
	var mon: Pokemon = serde.deserialize(data) as Pokemon
	if mon == null:
		return null
	mon.is_wild = false
	mon.capture_level = mon.level
	mon.capture_date = Time.get_datetime_string_from_system(true, true)
	var map_id := GameStateService.get_current_map_id()
	if not map_id.is_empty():
		mon.capture_route = map_id
	var player_name := str(GameStateService.get_variable("PLAYER_NAME", "")).strip_edges()
	if not player_name.is_empty():
		mon.original_trainer = player_name
	return mon
