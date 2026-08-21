extends Object
class_name BattleFieldAnimations

## Clips de campo reutilizables (intro / switch). Solo presentación.

const POKEBALL_THROW_PATH := "res://Scenes/Battle/animations/intro/PokeballThrowAnimation.tres"
const POKEMON_ENTER_PATH := "res://Scenes/Battle/animations/intro/PokemonEnterAnimation.tres"

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
