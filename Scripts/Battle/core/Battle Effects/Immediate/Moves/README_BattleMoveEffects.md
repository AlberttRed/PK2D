# BattleMoveEffects - Efectos de Movimientos

## Descripción

Los `BattleMoveEffect` son efectos inmediatos que se ejecutan cuando un movimiento es usado. Se utilizan principalmente para movimientos que crean efectos de campo o clima.

## Jerarquía de Clases

```
ImmediateBattleEffect
  └─ BattleMoveEffect
      ├─ RainDanceMoveEffect
      ├─ SunnyDayMoveEffect (futuro)
      ├─ SandstormMoveEffect (futuro)
      └─ ... (otros efectos de campo)
```

## Cómo Crear un Nuevo BattleMoveEffect

### 1. Crear el Script del Efecto

Crea un archivo `.gd` en `Scripts/Battle/core/Battle Effects/Immediate/Moves/`

**Ejemplo:** `SunnyDayMoveEffect.gd`

```gdscript
extends BattleMoveEffect
class_name SunnyDayMoveEffect

func _init(_user: BattlePokemon, _target: BattlePokemon = null) -> void:
	super._init(_user, _target)

func apply():
	# Crear efecto de sol con duración de 5 turnos
	# El parámetro 'true' indica que fue iniciado por un movimiento
	var sun_effect := SunWeatherEffect.new(user, 5, true)
	BattleEffectController.add_field_effect(sun_effect)

func visualize(ui: BattleUI):
	# Mostrar mensaje cuando el sol es provocado por el movimiento
	await ui.show_message_from_dict({
		"type": "wait",
		"text": "¡El sol brilla con intensidad!",
		"wait_time": 1.5
	})
```

### 2. Asignar el Script al Movimiento en Godot

Para asignar el efecto a un movimiento (ej: Rain Dance):

1. Abre el archivo del movimiento en Godot:
   - Navega a `Resources/Data/Moves/`
   - Busca el movimiento (ej: `464.tres` para Rain Dance)
   - Abre el archivo en el Inspector

2. En el campo **`Move Effect`**:
   - Arrastra el script `RainDanceMoveEffect.gd`
   - O haz clic en el campo y navega hasta el script

3. Guarda el recurso

**Ejemplo de configuración:**

```
Move Resource (464.tres - Rain Dance)
├─ Name: "Rain Dance"
├─ Power: 0
├─ PP: 5
├─ Category: BattleWholeFieldEffectMoveCategory
└─ Move Effect: RainDanceMoveEffect.gd ← ¡IMPORTANTE!
```

### 3. Configurar la Categoría del Movimiento

El movimiento debe usar la categoría `BattleWholeFieldEffectMoveCategory` que apunta al handler `BattleWholeFieldEffectMoveHandler`.

Este handler automáticamente:
1. Obtiene el `move_effect` del movimiento
2. Crea una instancia del efecto
3. Ejecuta `apply()` y `visualize()`

## Ejemplo Completo: Rain Dance

### Archivo: `RainDanceMoveEffect.gd`

```gdscript
extends BattleMoveEffect
class_name RainDanceMoveEffect

func _init(_user: BattlePokemon, _target: BattlePokemon = null) -> void:
	super._init(_user, _target)

func apply():
	var rain_effect := RainWeatherEffect.new(user, 5, true)
	BattleEffectController.add_field_effect(rain_effect)

func visualize(ui: BattleUI):
	await ui.show_message_from_dict({
		"type": "wait",
		"text": "¡Comenzó a llover!",
		"wait_time": 1.5
	})
```

### Efecto Persistente: `RainWeatherEffect.gd`

```gdscript
extends PersistentBattleEffect
class_name RainWeatherEffect

var started_by_move: bool = false

func _init(_source = null, _duration: int = 5, _started_by_move: bool = false):
	super._init(_source)
	turns_left = _duration
	started_by_move = _started_by_move

func on_modifier(modifier_type: int, move: BattleMove, _user, _target, value):
	if modifier_type == BattleEffect.Modifiers.MOVE_POWER:
		var move_type = move.get_type()
		if move_type.Name == "Agua":
			return value * 1.5  # +50% poder
		elif move_type.Name == "Fuego":
			return value * 0.5  # -50% poder
	return value
```

## Flujo de Ejecución

```
1. Usuario selecciona Rain Dance
   ↓
2. BattleWholeFieldEffectMoveHandler se crea
   ↓
3. Handler obtiene move_effect del movimiento
   ↓
4. Se crea instancia de RainDanceMoveEffect(user, target)
   ↓
5. apply(): Crea RainWeatherEffect y lo añade como field effect
   ↓
6. visualize(): Muestra "¡Comenzó a llover!"
   ↓
7. Cada turno: RainWeatherEffect.on_modifier() ajusta poder de movimientos
   ↓
8. Tras 5 turnos: Efecto expira y se auto-elimina
```

## Ventajas de Este Sistema

✅ **Escalable**: Añadir nuevos efectos solo requiere crear el script y asignarlo
✅ **Configurable**: Cada movimiento puede tener su propio efecto único
✅ **Reutilizable**: Múltiples movimientos pueden compartir el mismo efecto
✅ **Sin código hardcoded**: No hay diccionarios ni switch/match de nombres
✅ **Editor-friendly**: Se configura todo desde el Inspector de Godot

## Lista de Movimientos de Campo a Implementar

- [x] Rain Dance / Danza lluvia → `RainDanceMoveEffect`
- [ ] Sunny Day / Día soleado → `SunnyDayMoveEffect`
- [ ] Sandstorm / Tormenta de arena → `SandstormMoveEffect`
- [ ] Hail / Granizo → `HailMoveEffect`
- [ ] Trick Room / Espacio raro → `TrickRoomMoveEffect`
- [ ] Gravity / Gravedad → `GravityMoveEffect`
- [ ] etc...

## Notas Importantes

- El `BattleMoveEffect` se ejecuta **inmediatamente** al usar el movimiento
- El `PersistentBattleEffect` creado por el efecto persiste durante varios turnos
- El flag `started_by_move` diferencia entre efectos por movimiento vs clima natural
- Los modificadores se aplican en `DamageCalculator_Gen5.apply_power_modifiers()`

