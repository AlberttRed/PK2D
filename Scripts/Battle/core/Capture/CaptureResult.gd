extends RefCounted
class_name CaptureResult

enum FailureKind {
	NONE,
	EARLY_FAIL,
	SHAKE_FAIL,
}

var success: bool = false
## Sacudidas visibles completadas (0–3). La 4.ª comprobación solo decide captura.
var shakes: int = 0
## Índice de comprobación en la que falló (0–3; 3 = fallo tras 3 balanceos).
var failed_shake_index: int = -1
var failure_kind: FailureKind = FailureKind.NONE
## Instancia lista para persistencia (solo si success).
var captured_pokemon: Pokemon = null
var target_display_name: String = ""
var ball_display_name: String = ""


func is_early_fail() -> bool:
	return not success and failure_kind == FailureKind.EARLY_FAIL


func is_shake_fail() -> bool:
	return not success and failure_kind == FailureKind.SHAKE_FAIL
