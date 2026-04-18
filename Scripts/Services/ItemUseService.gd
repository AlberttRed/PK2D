extends RefCounted
class_name ItemUseService
## Punto único para ejecutar `ItemEffect` y devolver `ItemUseResult` (sin consumo de Bag aquí).


static func try_use(item_data: ItemData, ctx: ItemUseContext) -> ItemUseResult:
	if item_data == null:
		return ItemUseResult.failure_error("Objeto inválido.")
	if item_data.effect == null:
		return ItemUseResult.failure_error("Este objeto no tiene efecto definido.")
	return item_data.effect.apply(ctx)
