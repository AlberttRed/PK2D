class_name AilmentData
extends Resource

## `CONST.STATUS` (overworld / `Pokemon.major_status`) → recursos bajo `res://Resources/Data/Ailments/`.
const _MAJOR_STATUS_TO_PATH: Dictionary = {
	CONST.STATUS.SLEEP: "res://Resources/Data/Ailments/SLEEP.tres",
	CONST.STATUS.POISON: "res://Resources/Data/Ailments/POISON.tres",
	CONST.STATUS.BURN: "res://Resources/Data/Ailments/BURN.tres",
	CONST.STATUS.PARALYSIS: "res://Resources/Data/Ailments/PARALYSIS.tres",
	CONST.STATUS.FROZEN: "res://Resources/Data/Ailments/FREEZE.tres",
}

static var _major_status_ailment_cache: Dictionary = {}

# Esquema unificado: id numérico e internal_name en minúsculas
@export var id: int = 0                 # ID numérico (PokeAPI)
@export var internal_name: String = "" # nombre interno en minúsculas ("paralysis")

@export var display_name: String     # Nombre visible ("Parálisis")
@export var description: String = "" # Texto opcional descriptivo
@export var icon: Texture2D = null   # Icono opcional para mostrar en batalla
@export var is_persistent: bool = true  # Si persiste fuera de combate o al hacer switch
@export var effect: Resource = null        # Script del PersistentBattleEffect asociado
## Animación visual al aplicar y al repetir el efecto (p. ej. burn). Solo presentación.
@export var battle_animation: BattleAnimation = null

func get_effect(_min_turn = null, _max_turn = null, _application_chance: int = 100):
	return effect.new(self, _min_turn, _max_turn, _application_chance) if effect != null else null


func get_battle_animation() -> BattleAnimation:
	return battle_animation


## Reproduce battle_animation sobre el spot del Pokémon (si existe). Solo presentación.
func play_battle_animation_on(ui: BattleUI, pokemon: BattlePokemon) -> void:
	if ui == null or pokemon == null:
		return
	var anim := get_battle_animation()
	if anim == null:
		return
	var layer: Node2D = ui.get_animation_layer()
	var spot: BattleSpot = (
		pokemon.resolve_battle_spot()
		if pokemon.has_method("resolve_battle_spot")
		else pokemon.battle_spot
	)
	if spot == null:
		return
	var targets: Array[BattleSpot] = [spot]
	await anim.play(layer, spot, targets)


# Helper para obtener el enum de mensajes de forma segura durante la transición
func get_enum_value() -> int:
	if id != 0:
		return AilmentsEnum.from_id(id)
	elif internal_name != "":
		return AilmentsEnum.from_string(internal_name)
	else:
		return AilmentsEnum.Values.NONE


## Recurso de combate para un estado mayor fuera de combate, o `null` si no aplica.
static func from_major_status(major_status: int) -> AilmentData:
	if major_status == CONST.STATUS.OK or major_status == CONST.STATUS.NONE:
		return null
	var path: Variant = _MAJOR_STATUS_TO_PATH.get(major_status)
	if path == null or str(path).is_empty():
		return null
	if _major_status_ailment_cache.has(path):
		return _major_status_ailment_cache[path]
	if not ResourceLoader.exists(str(path)):
		push_warning("AilmentData: no existe recurso %s" % path)
		return null
	var res: Resource = load(str(path)) as Resource
	if res is AilmentData:
		_major_status_ailment_cache[path] = res
		return res
	return null


## De ailment persistente de combate a `CONST.STATUS` en `Pokemon.major_status`.
static func to_major_status(ailment: AilmentData) -> int:
	if ailment == null:
		return CONST.STATUS.OK
	var ev: int = ailment.get_enum_value()
	match ev:
		AilmentsEnum.Values.POISON:
			return CONST.STATUS.POISON
		AilmentsEnum.Values.BURN:
			return CONST.STATUS.BURN
		AilmentsEnum.Values.PARALYSIS:
			return CONST.STATUS.PARALYSIS
		AilmentsEnum.Values.SLEEP:
			return CONST.STATUS.SLEEP
		AilmentsEnum.Values.FREEZE:
			return CONST.STATUS.FROZEN
		_:
			return CONST.STATUS.OK


## Etiqueta corta para Party / resumen.
static func major_status_display_name(major_status: int) -> String:
	match major_status:
		CONST.STATUS.POISON:
			return "Envenenado"
		CONST.STATUS.BURN:
			return "Quemadura"
		CONST.STATUS.PARALYSIS:
			return "Paralizado"
		CONST.STATUS.SLEEP:
			return "Dormido"
		CONST.STATUS.FROZEN:
			return "Congelado"
		_:
			return "Estado alterado"
