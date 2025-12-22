class_name CatchupPolicy

## Enum para políticas de recuperación cuando el follower queda bloqueado o muy lejos

enum Type {
	SNAP,            ## Teletransporta cerca del leader
	WAIT,            ## Espera a que sea posible moverse
	TELEPORT_IF_FAR  ## Teleporta solo si se excede distancia máxima
}


