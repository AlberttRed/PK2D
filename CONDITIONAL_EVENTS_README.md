# Sistema de Eventos Condicionales (PBI-286)

## Descripción

Sistema de eventos reactivo que permite que las EventPages se activen o desactiven automáticamente según condiciones del juego (flags, variables, self-switches).

Inspirado en RPG Maker, los eventos pueden cambiar dinámicamente su comportamiento sin necesidad de código manual.

## Componentes Modificados

### 1. **EventPage** - Condiciones por página
Cada página puede tener condiciones que deben cumplirse para activarse:
- `required_flag`: Nombre del flag global
- `required_flag_value`: Valor esperado (true/false)
- `required_variable`: Nombre de variable global
- `variable_operator`: Comparación (==, !=, >, <, >=, <=)
- `variable_value`: Valor esperado
- `required_self_switch`: Self-switch local (A, B, C, D)
- `required_self_switch_value`: Valor esperado (true/false)
- `invert_conditions`: Invertir resultado (NOT)

### 2. **GameStateManager** - Estado ampliado
Ahora gestiona:
- `event_flags`: Flags globales (ya existía)
- `game_variables`: Variables globales (NUEVO)
- `self_switches`: Self-switches por evento (NUEVO)

Emite señales cuando cambian:
- `flag_changed(flag_name, new_value)`
- `variable_changed(variable_name, new_value)`
- `self_switch_changed(event_id, switch_letter, new_value)`

### 3. **SignalManager** - Reenvío de señales
Reenvía las señales de GameStateManager globalmente:
- `game_flag_changed`
- `game_variable_changed`
- `game_self_switch_changed`

### 4. **Event** - Sistema reactivo
Los eventos se suscriben automáticamente a las señales y reevalúan su página activa cuando cambian las condiciones relevantes.

## Nuevos Comandos

### SetVariableCommand
Establece o modifica variables globales:
```gdscript
SetVariableCommand {
  variable_name = "player_money",
  operation = Add,  // Set, Add, Subtract, Multiply, Divide, Modulo
  value = 500
}
```

### SetSelfSwitchCommand
Establece self-switches locales del evento:
```gdscript
SetSelfSwitchCommand {
  switch_letter = A,  // A, B, C, D
  switch_value = true
}
```

### SetFlagCommand (mejorado)
Ahora emite señales automáticamente cuando cambia un flag.

## Ejemplo de Uso: Trainer con 2 páginas

### Configuración del Trainer:

```
Trainer "Jano":
  defeated_flag = "route_1_jano_defeated"
  
  pages[0] (Página de batalla):
    Trainer Detection:
      enable_trainer_detection = true  // Activa detección automática
      detection_range = 5
    
    Conditions:
      required_flag = "route_1_jano_defeated"
      required_flag_value = false  // Solo si NO está derrotado
    
    commands = [
      StartBattleEventCommand {
        battle_type = TRAINER,
        trainer_data = preload("res://Resources/Trainers/jano.tres")
        // defeated_flag vacío = usa el del Trainer automáticamente
        // intro_text se toma automáticamente del TrainerData
      }
    ]
  
  pages[1] (Página post-derrota):
    Trainer Detection:
      enable_trainer_detection = false  // NO detecta (ya derrotado)
    
    Conditions:
      required_flag = "route_1_jano_defeated"
      required_flag_value = true  // Solo si YA está derrotado
    
    trigger_type = ACTION
    commands = [
      ShowMessageCommand { message = "Mis bichos necesitan entrenar más..." }
    ]
```

## Flujo Automático:

```
1. Inicialmente: flag "route_1_jano_defeated" = false
   → Event evalúa condiciones
   → pages[0] cumple condiciones (required_flag=false)
   → Página activa = pages[0] (batalla)
   → Trainer._update_detection_state() activa detección (enable_trainer_detection=true)

2. Jugador entra en rango → Trainer detecta → Exclamación → Aproximación → trigger()
   → Ejecuta comandos de pages[0]
   → Muestra mensaje + StartBattleEventCommand inicia batalla

3. Jugador gana → StartBattleEventCommand:
   → battler.is_defeated = true
   → GameStateManager.set_event_flag("route_1_jano_defeated", true)
   → Emite señal: flag_changed("route_1_jano_defeated", true)
   → SignalManager reenvía: game_flag_changed(...)
   → Event escucha la señal

4. Event.refresh_active_page():
   → Reevalúa todas las páginas
   → pages[0] YA NO cumple (required_flag=false pero flag=true)
   → pages[1] SÍ cumple (required_flag=true y flag=true)
   → Página activa = pages[1] (post-derrota)
   → Trainer.refresh_active_page() llama _update_detection_state()
   → Detección DESACTIVADA (enable_trainer_detection=false en pages[1])

5. Siguiente interacción:
   → NO detecta automáticamente (detección desactivada)
   → Jugador interactúa manualmente (ACTION)
   → Muestra mensaje de derrota
   → NO inicia batalla
```

## Prioridad de Páginas

Las páginas se evalúan en **orden inverso** (última a primera).

Esto permite:
- **Página 0**: Condiciones vacías (página por defecto)
- **Página 1**: Condiciones específicas (se prioriza si se cumple)
- **Página 2**: Condiciones más específicas (máxima prioridad)

Si varias páginas cumplen condiciones, se activa la de **mayor índice**.

## Self-Switches

Los self-switches son **locales al evento**:

```gdscript
// Event "Cofre"
pages[0]:
  commands = [
    ShowMessageCommand { message = "¡Encontraste una Poción!" },
    SetSelfSwitchCommand { switch_letter = A, switch_value = true }
  ]

pages[1]:
  required_self_switch = A  // A = 1
  required_self_switch_value = true
  commands = [
    ShowMessageCommand { message = "El cofre está vacío." }
  ]
```

**Flujo:**
1. Primera interacción: Se ejecuta pages[0], activa switch A
2. Switch A cambia → Event se reevalúa
3. pages[1] cumple condiciones (switch A = true)
4. Siguiente interacción: Se ejecuta pages[1] (cofre vacío)

## Variables Globales

Las variables permiten tracking numérico:

```gdscript
// Contador de batallas ganadas
SetVariableCommand {
  variable_name = "battles_won",
  operation = Add,
  value = 1
}

// Página que solo aparece tras 10 batallas
EventPage:
  required_variable = "battles_won"
  variable_operator = >=  // 4 en enum
  variable_value = 10
```

## Criterios de Aceptación (PBI-286)

✅ Cada EventPage incluye propiedades condicionales (flag, variable, self-switch, invert)  
✅ Event determina automáticamente su página activa evaluando condiciones  
✅ GameState emite señales cuando cambian flags/variables/self-switches  
✅ SignalManager reenvía las señales globalmente  
✅ Events se actualizan automáticamente cuando cambian condiciones relevantes  
✅ Comandos implementados: SetVariableCommand, SetSelfSwitchCommand, SetFlagCommand (mejorado)  
✅ El cambio de página actualiza sprite, trigger y bloqueos automáticamente  
✅ Sin reevaluación por frame (solo cuando cambian condiciones)  
✅ Compatible con el sistema actual de EventSystem y EventController  

## Archivos Modificados

- `Scripts/Events/EventPage.gd` - Condiciones y evaluación
- `Scripts/Events/Event.gd` - Sistema reactivo y reevaluación
- `Scripts/AutoLoads/GameStateManager.gd` - Variables, self-switches y señales
- `Scripts/AutoLoads/SignalManager.gd` - Reenvío de señales
- `Scripts/Events/Commands/SetVariableCommand.gd` - NUEVO
- `Scripts/Events/Commands/SetSelfSwitchCommand.gd` - NUEVO
- `Scripts/Events/Commands/SetFlagCommand.gd` - Actualizado (ya emitía señales)

## Ver También

- `Scripts/Events/Commands/StartBattleEventCommand_README.md` - Sistema de batallas
- `TRAINER_SYSTEM_README.md` - Sistema de trainers

