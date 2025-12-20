## Enum para los diferentes estilos de marco de mensajes
## Basado en los estilos de Pokemon Essentials
class_name MessageBoxFrameStyle

enum Values {
	HGSS = 0,  # HeartGold/SoulSilver (estilo por defecto)
	SIGN_1 = 1  # Cartel 1
}

## Retorna el path del StyleBox correspondiente al estilo
static func get_stylebox_path(style: Values) -> String:
	match style:
		Values.HGSS: return "res://Resources/UI/MessageBox/Message Styles/HGSS_MessageBox_Style.tres"
		Values.SIGN_1: return "res://Resources/UI/MessageBox/Message Styles/Sign1_MessageBox_Style.tres"
		_: return "res://Resources/UI/MessageBox/Message Styles/HGSS_MessageBox_Style.tres"  # Por defecto HGSS

## Retorna el nombre legible del estilo
static func get_display_name(style: Values) -> String:
	match style:
		Values.HGSS: return "HeartGold/SoulSilver"
		Values.SIGN_1: return "Cartel 1"
		_: return "Desconocido"
