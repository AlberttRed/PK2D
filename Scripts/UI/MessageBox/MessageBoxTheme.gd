extends Resource
class_name MessageBoxTheme

## Resource para definir el tema visual completo de un MessageBox
## Incluye el marco, el indicador de espera y su configuración

@export var frame_stylebox: StyleBox  ## El StyleBox para el marco del mensaje

## Márgenes del área de texto (`ScrollContainer` interior). **−1** = no cambiar (se usan los de la escena / tema previo).
## Ajusta aquí el texto más a la izquierda/derecha sin tocar código (mismo `MessageBoxTheme` que cargan eventos vía `frameStyle`).
@export_range(-1.0, 512.0) var content_margin_left: float = -1.0
@export_range(-1.0, 512.0) var content_margin_right: float = -1.0
@export_range(-1.0, 256.0) var content_margin_top: float = -1.0
@export_range(-1.0, 256.0) var content_margin_bottom: float = -1.0

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
