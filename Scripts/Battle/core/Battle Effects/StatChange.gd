# StatChange.gd
class_name StatChange
extends RefCounted

var stat: StatsEnum.Values
var amount: int
var applied: bool = false

func _init(_stat: StatsEnum.Values, _amount: int):
	stat = _stat
	amount = _amount

