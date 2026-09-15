## Máscaras de transición de pantalla (combate, puertas, warps, cutscenes…).
## Assets en res://Sprites/Transiciones/
class_name ScreenTransitionEnum

enum Type {
	BATTLE1,           ## Transición clásica 1
	BATTLE2,           ## Transición clásica 2
	BATTLE3,           ## Transición clásica 3
	BATTLE4,           ## Transición clásica 4
	NORMAL01,          ## Transición normal 1 (021-Normal01)
	NORMAL02,          ## Transición normal 2 (022-Normal02)
	HEXATR,            ## Transición hexagonal
	HEXATRC,           ## Transición hexagonal centrada
	HEXATZR,           ## Transición hexagonal zoom rotada
	WIPE_VERTICAL,     ## Wipe reflejado: abre centro → arriba/abajo
	WIPE_HORIZONTAL,   ## Wipe reflejado: abre centro → izquierda/derecha
	DOOR               ## Puerta Gen 3: wipe horizontal + oscurecido→claro
}

## Convierte el enum a la ruta del archivo de máscara
static func to_mask_path(type: Type) -> String:
	match type:
		Type.BATTLE1:
			return "res://Sprites/Transiciones/battle1.png"
		Type.BATTLE2:
			return "res://Sprites/Transiciones/battle2.png"
		Type.BATTLE3:
			return "res://Sprites/Transiciones/battle3.png"
		Type.BATTLE4:
			return "res://Sprites/Transiciones/battle4.png"
		Type.NORMAL01:
			return "res://Sprites/Transiciones/021-Normal01.png"
		Type.NORMAL02:
			return "res://Sprites/Transiciones/022-Normal02.png"
		Type.HEXATR:
			return "res://Sprites/Transiciones/hexatr.png"
		Type.HEXATRC:
			return "res://Sprites/Transiciones/hexatrc.png"
		Type.HEXATZR:
			return "res://Sprites/Transiciones/hexatzr.png"
		Type.WIPE_VERTICAL:
			return "res://Sprites/Transiciones/wipe-vertical-reflected.png"
		Type.WIPE_HORIZONTAL, Type.DOOR:
			return "res://Sprites/Transiciones/wipe-horizontal-reflected.png"
		_:
			return "res://Sprites/Transiciones/battle1.png"

## True si la transición es compuesta (wipe + dim), no solo máscara.
static func is_door(type: Type) -> bool:
	return type == Type.DOOR

## Retorna el nombre legible del tipo de transición
static func get_display_name(type: Type) -> String:
	match type:
		Type.BATTLE1: return "Battle 1"
		Type.BATTLE2: return "Battle 2"
		Type.BATTLE3: return "Battle 3"
		Type.BATTLE4: return "Battle 4"
		Type.NORMAL01: return "Normal 01"
		Type.NORMAL02: return "Normal 02"
		Type.HEXATR: return "Hexagonal"
		Type.HEXATRC: return "Hexagonal Centrada"
		Type.HEXATZR: return "Hexagonal Zoom"
		Type.WIPE_VERTICAL: return "Wipe Vertical"
		Type.WIPE_HORIZONTAL: return "Wipe Horizontal"
		Type.DOOR: return "Door"
		_: return "Unknown"

## Todos los valores del enum (para editores)
static func all_types() -> Array[Type]:
	return [
		Type.BATTLE1, Type.BATTLE2, Type.BATTLE3, Type.BATTLE4,
		Type.NORMAL01, Type.NORMAL02,
		Type.HEXATR, Type.HEXATRC, Type.HEXATZR,
		Type.WIPE_VERTICAL, Type.WIPE_HORIZONTAL, Type.DOOR,
	]
