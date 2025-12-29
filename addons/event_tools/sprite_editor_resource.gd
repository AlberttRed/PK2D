@tool
extends RefCounted
class_name SpriteEditorResource

## Recurso temporal para editar propiedades de sprite en el editor
## Se usa como objeto intermedio para el EditorInspector

@export var actor_style: ActorStyle = null
@export var sprite_frames: SpriteFrames = null
@export var sprite_texture: Texture2D = null

