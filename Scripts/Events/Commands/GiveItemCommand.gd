extends EventCommand
class_name GiveItemCommand

## Entrega un objeto al jugador y muestra el mensaje de recibido.

@export var item_id: int = 0
@export_range(1, 999, 1) var quantity: int = 1
@export var show_message: bool = true
@export_multiline var message_template: String = "¡Obtuviste [item]!"

func execute(context: Node) -> void:
	var safe_quantity := maxi(1, quantity)
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null:
		push_warning("GiveItemCommand: item_id=%d no existe en la DB. Se omite entrega." % item_id)
		context.continue_execution()
		return

	var bag_controller := BagController.new()
	var added_amount := bag_controller.add_item(item_id, safe_quantity)
	if added_amount <= 0:
		push_warning("GiveItemCommand: no se pudo añadir item_id=%d (cantidad=%d)." % [item_id, safe_quantity])
		context.continue_execution()
		return

	if show_message:
		var player_name := str(GameStateService.get_variable("PLAYER_NAME", "PLAYER")).strip_edges()
		if player_name.is_empty():
			player_name = "PLAYER"
		var item_name := item_data.get_display_name()
		var pocket_name := _get_pocket_display_name(int(item_data.pocket))
		var primary_message := _build_message(player_name, item_name, added_amount, pocket_name)
		await DisplayManager.show_message(primary_message, {
			"waitInput": true,
			"closeAtEnd": true,
			"waitTime": 0.0,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.HGSS
		})
		var pocket_message := "%s puso %s en el BOLSILLO de %s de la MOCHILA." % [player_name, item_name, pocket_name]
		await DisplayManager.show_message(pocket_message, {
			"waitInput": true,
			"closeAtEnd": true,
			"waitTime": 0.0,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.HGSS
		})

	context.continue_execution()

func is_async() -> bool:
	return show_message

func is_safe_for_parallel() -> bool:
	return false

func _build_message(player_name: String, item_name: String, qty: int, pocket_name: String) -> String:
	var template := message_template.strip_edges()
	if template.is_empty():
		template = "¡Obtuviste [item]!"
	var safe_qty := maxi(1, qty)
	var item_with_qty := _format_item_with_quantity(item_name, safe_qty)
	return template \
		.replace("[player]", player_name) \
		.replace("[item]", item_name) \
		.replace("[item_with_qty]", item_with_qty) \
		.replace("[qty]", str(safe_qty)) \
		.replace("[pocket]", pocket_name)

func _format_item_with_quantity(item_name: String, qty: int) -> String:
	var safe_qty := maxi(1, qty)
	if safe_qty <= 1:
		return item_name
	var plural_name := item_name
	if not plural_name.ends_with("s") and not plural_name.ends_with("S"):
		plural_name += "s"
	return "%d %s" % [safe_qty, plural_name]

func _get_pocket_display_name(pocket: int) -> String:
	match pocket:
		ItemEnums.Pocket.ITEMS:
			return "OBJETOS"
		ItemEnums.Pocket.MEDICINE:
			return "MEDICINAS"
		ItemEnums.Pocket.BALLS:
			return "POKE BALLS"
		ItemEnums.Pocket.TM_HM:
			return "MTs / MOs"
		ItemEnums.Pocket.BERRIES:
			return "BAYAS"
		ItemEnums.Pocket.KEY_ITEMS:
			return "OBJ. CLAVE"
		ItemEnums.Pocket.MACHINES:
			return "CARTAS"
		ItemEnums.Pocket.BATTLE_ITEMS:
			return "OBJ. BATALLA"
		_:
			return "OBJETOS"
