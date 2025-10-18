class_name OrientationBehaviorEnum

## Comportamientos de orientación para NPCs al interactuar

enum Type {
	FACE_PLAYER,        ## Siempre mira al jugador al interactuar
	FIXED,              ## Nunca cambia de dirección
	FACE_AND_RESTORE    ## Mira al jugador, luego recupera su dirección inicial
}
