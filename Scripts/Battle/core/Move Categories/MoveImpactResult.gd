extends Resource
class_name MoveImpactResult

# Base para resultados de un impacto de movimiento (daño, curación, estado, etc.)
# NO contiene lógica de presentación.

var user: BattlePokemon
var target: BattlePokemon

class Damage extends MoveImpactResult:
	var amount: int
	var is_critical: bool
	var effectiveness: float

	func _init(_amount: int, _crit: bool, _eff: float):
		amount = _amount
		is_critical = _crit
		effectiveness = _eff
		
	func is_super_effective() -> bool:
		return effectiveness > 1.0

	func is_not_very_effective() -> bool:
		return effectiveness > 0.0 and effectiveness < 1.0

	func is_ineffective() -> bool:
		return effectiveness == 0.0

class Heal extends MoveImpactResult:
	var amount: int

	func _init(_amount: int):
		amount = _amount

class Status extends MoveImpactResult:
	var status_name: String
	var was_applied: bool

	func _init(_status_name: String, _applied: bool):
		status_name = _status_name
		was_applied = _applied
