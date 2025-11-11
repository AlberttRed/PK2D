extends Node

## SignalManager (legacy stub)
## ---------------------------------------------------------------------------
##
## Tras migrar la UI a `DisplayManager` y los sistemas del overworld a
## `OverworldContext`, el bus global dejó de ser necesario. Este autoload se
## mantiene vacío para evitar errores en recursos antiguos que todavía hagan
## referencia a `SignalManager`, pero ya no define ni emite señales.

func _ready() -> void:
	print("SignalManager: Autoload legacy inicializado (sin señales activas)")
