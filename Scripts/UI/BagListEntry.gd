extends RefCounted
class_name BagListEntry

var is_exit: bool = false
var item_id: int = 0
var quantity: int = 0
var display_name: String = ""
var description: String = ""
var icon: Texture2D = null
var is_usable_overworld: bool = false

static func create_exit_entry() -> BagListEntry:
	var entry := BagListEntry.new()
	entry.is_exit = true
	entry.display_name = "CERRAR LA MOCHILA"
	entry.description = "Cerrar mochila."
	return entry

static func create_item_entry(
	p_item_id: int,
	p_quantity: int,
	p_display_name: String,
	p_description: String,
	p_icon: Texture2D,
	p_is_usable_overworld: bool
) -> BagListEntry:
	var entry := BagListEntry.new()
	entry.is_exit = false
	entry.item_id = p_item_id
	entry.quantity = p_quantity
	entry.display_name = p_display_name
	entry.description = p_description
	entry.icon = p_icon
	entry.is_usable_overworld = p_is_usable_overworld
	return entry
