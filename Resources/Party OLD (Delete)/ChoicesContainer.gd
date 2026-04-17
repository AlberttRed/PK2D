extends PanelContainer

class_name ChoicesContainer

var newChoiceNode = preload("res://Escenas/UI/Textbox/Choices/ChoicePanel.tscn")

var CONTAINER_CHOICES_POS: Vector2 #= Vector2(368, 351)
var CONTAINER_CHOICES_EMPTY_SIZE: Vector2 #= Vector2(144, 28)

var selectedIndex:int = 0
var selectedChoice:ChoicePanel

@onready var listChoices : Array[ChoicePanel] = []
@onready var listActiveChoices : Array[ChoicePanel] = []

@export var stylePanel: StyleBox
@export var styleArrow: StyleBox
@export var styleEmpty: StyleBox

# Called when the node enters the scene tree for the first time.
func _ready():
	CONTAINER_CHOICES_POS = position
	CONTAINER_CHOICES_EMPTY_SIZE = size
	if stylePanel != null:
		add_theme_stylebox_override("panel", stylePanel)
	initChoices()

func initChoices():
	for choice:ChoicePanel in $VBoxContainer.get_children():
		initChoice(choice)

func addChoice(choiceName:String):
	var newChoice:ChoicePanel = newChoiceNode.instantiate()
	newChoice.name = choiceName
	newChoice.text = choiceName
	$VBoxContainer.add_child(newChoice)
	newChoice.added = true
	initChoice(newChoice)
	
func addChoices(choices:Array[String]):
	for choice:String in choices:
		addChoice(choice)

func removeChoice(choice:ChoicePanel):
	if choice!=null and listChoices.has(choice) and choice.added:
		$VBoxContainer.remove_child(choice)

func removeChoices(choices:Array[ChoicePanel]):
	for choice:ChoicePanel in choices:
		removeChoice(choice)


func removeChoiceByName(choiceName:String):
	var choice:ChoicePanel = getChoice(choiceName)
	removeChoice(choice)
		
func removeeAllChoices():
	for c in listChoices:
		removeChoice(c)
	listChoices.clear()

func initChoice(choice:ChoicePanel):
	choice.index = listChoices.size()
	if !listChoices.has(choice):
		listChoices.push_back(choice)
	if styleArrow != null:
		choice.styleSelected = styleArrow
	if styleEmpty != null:
		choice.styleUnselected = styleEmpty

func getIndex(choiceName:String) -> int:
	var choice:ChoicePanel = getChoice(choiceName)
	var index
	if choice != null:
		index = choice.index
	return index
	
func getChoiceById(choiceIndex:int) -> ChoicePanel:
		return $VBoxContainer.get_child(choiceIndex)

func getChoice(choiceName:String) -> ChoicePanel:
	return $VBoxContainer.get_node(choiceName)

func activeChoice(choiceName:String):
	var choice:ChoicePanel = getChoice(choiceName)
	if choice != null and !listActiveChoices.has(choice):
		listActiveChoices.push_back(choice)
		$VBoxContainer.move_child(choice, listActiveChoices.size()-1)
		print(choice.size.y)
		position -= Vector2(0, choice.size.y+2)
	choice.show()
	
func disableChoice(choiceName:String):
	var choice:ChoicePanel = getChoice(choiceName)
	if listActiveChoices.has(choice):
		listActiveChoices.erase(choice)
		position += Vector2(0, 36)
	choice.hide()

func activeChoices(choiceNames:Array[String]):
	for cName:String in choiceNames:
		activeChoice(cName)

func disableChoices(choiceNames:Array[String]):
	for cName:String in choiceNames:
		disableChoice(cName)

func disableAllChoices():
	for c in listChoices:
		print("disable " + c.name)
		disableChoice(c.name)
	

func moveNext():
	if selectedIndex < listActiveChoices.size()-1:
		selectedIndex += 1
	selectChoice(listActiveChoices[selectedIndex].name)

func movePrevious():
	if selectedIndex > 0:
		selectedIndex -= 1
	selectChoice(listActiveChoices[selectedIndex].name)
	
func selectChoice(choiceName:String):
	var choice:ChoicePanel = getChoice(choiceName)
	selectedChoice = choice
	updateStyles()	

func showContainer():
	GUI.up.connect(Callable(self, "movePrevious"))
	GUI.down.connect(Callable(self, "moveNext"))
	selectedIndex=0
	selectChoice(listActiveChoices[selectedIndex].name)
	show()
	await GUI.select
	return selectedIndex

func hideContainer():
	if GUI.up.is_connected(Callable(self, "movePrevious")):
		GUI.up.disconnect(Callable(self, "movePrevious"))
	if GUI.down.is_connected(Callable(self, "moveNext")):
		GUI.down.disconnect(Callable(self, "moveNext"))
	disableAllChoices()
	removeeAllChoices()
	size = CONTAINER_CHOICES_EMPTY_SIZE
	hide()

func isSelected(choiceName:String) -> bool:
	return selectedChoice == getChoice(choiceName)

func updateStyles():
	for choice:ChoicePanel in $VBoxContainer.get_children():
		if choice == selectedChoice:
			choice.select()
		else:
			choice.unselect()
