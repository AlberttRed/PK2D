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
	LOOK_PLAYER, ## Solo mirar hacia el jugador (sin moverse)
	WAIT_025,    ## Espera de 0.25 segundos
	WAIT_050,    ## Espera de 0.5 segundos
	WAIT_100,    ## Espera de 1.0 segundo
	SPEED_SLOWEST, ## Cambiar velocidad a Slowest (0.5x)
	SPEED_SLOWER,  ## Cambiar velocidad a Slower (0.75x)
	SPEED_NORMAL, ## Cambiar velocidad a Normal (1.0x)
	SPEED_FASTER, ## Cambiar velocidad a Faster (1.5x)
	SPEED_FASTEST, ## Cambiar velocidad a Fastest (2.0x)
	EXCLAMATION_ANIM ## Mostrar animación de exclamación (trainer_exclamation)
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
		Type.LOOK_PLAYER: return Vector2.ZERO  # Se calculará dinámicamente
		_: return Vector2.ZERO

## Verifica si es un comando de movimiento (true) o solo orientación (false)
static func is_movement(direction: int) -> bool:
	match direction:
		Type.UP, Type.DOWN, Type.LEFT, Type.RIGHT:
			return true
		Type.LOOK_UP, Type.LOOK_DOWN, Type.LOOK_LEFT, Type.LOOK_RIGHT, Type.LOOK_PLAYER, \
		Type.WAIT_025, Type.WAIT_050, Type.WAIT_100, \
		Type.SPEED_SLOWEST, Type.SPEED_SLOWER, Type.SPEED_NORMAL, Type.SPEED_FASTER, Type.SPEED_FASTEST, \
		Type.EXCLAMATION_ANIM:
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

## Verifica si es un comando de cambio de velocidad
static func is_speed_change(direction: int) -> bool:
	match direction:
		Type.SPEED_SLOWEST, Type.SPEED_SLOWER, Type.SPEED_NORMAL, Type.SPEED_FASTER, Type.SPEED_FASTEST:
			return true
		_:
			return false

## Verifica si es un comando de animación (exclamación, etc.)
static func is_animation(direction: int) -> bool:
	match direction:
		Type.EXCLAMATION_ANIM:
			return true
		_:
			return false

## Convierte un comando de velocidad a MoveSpeedEnum.Type
static func to_speed_enum(direction: int) -> int:
	match direction:
		Type.SPEED_SLOWEST: return MoveSpeedEnum.Type.SLOWEST
		Type.SPEED_SLOWER: return MoveSpeedEnum.Type.SLOWER
		Type.SPEED_NORMAL: return MoveSpeedEnum.Type.NORMAL
		Type.SPEED_FASTER: return MoveSpeedEnum.Type.FASTER
		Type.SPEED_FASTEST: return MoveSpeedEnum.Type.FASTEST
		_: return MoveSpeedEnum.Type.NORMAL

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
