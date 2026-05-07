@tool
extends EditorScript

const ITEMS_DIR := "res://Resources/Data/Items/"
const REVIVE_CATEGORY := "res://Resources/BattleCategories/Items/BattleReviveItemCategory.tres"

const HEALING_EFFECT := preload("res://Scripts/Resources/Effects/HealingItemEffect.gd")
const STATUS_HEAL_EFFECT := preload("res://Scripts/Resources/Effects/StatusHealItemEffect.gd")
const REVIVE_EFFECT := preload("res://Scripts/Resources/Effects/ReviveItemEffect.gd")


func _run() -> void:
	var updated := 0
	updated += _patch_status_specific("019 - Antiquemar.tres", [CONST.STATUS.BURN])
	updated += _patch_status_specific("020 - Antihielo.tres", [CONST.STATUS.FROZEN])
	updated += _patch_status_specific("021 - Despertar.tres", [CONST.STATUS.SLEEP])
	updated += _patch_status_specific("022 - Antiparalizador.tres", [CONST.STATUS.PARALYSIS])
	updated += _patch_heal_full("023 - Restaurar Todo.tres")
	updated += _patch_heal_fixed("024 - Poción Máxima.tres", 9999)
	updated += _patch_heal_fixed("025 - Hiperpoción.tres", 200)
	updated += _patch_heal_fixed("026 - Superpoción.tres", 50)
	updated += _patch_status_all("027 - Cura Total.tres")
	updated += _patch_heal_fixed("030 - Agua Fresca.tres", 50)
	updated += _patch_heal_fixed("031 - Refresco.tres", 60)
	updated += _patch_heal_fixed("032 - Limonada.tres", 70)
	updated += _patch_heal_fixed("033 - Leche Mu-mu.tres", 100)
	updated += _patch_heal_fixed("034 - Polvo Energía.tres", 50)
	updated += _patch_heal_fixed("035 - Raíz Energía.tres", 200)
	updated += _patch_status_all("036 - Polvo Curación.tres")
	updated += _patch_pp_item_meta("038 - Éter.tres", ItemEnums.TargetType.MOVE_SLOT)
	updated += _patch_pp_item_meta("039 - Éter Máximo.tres", ItemEnums.TargetType.MOVE_SLOT)
	updated += _patch_pp_item_meta("040 - Elixir.tres", ItemEnums.TargetType.POKEMON)
	updated += _patch_pp_item_meta("041 - Elixir Máximo.tres", ItemEnums.TargetType.POKEMON)
	updated += _patch_status_all("042 - Galleta Lava.tres")
	updated += _patch_heal_fixed("043 - Zumo de Baya.tres", 20)
	updated += _patch_revive_full_with_meta("044 - Ceniza Sagrada.tres", ItemEnums.UseContext.OVERWORLD | ItemEnums.UseContext.PARTY_MENU)
	updated += _patch_status_all("054 - Barrita Plus.tres")
	updated += _patch_status_specific("567 - Corazón Dulce.tres", [CONST.STATUS.POISON])
	updated += _patch_status_all("632 - Porcehelado.tres")
	updated += _patch_status_all("728 - Crêpe Luminalia.tres")
	updated += _patch_status_all("765 - Galleta Yantra.tres")
	updated += _patch_status_all("888 - Malasada Maxi.tres")

	print("[normalize_item_resources] Items normalizados: %d" % updated)


func _load_item(file_name: String) -> Resource:
	var path := ITEMS_DIR + file_name
	var item_res := ResourceLoader.load(path)
	if item_res == null:
		push_warning("[normalize_item_resources] No se pudo cargar: %s" % path)
	return item_res


func _save_item(file_name: String, item_res: Resource) -> int:
	if item_res == null:
		return 0
	var path := ITEMS_DIR + file_name
	var err := ResourceSaver.save(item_res, path)
	if err != OK:
		push_warning("[normalize_item_resources] Error guardando %s (%d)" % [path, err])
		return 0
	return 1


func _ensure_common_target_item_meta(item_res: Resource) -> void:
	item_res.set("allowed_contexts", ItemEnums.UseContext.OVERWORLD | ItemEnums.UseContext.PARTY_MENU | ItemEnums.UseContext.BATTLE)
	item_res.set("target_type", ItemEnums.TargetType.POKEMON)


func _new_healing_effect_fixed(amount: int) -> Resource:
	var fx: Resource = HEALING_EFFECT.new()
	fx.set("heal_mode", HealingItemEffect.HealMode.FIXED_AMOUNT)
	fx.set("heal_amount", amount)
	return fx


func _new_healing_effect_full() -> Resource:
	var fx: Resource = HEALING_EFFECT.new()
	fx.set("heal_mode", HealingItemEffect.HealMode.FULL_HEAL)
	return fx


func _new_status_effect_all() -> Resource:
	var fx: Resource = STATUS_HEAL_EFFECT.new()
	fx.set("cure_mode", StatusHealItemEffect.CureMode.ALL_STATUS)
	return fx


func _new_status_effect_specific(statuses: Array[int]) -> Resource:
	var fx: Resource = STATUS_HEAL_EFFECT.new()
	fx.set("cure_mode", StatusHealItemEffect.CureMode.SPECIFIC_STATUS)
	fx.set("status_to_cure", statuses)
	return fx


func _new_revive_effect_full() -> Resource:
	var fx: Resource = REVIVE_EFFECT.new()
	fx.set("revive_mode", ReviveItemEffect.ReviveMode.FULL)
	return fx


func _patch_heal_fixed(file_name: String, amount: int) -> int:
	var item := _load_item(file_name)
	if item == null:
		return 0
	_ensure_common_target_item_meta(item)
	item.set("effect", _new_healing_effect_fixed(amount))
	return _save_item(file_name, item)


func _patch_heal_full(file_name: String) -> int:
	var item := _load_item(file_name)
	if item == null:
		return 0
	_ensure_common_target_item_meta(item)
	item.set("effect", _new_healing_effect_full())
	return _save_item(file_name, item)


func _patch_status_all(file_name: String) -> int:
	var item := _load_item(file_name)
	if item == null:
		return 0
	_ensure_common_target_item_meta(item)
	item.set("effect", _new_status_effect_all())
	return _save_item(file_name, item)


func _patch_status_specific(file_name: String, statuses: Array[int]) -> int:
	var item := _load_item(file_name)
	if item == null:
		return 0
	_ensure_common_target_item_meta(item)
	item.set("effect", _new_status_effect_specific(statuses))
	return _save_item(file_name, item)


func _patch_pp_item_meta(file_name: String, target_type: int) -> int:
	var item := _load_item(file_name)
	if item == null:
		return 0
	item.set("allowed_contexts", ItemEnums.UseContext.OVERWORLD | ItemEnums.UseContext.PARTY_MENU)
	item.set("target_type", target_type)
	return _save_item(file_name, item)


func _patch_revive_full_with_meta(file_name: String, allowed_ctx: int) -> int:
	var item := _load_item(file_name)
	if item == null:
		return 0
	item.set("kind", ItemEnums.Kind.REVIVE)
	item.set("allowed_contexts", allowed_ctx)
	item.set("target_type", ItemEnums.TargetType.POKEMON)
	item.set("category", load(REVIVE_CATEGORY))
	item.set("effect", _new_revive_effect_full())
	return _save_item(file_name, item)
