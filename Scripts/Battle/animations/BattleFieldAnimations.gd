extends Object
class_name BattleFieldAnimations

## Clips de campo reutilizables (intro / switch). Solo presentación.

const ENEMY_SEND_IN_PARTY_FADE_SEC := BattlePartyBarUI.FADE_OUT_DURATION
## Retardo extra tras arrancar el exit del trainer antes de retirar la party.
const PARTY_ROLL_OUT_AFTER_TRAINER_EXIT_SEC := 0.22
const POKEBALL_THROW_PATH := "res://Scenes/Battle/animations/intro/PokeballThrowAnimation.tres"
const POKEMON_ENTER_PATH := "res://Scenes/Battle/animations/intro/PokemonEnterAnimation.tres"
const BASE_ENTER_DURATION := 1.35
## Party intro arranca a esta fracción del slide de bases (solapa con trainer/base).
const PARTY_INTRO_START_AT_BASE_FRACTION := 0.55
const TRAINER_EXIT_DURATION := 1.1
const TRAINER_EXIT_SLIDE := 360.0
## Rival: ball visible en el suelo antes de empezar a salir.
const ENEMY_EXIT_AFTER_BALL_SEC := 0.38
## Player: deja arrancar el gesto/salida antes de que vuele la ball.
const PLAYER_THROW_AFTER_EXIT_SEC := 0.5
## Clips throw_*: instante en que se abre / empieza el brillo (ver PokeballThrowAnimation.tscn).
const THROW_OPEN_PLAYER_SEC := 0.58
const THROW_OPEN_ENEMY_SEC := 1.15
## Por encima de BattleAnimationLayer (z=1) para que el grow tape la ball.
const POKEMON_ABOVE_THROW_Z := 5

static var _pokeball_throw: BattleAnimation = null
static var _pokemon_enter: BattleAnimation = null


static func get_pokeball_throw() -> BattleAnimation:
	if _pokeball_throw == null:
		if not ResourceLoader.exists(POKEBALL_THROW_PATH):
			return null
		_pokeball_throw = load(POKEBALL_THROW_PATH) as BattleAnimation
	return _pokeball_throw


static func get_pokemon_enter() -> BattleAnimation:
	if _pokemon_enter == null:
		if not ResourceLoader.exists(POKEMON_ENTER_PATH):
			return null
		_pokemon_enter = load(POKEMON_ENTER_PATH) as BattleAnimation
	return _pokemon_enter


## Prepara intro mientras la pantalla está en negro: HP ocultas, trainers en base,
## bases ya en posición inicial (fuera) para no flash al reveal.
static func prepare_intro_field(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null:
		return
	var mode := BattleRules.BattleModes.SINGLE
	if rules != null:
		mode = rules.mode
	ui.field_ui.hide_all_hp_bars(mode)
	ui.field_ui.hide_all_party_bars()
	ui.field_ui.apply_trainer_rest_positions(mode)
	ui.field_ui.reveal_intro_trainers(rules)
	BattleAnimationUtils.park_bases_offscreen(
		ui.field_ui.get_player_base(),
		ui.field_ui.get_enemy_base()
	)


## Intro (PBI 706): bases/trainers entran; party arranca ~a mitad del slide de bases.
static func play_intro_trainers_enter(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null:
		return
	var mode := BattleRules.BattleModes.SINGLE
	if rules != null:
		mode = rules.mode
	ui.field_ui.hide_all_hp_bars(mode)
	ui.field_ui.apply_trainer_rest_positions(mode)
	ui.field_ui.reveal_intro_trainers(rules)

	var done := {"bases": false, "party": false}

	(
		func() -> void:
			await BattleAnimationUtils.battle_bases_enter(
				ui.field_ui.get_player_base(),
				ui.field_ui.get_enemy_base(),
				ui,
				BASE_ENTER_DURATION
			)
			done.bases = true
	).call()

	(
		func() -> void:
			await BattleAnimationUtils.wait(
				ui, BASE_ENTER_DURATION * PARTY_INTRO_START_AT_BASE_FRACTION
			)
			await show_party_bars(ui, rules)
			done.party = true
	).call()

	while ui != null and is_instance_valid(ui) and ui.get_tree() != null:
		if done.bases and done.party:
			return
		await ui.get_tree().process_frame


## Barra de party: slide in (player siempre; rival solo trainer).
static func show_party_bars(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null or ui.battle_controller == null:
		return
	await ui.field_ui.show_party_bars(
		ui,
		ui.battle_controller.player_side,
		ui.battle_controller.enemy_side,
		rules
	)


static func hide_party_bars(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null:
		return
	await ui.field_ui.hide_party_bars(ui, rules)


static func hide_party_bar_for_spot(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or ui.field_ui == null or landing_spot == null:
		return
	var rules: BattleRules = null
	if ui.battle_controller != null:
		rules = ui.battle_controller.rules
	ui.field_ui.hide_party_bar_for_spot(ui, landing_spot, rules)


static func refresh_party_bars(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null or ui.battle_controller == null:
		return
	ui.field_ui.refresh_party_bars(
		ui.battle_controller.player_side,
		ui.battle_controller.enemy_side,
		rules
	)


## Envío rival mid-battle: party slide-in → «X saca a Y» → fade → send-in (intro excluida).
static func play_enemy_trainer_send_in_pre_entry(
	ui: BattleUI,
	rules: BattleRules,
	trainer_name: String,
	incoming_name: String
) -> void:
	if ui == null or ui.field_ui == null or ui.battle_controller == null:
		return
	if rules == null or rules.type != BattleRules.BattleTypes.TRAINER:
		return
	await ui.field_ui.show_enemy_party_bar(
		ui,
		ui.battle_controller.enemy_side,
		rules
	)
	await ui.show_enemy_switch_in_message(trainer_name, incoming_name)
	await ui.field_ui.fade_out_enemy_party_bar(ui, ENEMY_SEND_IN_PARTY_FADE_SEC)


## Salida del trainer del lado del spot (player← / rival→). Awaitable.
## Fin de combate (trainer): rival reaparece desde la derecha antes del defeat_message.
static func play_enemy_trainer_defeat_enter(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null:
		return
	if rules == null or rules.type != BattleRules.BattleTypes.TRAINER:
		return
	var mode := rules.mode
	ui.field_ui.apply_trainer_rest_positions(mode)
	var trainer: Node2D = ui.field_ui.get_enemy_trainer(0)
	if trainer == null or not is_instance_valid(trainer):
		push_warning("BattleFieldAnimations: sin trainer rival para defeat enter")
		return
	await BattleAnimationUtils.trainer_enter(
		trainer, false, TRAINER_EXIT_DURATION, TRAINER_EXIT_SLIDE
	)


static func play_trainer_exit_for_spot(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or ui.field_ui == null or landing_spot == null:
		return
	var trainer: Node2D = null
	var to_left := true
	if landing_spot.side != null and landing_spot.side.type == BattleSide.Types.ENEMY:
		trainer = ui.field_ui.get_enemy_trainer(0)
		to_left = false
	else:
		trainer = ui.field_ui.get_player_trainer(0)
		to_left = true
	if trainer == null or not is_instance_valid(trainer):
		return
	await BattleAnimationUtils.trainer_exit(
		trainer, to_left, TRAINER_EXIT_DURATION, TRAINER_EXIT_SLIDE
	)


## Lanza la ball hacia el spot de aterrizaje (Feet). Fallback no bloqueante.
static func play_pokeball_throw(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or landing_spot == null or not is_instance_valid(landing_spot):
		return
	var anim := get_pokeball_throw()
	if anim == null:
		return
	var layer: Node2D = ui.get_animation_layer()
	if layer == null:
		return
	var targets: Array[BattleSpot] = [landing_spot]
	await anim.play(layer, landing_spot, targets)


## Aparición del Pokémon en el spot (blanco + grow). Fallback no bloqueante.
static func play_pokemon_enter(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or landing_spot == null or not is_instance_valid(landing_spot):
		return
	var anim := get_pokemon_enter()
	if anim == null:
		# Fallback directo por si falta el .tres
		await BattleAnimationUtils.pokemon_enter_spot(landing_spot)
		return
	var layer: Node2D = ui.get_animation_layer()
	var targets: Array[BattleSpot] = [landing_spot]
	await anim.play(layer, landing_spot, targets)


## Recall / salida del Pokémon (player slide / rival ball+scale). Awaitable.
static func play_pokemon_exit(ui: BattleUI, leaving_spot: BattleSpot) -> void:
	if ui == null or leaving_spot == null or not is_instance_valid(leaving_spot):
		return
	await BattleAnimationUtils.pokemon_exit_spot(leaving_spot)


## Secuencia send-in: trainer exit (+ gesto player) en paralelo con ball;
## el grow del Pokémon arranca al abrir/brillar la ball (solapa con el final del throw).
static func play_send_in(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or landing_spot == null or not is_instance_valid(landing_spot):
		return
	landing_spot.set_pokemon_sprite_visible(false)
	if landing_spot.hp_bar:
		landing_spot.hp_bar.visible = false

	var is_enemy := _is_enemy_spot(landing_spot)
	var open_at := THROW_OPEN_ENEMY_SEC if is_enemy else THROW_OPEN_PLAYER_SEC
	var exit_tw: Tween = null
	var trainer: Node2D = null

	_start_party_roll_out_with_trainer_exit(ui, landing_spot, is_enemy)

	if is_enemy:
		exit_tw = _start_enemy_trainer_exit(ui)
	else:
		trainer = ui.field_ui.get_player_trainer(0) if ui.field_ui else null
		if trainer != null and is_instance_valid(trainer) and trainer.visible:
			exit_tw = BattleAnimationUtils.start_player_trainer_exit_with_throw(
				trainer, TRAINER_EXIT_DURATION, TRAINER_EXIT_SLIDE
			)
			await BattleAnimationUtils.wait(ui, PLAYER_THROW_AFTER_EXIT_SEC)

	await _play_throw_with_enter_overlap(ui, landing_spot, open_at)

	if landing_spot.hp_bar:
		await landing_spot.play_hp_bar_slide_in()

	if exit_tw != null and is_instance_valid(exit_tw) and exit_tw.is_running():
		await exit_tw.finished
	if trainer != null and is_instance_valid(trainer) and trainer.visible:
		BattleAnimationUtils.finalize_trainer_exit(trainer)


static func _is_enemy_spot(landing_spot: BattleSpot) -> bool:
	return (
		landing_spot.side != null
		and landing_spot.side.type == BattleSide.Types.ENEMY
	)


## Throw en paralelo; al llegar a `open_at` arranca el enter (scale/blanco).
static func _play_throw_with_enter_overlap(
	ui: BattleUI,
	landing_spot: BattleSpot,
	open_at: float
) -> void:
	var flags := {"throw": false, "enter": false}

	var run_throw := func() -> void:
		await play_pokeball_throw(ui, landing_spot)
		flags.throw = true
	run_throw.call()

	await BattleAnimationUtils.wait(ui, open_at)

	# BattleAnimationLayer (z=1) pinta la ball por encima del spot; al crecer el
	# Pokémon debe quedar delante de la ball abierta/brillo.
	var spr: Sprite2D = landing_spot.sprite
	var prev_sprite_z := 0
	if spr != null and is_instance_valid(spr):
		prev_sprite_z = spr.z_index
		spr.z_index = POKEMON_ABOVE_THROW_Z

	var run_enter := func() -> void:
		await play_pokemon_enter(ui, landing_spot)
		flags.enter = true
	run_enter.call()

	# Espera a que termine el grow (el fade de la ball puede seguir en paralelo).
	while not flags.enter:
		if ui == null or not is_instance_valid(ui) or ui.get_tree() == null:
			return
		await ui.get_tree().process_frame

	# Si el throw aún no acabó (fade), espera un poco para no cortar la ball.
	var guard := 0
	while not flags.throw and guard < 90:
		if ui == null or not is_instance_valid(ui) or ui.get_tree() == null:
			return
		await ui.get_tree().process_frame
		guard += 1

	if spr != null and is_instance_valid(spr):
		spr.z_index = prev_sprite_z


## Party intro: sale en paralelo al exit del trainer (player al instante; rival tras delay de ball).
static func _start_party_roll_out_with_trainer_exit(
	ui: BattleUI,
	landing_spot: BattleSpot,
	is_enemy: bool
) -> void:
	(
		func() -> void:
			if is_enemy:
				await BattleAnimationUtils.wait(ui, ENEMY_EXIT_AFTER_BALL_SEC)
			await BattleAnimationUtils.wait(ui, PARTY_ROLL_OUT_AFTER_TRAINER_EXIT_SEC)
			hide_party_bar_for_spot(ui, landing_spot)
	).call()


static func _start_enemy_trainer_exit(ui: BattleUI) -> Tween:
	if ui == null or ui.field_ui == null:
		return null
	var trainer: Node2D = ui.field_ui.get_enemy_trainer(0)
	if trainer == null or not is_instance_valid(trainer) or not trainer.visible:
		return null
	if not trainer.has_meta("trainer_rest_pos"):
		trainer.set_meta("trainer_rest_pos", trainer.position)
	var rest: Vector2 = trainer.get_meta("trainer_rest_pos")
	var end := rest + Vector2(TRAINER_EXIT_SLIDE, 0.0)
	var exit_tw := ui.create_tween()
	exit_tw.tween_interval(ENEMY_EXIT_AFTER_BALL_SEC)
	exit_tw.tween_property(trainer, "position", end, TRAINER_EXIT_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	exit_tw.tween_callback(
		func():
			if is_instance_valid(trainer):
				trainer.visible = false
				trainer.position = rest
	)
	return exit_tw
