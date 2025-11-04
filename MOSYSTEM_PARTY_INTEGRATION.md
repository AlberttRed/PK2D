# MOSystem - Integración con Sistema de Party

## ✅ Verificación de Movimientos Implementada

Se ha implementado la verificación de si el jugador tiene un Pokémon con el movimiento necesario.

---

## 🎯 Funcionalidad Implementada

### 1. **can_use() Verifica el Party**

```gdscript
func can_use(player, target):
    // 1. Target válido
    if not target:
        return false

    // 2. Verificar que tiene Pokémon con CORTE ✅ NUEVO
    var pokemon_with_cut = _find_pokemon_with_move("CUT")
    if not pokemon_with_cut:
        print("Ningún Pokémon conoce CORTE")
        return false

    print("%s conoce CORTE" % pokemon_with_cut.get_display_name())

    // 3. TODO FUTURO: Verificar medalla

    return true
```

---

### 2. **_find_pokemon_with_move() - Busca en el Party**

```gdscript
func _find_pokemon_with_move(move_name: String) -> Pokemon:
    var party = _get_player_party()

    // Buscar en cada Pokémon del equipo
    for pokemon in party:
        for move in pokemon.movements:
            if move.base.name.to_upper() == move_name.to_upper():
                return pokemon  // ← Retorna el Pokémon que lo tiene

    return null  // Ninguno tiene el movimiento
```

---

### 3. **Mensaje con Nombre del Pokémon**

```gdscript
func execute(player, target, context):
    // Obtener el Pokémon que tiene CORTE
    var pokemon_with_cut = _find_pokemon_with_move("CUT")
    var pokemon_name = pokemon_with_cut.get_display_name()

    // ...choice...

    // Mensaje personalizado
    await gui.show_message("¡%s usó CORTE!" % pokemon_name)
    //                       ↑ Nombre del Pokémon
```

---

## 🎮 Resultado en Juego

### Si tiene un Charizard con CORTE:

```
"¡Un árbol pequeño bloquea el camino!"
[Presiona botón]

"¿Usar CORTE?"
[Elige Sí]

"¡CHARIZARD usó CORTE!"  ← Nombre del Pokémon
[Animación de corte]
[Árbol desaparece]
```

### Si NO tiene ningún Pokémon con CORTE:

```
"¡Un árbol pequeño bloquea el camino!"
[Presiona botón]

"¿Usar CORTE?"
[Elige Sí]

[No pasa nada - can_use() retorna false]
[MOSystem emite mo_failed]
```

---

## 🔧 Integración con Sistema de Party

### Implementación Actual (Temporal)

```gdscript
func _get_player_party() -> Array[Pokemon]:
    // Buscar PlayerBattler en el árbol
    var player_battler = get_tree().get_first_node_in_group("PlayerBattler")
    if player_battler:
        return player_battler.party

    // Fallback: array vacío
    return []
```

### Implementación Futura (Cuando exista PlayerParty)

```gdscript
func _get_player_party() -> Array[Pokemon]:
    // Usar autoload o singleton
    return PlayerParty.get_party()

    // O desde GameStateManager
    return GameStateManager.get_player_party()
```

---

## 📊 Flujo Completo

```
Jugador presiona ACTION frente al árbol
   ↓
UseMOCommand → MOSystem
   ↓
MOSystem llama can_use()
   ↓
CutAction.can_use():
   ├─ _get_player_party() → Array[Pokemon]
   ├─ _find_pokemon_with_move("CUT") → Pokemon
   ├─ Si null → return false (no tiene CORTE)
   └─ Si encontrado → return true
   ↓
Si can_use() = false:
   └─ mo_finished(false, "No puede usar CORTE")
   ↓
Si can_use() = true:
   ├─ MOSystem llama execute()
   ├─ CutAction.execute():
   │  ├─ Obtiene pokemon_with_cut
   │  ├─ pokemon_name = pokemon.get_display_name()
   │  ├─ Muestra: "¡POKEMON_NAME usó CORTE!"
   │  └─ Reproduce animación
   └─ mo_finished(true, "")
```

---

## ✅ Implementado

- ✅ Verificación de movimiento en party
- ✅ Búsqueda del Pokémon con el movimiento
- ✅ Uso del nombre del Pokémon en mensaje
- ✅ Fallback si no se encuentra party
- ✅ Logs informativos

---

## 📋 TODOs Futuros

### 1. Sistema de Party Global

Cuando se implemente PlayerParty:

```gdscript
// En MOAction.gd (método auxiliar base)
func get_player_party() -> Array[Pokemon]:
    return PlayerParty.get_party()
```

### 2. Sistema de Medallas

```gdscript
func can_use(player, target):
    // Verificar Pokémon con CORTE ✅

    // Verificar medalla necesaria
    if not PlayerBadges.has_badge("CASCADE_BADGE"):
        return false

    return true
```

---

## 🎊 Resultado

El sistema ahora:
- ✅ Verifica que el jugador tenga un Pokémon con CORTE
- ✅ Usa el nombre del Pokémon en el mensaje
- ✅ Falla correctamente si no tiene el movimiento
- ✅ Preparado para integración con sistema de party real

**Más realista y fiel a Pokémon.** 🎮

