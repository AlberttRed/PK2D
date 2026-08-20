# StatChange.gd
class_name StatChange
extends RefCounted

var stat: StatsEnum.Values
var amount: int
var applied: bool = false
var block_reason: String = ""
var rejection_message: Dictionary = {}

func _init(_stat: StatsEnum.Values, _amount: int):
	stat = _stat
	amount = _amount

