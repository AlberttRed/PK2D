class_name DirectionFlagsEnum

## Máscaras direccionales para entry_mask y exit_mask (flags de bits)
## Cada dirección es un bit que se puede combinar con OR (|)
## Ejemplo: UP | DOWN = 0b1010 = permite movimiento arriba y abajo
enum Values {
	NONE = 0,      # 0b0000 - Sin restricciones (permitido en todas direcciones)
	UP = 1,        # 0b0001 - Arriba
	RIGHT = 2,     # 0b0010 - Derecha
	DOWN = 4,      # 0b0100 - Abajo
	LEFT = 8,      # 0b1000 - Izquierda
	ALL = 15       # 0b1111 - Todas las direcciones
}

