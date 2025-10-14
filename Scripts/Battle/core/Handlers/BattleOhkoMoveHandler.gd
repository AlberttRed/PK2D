extends BattleMoveHandler

class_name BattleOhkoMoveHandler

var damage: DamageEffect = null

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func _apply() -> void:
	# OHKO simple: si se cumplen condiciones (placeholder), dejar al objetivo a 0
	if target == null or target.get_pokemon() == null:
		return
	var tp: BattlePokemon = target.get_pokemon()
	# Reglas reales de OHKO dependen de niveles/precisión; aquí aplicamos daño igual a HP restante
	damage = DamageEffect.new(user, tp, move, tp.get_hp())
	damage.effectiveness = 1.0
	damage.apply()

func _visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)


