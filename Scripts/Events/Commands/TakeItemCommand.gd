extends EventCommand
class_name TakeItemCommand

@export var item_id: int = 0
@export_range(1, 999, 1) var quantity: int = 1

func execute(context: Node) -> void:
	if item_id <= 0:
		push_warning("TakeItemCommand: item_id inválido (%d). Se omite." % item_id)
		context.continue_execution()
		return

	var safe_quantity := maxi(1, quantity)
	var bag_controller := BagController.new()
	var removed_amount := bag_controller.remove_item(item_id, safe_quantity)
	# remove_item ya recorta al máximo disponible, así que no hace falta lógica extra.
	if removed_amount <= 0:
		# Sin mensajes UI por diseño; solo trazabilidad en consola.
		print("TakeItemCommand: no se retiró item_id=%d (cantidad solicitada=%d)." % [item_id, safe_quantity])

	context.continue_execution()

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return false
