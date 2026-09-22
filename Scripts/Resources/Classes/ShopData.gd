## ShopData — catálogo de tienda + API buy/sell atómica (#833).
##
## Precios siempre desde ItemData (sin override por tienda en MVP).
## Money → GameStateService; inventario → Bag. Sin ShopService / autoload.
extends Resource
class_name ShopData

## Identificador opcional (eventos, saves, debug).
@export var shop_id: String = ""

## Nombre para mostrar en UI (#834 / #836).
@export var display_name: String = ""

## Catálogo de la tienda: solo estos `item_id` se pueden comprar aquí.
@export var item_ids: Array[int] = []


func has_in_catalog(item_id: int) -> bool:
	return item_id > 0 and item_ids.has(item_id)


## Compra posible: en catálogo, buy_price > 0, dinero suficiente y bag acepta qty completa.
func can_buy(item_id: int, qty: int) -> bool:
	if item_id <= 0 or qty <= 0:
		return false
	if not has_in_catalog(item_id):
		return false

	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null or not item_data.is_buyable():
		return false

	var total_cost: int = item_data.buy_price * qty
	if total_cost < 0:
		return false
	if not GameStateService.can_afford(total_cost):
		return false

	return _bag_can_accept(GameStateService.get_bag(), item_id, qty, item_data)


## Compra atómica: money + bag. Si falla cualquier paso, no deja estado a medias.
func buy(item_id: int, qty: int) -> bool:
	if not can_buy(item_id, qty):
		return false

	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		return false

	var total_cost: int = item_data.buy_price * qty
	if not GameStateService.remove_money(total_cost):
		return false

	var bag = GameStateService.get_bag()
	var added: int = bag.add_item(item_id, qty)
	if added != qty:
		if added > 0:
			bag.remove_item(item_id, added)
		GameStateService.add_money(total_cost)
		return false

	return true


## Venta posible: sell_price > 0 y cantidad en bag. No depende del catálogo de esta tienda.
func can_sell(item_id: int, qty: int) -> bool:
	return _can_sell(item_id, qty)


## Venta atómica: bag → money. Independiente del catálogo.
func sell(item_id: int, qty: int) -> bool:
	return _sell(item_id, qty)


## Variante estática (vender no necesita instancia de tienda).
static func can_sell_item(item_id: int, qty: int) -> bool:
	return _can_sell(item_id, qty)


static func sell_item(item_id: int, qty: int) -> bool:
	return _sell(item_id, qty)


static func _can_sell(item_id: int, qty: int) -> bool:
	if item_id <= 0 or qty <= 0:
		return false

	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null or not item_data.is_sellable():
		return false

	return GameStateService.get_bag().has_item(item_id, qty)


static func _sell(item_id: int, qty: int) -> bool:
	if not _can_sell(item_id, qty):
		return false

	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		return false

	var total_gain: int = item_data.sell_price * qty
	var bag = GameStateService.get_bag()
	var removed: int = bag.remove_item(item_id, qty)
	if removed != qty:
		if removed > 0:
			bag.add_item(item_id, removed)
		return false

	GameStateService.add_money(total_gain)
	return true


static func _bag_can_accept(bag, item_id: int, qty: int, item_data: ItemData) -> bool:
	if bag == null or item_data == null or qty <= 0:
		return false

	var stack_limit: int = int(item_data.stack_limit)
	if stack_limit <= 0:
		return true

	var current: int = int(bag.get_quantity(item_id))
	return current + qty <= stack_limit
