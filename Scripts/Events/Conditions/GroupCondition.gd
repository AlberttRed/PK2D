extends EventCondition
class_name GroupCondition

## Condición compuesta que agrupa múltiples condiciones con operadores lógicos AND/OR
enum Mode { ALL, ANY }

## Modo de evaluación: ALL (todas deben cumplirse) o ANY (al menos una)
@export var mode: Mode = Mode.ALL

## Array de condiciones hijas a evaluar
@export var children: Array[EventCondition] = []

## Evalúa el grupo de condiciones según el modo
func evaluate(context: EventConditionContext) -> bool:
	# Neutrales: ALL con children vacío → true, ANY con children vacío → false
	if children.size() == 0:
		match mode:
			Mode.ALL:
				return true
			Mode.ANY:
				return false
			_:
				return true

	match mode:
		Mode.ALL:
			# Todas las condiciones deben cumplirse (short-circuit)
			for child in children:
				if not child:
					push_warning("GroupCondition: Se encontró una condición null en children, se ignora")
					continue
				if not child.evaluate(context):
					return false
			return true
		Mode.ANY:
			# Al menos una condición debe cumplirse (short-circuit)
			for child in children:
				if not child:
					push_warning("GroupCondition: Se encontró una condición null en children, se ignora")
					continue
				if child.evaluate(context):
					return true
			return false
		_:
			return true

## Verifica si este grupo de condiciones depende de una variable global específica
## Recorre recursivamente todas las condiciones hijas
func depends_on_variable(variable_name: String) -> bool:
	for child in children:
		if child and child.depends_on_variable(variable_name):
			return true
	return false

## Verifica si este grupo de condiciones depende de un flag global específico
## Recorre recursivamente todas las condiciones hijas
func depends_on_flag(flag_name: String) -> bool:
	for child in children:
		if child and child.depends_on_flag(flag_name):
			return true
	return false

## Verifica si este grupo de condiciones depende de un trainer específico
## Recorre recursivamente todas las condiciones hijas
func depends_on_trainer(trainer_id: String) -> bool:
	for child in children:
		if child and child.depends_on_trainer(trainer_id):
			return true
	return false

