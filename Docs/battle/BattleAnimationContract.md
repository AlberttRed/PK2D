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

| Campo | Tipo | Default | Notas |
|-------|------|---------|--------|
| `animation_scene` | `PackedScene` | `null` | Escena temporal a instanciar |
| `animation_name` | `String` | `"default"` | Clip del `AnimationPlayer` |
| `blocks_visualize` | `bool` | `true` | Solo path bloqueante activo en este bloque de PBIs |
| `fit_visual_to_anchors` | `bool` | `true` | Encaja `VisualRoot` al segmento user→target real |
| `authored_travel_length` | `float` | `200` | Unidad de viaje completo en +X local; **debe coincidir con las keys del proyectil** |
| `user_spot_anchor` | `SpotAnchor` | `PROJECTILE_ORIGIN` | Anchor del spot para el origen |
| `target_spot_anchor` | `SpotAnchor` | `HIT_CENTER` | Anchor del spot para el destino |

`SpotAnchor`: `CENTER`, `HIT_CENTER`, `PROJECTILE_ORIGIN`, `STATUS_ICON`, `FEET` (mismo set que `BattleSpot`).

---

## 9. Convención de escenas de animación (autoría)

Autoría en workbench (PBI 670); runtime solo instancia la `.tscn` del VFX.

### Workbench

- Escena: `Scenes/Battle/animations/BattleAnimationWorkbench.tscn`
- Réplica visual del **campo** (fondo, bases, spots mock single, `BattleAnimationLayer`).
- **No** es escena de combate: sin controllers, menús ni lógica.
- Spots mock incluyen `Positions/Anchors` con los mismos nombres que `BattleSpotUI`: `Center`, `HitCenter`, `ProjectileOrigin`, `StatusIcon`, `Feet`.
- Flujo típico:
  1. Duplicar una plantilla de `Scenes/Battle/animations/templates/`.
  2. Abrir el workbench y, para previsualizar, instanciar temporalmente la escena bajo `BattleAnimationLayer` (o editar la escena de animación con el workbench como referencia de posiciones).
  3. Guardar la animación como `.tscn` independiente.
  4. Asignarla a un recurso `BattleAnimation.animation_scene`.

### Dirigidas (user → target)

Plantilla: `Scenes/Battle/animations/templates/DirectedAnimationTemplate.tscn`

- `Hooks`, `UserAnchor`, `TargetAnchor`, `VisualRoot`, `AnimationPlayer`
- Tracks del `AnimationPlayer` **solo** a nodos internos de esa escena
- Prohibido: rutas a nodos de `Battle.tscn` / `FieldUI` / workbench de runtime

### Globales (campo)

Plantilla: `Scenes/Battle/animations/templates/GlobalAnimationTemplate.tscn`

- `Hooks`, `FieldAnchor`, `VisualRoot`, `AnimationPlayer`
- Misma regla de independencia de rutas

### Orientación / marco dirigido (user → target)

**Contrato de autoría (importante):**

1. Viaje completo del proyectil en local = eje **+X** de `0` a **`authored_travel_length`** (default `200` en el `.tres` de `BattleAnimation`).
2. Las keys de posición de partículas/sprites **deben usar esa misma longitud**. Si el export es `200`, anima `x: 0 → 200`; si lo cambias a `1000`, anima `0 → 1000`. Si no coinciden, el proyectil se queda corto o se pasa.
3. La velocidad la marca la **duración del clip**, no el valor de `authored_travel_length` (si keys y export están alineados).
4. `UserAnchor` / `TargetAnchor` en la escena son **guías opcionales** en la plantilla (p. ej. en `0` y `authored_travel_length`); el runtime obtiene origen/destino de los anchors del **BattleSpot** según `user_spot_anchor` / `target_spot_anchor`.
5. **No** animar `VisualRoot:position` / `rotation` / `scale` si `fit_visual_to_anchors` está activo.

En runtime (`fit_visual_to_anchors`, default true):

1. Lee posiciones reales de los spots (`user_spot_anchor` → `target_spot_anchor`).
2. `VisualRoot.global_position` = origen (user).
3. `VisualRoot.rotation` = ángulo del vector real (alinea +X local hacia el target).
4. `VisualRoot.scale.x` = `distancia_real / authored_travel_length`.

Así el mismo clip funciona player→enemy y enemy→player.

Desactivar `fit_visual_to_anchors` en el `.tres` para VFX que no deban estirarse/orientarse así.

### Anchors de `BattleSpot` (PBI 671)

Nombres estables: `Center`, `HitCenter`, `ProjectileOrigin`, `StatusIcon`, `Feet`.  
API: `get_anchor_node(name)`, `get_anchor_global_position(name)` — fallback a `Center`, o a `global_position` del spot si no hay anchors.

Mapeo al preparar la instancia (configurable en el `.tres`):

- `UserAnchor` → `user_spot_anchor` (default `ProjectileOrigin`; fallback `Center` vía API del spot)
- `TargetAnchor` → `target_spot_anchor` (default `HitCenter`; fallback `Center`)
- Multi-target: se usa el **primer** target

### Hooks (mando al spot)

- Nodo no visual `Hooks` (`BattleAnimationHooks`) dentro de la escena VFX.
- En `_prepare_instance`: si existe, `bind(user_spot, target_spots)`.
- Forwarder genérico (sin espejar la API del spot):
  - `call_on_user(method, args := [])`
  - `call_on_target(method, args := [])`
- El `AnimationPlayer` usa Call Method Track → hook → `BattleSpot.callv(...)`.
- Los efectos visuales viven en el **spot** (helpers en PBI 673); el hook solo reenvía.
- Call Method no hace `await`: métodos del spot deben ser fire-and-forget si lanzan tweens.

---

## 10. Integración con datos (PBI 672)

- `MoveData.battle_animation: BattleAnimation` (nullable).
- `Move` / `BattleMove.get_battle_animation()` exponen el recurso.
- `BattleMoveHandler.visualize()` hace `await _play_move_battle_animation(ui)` **antes** de `_visualize` (impacto HP/mensajes).
- Mismo recurso reutilizable por varios movimientos.
- Sin animación → flujo visual previo sin cambios.
- Otros sistemas (ailments, weather, items) podrán invocar el mismo `play(...)` sin API distinta.

### Campo / intro (PBI 339 / 338 / 706 / 707)

- **Orquestación intro (707):** `BattleUI.prepare_intro_field` + `BattleUI.play_intro_sequence`
  - prepare — en negro, antes del reveal
  - play — tras reveal: bases/trainers → mensajes → send-in → menú
- Catálogo de clips: `BattleFieldAnimations` (`play_intro_trainers_enter`, `play_pokeball_throw`, `play_pokemon_enter`, `play_send_in`).
- Trainer enter (706): trainers fijos en la base; se animan `PlayerBase`/`EnemyBase` (player der→izq, rival izq→der) con deltas de `CONST.BATTLE.*_BASE_*POSITION`. Idle frame 0. Sin gesto de brazo.
- Posiciones de trainer: `CONST.BATTLE.BACK_SINGLE_TRAINER_POS` / `FRONT_SINGLE_TRAINER_POS`.
- Trainer exit: `play_trainer_exit_for_spot` — slide del nodo Trainer (player← / rival→); la base permanece.
- `PokeballThrowBattleAnimation`: clips `throw_player` / `throw_enemy`; `ball00` → open + brillo.
- `PokemonEnterBattleAnimation`: grow desde silueta blanca sobre el sprite del spot (`evolution_white`).
- Intro / switch-in: `play_send_in` = trainer exit → ball → enter → HP bar.

### Ailments

- `AilmentData.battle_animation: BattleAnimation` (nullable) + `get_battle_animation()` / `play_battle_animation_on(ui, pokemon)`.
- Ejemplo: burn → `Scenes/Battle/animations/ailments/BurnAnimation.*` en `BURN.tres`.
- Al **aplicar** el ailment (`BattleMoveHandler._visualize_ailment_entry_result`): anim → mensaje de inicio («se ha quemado», etc.).
- Al **repetir** el efecto (p. ej. burn end-of-turn en `BurnAilmentEffect.visualize_phase`): anim → mensaje → HP.
- VFX locales: `fit_visual_to_anchors = false` → `VisualRoot` se coloca en el anchor del spot (sin rotar/estirar).
- Ejemplo E2E: Ascuas (`052`) → `Scenes/Battle/animations/moves/EmberAnimation.tres`.

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

## 12. Fuera de alcance de este contrato (posteriores)

- Catálogo masivo de animaciones concretas
- Animaciones no bloqueantes reales
- Coreografía multi-target avanzada

---

## 13. Helpers y subclases (PBI 673)

### `BattleAnimationUtils`

Helpers estáticos (solo visual):

- `flash_spot(spot, flashes, step_duration, end_pause)`
- `shake_spot(spot, intensity, duration)`
- `move_spot_forward(spot, distance, duration)`
- `darken_overlay(parent, alpha, duration)` / `restore_overlay(overlay, duration)`
- `wait(host, seconds)`

### API en `BattleSpot`

Fachadas que delegan en utils (call sites y Hooks):

- `play_hit_animation()` → `flash_spot` (comportamiento de impacto existente)
- `flash(...)`, `shake(...)`, `move_forward(...)`

### Hooks

Siguen siendo forwarder genérico: `call_on_target("play_hit_animation")` o `call_on_target("flash", [1, 0.05, 0.0])`.  
Call Method no hace `await`; los tweens arrancan igual (fire-and-forget).

### Subclases

Ejemplo: `BattleAnimationWithFieldFlash` — oscurece el layer, `super.play`, restaura.  
Recurso smoke: `Scenes/Battle/animations/_smoke/SmokeBattleAnimationWithFieldFlash.tres`.  
Criterio: subclase solo si tracks + anchors + hooks no bastan.

### Criterios de aceptación (PBI 673)

- [x] Existe `BattleAnimationUtils` con flash, shake, move forward, darken/restore, wait.
- [x] `BattleSpot.play_hit_animation` (y flash/shake/move_forward) delegan en utils.
- [x] Call sites existentes (`DamageEffect`, etc.) siguen usando la fachada del spot.
- [x] Hooks siguen siendo forwarder genérico hacia métodos del spot.
- [x] Ejemplo de subclase (`BattleAnimationWithFieldFlash`) + recurso smoke.
- [x] Sin efectos lógicos; documentado en el contrato.
