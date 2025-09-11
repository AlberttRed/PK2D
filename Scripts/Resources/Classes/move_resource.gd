extends Resource

class_name Move

#var MOVE_FUNCTIONS = load("res://Assets/ui/battle/BATTLE_MoveFunctions.gd").INST()
#var MOVE_ANIMATIONS = load("res://Assets/ui/battle/BATTLE_MoveAnimations.gd").new()

@export var internal_name : String = ""
@export var Name : String = "" # the resource name e.g. Overgrow.
@export var id : int = 0 # the id of the resource.
@export_multiline var description : String = "" # a description of the move.
@export var type : Resource = null
#@export_enum("None, Normal, Fighting, Flying, Poison, Ground, Rock, Bug, Ghost, Steel, Fire, Water, Grass, Electric, Psychic, Ice, Dragon, Dark, Fairy") var type = 1
@export var power : int = 0 # the power of the move.
@export var accuracy : int = 0 # the accuracy of the move.
@export var pp : int = 0 # the pp points of the move.
@export var effect_chance : int # % de que un atac pugui produir un problema d estat(cremar, confuso etc)
@export var priority : int = 0 # % de que un atac pugui produir un problema d estat(cremar, confuso etc)
@export_enum("None", "Estado", "Físico", "Especial") var damage_class_id : int = 0 # % de que un atac pugui produir un problema d estat(cremar, confuso etc)
@export_multiline var effect_entries : String = "" # Explicacio de com es produeix l atac. Ho faré servir per quan fagi els scripts dels atacs
@export var stat_changes : Dictionary[StatTypes.Stat, int] # Diccionari amb els stats que modifica el moviment, i en quin valor
@export var target_id : int = 1 # la id del target de l atac. Si ataca al rival, o pot atacar a dos a lhora, o a un aliat, o a tots els q hi ha en combat...
@export var meta_ailment_id : int # la id del tipus de ailment que pot provocar el mov.(cremar, paralitzar etc)
@export var meta_category_id : int = 1 # la id de l'"efecte" que provoca el moviment. si fa mal, si fa mal i pot cremar, si cura etc.
@export var meta_min_hits : int = 1 #numero minim de cops q fa l atac en un turn. si només fa un és null
@export var meta_max_hits : int = 1 #numero maxim de cops q fa l atac en un turn. si només fa un és null
@export var meta_min_turns : int = 1 #numero minim de truns q dura o es repeteix l atac. si només dura un és null
@export var meta_max_turns : int = 1 #numero maxim de truns q dura o es repeteix l atac. si només dura un és null
@export var meta_drain : int = 0 #numero de ps que et cura o et treu l atac. (drenadoras cura, per tant sera valor positiu, si estas enverinat et treu, per tant sera valor negatiu)
@export var meta_healing : int = 0 # % de vida que es cura l atacant fent el mov. segons el seu total de ps
@export var meta_crit_rate : int = 0 # ratio de que l atac pugui provocar un cop critic
@export var meta_ailment_chance : int = 0 # % de que el mov. provoqui ailment
@export var meta_flinch_chance : int = 0 # % de que un atac fagi retrocedir  al rival
@export var meta_stat_chance : int = 0 # % de que un atac pugi o baixi els stats
@export var contact_flag : bool = false
@export var ailment : Ailment = null
@export var move_effect : Script = null

func _init():
	add_user_signal("move_done")
	add_user_signal("animation_done")
#
#func get_name():
#	return DB.moves[id].Name
##
#func doMove(move,from,to):
##	var ran = 0.85
##	var damages = ""
##	while ran < 1.01:
##		damages = damages + str(get_damage(from,to,ran)) + ", "
##		ran = ran + 0.01
##	print(damages)
#	MOVE_FUNCTIONS.functions["Move_Function" + str(self.move_effect).pad_zeros(3)].new().ApplyDamage(move,from,to)
#	yield(MOVE_FUNCTIONS.functions["Move_Function" + str(self.move_effect).pad_zeros(3)].new(), "move_done")
#
#	emit_signal("move_done")
#
#func ShowAnimation(from,to):	
#	MOVE_ANIMATIONS.animations["Move_Animation" + str(self.move_effect).pad_zeros(3)].new().ShowAnimation(from,to)
#	yield(MOVE_ANIMATIONS.animations["Move_Animation" + str(self.move_effect).pad_zeros(3)].new(), "animation_done")
#	emit_signal("animation_done")
#
func is_special():
	return damage_class_id == CONST.DAMAGE_CLASS.ESPECIAL
	
func has_target(target):
	return target_id == target
	
func has_multiple_targets(from):
	if from.listEnemies.size() == 2:
		if has_target(CONST.TARGETS.BASE_ENEMY) or has_target(CONST.TARGETS.ALL_OTHER) or has_target(CONST.TARGETS.ENEMIES) or has_target(CONST.TARGETS.ALL_FIELD) or has_target(CONST.TARGETS.ALL_POKEMON) or has_target(CONST.TARGETS.PLAYERS) or has_target(CONST.TARGETS.BASE_PLAYER):
			return true
		else:
			return false
	else:
		return false
		
func is_type(t):
	return type == t
	

func makeContact():
	return contact_flag

func get_pp():
	return pp
