class_name ActorSprite3D
extends RefCounted
## Configuración compartida del "sprite plano" del Overworld3D (Player3D y Event3D).
##
## Un sprite 2D se muestra en un `AnimatedSprite3D` colgado de un pivote (`Node3D`) inclinado 45° hacia
## la cámara, con 1 tile 2D = 1 celda 3D. Centralizarlo aquí garantiza que un evento con sprite plano
## tenga exactamente la misma altura, inclinación y anclaje al suelo que el Player3D.
##
## Estructura esperada: `pivot` (inclinado + desplazado hacia la cámara) > `sprite` (AnimatedSprite3D).

## Inclinación del plano hacia la cámara (igual que Tree.glb).
const TILT := -PI * 0.25
## Offset 2D de referencia del Player (0, -8) en píxeles de frame; en 3D solo sirve para anclar el pie.
const REFERENCE_OFFSET := Vector2(0, -8)
## Empuje por defecto hacia la cámara (+Z) para compensar el tilt.
const DEFAULT_BACK_OFFSET := 1.0
## Tamaño en píxeles de un tile 2D (Tileset 32×32).
const DEFAULT_TILE_PIXELS := 32.0


## Aplica inclinación, filtro, recorte alfa, escala por celda y anclaje al suelo.
## - `cell_size`: lado de la celda 3D (metros).
## - `frame_pixels`: tamaño del frame en píxeles (define la altura del sprite).
## - `extra_offset_px`: desplazamiento 2D adicional de la página (X derecha, Y abajo, en píxeles).
static func setup(pivot: Node3D, sprite: AnimatedSprite3D, cell_size: float, tile_pixels: float,
		frame_pixels: Vector2, back_offset: float = DEFAULT_BACK_OFFSET,
		extra_offset_px: Vector2 = Vector2.ZERO) -> void:
	pivot.rotation = Vector3(TILT, 0.0, 0.0)
	apply_back_offset(pivot, back_offset)
	sprite.centered = true
	sprite.offset = REFERENCE_OFFSET
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.shaded = false
	sprite.double_sided = false
	sprite.pixel_size = cell_size / tile_pixels
	anchor_to_ground(sprite, frame_pixels, extra_offset_px)


## Empuja el pivote hacia la cámara (+Z).
static func apply_back_offset(pivot: Node3D, back_offset: float) -> void:
	pivot.position.z = back_offset


## Deja el pie del sprite en Y≈0 del pivote (espacio previo al tilt).
static func anchor_to_ground(sprite: AnimatedSprite3D, frame_pixels: Vector2,
		extra_offset_px: Vector2 = Vector2.ZERO) -> void:
	# Con `centered`, el pie ≈ -H/2 (+ offset) en Y local del sprite.
	var half_h := frame_pixels.y * sprite.pixel_size * 0.5
	var offset_y_world := sprite.offset.y * sprite.pixel_size
	sprite.position = Vector3(
		extra_offset_px.x * sprite.pixel_size,
		half_h - offset_y_world - extra_offset_px.y * sprite.pixel_size,
		0.0)
