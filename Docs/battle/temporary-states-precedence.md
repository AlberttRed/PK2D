# Precedencias de estados temporales (PBI 686)

Referencia canónica: **Gen 4** (HGSS). Mayor `get_priority()` = se evalúa antes dentro del mismo `effect_source`.

Constantes en `BattleEffectPriority.gd`.

## Fases del turno

```
ON_INIT_BATTLE_TURN
  → selección de acciones (ON_VALIDATE_MOVE / ON_VALIDATE_SWITCH / ON_VALIDATE_RUN en UI)
  → por velocidad/prioridad de acción:
      ON_INIT_POKEMON_TURN
      → ON_BEFORE_MOVE
      → ejecución del movimiento
      → ON_AFTER_MOVE
      ON_END_POKEMON_TURN
ON_END_BATTLE_TURN (global: field/side, luego Pokémon por velocidad descendente)
```

## ON_BEFORE_MOVE — bloqueo de acción

Solo el **primer** efecto que impide actuar muestra mensaje (`BattleEffectController` registra `_phase_blocker`).

| Prioridad | Efecto | Comportamiento |
|-----------|--------|----------------|
| 40 | Sleep | No puede moverse; decrementa turnos |
| 39 | Freeze | 20% descongelar; si no, bloqueado |
| 38 | Paralysis | 25% plena parálisis |
| 37 | Flinch | Bloqueado si retrocedió este turno |
| 36 | Confusion | 50% auto-daño; si no, actúa |
| 35 | Infatuation | 50% bloqueo por amor |

Taunt en `ON_BEFORE_MOVE` actúa como red de seguridad (IA); la restricción principal es `ON_VALIDATE_MOVE` + `restrict_selectable_moves`.

## ON_VALIDATE_MOVE — restricción de selección

Primer rechazo gana (`ctx.validation.rejected` + `ctx.validation.blocking_effect`).

| Prioridad | Efecto |
|-----------|--------|
| 11 | Encore |
| 10 | Taunt |
| 9 | Disable |
| 8 | Torment |

`restrict_selectable_moves` usa el mismo orden. Si 0 movimientos elegibles → Forcejeo (`BattleStruggleChoice`).

## ON_VALIDATE_STAT — bloqueo de bajadas de stats

Validación centralizada vía `BattlePhaseContext.stat_change` + resultado en `ctx.validation` (p. ej. Neblina → `block_reason = "mist"`).

Aplica a movimientos con `StatChangeEffect` y a habilidades que bajan stats rivales vía el mismo efecto (p. ej. Intimidate). El bloqueador publica `rejection_message`.

## ON_VALIDATE_AILMENT — bloqueo de estados

Payload en `ctx.ailment`; rechazo en `ctx.validation.rejected` (p. ej. Velo Sagrado, Substitute).

## ON_VALIDATE_SWITCH / ON_VALIDATE_RUN

| Prioridad | Efecto |
|-----------|--------|
| 10 | Trap |

Validación centralizada vía pipeline; `BattleSwitchChoice.resolve()` y `RunEffect.apply()` delegan aquí.

## ON_END_BATTLE_TURN — residuales y ticks

Por Pokémon, ordenados por velocidad descendente; dentro de cada uno:

| Prioridad | Efecto |
|-----------|--------|
| 25 | Poison |
| 24 | Burn |
| 15 | Trap (daño) |
| 14 | Perish Song (cuenta atrás) |
| 13 | Yawn → Sleep |
| 5 | Encore / Taunt / Disable / Torment (decremento) |

Field/Weather/Side se procesan antes que efectos por Pokémon (`effect_source`).

## Field effects (screens + hazards)

Matriz de stacking, fases, reaplicación y orden de entrada: ver [`field-effects.md`](field-effects.md) (PBI 704).

## Limpieza

| Evento | Comportamiento |
|--------|----------------|
| Switch out | `clear_pokemon_effects` (SwitchEffect) |
| KO | `clear_pokemon_effects` (BattleTurnController) |
| Inflictor sale/KO | Trap, Infatuation terminan (`_should_end`) |
| Fin combate | `BattleEffectController.cleanup()` |

## Excepciones documentadas

- **Substitute**: pipeline de daño (`ON_INCOMING_DAMAGE_*`, payload en `ctx.damage`) y `ON_VALIDATE_AILMENT`; no participa en restricción de movimientos.
- **Perish Song**: mensajes vía `BattleMessageAilment.get_perish_song_tick_message()`.
- **BattlePhaseContext**: subcontextos opcionales (`validation`, `damage`, `ailment`, `stat_change`, `choice`); ver factories en `BattlePhaseContext.gd`.

## Casos QA (TestBattle)

Ver `_print_volatile_integration_guide()` en `TestBattle.gd`.
