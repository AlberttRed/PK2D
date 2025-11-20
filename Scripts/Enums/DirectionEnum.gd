class_name DirectionEnum

## Enum para direcciones de movimiento y orientación
##
## Direcciones de MOVIMIENTO (UP, DOWN, LEFT, RIGHT):
## - Mueven al actor 1 tile en esa dirección
## - Si el actor mira a otra dirección, primero hace un "initial step" (giro sin movimiento)
##
## Direcciones de ORIENTACIÓN (LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT):
## - Solo cambian la dirección que mira el actor, SIN moverse
## - Útil para evitar el "initial step" en rutas predefinidas

enum Type {
	UP,          ## Movimiento: arriba
	DOWN,        ## Movimiento: abajo
	LEFT,        ## Movimiento: izquierda
	RIGHT,       ## Movimiento: derecha
	LOOK_UP,     ## Solo mirar arriba (sin moverse)
	LOOK_DOWN,   ## Solo mirar abajo (sin moverse)
	LOOK_LEFT,   ## Solo mirar izquierda (sin moverse)
	LOOK_RIGHT,  ## Solo mirar derecha (sin moverse)
	WAIT_025,    ## Espera de 0.25 segundos
	WAIT_050,    ## Espera de 0.5 segundos
	WAIT_100     ## Espera de 1.0 segundo
}

## Convierte el enum a Vector2
static func to_vector2(direction: int) -> Vector2:
	match direction:
		Type.UP: return Vector2.UP
		Type.DOWN: return Vector2.DOWN
		Type.LEFT: return Vector2.LEFT
		Type.RIGHT: return Vector2.RIGHT
		Type.LOOK_UP: return Vector2.UP
		Type.LOOK_DOWN: return Vector2.DOWN
		Type.LOOK_LEFT: return Vector2.LEFT
		Type.LOOK_RIGHT: return Vector2.RIGHT
		_: return Vector2.ZERO

## Verifica si es un comando de movimiento (true) o solo orientación (false)
static func is_movement(direction: int) -> bool:
	match direction:
		Type.UP, Type.DOWN, Type.LEFT, Type.RIGHT:
			return true
		Type.LOOK_UP, Type.LOOK_DOWN, Type.LOOK_LEFT, Type.LOOK_RIGHT, Type.WAIT_025, Type.WAIT_050, Type.WAIT_100:
			return false
		_:
			return false

## Verifica si es un comando de espera
static func is_wait(direction: int) -> bool:
	match direction:
		Type.WAIT_025, Type.WAIT_050, Type.WAIT_100:
			return true
		_:
			return false

## Obtiene la duración del wait en segundos
static func get_wait_duration(direction: int) -> float:
	match direction:
		Type.WAIT_025:
			return 0.25
		Type.WAIT_050:
			return 0.50
		Type.WAIT_100:
			return 1.00
		_:
			return 0.0

## Convierte un array de enum a array de Vector2
static func array_to_vector2(directions: Array[int]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for dir in directions:
		match dir:
			Type.UP: result.append(Vector2.UP)
			Type.DOWN: result.append(Vector2.DOWN)
			Type.LEFT: result.append(Vector2.LEFT)
			Type.RIGHT: result.append(Vector2.RIGHT)
			_: result.append(Vector2.ZERO)
	return result
