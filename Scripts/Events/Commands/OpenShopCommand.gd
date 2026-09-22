extends EventCommand
class_name OpenShopCommand

## Menú raíz de tienda (COMPRAR / VENDER / SALIR) estilo FRLG.
## Compra → DisplayManager.open_poke_mart; venta → open_bag_for_sell.

enum RootOption {
	BUY = 0,
	SELL = 1,
	EXIT = 2,
}

const ROOT_OPTIONS: Array[String] = [
	"COMPRAR",
	"VENDER",
	"SALIR",
]

const MSG_GREETING := "¡Hola! ¿Puedo ayudarte en algo?"
const MSG_AGAIN := "¿Puedo ayudarte en algo más?"
const MSG_GOODBYE := "¡Vuelve cuando quieras!"

@export var shop_data: ShopData = null


func execute(context: Node) -> void:
	if shop_data == null:
		push_warning("OpenShopCommand: shop_data es null; no-op")
		context.continue_execution()
		return

	var first_prompt := true
	while true:
		var prompt: String = MSG_GREETING if first_prompt else MSG_AGAIN
		first_prompt = false
		var choice: int = await _prompt_root_menu(prompt)
		if choice < 0 or choice == RootOption.EXIT:
			break
		match choice:
			RootOption.BUY:
				await DisplayManager.open_poke_mart(shop_data)
			RootOption.SELL:
				await DisplayManager.open_bag_for_sell()

	await DisplayManager.show_message(MSG_GOODBYE, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": true,
		"typingMode": MessageBox.TypingMode.TYPING,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
	})
	context.continue_execution()


func is_async() -> bool:
	return true


func is_safe_for_parallel() -> bool:
	return false


func _prompt_root_menu(prompt: String) -> int:
	await DisplayManager.show_message(prompt, {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"typingMode": MessageBox.TypingMode.TYPING,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
	})
	DisplayManager.hide_message_wait_indicator()
	var choice: int = await DisplayManager.show_choices_corner(
		ROOT_OPTIONS,
		ChoiceBox.ChoiceAnchor.TOP_LEFT
	)
	DisplayManager.close_message()
	return choice
