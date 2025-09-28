class_name BattlePassChoice
extends BattleChoice

func is_pass() -> bool:
    return true

func get_priority() -> int:
    return 0

func resolve():
    var result = BattlePassResult.new()
    return result
