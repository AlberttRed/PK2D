extends Object
class_name BattleFieldAnimations

## Clips de campo reutilizables (intro / switch). Solo presentación.

const POKEBALL_THROW_PATH := "res://Scenes/Battle/animations/intro/PokeballThrowAnimation.tres"
const POKEMON_ENTER_PATH := "res://Scenes/Battle/animations/intro/PokemonEnterAnimation.tres"
const BASE_ENTER_DURATION := 1.35
const TRAINER_EXIT_DURATION := 1.1
const TRAINER_EXIT_SLIDE := 360.0
## Rival: ball visible en el suelo antes de empezar a salir.
const ENEMY_EXIT_AFTER_BALL_SEC := 0.38
## Player: deja arrancar el gesto/salida antes de que vuele la ball.
const PLAYER_THROW_AFTER_EXIT_SEC := 0.5

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
	ui.field_ui.apply_trainer_rest_positions(mode)
	ui.field_ui.reveal_intro_trainers(rules)
	BattleAnimationUtils.park_bases_offscreen(
		ui.field_ui.get_player_base(),
		ui.field_ui.get_enemy_base()
	)


## Intro (PBI 706): trainers ya en la base; se deslizan PlayerBase/EnemyBase.
## Player base der→izq, rival izq→der. Sin gesto de brazo.
static func play_intro_trainers_enter(ui: BattleUI, rules: BattleRules) -> void:
	if ui == null or ui.field_ui == null:
		return
	var mode := BattleRules.BattleModes.SINGLE
	if rules != null:
		mode = rules.mode
	ui.field_ui.hide_all_hp_bars(mode)
	ui.field_ui.apply_trainer_rest_positions(mode)
	ui.field_ui.reveal_intro_trainers(rules)
	# Si prepare_intro_field ya aparcó las bases, solo anima hacia reposo.
	await BattleAnimationUtils.battle_bases_enter(
		ui.field_ui.get_player_base(),
		ui.field_ui.get_enemy_base(),
		ui,
		BASE_ENTER_DURATION
	)


## Salida del trainer del lado del spot (player← / rival→). Awaitable.
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


## Secuencia send-in: trainer exit (+ gesto player) en paralelo con ball → enter → HP.
static func play_send_in(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or landing_spot == null or not is_instance_valid(landing_spot):
		return
	landing_spot.set_pokemon_sprite_visible(false)
	if landing_spot.hp_bar:
		landing_spot.hp_bar.visible = false
	if _is_enemy_spot(landing_spot):
		await _send_in_enemy(ui, landing_spot)
	else:
		await _send_in_player(ui, landing_spot)
	await play_pokemon_enter(ui, landing_spot)
	if landing_spot.hp_bar:
		landing_spot.hp_bar.visible = true


static func _is_enemy_spot(landing_spot: BattleSpot) -> bool:
	return (
		landing_spot.side != null
		and landing_spot.side.type == BattleSide.Types.ENEMY
	)


## Rival: ball cae al suelo → trainer sale (en paralelo) → open más tarde (clip).
static func _send_in_enemy(ui: BattleUI, landing_spot: BattleSpot) -> void:
	var trainer: Node2D = ui.field_ui.get_enemy_trainer(0) if ui.field_ui else null
	var exit_tw: Tween = null
	if trainer != null and is_instance_valid(trainer) and trainer.visible:
		if not trainer.has_meta("trainer_rest_pos"):
			trainer.set_meta("trainer_rest_pos", trainer.position)
		var rest: Vector2 = trainer.get_meta("trainer_rest_pos")
		var end := rest + Vector2(TRAINER_EXIT_SLIDE, 0.0)
		exit_tw = ui.create_tween()
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
	await play_pokeball_throw(ui, landing_spot)
	if exit_tw != null and is_instance_valid(exit_tw) and exit_tw.is_running():
		await exit_tw.finished


## Player: gesto de mano + salida; la ball arranca un poco después.
static func _send_in_player(ui: BattleUI, landing_spot: BattleSpot) -> void:
	var trainer: Node2D = ui.field_ui.get_player_trainer(0) if ui.field_ui else null
	var exit_tw: Tween = null
	if trainer != null and is_instance_valid(trainer) and trainer.visible:
		exit_tw = BattleAnimationUtils.start_player_trainer_exit_with_throw(
			trainer, TRAINER_EXIT_DURATION, TRAINER_EXIT_SLIDE
		)
	await BattleAnimationUtils.wait(ui, PLAYER_THROW_AFTER_EXIT_SEC)
	await play_pokeball_throw(ui, landing_spot)
	if exit_tw != null and is_instance_valid(exit_tw) and exit_tw.is_running():
		await exit_tw.finished
	if trainer != null and is_instance_valid(trainer) and trainer.visible:
		BattleAnimationUtils.finalize_trainer_exit(trainer)
