extends Node
class_name BattleAnimationHooks

## Puente no visual entre AnimationPlayer (Call Method) y BattleSpot.
## Los efectos viven en el spot; este nodo solo reenvía tras bind().
## Contrato: Docs/battle/BattleAnimationContract.md

var user_spot: BattleSpot = null
var target_spots: Array[BattleSpot] = []


func bind(user: BattleSpot, targets: Array[BattleSpot]) -> void:
	user_spot = user
	target_spots.clear()
	if targets == null:
		return
	for spot in targets:
		target_spots.append(spot)


## Call Method Track: call_on_user("flash", [duration, color]) — args opcionales vía callv.
func call_on_user(method: StringName, args: Array = []) -> void:
	_call_on_spot(user_spot, method, args)


func call_on_target(method: StringName, args: Array = []) -> void:
	_call_on_spot(_first_target(), method, args)


func _first_target() -> BattleSpot:
	if target_spots.is_empty():
		return null
	return target_spots[0]


func _call_on_spot(spot: BattleSpot, method: StringName, args: Array) -> void:
	if spot == null or not is_instance_valid(spot):
		return
	if not spot.has_method(method):
		push_warning("BattleAnimationHooks: BattleSpot no tiene método '%s'." % String(method))
		return
	spot.callv(method, args)
