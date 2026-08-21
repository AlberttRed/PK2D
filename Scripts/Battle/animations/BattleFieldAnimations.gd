extends Object
class_name BattleFieldAnimations

## Clips de campo reutilizables (intro / switch). Solo presentación.

const POKEBALL_THROW_PATH := "res://Scenes/Battle/animations/intro/PokeballThrowAnimation.tres"
const POKEMON_ENTER_PATH := "res://Scenes/Battle/animations/intro/PokemonEnterAnimation.tres"
const BASE_ENTER_DURATION := 1.35

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


## Provisional hasta animación de exit: oculta el trainer del lado del spot.
static func hide_trainer_for_spot(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or ui.field_ui == null or landing_spot == null:
		return
	var trainer: Node2D = null
	if landing_spot.side != null and landing_spot.side.type == BattleSide.Types.ENEMY:
		trainer = ui.field_ui.get_enemy_trainer(0)
	else:
		trainer = ui.field_ui.get_player_trainer(0)
	if trainer != null and is_instance_valid(trainer):
		trainer.visible = false


## Lanza la ball hacia el spot de aterrizaje (Feet). Fallback no bloqueante.
static func play_pokeball_throw(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or landing_spot == null or not is_instance_valid(landing_spot):
		return
	# Sin exit clip aún: quitar trainer justo antes del throw.
	hide_trainer_for_spot(ui, landing_spot)
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


## Secuencia send-in: ball → enter → HP bar.
static func play_send_in(ui: BattleUI, landing_spot: BattleSpot) -> void:
	if ui == null or landing_spot == null or not is_instance_valid(landing_spot):
		return
	landing_spot.set_pokemon_sprite_visible(false)
	if landing_spot.hp_bar:
		landing_spot.hp_bar.visible = false
	await play_pokeball_throw(ui, landing_spot)
	# El enter hace visible el sprite desde silueta pequeña (evita flash a tamaño completo).
	await play_pokemon_enter(ui, landing_spot)
	if landing_spot.hp_bar:
		landing_spot.hp_bar.visible = true
