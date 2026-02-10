## Resultado de usar un item
## Comunica al sistema llamador el resultado de la ejecución de un ItemEffect
extends RefCounted
class_name ItemUseResult

## Si el uso fue exitoso
var success: bool = false

## Si debe consumirse el item (cantidad a consumir)
var consume_amount: int = 0

## Mensaje para mostrar en la UI (texto directo o clave de localización)
var message: String = ""

## Código de mensaje para UI (opcional, para localización)
var message_code: String = ""

## Datos adicionales del efecto (opcional)
## Ejemplos: healed_amount, cured_status, etc.
var effect_data: Dictionary = {}

## Constructor
func _init(
	_success: bool = false,
	_consume_amount: int = 0,
	_message: String = "",
	_message_code: String = "",
	_effect_data: Dictionary = {}
) -> void:
	success = _success
	consume_amount = _consume_amount
	message = _message
	message_code = _message_code
	effect_data = _effect_data

## Helper para crear un resultado exitoso
static func success_result(consume: int = 1, msg: String = "", data: Dictionary = {}) -> ItemUseResult:
	return ItemUseResult.new(true, consume, msg, "", data)

## Helper para crear un resultado fallido
static func failure_result(msg: String = "", code: String = "") -> ItemUseResult:
	return ItemUseResult.new(false, 0, msg, code, {})

