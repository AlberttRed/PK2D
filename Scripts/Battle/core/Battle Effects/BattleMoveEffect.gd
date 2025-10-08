class_name BattleMoveEffect
extends ImmediateBattleEffect

## Clase base para efectos inmediatos causados por movimientos de batalla.
## Hereda de ImmediateBattleEffect y añade funcionalidad específica para movimientos.
##
## Esta clase sirve como punto intermedio entre ImmediateBattleEffect y efectos
## específicos de movimientos como RainDanceMoveEffect, SunnyDayMoveEffect, etc.

var user: BattlePokemon
var target: BattlePokemon

func _init(_user: BattlePokemon, _target: BattlePokemon = null) -> void:
	user = _user
	target = _target

func apply() -> void:
	pass

func visualize(_ui: BattleUI) -> void:
	pass

