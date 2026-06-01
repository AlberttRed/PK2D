extends ItemEffect
class_name PokeballItemEffect

## Multiplicador de la fórmula de captura (Poké Ball = 1.0, Super = 1.5, Ultra = 2.0, etc.).
@export_range(0.1, 4.0, 0.1) var capture_ball_modifier: float = 1.0
## Captura garantizada (Master Ball).
@export var guaranteed_capture: bool = false


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
