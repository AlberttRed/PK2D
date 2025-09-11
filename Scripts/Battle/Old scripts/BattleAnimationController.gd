class_name BattleAnimationController extends AnimationPlayer

signal finished

var listPlayingAnimations:Array[AnimationPlayer]

var currentAnimationName :String
var currentAnimation :Animation
var animParams :Dictionary
var root
@onready var frames : Dictionary

func _ready() -> void:
	for frameGroup:Node2D in $AnimationFrames.get_children():
		frames[frameGroup.name] = frameGroup

var temporary: bool = false

func playAnimation(animation, _animParams:Dictionary = {}, _root:Node = get_parent(), custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	root = _root
	if animation is Animation:
		await _playAnimationByAnimation(animation, custom_blend, custom_speed, from_end)
	elif animation is String:
		await _playAnimationByName(animation, _animParams, custom_blend, custom_speed, from_end)
	else:
		assert(false, "Invalid 'animation' param for function playAnimation")
	#await SignalManager.Animations.finished_animation
	
func _playAnimationByName(name: StringName = "", _animParams:Dictionary = {}, custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	var animPlayer : BattleAnimationPlayer = newAnimationPlayer()
	animParams = _animParams
	listPlayingAnimations.push_back(animPlayer)
	#set_process(true)

	root.add_child(animPlayer)
	animPlayer.finished.connect(_on_animation_finished)

	animPlayer.setAnimation(getAnimation(name))

	if animPlayer.animation == null:
		assert(false, "Animation " + name + " does not exist.")
		return
		#
	#if animPlayer.animation.has_method("setAnimation"):#get_script() != null:
	if frames.has(name):
		var framesCopy:Node2D = frames.get(name).duplicate()
		framesCopy.name = "AnimationFrames"
		root.add_child(framesCopy)
		animPlayer.frames = framesCopy
	if animPlayer.animation.has_method("setAnimation"):#get_script() != null:
		animPlayer.animation.setAnimation(root, animParams)

	animPlayer.play(currentAnimationName, custom_blend, custom_speed, from_end)
	await animPlayer.animation_finished

func _playAnimationByAnimation(animation: Animation, custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	var animPlayer : BattleAnimationPlayer = newAnimationPlayer()
	listPlayingAnimations.push_back(animPlayer)
	#set_process(true)

	root.add_child(animPlayer)
	animPlayer.finished.connect(_on_animation_finished)

	#animPlayer.setAnimation(animation)
	animPlayer.animation = animation#getAnimation(name)

	if animPlayer.animation == null:
		assert(false, "Animation " + name + " does not exist.")
		return
	print(animation.resource_name)
	if frames.has(animation.resource_name):
		var framesCopy:Node2D = frames.get(animation.resource_name).duplicate()
		framesCopy.name = "AnimationFrames"
		root.add_child(framesCopy)
		animPlayer.frames = framesCopy
	if animPlayer.animation.has_method("setAnimation"):#get_script() != null:
		animPlayer.animation.setAnimation(root, animParams)
	
	animPlayer.play("TEMP/"+animation.resource_name, custom_blend, custom_speed, from_end)
	await animPlayer.animation_finished


func getAnimation(name:String) -> Animation:
	var anim : Animation = null
	for libName:String in get_animation_library_list():
		var library:AnimationLibrary = get_animation_library(libName)
		if libName!=null and !libName.is_empty() and library!=null and library.has_animation(name):
			anim = library.get_animation(name)
			currentAnimationName = libName+"/"+name
			#if anim.has_meta("Script"):
				#
				#anim.set_script(load(anim.get_meta("Script")))
			break
	return anim

#func _process(delta):
	#if listPlayingAnimations.is_empty():
		#SignalManager.ANIMATION.finished_animation.emit()
		#set_process(false)

func _on_animation_finished(player:AnimationPlayer):
	listPlayingAnimations.erase(player)
	player.queue_free()
	for p:BattleAnimationPlayer in listPlayingAnimations:
		print(p.currentAnimationName)
	if listPlayingAnimations.is_empty():
			SignalManager.Animations.finished_animation.emit()
	
	#currentAnimationName=""
	#if currentAnimation!=null and currentAnimation.get_script() != null:
		#currentAnimation.freeAnimation()
	#currentAnimation = null
	#if temporary:
		#queue_free()

func stopAnimation(animName:String):
	for anim:AnimationPlayer in listPlayingAnimations:
		if anim.current_animation.contains("/"+animName):
			anim.stop()
			anim.finish()
			#listPlayingAnimations.erase(anim)
			#anim.queue_free()

func setAnimation():
	if currentAnimation!=null and currentAnimation.has_method("setAnimation"):
		currentAnimation.setAnimation(get_parent(), animParams)
	
#func animationFinished():
	#SignalManager.ANIMATION.finished_animation.emit()
	
func newAnimationPlayer()->BattleAnimationPlayer:
	var animPlayer : BattleAnimationPlayer = BattleAnimationPlayer.new()
	animPlayer.libraries = self.libraries
	animPlayer.name = "AnimationPlayer"
	animPlayer.temporary = true
	animPlayer.root_node = self.root_node
	return animPlayer
