# Guía de Configuración de Sombra para Saltos (Ledges)

## 📋 Resumen

El sistema de ledges ya está preparado para mostrar una sombra circular debajo del sprite del jugador durante los saltos, como en los juegos de Pokémon originales.

## 🎯 Configuración en el Editor

### 1. Abrir la Escena del Player

Abre `Scenes/Overworld/Actors/Player.tscn`

### 2. Añadir Nodo Shadow

1. Selecciona el nodo `Player` (raíz)
2. Añade un nodo hijo de tipo `Sprite2D`
3. Renómbralo a **`Shadow`** (exactamente así)

### 3. Configurar Propiedades del Shadow

```
Shadow (Sprite2D)
├─ Texture: [sprite de sombra - ver abajo]
├─ Visible: false ← IMPORTANTE: inicialmente oculto
├─ Position: (0, 0)
├─ Centered: true
├─ Z Index: -1 ← Para que esté debajo del sprite
└─ Modulate: Color(1, 1, 1, 0.5) ← Semi-transparente (opcional)
```

**IMPORTANTE**: El nodo debe llamarse exactamente `Shadow` para que el código lo encuentre.

---

## 🎨 Obtener el Sprite de Sombra

### Opción 1: Pokémon Essentials

El sprite de sombra en Pokémon Essentials suele estar en:

```
Graphics/
├─ Characters/shadow.png
├─ Pictures/shadow.png
└─ UI/shadow.png
```

**Características**:
- Círculo negro difuminado
- Tamaño típico: 32x32 píxeles
- Formato: PNG con transparencia

### Opción 2: Crear tu Propia Sombra

Si no encuentras el sprite, puedes crear uno simple:

**En GIMP/Photoshop**:
1. Nuevo archivo 32x32 píxeles
2. Crear capa transparente
3. Dibujar círculo negro centrado (20-24px de diámetro)
4. Aplicar Blur/Desenfoque (radio 3-5px)
5. Reducir opacidad a ~50-70%
6. Guardar como PNG con transparencia

**Ejemplo visual**:
```
  ████████
 ██████████
████████████  ← Círculo negro difuminado
████████████
 ██████████
  ████████
```

---

## 🔧 Cómo Funciona (Código)

El código ya está implementado en `GridMotion.gd`:

```gdscript
// Al inicio del salto
if actor.has_node("Shadow"):
    shadow_node.visible = true  // Mostrar sombra

// Durante el salto
// (La sombra permanece en el suelo mientras el sprite sube)

// Al finalizar el salto
shadow_node.visible = false  // Ocultar sombra
```

### Flujo:

```
1. Jugador intenta saltar
   ↓
2. Sistema detecta nodo "Shadow"
   ↓
3. Muestra sombra (visible = true)
   ↓
4. Sprite sube y baja (offset.y)
   Sombra permanece en el suelo
   ↓
5. Salto termina
   ↓
6. Oculta sombra (visible = false)
```

---

## 🎮 Resultado Visual

**Sin sombra**:
```
     🚶  ← Sprite en el aire
   -------
```

**Con sombra**:
```
     🚶  ← Sprite en el aire

     ●   ← Sombra en el suelo
   -------
```

---

## ✨ Mejora Opcional: Sombra Dinámica

Si quieres que la sombra cambie de tamaño según la altura (más pequeña cuando el jugador está más alto), puedes activar la animación dinámica.

**Edita `GridMotion.gd` y añade después de mostrar la sombra**:

```gdscript
# Animar el tamaño de la sombra según la altura del salto
if shadow_node:
    shadow_node.visible = true

    # Reducir tamaño cuando sube (primera mitad)
    active_tween.tween_property(shadow_node, "scale", Vector2(0.7, 0.7), ledge_jump_duration / 2.0)\
        .set_ease(Tween.EASE_OUT)\
        .set_trans(Tween.TRANS_QUAD)

    # Volver a tamaño normal cuando baja (segunda mitad)
    active_tween.tween_property(shadow_node, "scale", Vector2(1.0, 1.0), ledge_jump_duration / 2.0)\
        .set_delay(ledge_jump_duration / 2.0)\
        .set_ease(Tween.EASE_IN)\
        .set_trans(Tween.TRANS_QUAD)
```

Esto hará que la sombra:
- Se encoja cuando el jugador sube (más alto = sombra más pequeña)
- Crezca cuando el jugador baja (más cerca del suelo = sombra más grande)

---

## 🧪 Testing

Para probar que funciona:

1. Configura un ledge en tu mapa
2. Añade el nodo Shadow con el sprite en el Player
3. Salta el ledge
4. Deberías ver:
   - ✅ La sombra aparece al inicio del salto
   - ✅ La sombra permanece en el suelo mientras el sprite sube
   - ✅ La sombra desaparece al finalizar el salto

---

## 🐛 Troubleshooting

### La sombra no aparece

**Causas**:
- El nodo no se llama exactamente `Shadow`
- El nodo no es hijo directo de `Player`
- La textura no está asignada
- Visible está en true inicialmente (debería ser false)

**Solución**: Verifica la jerarquía y el nombre del nodo.

### La sombra se mueve con el sprite

**Causa**: Esto no debería pasar, la sombra está en Position (0,0) del Player, no usa offset.

**Solución**: Verifica que el Shadow sea Sprite2D, no AnimatedSprite2D, y que Position sea (0, 0).

### La sombra está sobre el sprite

**Causa**: Z Index incorrecto

**Solución**: Establece Z Index del Shadow a -1 (negativo)

---

## 📚 Documentación Relacionada

- `LEDGES_SYSTEM_README.md` - Documentación completa del sistema de ledges
- `Scripts/Overworld/Core/GridMotion.gd` - Código de implementación

---

## 🎉 Resultado Final

Con la sombra configurada, tus saltos se verán exactamente como en los juegos de Pokémon originales:

```
Frame 1 (inicio):        Frame 2 (mitad):        Frame 3 (final):

  🚶  ● (sombra)             🚶 (en el aire)         🚶  (aterriza)
 ─────                          ● (sombra)           ─────
                             ─────
```

¡Disfruta de tus saltos con sombra! 🌟

