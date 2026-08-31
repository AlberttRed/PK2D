extends ItemEffect
class_name PokeballItemEffect

const BATTLE_PICTURES_DIR := "res://Sprites/Pictures/"
const SUMMARY_DIR := "res://Sprites/UI/Party/"
const DEFAULT_BALL_SPRITE_ID := "ball00"

## Multiplicador de la fórmula de captura (Poké Ball = 1.0, Super = 1.5, Ultra = 2.0, etc.).
@export_range(0.1, 4.0, 0.1) var capture_ball_modifier: float = 1.0
## Captura garantizada (Master Ball).
@export var guaranteed_capture: bool = false
## Prefijo de sprite Essentials (ball00 = Poké Ball, ball01 = Super Ball, etc.).
@export var ball_sprite_id: String = DEFAULT_BALL_SPRITE_ID


static func resolve_for_item(item_data: ItemData) -> PokeballItemEffect:
	if item_data == null:
		return null
	if item_data.effect is PokeballItemEffect:
		return item_data.effect as PokeballItemEffect
	return _create_default_for_item(item_data)


static func _create_default_for_item(item_data: ItemData) -> PokeballItemEffect:
	var eff := PokeballItemEffect.new()
	var name_key := item_data.internal_name.to_lower()
	eff.guaranteed_capture = name_key == "master-ball"
	eff.capture_ball_modifier = _default_modifier_for_name(name_key)
	eff.ball_sprite_id = _default_sprite_id_for_name(name_key)
	return eff


static func _default_modifier_for_name(internal_name: String) -> float:
	match internal_name:
		"great-ball":
			return 1.5
		"ultra-ball":
			return 2.0
		"master-ball":
			return 255.0
		_:
			return 1.0


static func _default_sprite_id_for_name(internal_name: String) -> String:
	match internal_name:
		"great-ball":
			return "ball01"
		"ultra-ball":
			return "ball03"
		"master-ball":
			return "ball04"
		"safari-ball":
			return "ball02"
		_:
			return DEFAULT_BALL_SPRITE_ID


static func normalize_ball_sprite_id(ball_id: String) -> String:
	if ball_id.is_empty():
		return DEFAULT_BALL_SPRITE_ID
	return ball_id


static func get_battle_closed_texture(ball_id: String) -> Texture2D:
	var id := normalize_ball_sprite_id(ball_id)
	var tex := load(BATTLE_PICTURES_DIR + id + ".png") as Texture2D
	if tex != null:
		return tex
	if id != DEFAULT_BALL_SPRITE_ID:
		push_warning("PokeballItemEffect: no se encontró %s.png, usando ball00." % id)
		return get_battle_closed_texture(DEFAULT_BALL_SPRITE_ID)
	return null


static func get_battle_throw_sheet_path(ball_id: String) -> String:
	return BATTLE_PICTURES_DIR + normalize_ball_sprite_id(ball_id) + "_throw.png"


static func get_battle_fail_sheet_path(ball_id: String) -> String:
	return BATTLE_PICTURES_DIR + normalize_ball_sprite_id(ball_id) + "_fail.png"


static func get_summary_texture(ball_id: String) -> Texture2D:
	var id := normalize_ball_sprite_id(ball_id)
	var suffix := id.trim_prefix("ball")
	var tex := load(SUMMARY_DIR + "summaryball" + suffix + ".png") as Texture2D
	if tex != null:
		return tex
	if id != DEFAULT_BALL_SPRITE_ID:
		push_warning("PokeballItemEffect: no se encontró summaryball%s.png, usando summaryball00." % suffix)
		return get_summary_texture(DEFAULT_BALL_SPRITE_ID)
	return null


func can_use(context: ItemUseContext) -> bool:
	if not context.is_battle_use():
		return false
	if context.battle_controller == null or context.battle_controller.rules == null:
		return false
	if context.battle_controller.rules.type != BattleRules.BattleTypes.WILD:
		return false
	return _is_capturable_target(context)


func apply(context: ItemUseContext) -> ItemUseResult:
	var outside := context.failure_if_not_battle_use()
	if outside != null:
		return outside

	var battle_err := require_battle_runtime(context)
	if battle_err != null:
		return battle_err

	if context.battle_controller.rules.type != BattleRules.BattleTypes.WILD:
		return ItemUseResult.failure_blocked("¡No puedes capturar el Pokémon de otro entrenador!")

	if not _is_capturable_target(context):
		return ItemUseResult.failure_blocked("No hay un Pokémon salvaje capturable.")

	return ItemUseResult.success_result(1, "", {
		"capture_ball_modifier": capture_ball_modifier,
		"guaranteed_capture": guaranteed_capture,
	})


func _is_capturable_target(context: ItemUseContext) -> bool:
	var target_bp: BattlePokemon = context.target_battle_pokemon
	if target_bp == null or target_bp.base_data == null:
		return false
	if target_bp.is_fainted():
		return false
	return target_bp.is_wild
