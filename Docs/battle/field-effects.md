# Field effects — reglas de convivencia (PBI 704)

Referencia canónica: **Gen 4** (HGSS).  
Implementación: `FieldBattleEffect` → `ScreenFieldEffect` / `HazardFieldEffect`, registrados con `BattleEffectController.add_side_effect(side, effect)`.

Identidad de existencia: **por clase** (`has_side_effect` / `remove_side_effect`). Reflect y Light Screen no se pisan entre sí; Spikes y Toxic Spikes son tipos distintos.

## Fases relevantes

```
ON_SWITCH_IN          → hazards de entrada (apply+visualize intercalados por efecto; Gen 4)
ON_INCOMING_DAMAGE_*  → Reflect / Light Screen (mitigación)
ON_VALIDATE_AILMENT   → Safeguard
ON_VALIDATE_STAT      → Mist
get_speed_multiplier  → Tailwind (fuera de fase; al calcular velocidad)
ON_END_BATTLE_TURN    → decremento/expiración de screens (hazards no caducan por turnos)
```

Orden de fuentes en apply: Weather → Field → Ailment → Ability → …  
En visualize: Field → Weather → Ailment → Ability → …

## Matriz por efecto

| Efecto | Clase | Stackable | Max capas | Fase principal | Expiración | Reaplicación |
|--------|-------|-----------|-----------|----------------|------------|--------------|
| Reflect | `ReflectFieldEffect` | No | 1 | `ON_INCOMING_DAMAGE_*` (físico) | 5 turnos | Fail (`already`) — no refresh |
| Light Screen | `LightScreenFieldEffect` | No | 1 | `ON_INCOMING_DAMAGE_*` (especial) | 5 turnos | Fail — no refresh |
| Safeguard | `SafeguardFieldEffect` | No | 1 | `ON_VALIDATE_AILMENT` | 5 turnos | Fail — no refresh |
| Mist | `MistFieldEffect` | No | 1 | `ON_VALIDATE_STAT` | 5 turnos | Fail — no refresh |
| Tailwind | `TailwindFieldEffect` | No | 1 | velocidad (`get_speed_multiplier`) | 3 turnos | Fail — no refresh |
| Spikes | `SpikesFieldEffect` | Capas | 1–3 | `ON_SWITCH_IN` | Ninguna (`turns_left = null`) | +1 capa; a 3 → fail |
| Toxic Spikes | `ToxicSpikesFieldEffect` | Capas | 1–2 | `ON_SWITCH_IN` | Ninguna (salvo absorción Veneno) | +1 capa; a 2 → fail |
| Stealth Rock | `StealthRockFieldEffect` | No | 1 | `ON_SWITCH_IN` | Ninguna | Fail si ya activo |

## Orden de hazards en `ON_SWITCH_IN`

Prioridades en `BattleEffectPriority` (mayor = antes):

| Prioridad | Efecto |
|-----------|--------|
| 30 | Stealth Rock |
| 20 | Spikes |
| 10 | Toxic Spikes |

Así el orden es estable aunque se hayan colocado en otro orden.

## Presentación en `ON_SWITCH_IN`

`BattleEffectController._process_switch_in_phase`: por cada efecto, en orden de prioridad,

1. `apply_phase` (daño/estado),
2. `visualize_phase` (barra + mensaje),
3. si el entrante está KO → **corte** (no más hazards ni habilidades de entrada).

Así cada hazard baja la vida y muestra su mensaje por separado (no un batch apply→visualize).

El faint UI/EXP se resuelve después del switch (`BattleTurnController.check_and_show_fainted`).

Un hazard se activa **como máximo una vez** por `process_phase(ON_SWITCH_IN)` válido.

## Mensajería

Familia `MessageFamily.Values.FIELD_EFFECT` vía `BattleMessageFieldEffect`:

| Momento | Quién lo muestra |
|---------|------------------|
| start (colocación) | `*MoveEffect.visualize` |
| already / fail | `*MoveEffect.visualize` |
| end (screen) | `FieldBattleEffect` en `ON_END_BATTLE_TURN` si `has_finished()` |
| activation (daño/veneno) | `HazardFieldEffect.visualize_on_entry` |

Evitar segundo `start` en el persistent salvo efectos pre-sembrados en `ON_BATTLE_START`.

## Añadir un field effect nuevo

1. Heredar `ScreenFieldEffect` o `HazardFieldEffect` (no `FieldBattleEffect` directo salvo excepción documentada).
2. `*MoveEffect` con reglas de reaplicación explícitas.
3. Si es hazard: prioridad en `BattleEffectPriority` para `ON_SWITCH_IN`.
4. Mensajes en `BattleMessageFieldEffect`.
5. Actualizar esta matriz.

## QA

`TestBattle.gd` → flag `use_field_effects_integration_test` (3 hazards + Reflejo sembrado + Pistola Agua).
