# Guía Visual de Máscaras Direccionales (entry_mask y exit_mask)

## 🎯 Conceptos Básicos

Las máscaras direccionales son números que indican **desde qué direcciones se puede entrar o salir** de un tile.

### Valores Base (Flags)
```
UP    = 1  (binario: 0001)
RIGHT = 2  (binario: 0010)
DOWN  = 4  (binario: 0100)
LEFT  = 8  (binario: 1000)
```

Para combinar direcciones, **sumas los valores**:
```
UP + DOWN = 1 + 4 = 5
LEFT + RIGHT = 8 + 2 = 10
UP + LEFT + RIGHT = 1 + 8 + 2 = 11
```

---

## 📊 Tabla de Referencia Rápida

| Direcciones Permitidas | Valor | Cálculo | Uso Común |
|------------------------|-------|---------|-----------|
| Ninguna | 0 | 0 | Sin restricciones* |
| UP ↑ | 1 | 1 | - |
| RIGHT → | 2 | 2 | - |
| UP + RIGHT ↑→ | 3 | 1 + 2 | - |
| DOWN ↓ | 4 | 4 | - |
| UP + DOWN ↑↓ | 5 | 1 + 4 | - |
| RIGHT + DOWN →↓ | 6 | 2 + 4 | - |
| UP + RIGHT + DOWN ↑→↓ | 7 | 1 + 2 + 4 | **Ledge hacia abajo** |
| LEFT ← | 8 | 8 | - |
| UP + LEFT ↑← | 9 | 1 + 8 | - |
| LEFT + RIGHT ←→ | 10 | 8 + 2 | - |
| UP + LEFT + RIGHT ↑←→ | 11 | 1 + 8 + 2 | **Ledge hacia arriba** |
| LEFT + DOWN ←↓ | 12 | 8 + 4 | - |
| UP + LEFT + DOWN ↑←↓ | 13 | 1 + 8 + 4 | **Ledge hacia derecha** |
| LEFT + RIGHT + DOWN ←→↓ | 14 | 8 + 2 + 4 | **Ledge hacia izquierda** |
| Todas (UP+RIGHT+DOWN+LEFT) | 15 | 1+2+4+8 | Permitir todas |

\* **Importante**: `0` significa "sin restricciones" = permitir todas las direcciones

---

## 🪜 LEDGES: Configuración Paso a Paso

### Regla de Oro para Ledges
> **Para un ledge, el `entry_mask` debe permitir todas las direcciones EXCEPTO la dirección del salto**

---

### 🔽 Ledge hacia ABAJO (el más común)

**Configuración del tile:**
```
ledge_direction: "down"
entry_mask: 7
```

**Visualización:**
```
     [Tile normal]
          ↓ ✅ Puede entrar desde arriba
     [LEDGE ⬇]
          ↓ ❌ NO puede entrar desde abajo
     [Tile normal]
```

**Explicación:**
- `entry_mask = 7` = UP + RIGHT + LEFT (1 + 2 + 4)
- Permite entrada desde: ↑ arriba, → derecha, ← izquierda
- **Bloquea** entrada desde: ↓ abajo
- Cuando el jugador está en el ledge y presiona ↓, salta automáticamente

**Cómo calcularlo:**
```
Direcciones permitidas: UP + RIGHT + LEFT
UP = 1
RIGHT = 2
LEFT = 8
Total: 1 + 2 + 8 = 11

¡ERROR! El correcto es:
UP = 1
DOWN = 4
LEFT = 8
Total: 1 + 4 + 8 = 13

¡NO! Pensémoslo de nuevo:
Queremos BLOQUEAR entrada desde ABAJO
Entonces permitimos: UP, LEFT, RIGHT
UP = 1
LEFT = 8
RIGHT = 2
Total: 1 + 8 + 2 = 11
```

**CORRECCIÓN:**
```
entry_mask: 11  (UP + LEFT + RIGHT = 1 + 8 + 2)
```

---

### 🔼 Ledge hacia ARRIBA

**Configuración del tile:**
```
ledge_direction: "up"
entry_mask: 14
```

**Visualización:**
```
     [Tile normal]
          ↑ ❌ NO puede entrar desde arriba
     [LEDGE ⬆]
          ↑ ✅ Puede entrar desde abajo
     [Tile normal]
```

**Explicación:**
- `entry_mask = 14` = DOWN + RIGHT + LEFT (4 + 2 + 8)
- Permite entrada desde: ↓ abajo, → derecha, ← izquierda
- **Bloquea** entrada desde: ↑ arriba

---

### ➡️ Ledge hacia la DERECHA

**Configuración del tile:**
```
ledge_direction: "right"
entry_mask: 13
```

**Visualización:**
```
[Tile normal] ← ✅ → [LEDGE ⮕] ← ❌ → [Tile normal]
```

**Explicación:**
- `entry_mask = 13` = UP + DOWN + LEFT (1 + 4 + 8)
- Permite entrada desde: ↑ arriba, ↓ abajo, ← izquierda
- **Bloquea** entrada desde: → derecha

---

### ⬅️ Ledge hacia la IZQUIERDA

**Configuración del tile:**
```
ledge_direction: "left"
entry_mask: 7
```

**Visualización:**
```
[Tile normal] ← ❌ ← [LEDGE ⬅] ← ✅ [Tile normal]
```

**Explicación:**
- `entry_mask = 7` = UP + DOWN + RIGHT (1 + 4 + 2)
- Permite entrada desde: ↑ arriba, ↓ abajo, → derecha
- **Bloquea** entrada desde: ← izquierda

---

## 🎓 Tabla de Ledges (Referencia Rápida)

| Tipo de Ledge | `ledge_direction` | `entry_mask` | Cálculo | Bloquea entrada desde |
|---------------|-------------------|--------------|---------|----------------------|
| Salta hacia ABAJO ⬇ | `"down"` | **11** | 1+8+2 | ↓ Abajo |
| Salta hacia ARRIBA ⬆ | `"up"` | **14** | 4+8+2 | ↑ Arriba |
| Salta hacia DERECHA ⮕ | `"right"` | **13** | 1+4+8 | → Derecha |
| Salta hacia IZQUIERDA ⬅ | `"left"` | **7** | 1+4+2 | ← Izquierda |

---

## 🧮 Cómo Calcular el entry_mask

### Método 1: Suma Directa (Recomendado)

**Paso 1**: Identifica la dirección del ledge
**Paso 2**: Suma TODAS las direcciones EXCEPTO la dirección del salto

**Ejemplo para ledge hacia ABAJO:**
```
Direcciones disponibles: UP(1), RIGHT(2), DOWN(4), LEFT(8)
Dirección del salto: DOWN(4)
Direcciones a permitir: UP(1) + RIGHT(2) + LEFT(8) = 11
```

### Método 2: Resta (Alternativo)

**Paso 1**: Empieza con 15 (todas las direcciones)
**Paso 2**: Resta la dirección que quieres bloquear

**Ejemplo para ledge hacia ABAJO:**
```
Todas las direcciones: 15
Bloquear DOWN: 15 - 4 = 11
```

---

## 🎯 Ejemplos Prácticos

### Ejemplo 1: Acantilado Clásico

**Escenario**: Acantilado de 3 tiles de altura
```
[Grass]  ←  Tile normal (sin restricciones)
[Ledge1] ←  Ledge hacia abajo (entry_mask: 11)
[Ledge2] ←  Ledge hacia abajo (entry_mask: 11)
[Ledge3] ←  Ledge hacia abajo (entry_mask: 11)
[Grass]  ←  Tile normal (sin restricciones)
```

**Comportamiento**:
- Jugador puede saltar de [Grass] → [Ledge1] → [Ledge2] → [Ledge3] → [Grass]
- Jugador NO puede subir de [Grass] → [Ledge3] (bloqueado por entry_mask)

### Ejemplo 2: Plataforma con Acceso Lateral

**Escenario**: Plataforma elevada con escaleras a los lados
```
            [Ledge ⬇]
           entry_mask: 11
                ↓
[Escalera] [Grass] [Escalera]
```

**Configuración**:
- Ledge: `ledge_direction: "down"`, `entry_mask: 11`
- Jugador puede entrar desde los lados (escaleras) ← →
- Jugador puede entrar desde arriba ↑
- Jugador NO puede subir desde abajo ↓

---

## ❓ Preguntas Frecuentes

### ¿Por qué 0 significa "sin restricciones"?
En lógica de bits, 0 es un valor especial que indica "no hay máscara". El código lo interpreta como "permitir todo".

### ¿Qué pasa si uso entry_mask: 15?
`15 = 1+2+4+8` = todas las direcciones permitidas. Es equivalente a no tener restricciones (pero usa 0 para ser más claro).

### ¿Necesito configurar exit_mask también?
**Para ledges NO**. Solo necesitas `entry_mask` para bloquear la subida. El sistema de salto ya maneja la salida automáticamente.

### ¿Puedo combinar ledges con otros sistemas?
**Sí**, el sistema de ledges se integra con:
- Restricciones direccionales (PBI 454)
- Sistema de eventos
- Colisiones normales

---

## 🔧 Configuración en Godot

### Paso 1: Añadir Custom Data Layers al TileSet

1. Abre tu TileSet
2. Ve a "Custom Data Layers"
3. Añade:
   - `ledge_direction` (tipo: String)
   - `entry_mask` (tipo: int)

### Paso 2: Configurar un Tile Individual

1. Selecciona el tile en el TileSet
2. En "Custom Data":
   - `ledge_direction`: Escribe "down" (o "up", "left", "right")
   - `entry_mask`: Escribe el número (ej: 11 para ledge hacia abajo)

### Paso 3: ¡Listo para Usar!

Coloca el tile en tu mapa y el jugador podrá saltar automáticamente.

---

## 📋 Hoja de Cálculo Rápida

**Para calcular tu propio entry_mask:**

1. Marca las direcciones que quieres **PERMITIR**:
   ```
   [ ] UP (1)
   [ ] RIGHT (2)
   [ ] DOWN (4)
   [ ] LEFT (8)
   ```

2. Suma los números marcados:
   ```
   Total = _____
   ```

3. Ese es tu `entry_mask`!

**Ejemplo**: Quiero permitir UP, LEFT y RIGHT:
```
[✓] UP (1)
[✓] RIGHT (2)
[ ] DOWN (4)  ← NO permitir (es el ledge hacia abajo)
[✓] LEFT (8)

Total = 1 + 2 + 8 = 11
```

---

## 🎨 Herramienta Visual

Si prefieres una herramienta visual, aquí tienes una tabla para marcar:

```
┌─────────────────────────────────────┐
│   Calculadora de entry_mask         │
├─────────────────────────────────────┤
│                                     │
│            UP (1)                   │
│              ↑                      │
│              │                      │
│   LEFT (8) ←─┼─→ RIGHT (2)         │
│              │                      │
│              ↓                      │
│           DOWN (4)                  │
│                                     │
│  Marca las direcciones PERMITIDAS:  │
│  [ ] UP = 1                         │
│  [ ] RIGHT = 2                      │
│  [ ] DOWN = 4                       │
│  [ ] LEFT = 8                       │
│                                     │
│  TOTAL: _____                       │
└─────────────────────────────────────┘
```

---

## 📝 Resumen Final

**Para Ledges, solo recuerda:**

| Salto hacia | entry_mask | Regla Nemotécnica |
|-------------|------------|-------------------|
| ⬇ ABAJO | **11** | "Once para bajar" |
| ⬆ ARRIBA | **14** | "Catorce para subir" |
| ⮕ DERECHA | **13** | "Trece a la derecha" |
| ⬅ IZQUIERDA | **7** | "Siete a la izquierda" |

¡Con esta guía ya puedes configurar cualquier ledge fácilmente! 🎉

