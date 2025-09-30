class_name RunEffect
extends ImmediateBattleEffect

var side: BattleSide
var succeeded: bool = false

func _init(_side: BattleSide, _succeeded: bool):
    side = _side
    succeeded = _succeeded

func apply():
    if succeeded:
        side.escapedBattle = true

func visualize(_ui):
    var who = side.to_string() if side else "(?)"
    if succeeded:
        print("[RUN] %s ha escapado del combate" % who)
    else:
        print("[RUN] %s no pudo escapar" % who)

