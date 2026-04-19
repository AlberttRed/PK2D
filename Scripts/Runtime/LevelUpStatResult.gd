extends RefCounted

var old_level: int = 0
var new_level: int = 0
var old_max_hp: int = 0
var new_max_hp: int = 0
var hp_actual_before: int = 0
var hp_actual_after: int = 0
## StatsEnum.Values -> int (HP + las cinco stats de combate)
var stats_before: Dictionary = {}
var stats_after: Dictionary = {}
