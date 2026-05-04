## Resultado de usar un item
## Comunica al sistema llamador el resultado de la ejecución de un ItemEffect
extends RefCounted
class_name ItemUseResult

## Clasificación para UI / feedback (similar en espíritu a efectos de batalla).
enum Outcome {
	NONE,
	SUCCESS,
	NO_EFFECT,
	BLOCKED,
	ERROR,
}

## Cómo debe continuar el flujo cuando el uso ocurre en combate (`BattleItemHandler` / turno).
enum BattleContinuation {
	## No aplica (p. ej. overworld) o aún no asignado.
	UNSPECIFIED,
	## Resolución del objeto lista (éxito o fallo mostrado); el turno puede seguir su curso normal.
	COMPLETE_ACTION,
	## Secuencia que bloquea el flujo (capturas, cinematicas); reservado para futuros ítems.
	BLOCKING_SEQUENCE,
}

## Si el uso fue exitoso
var success: bool = false

## Si debe consumirse el item (cantidad a consumir)
var consume_amount: int = 0

## Mensaje para mostrar en la UI (texto directo o clave de localización)
var message: String = ""

## Código de mensaje para UI (opcional, para localización)
var message_code: String = ""

## Resultado semántico para capa de presentación (MessageBox, tono, etc.)
var outcome: Outcome = Outcome.NONE

## Datos adicionales del efecto (opcional)
## Ejemplos: healed_amount, cured_status, etc.
var effect_data: Dictionary = {}

## Hint para el controlador de turno / UI de batalla.
var battle_continuation: BattleContinuation = BattleContinuation.UNSPECIFIED

## Constructor
func _init(
	_success: bool = false,
	_consume_amount: int = 0,
	_message: String = "",
	_message_code: String = "",
	_effect_data: Dictionary = {},
	_outcome: Outcome = Outcome.NONE,
	_battle_continuation: BattleContinuation = BattleContinuation.UNSPECIFIED
) -> void:
	success = _success
	consume_amount = _consume_amount
	message = _message
	message_code = _message_code
	effect_data = _effect_data
	outcome = _outcome
	battle_continuation = _battle_continuation
	if outcome == Outcome.NONE:
		outcome = Outcome.SUCCESS if success else Outcome.NO_EFFECT

## Helper para crear un resultado exitoso
static func success_result(consume: int = 1, msg: String = "", data: Dictionary = {}) -> ItemUseResult:
	return ItemUseResult.new(true, consume, msg, "", data, Outcome.SUCCESS)

## Fallo genérico (suele tratarse como «sin efecto» en UI salvo que se indique otro helper).
static func failure_result(msg: String = "", code: String = "") -> ItemUseResult:
	return ItemUseResult.new(false, 0, msg, code, {}, Outcome.NO_EFFECT)

static func failure_no_effect(msg: String = "", code: String = "") -> ItemUseResult:
	return ItemUseResult.new(false, 0, msg, code, {}, Outcome.NO_EFFECT)

static func failure_blocked(msg: String = "", code: String = "") -> ItemUseResult:
	return ItemUseResult.new(false, 0, msg, code, {}, Outcome.BLOCKED)

static func failure_error(msg: String = "", code: String = "") -> ItemUseResult:
	return ItemUseResult.new(false, 0, msg, code, {}, Outcome.ERROR)
