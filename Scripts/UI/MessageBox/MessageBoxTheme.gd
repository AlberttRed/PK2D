extends Resource
class_name MessageBoxTheme

## Resource para definir el tema visual completo de un MessageBox
## Incluye el marco, el indicador de espera y su configuración

@export var frame_stylebox: StyleBox  ## El StyleBox para el marco del mensaje

@export var wait_indicator_texture: Texture2D  ## La textura del indicador de espera (flecha)

@export var wait_indicator_mode: WaitIndicatorMode = WaitIndicatorMode.BOTTOM_RIGHT  ## Modo de posicionamiento del indicador
@export var wait_indicator_offset: Vector2 = Vector2.ZERO  ## Offset adicional para el posicionamiento

## Velocidad de animación del indicador de espera (por defecto 1.0)
@export var wait_indicator_blink_speed: float = 1.0

## Enum para los modos de posicionamiento del WaitIndicator
enum WaitIndicatorMode {
	BOTTOM_RIGHT,  ## Posicionado en la esquina inferior derecha del MessageBox
	INLINE_END_OF_TEXT  ## Posicionado al final del texto visible (estilo FireRed)
}
