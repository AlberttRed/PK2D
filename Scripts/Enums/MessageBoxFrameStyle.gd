## Enum para los diferentes estilos de marco de mensajes
## Basado en los estilos de Pokemon Essentials
class_name MessageBoxFrameStyle

enum Values {
	HGSS = 0,  # HeartGold/SoulSilver (estilo por defecto)
	SIGN_1 = 1  # Cartel 1
}

## Retorna el path del StyleBox correspondiente al estilo
static func get_messagebox_theme(style: Values) -> MessageBoxTheme:
	match style:
		Values.HGSS: return preload("res://Resources/UI/MessageBox/Themes/Default.tres") as MessageBoxTheme
		Values.SIGN_1: return preload("res://Resources/UI/MessageBox/Themes/Sign1.tres") as MessageBoxTheme
		_: return preload("res://Resources/UI/MessageBox/Themes/Default.tres") as MessageBoxTheme # Por defecto HGSS

## Retorna el nombre legible del estilo
static func get_display_name(style: Values) -> String:
	match style:
		Values.HGSS: return "HeartGold/SoulSilver"
		Values.SIGN_1: return "Cartel 1"
		_: return "Desconocido"
