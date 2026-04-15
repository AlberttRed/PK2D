extends RefCounted
class_name BagEntry

var item_id: int = 0
var quantity: int = 0

func _init(p_item_id: int = 0, p_quantity: int = 0) -> void:
	item_id = p_item_id
	quantity = max(0, p_quantity)
