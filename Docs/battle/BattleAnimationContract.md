# BattleAnimation — contrato técnico (PBI 675)

Contrato canónico para **todas** las animaciones de combate (movimientos, estados, clima, ítems).  
Los PBIs 669–673 deben implementarse sin redefinir ni contradecir estas reglas.

Implementación runtime: `BattleAnimation` (`Resource`) + nodo fijo `BattleAnimationLayer` bajo `FieldUI`.  
Implementación de `play(...)`: `Scripts/Battle/animations/BattleAnimation.gd` (PBI 669).

---

## 1. Responsabilidad

`BattleAnimation` **solo visualiza**.

Prohibido:

- modificar HP, PP, estados, ailments, clima, field effects
- alterar turno, orden de acciones, resultados de hit/miss/crítico
- emitir o consumir lógica de combate (daño, fallos, switches)

Permitido:

- instanciar/reproducir/limpiar nodos temporales bajo `BattleAnimationLayer`
- posicionar anchors visuales y orientar (`flip`) el root visual
- tweens / `AnimationPlayer` / partículas / overlays puramente gráficos

---

## 2. Firma canónica

```gdscript
func play(
	animation_layer: Node2D,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void
```

### Semántica async

- `play` es una **coroutine**.
- El caller externo **siempre** invoca:

```gdscript
await battle_animation.play(animation_layer, user_spot, target_spots)
```

- No hay API alternativa de entrada. Subclases pueden ampliar comportamiento interno; el call site no cambia.

### Precondiciones

| Parámetro | Regla |
|-----------|--------|
| `animation_layer` | Debe ser el nodo runtime `BattleAnimationLayer` (hijo de `FieldUI`). Si es `null` o inválido → warning y return (no crash). |
| `user_spot` | Opcional según tipo de animación. Puede ser `null` (p. ej. VFX globales de campo). |
| `target_spots` | Puede ser vacío, 1 o N. Multi-target coreografiado no está en el contrato base; el runtime usa el **primer** target cuando haga falta un único ancla. |
| `animation_scene` (recurso) | Puede ser `null` → no-op con warning opcional. |

### Postcondiciones

- No se ha alterado estado lógico de batalla.
- Si se creó una instancia temporal, **ya no existe** (o nunca se creó).
- El flujo de combate puede continuar aunque la animación haya fallado visualmente.

### Extensión por subclase

```gdscript
# Caller externo — siempre igual
await battle_animation.play(layer, user_spot, target_spots)

# Recurso puede usar script especializado:
# class_name BattleSurfAnimation extends BattleAnimation
```

Criterio: subclase solo cuando tracks + anchors + helpers no basten (PBI 673).

---

## 3. Ciclo de vida de ejecución

Orden obligatorio dentro de `play(...)`:

1. **Validar** `animation_layer` y `animation_scene`.
2. Si `animation_scene == null` → warning (opcional) y **return** sin error.
3. **Instanciar** la escena como hijo de `BattleAnimationLayer` (nunca de `BattleSpot`).
4. **Resolver** nodos internos esperados (`AnimationPlayer`, `UserAnchor` / `TargetAnchor` / `FieldAnchor`, `VisualRoot`) si existen; ausencia ≠ crash.
5. **Posicionar / orientar** (PBI 671): anchors y flip según spots; si no hay anchors en la escena, continuar.
6. **Reproducir** `AnimationPlayer` con `animation_name` (fallback a animación por defecto del player si el nombre no existe — warning, no crash).
7. **Esperar** finalización según política de sincronización (§4).
8. **Cleanup garantizado** de la instancia temporal (§5), en éxito y en fallo controlado.

Si falta `AnimationPlayer`: warning, cleanup de la instancia (si se creó), return. No abortar turno.

---

## 4. Sincronización con `visualize()`

### Blocking mode (por defecto)

- La animación principal del movimiento **bloquea** el avance de la fase visual hasta terminar.
- Equivale a: el caller hace `await play(...)` y no continúa el resto de `visualize()` hasta que `play` retorna.

### Reserva futura (fuera de este PBI)

- Campo previsto en el recurso: `blocks_visualize: bool = true`.
- Animaciones no bloqueantes (`blocks_visualize == false`) **no** se implementan aquí; el contrato solo reserva el flag para no romper la API después.

### Orden exacto respecto a mensajes e impacto

Flujo real del combate (ya existente) y dónde encaja la animación:

```
TurnController
  1. show_used_move_message(...)     # mensaje de uso (antes de apply)
  2. handlers.apply()                # lógica (daño/estados ya resueltos)
  3. await handlers.visualize(ui)
        └─ MoveHandler._visualize
             a. await battle_animation.play(...)   # animación principal (si existe)
             b. impacto mínimo (flash/shake existentes o helpers)
             c. actualización HP / UI
             d. mensajes adicionales (crítico, efectividad, ailments, …)
```

Reglas:

- El mensaje “usó el movimiento” **no** se mueve dentro de `BattleAnimation`; permanece en `TurnController`.
- Si `battle_animation` es `null`, se omiten (a) y el resto del flujo visual actual se mantiene.
- Fallos en (a) no saltan (b)–(d).

---

## 5. Ownership y cleanup

| Aspecto | Regla |
|---------|--------|
| Owner del nodo temporal | La ejecución de `BattleAnimation.play` |
| Contenedor permitido | Solo `BattleAnimationLayer` |
| Contenedor prohibido | `BattleSpot`, HPBar, menús UI, root `Battle` |
| Cleanup | Siempre: éxito, early-return controlado, falta de `AnimationPlayer`, error de instancia |
| Mecánica | `queue_free` / liberar en path de salida único (p. ej. `try`/`finally` o equivalente) |

Tras `play`, no deben quedar huérfanos bajo el layer atribuibles a esa ejecución.

---

## 6. Fallback — never-crash policy (visual)

| Situación | Comportamiento |
|-----------|----------------|
| `animation_scene == null` | Warning opcional; return; combate sigue |
| `animation_layer` inválido | Warning; return |
| Fallo al instanciar | Warning; no instancia; return |
| Sin `AnimationPlayer` | Warning; cleanup si hubo instancia; return |
| Nombre de animación inexistente | Warning; intentar fallback default del player o return tras cleanup |
| Anchor solicitado ausente en spot | Usar `Center` (PBI 671); no crash |
| Sin `UserAnchor` / `TargetAnchor` en escena | Continuar sin posicionamiento de anclas |

Ningún fallo visual debe lanzar un error que aborte el turno o invalide el resultado lógico ya calculado en `apply()`.

---

## 7. Capa runtime y acceso

- `BattleAnimationLayer` es un `Node2D` **fijo** bajo `FieldUI` (hermano de `PlayerBase` / `EnemyBase`), mismo espacio visual que los spots.
- Acceso previsto: `FieldUI` / `BattleUI.get_animation_layer()` (PBI 669).
- El nodo vacío `BattleAnimationController` bajo `Battle.tscn` **no** forma parte de este contrato (legado; no usarlo para VFX temporales).

---

## 8. Campos del recurso (contrato de datos)

Definidos para implementación en PBI 669:

| Campo | Tipo | Default | Notas |
|-------|------|---------|--------|
| `animation_scene` | `PackedScene` | `null` | Escena temporal a instanciar |
| `animation_name` | `String` | `"default"` | Clip del `AnimationPlayer` |
| `blocks_visualize` | `bool` | `true` | Solo path bloqueante activo en este bloque de PBIs |

---

## 9. Convención de escenas de animación (autoría)

Autoría en workbench (PBI 670); runtime solo instancia la `.tscn` del VFX.

### Workbench

- Escena: `Scenes/Battle/animations/BattleAnimationWorkbench.tscn`
- Réplica visual del **campo** (fondo, bases, spots mock single, `BattleAnimationLayer`).
- **No** es escena de combate: sin controllers, menús ni lógica.
- Spots mock incluyen anchors con nombres finales: `Center`, `HitCenter`, `ProjectileOrigin`, `StatusIcon`, `Feet`.
- Flujo típico:
  1. Duplicar una plantilla de `Scenes/Battle/animations/templates/`.
  2. Abrir el workbench y, para previsualizar, instanciar temporalmente la escena bajo `BattleAnimationLayer` (o editar la escena de animación con el workbench como referencia de posiciones).
  3. Guardar la animación como `.tscn` independiente.
  4. Asignarla a un recurso `BattleAnimation.animation_scene`.

### Dirigidas (user → target)

Plantilla: `Scenes/Battle/animations/templates/DirectedAnimationTemplate.tscn`

- `UserAnchor`, `TargetAnchor`, `VisualRoot`, `AnimationPlayer`
- Tracks del `AnimationPlayer` **solo** a nodos internos de esa escena
- Prohibido: rutas a nodos de `Battle.tscn` / `FieldUI` / workbench de runtime

### Globales (campo)

Plantilla: `Scenes/Battle/animations/templates/GlobalAnimationTemplate.tscn`

- `FieldAnchor`, `VisualRoot`, `AnimationPlayer`
- Misma regla de independencia de rutas

### Orientación (PBI 671)

- Flip horizontal solo en `VisualRoot` (si no existe, root de la instancia)
- Los tracks no deben pelear con ese `scale.x` (no animar el mismo eje en el mismo nodo, o documentar excepción en la escena)

### Anchors de `BattleSpot` (PBI 671)

Nombres estables: `Center`, `HitCenter`, `ProjectileOrigin`, `StatusIcon`, `Feet`.

Mapeo por defecto:

- `UserAnchor` → `ProjectileOrigin` (fallback `Center`)
- `TargetAnchor` → `HitCenter` (fallback `Center`)

---

## 10. Integración con datos (PBI 672)

- `MoveData.battle_animation: BattleAnimation` (nullable).
- Mismo recurso reutilizable por varios movimientos.
- Otros sistemas (ailments, weather, items) podrán invocar el mismo `play(...)` sin API distinta.

---

## 11. Criterios de aceptación (PBI 675)

- [x] Existe un contrato técnico explícito y único para ejecutar animaciones de combate.
- [x] Define la firma canónica de `play(...)` y pre/postcondiciones.
- [x] Define el orden exacto en `visualize()` respecto a mensajes e impacto visual.
- [x] Define que fallos visuales no interrumpen la lógica de combate.
- [x] Define cleanup garantizado de nodos temporales.
- [x] Define que `BattleAnimation` no altera estado lógico.
- [x] Define compatibilidad con subclases sin cambiar el call site externo.
- [x] Los PBIs 669–673 pueden implementarse sin contradecir estas reglas.

---

## 12. Fuera de alcance de este contrato (PBIs posteriores)

- Catálogo de animaciones concretas
- Workbench completo (670)
- Anchors runtime y flip (671)
- Cableado `MoveData` + handlers (672)
- Helpers / subclases especiales (673)
- Animaciones no bloqueantes reales
- Coreografía multi-target avanzada
