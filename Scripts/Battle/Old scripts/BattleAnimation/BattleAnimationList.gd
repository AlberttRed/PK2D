class_name BattleAnimationList

const COMMON_ANIM_PATH:String = "res://Animaciones/Batalla/General/Classes/THROWBALL.gd"

func getMoveAnimation(_move :BattleMove) -> BattleMoveAnimation:
	var t_num : String = "%03d" % (_move.id)
	if get("MoveAnimation_" + t_num) != null:
		return get("MoveAnimation_" + t_num).new(_move)
	else:
		return get("MoveAnimation_000").new(_move)
	
#func getWeatherAnimation(_target : BattlePokemon) -> BattleWeatherAnimation:
#	#var t_num : String = "%03d" % CONST.BATTLE_WEATHER
#	return get("WeatherAnimation_" + "t_num").new(_target)

#func getCommonAnimation(_name : String) -> BattleCommonAnimation:
	##var t_num : String = "%03d" % (move.category + 1)
	#return get("CommonAnimation_" + str(_name)).new(_name)

func getCommonAnimation(_name : String) -> BattleCommonAnimation:
	#var t_num : String = "%03d" % (move.category + 1)
	if FileAccess.file_exists(COMMON_ANIM_PATH + str(_name) + ".gd") != null:
		return load(COMMON_ANIM_PATH + str(_name) + ".gd").new(_name)
	return null# get("CommonAnimation_" + str(_name)).new(_name)
	
	
func getAilmentAnimation(_ailment : CONST.AILMENTS) -> BattleAilmentAnimation:
	var t_num : String = "%03d" % (_ailment)
	return get("AilmentAnimation_" + str(t_num)).new(_ailment)
	
# --------------------- MOVE ANIMATIONS ---------------------

class MoveAnimation_000 extends BattleMoveAnimation:
	func doAnimation(_target : BattleSpot):
		print("Do the animation bro")

# --------------------- COMMON ANIMATIONS ---------------------

#Animació que es mostra quan un pokémon rep mal
#class CommonAnimation_PokemonHit extends BattleCommonAnimation:
	#
	#func doAnimation(_target : BattleSpot):
		#_target.animPlayer.play("Pokemon/HIT")#("Common/Battle_PokemonHit")
		#await _target.animPlayer.animation_finished

#Animació que es mostra quan a un pokémon li pugen els stats
#class CommonAnimation_StatUp extends BattleCommonAnimation:
	#
	#func doAnimation(_target : BattleSpot):
		#_target.animPlayer.play("Pokemon/STATUP")#("Common/Battle_StatUp")
		#await _target.animPlayer.animation_finished

#Animació que es mostra quan a un pokemon li baixen els stats
#class CommonAnimation_StatDown extends BattleCommonAnimation:
	#
	#func doAnimation(_target : BattleSpot):
		#await _target.playAnimation("Pokemon/STATDOWN")#("Common/Battle_StatDown")
		#await _target.animPlayer.animation_finished

#Animació que es mostra quan un pokemon es cura
class CommonAnimation_Heal extends BattleCommonAnimation:
	
	func doAnimation(_target : BattleSpot):
		_target.animPlayer.play("Common/Battle_Heal")
		await _target.animPlayer.animation_finished
## --------------------- WEATHER ANIMATIONS ---------------------

#class WeatherAnimation_001 extends BattleWeatherAnimation:
#	func doAnimation():
#		print("Do the animation bro")

# --------------------- AILMENTS ANIMATIONS ---------------------

##CONST.PARALYZE
#class AilmentAnimation_001 extends BattleAilmentAnimation:
	#func doAnimation(_target : BattleSpot):
		##var target:BattleSpot = _target.battleSpot
		#var spr1 = Sprite2D.new()
		#var spr2 = Sprite2D.new()
		#spr1.name = "Sprite2D"
		#spr2.name = "Sprite2D2"
		#_target.get_node("Sprite").add_child(spr1)
		#_target.get_node("Sprite").add_child(spr2)
		#
		#_target.animPlayer.play("Ailments/Paralyzed")
		#await _target.animPlayer.animation_finished
		#spr1.queue_free()
		#spr2.queue_free()
