extends Node
class_name BattleAnimationHooks

## Puente no visual entre AnimationPlayer (Call Method) y BattleSpot.
## Los efectos viven en el spot / BattleAnimationUtils; este nodo solo reenvía tras bind().
## Ej.: call_on_target("play_hit_animation") | call_on_target("flash", [1, 0.05, 0.0])
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


## Atajo Call Method (sin Array anidado en el track): embestida del user.
func user_move_forward(distance: float = 24.0, duration: float = 0.12) -> void:
	call_on_user(&"move_forward", [distance, duration])


## Retroceso del target (aleja y vuelve). Distancia positiva = hacia atrás.
func target_recoil(distance: float = 16.0, duration: float = 0.1) -> void:
	call_on_target(&"move_forward", [-distance, duration])


## Retroceso del user (se echa atrás y vuelve). Distancia positiva = hacia atrás.
func user_recoil(distance: float = 16.0, duration: float = 0.1) -> void:
	call_on_user(&"move_forward", [-distance, duration])


## Baja el target en Y y vuelve (impacto tipo Mordisco).
func target_nudge_down(distance: float = 10.0, duration: float = 0.1) -> void:
	call_on_target(&"nudge_down", [distance, duration])


## User da vueltas en círculo (Látigo).
func user_orbit_circle(radius: float = 10.0, revolutions: float = 2.0, duration: float = 0.7) -> void:
	call_on_user(&"orbit_circle", [radius, revolutions, duration])


## Ilumina un poco el sprite del user (Ataque Rápido).
func user_glow(peak: float = 1.4, up_duration: float = 0.08, hold_duration: float = 0.25, down_duration: float = 0.12) -> void:
	call_on_user(&"glow", [peak, up_duration, hold_duration, down_duration])


## Tinte morado del target (ailment Poison). Defaults fijos para Call Method tracks.
func target_poison_tint(up_duration: float = 0.08, hold_duration: float = 0.55, down_duration: float = 0.15) -> void:
	call_on_target(&"tint", [Color(0.55, 0.0, 1.0, 1.0), up_duration, hold_duration, down_duration])


## Tinte cian del target (ailment Freeze).
func target_freeze_tint(up_duration: float = 0.1, hold_duration: float = 1.22, down_duration: float = 0.18) -> void:
	call_on_target(&"tint", [Color(0.48, 0.78, 1.0, 1.0), up_duration, hold_duration, down_duration])


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
