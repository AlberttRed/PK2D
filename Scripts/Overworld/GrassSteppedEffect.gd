extends AnimatedSprite2D
class_name GrassSteppedEffect

## Efecto de hierba "aplastada" que se muestra cuando el player pisa un tile de hierba
## Este efecto se queda en el tile (no sigue al player) y se autodestruye al terminar la animación


func _ready() -> void:
	# Configurar para que la animación continúe aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Reproducir la animación automáticamente
	play("stepped")

	# Conectar señal para autodestruirse cuando termine
	animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	# Autodestruirse cuando termina la animación
	queue_free()
