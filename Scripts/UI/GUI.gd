extends CanvasLayer

## GUI (Legacy) --------------------------------------------------------------
##
## Este script formaba parte de la antigua capa de UI basada en SignalManager.
## A partir de la migración a DisplayManager, todo su comportamiento se ha
## desactivado para evitar conflictos. Se mantiene como stub para que cualquier
## escena antigua que todavía lo instancie no falle por script faltante.
##
## El código original se movió a `Docs/legacy/GUI_legacy.gd.txt` y queda como
## referencia histórica.
##
## Si ves este script en ejecución, significa que queda algún recurso antiguo
## sin migrar: sustitúyelo por las llamadas a DisplayManager.

func _ready() -> void:
	push_warning("GUI.gd está obsoleto. Usa DisplayManager en su lugar.")
	# La instancia se elimina para que no interfiera con la UI actual.
	queue_free()

