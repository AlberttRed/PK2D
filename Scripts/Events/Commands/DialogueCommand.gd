extends EventCommand
class_name DialogueCommand

## Comando de diálogo multipágina usando el MessageBox del overworld.

@export var pages: Array[DialoguePage] = []
@export var message_box_theme: MessageBoxFrameStyle.Values = MessageBoxFrameStyle.Values.HGSS
@export var close_at_end: bool = true
@export var show_icon: bool = false

func execute(context: Node) -> void:
	if pages.is_empty():
		push_warning("DialogueCommand: No hay páginas configuradas, saltando comando")
		context.continue_execution()
		return

	for i in range(pages.size()):
		var page := pages[i]
		var page_text := ""
		if page != null:
			page_text = page.text

		var is_last_page := i == pages.size() - 1
		var show_icon_at_end := (not is_last_page) or show_icon
		var should_close := is_last_page and close_at_end

		await DisplayManager.show_message(page_text, {
			"waitInput": true,
			"closeAtEnd": should_close,
			"waitTime": 0.0,
			"showIconAtEnd": show_icon_at_end,
			"frameStyle": message_box_theme
		})

	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
