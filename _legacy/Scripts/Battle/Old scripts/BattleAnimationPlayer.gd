class_name BattleAnimationPlayer extends AnimationPlayer

signal finished

var currentAnimationName :String
var animation :Animation:
	set(_currentAnimation):
		if _currentAnimation != null and !_currentAnimation.resource_name.is_empty():
			self.get_animation_library("TEMP").add_animation(_currentAnimation.resource_name,_currentAnimation)
		animation = _currentAnimation
var animParams :Dictionary
var root
var frames : Node2D
var temporary: bool = false

func _enter_tree():
	add_animation_library("TEMP", AnimationLibrary.new())
	animation_finished.connect(_on_animation_finished)
	
func _exit_tree():
	animation_finished.disconnect(_on_animation_finished)

func setAnimation(_currentAnimation:Animation):
	animation = _currentAnimation
	#if _currentAnimation != null and !_currentAnimation.resource_name.is_empty():
		#self.get_animation_library("TEMP").add_animation(_currentAnimation.resource_name,_currentAnimation)
	#self.currentAnimation = _currentAnimation
	
func playAnimation(name: StringName = "", _animParams:Dictionary = {}, custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	SignalManager.Battle.Animations.playAnimation.emit(name, animParams, get_node(root_node))

func playMoveAnimation(animation: Animation, _animParams:Dictionary = {}, custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	#self.get_animation_library("TEMP").add_animation(animation.resource_name,animation)
	SignalManager.Battle.Animations.playMoveAnimation.emit(animation, animParams, get_node(root_node))

#func getAnimation(name:String) -> Animation:
	#var anim : Animation = null
	#for libName:String in get_animation_library_list():
		#var library:AnimationLibrary = get_animation_library(libName)
		#if library!=null && library.has_animation(name):
			#anim = library.get_animation(name)
			#currentAnimationName = libName+"/"+name
			##if anim.has_meta("Script"):
				##
				##anim.set_script(load(anim.get_meta("Script")))
			#break
	#return anim



func _on_animation_finished(anim_name):
	finish()

func finish():
	currentAnimationName=""
	if animation!=null and animation.get_script() != null && animation.has_method("freeAnimation"):
		animation.freeAnimation()
	if frames != null:
		frames.queue_free()
	animation = null
	finished.emit(self)

#
#func setAnimation():
	#if currentAnimation!=null and currentAnimation.has_method("setAnimation"):
		#currentAnimation.setAnimation(get_parent(), animParams)
	#
#func animationFinished():
	#SignalManager.ANIMATION.finished_animation.emit()
