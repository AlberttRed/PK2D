# Resumen de Funcionalidades - Database Editor

## 📋 Índice
1. [Database Editor (Ventana Central)](#1-database-editor-ventana-central)
2. [Ventana de Edición de Pokémon](#2-ventana-de-edición-de-pokémon)
3. [Ventana de Edición de Movimientos](#3-ventana-de-edición-de-movimientos)
4. [Ventana de Edición de Items](#4-ventana-de-edición-de-items)
5. [Operaciones CRUD desde Database Editor](#5-operaciones-crud-desde-database-editor)
6. [Selector (Picker) de Recursos](#6-selector-picker-de-recursos)

---

## 1. Database Editor (Ventana Central)

### Funcionalidades principales
- **Ventana principal** con sistema de pestañas para gestionar diferentes tipos de recursos
- **Interfaz con pestañas** para navegar entre:
  - Pokémon
  - Movimientos
  - Items
- **Búsqueda y filtrado** en tiempo real para cada tipo de recurso
- **Vista de lista** con información resumida de cada recurso
- **Panel de detalles** que muestra información completa del recurso seleccionado
- **Carga diferida** de recursos: solo carga la pestaña activa para optimizar rendimiento
- **Modo normal y modo picker**: puede funcionar como editor completo o como selector de recursos

### Características técnicas
- Sistema de carga optimizado que evita cargar subrecursos innecesarios
- Uso de IDs en lugar de referencias directas a recursos para mejorar rendimiento
- Compatibilidad hacia atrás con recursos antiguos que usan referencias directas
- Integración con el sistema de archivos del proyecto

---

## 2. Ventana de Edición de Pokémon

### Funcionalidades principales
- **Edición completa de PokemonData** con múltiples pestañas organizadas:
  - **General**: ID, nombre interno, nombre de visualización, descripción, tipos
  - **Base Stats y EVs**: Estadísticas base y puntos de esfuerzo
  - **Aprendizaje de Movimientos**: Configuración de movimientos aprendidos por nivel
  - **Evoluciones**: Configuración de condiciones y resultados de evolución
  - **Sprites**: Gestión de sprites frontales, traseros y animaciones
  - **Habilidades**: Asignación de habilidades disponibles
  - **Otros**: Configuraciones adicionales (ratio de captura, ratio de experiencia, etc.)

### Características técnicas
- **Validación de datos** en tiempo real
- **Cálculos automáticos** de estadísticas totales
- **Gestión de archivos**: guardado automático con nombres basados en ID y nombre
- **Detección de cambios sin guardar** con confirmación antes de cerrar
- **Soporte para tipos duales** (tipo A y tipo B)
- **Sistema de migración** automática de referencias antiguas a IDs

---

## 3. Ventana de Edición de Movimientos

### Funcionalidades principales
- **Edición completa de MoveData** con todas las propiedades:
  - Información básica: ID, nombre, descripción, tipo
  - Estadísticas de combate: poder, precisión, prioridad, PP
  - Clase de daño: físico, especial o estado
  - Efectos secundarios: ailments, cambios de estadísticas, drenaje, curación
  - Condiciones meteorológicas
  - Categoría y meta-información del movimiento

### Características técnicas
- **Selector de tipos** con carga optimizada usando IDs
- **Validación de rangos** para estadísticas y probabilidades
- **Gestión de archivos** con formato estándar
- **Compatibilidad con recursos antiguos** que usan referencias directas
- **Detección de cambios sin guardar**

---

## 4. Ventana de Edición de Items

### Funcionalidades principales
- **Edición completa de ItemData** con todas las propiedades:
  - Información básica: ID, nombre interno, nombre de visualización, descripción
  - Tipo de item y categoría
  - Precio y disponibilidad en tiendas
  - Efectos del item: curación, cambios de estadísticas, etc.
  - Configuraciones de uso: consumible, apilable, etc.

### Características técnicas
- **Interfaz intuitiva** con campos organizados por categorías
- **Validación de datos** en tiempo real
- **Gestión de archivos** consistente con otros editores
- **Detección de cambios sin guardar**

---

## 5. Operaciones CRUD desde Database Editor

### Funcionalidades implementadas

#### Crear (Create)
- **Botón "Crear"** en cada pestaña del Database Editor
- Abre la ventana de edición correspondiente en modo creación
- Genera automáticamente un nuevo ID disponible
- Permite configurar todas las propiedades del recurso
- Guarda el nuevo recurso con formato estándar de archivo

#### Editar (Edit)
- **Botón "Editar"** en cada pestaña
- **Doble clic** en un recurso de la lista para editarlo
- Abre la ventana de edición con los datos actuales cargados
- Permite modificar todas las propiedades
- Guarda los cambios en el archivo original

#### Duplicar (Duplicate)
- **Botón "Duplicar"** en cada pestaña
- Crea una copia del recurso seleccionado
- Asigna automáticamente un nuevo ID
- Permite modificar el nombre y otras propiedades antes de guardar
- Guarda como un nuevo archivo independiente

#### Eliminar (Delete)
- **Botón "Eliminar"** en cada pestaña
- Muestra diálogo de confirmación antes de eliminar
- Elimina el archivo del sistema de archivos
- Actualiza automáticamente la lista de recursos
- Previene eliminación accidental con confirmación

### Características adicionales
- **Menú contextual** (clic derecho) en algunos recursos para acceso rápido
- **Actualización automática** de listas después de operaciones CRUD
- **Gestión de errores** con mensajes informativos
- **Validación de operaciones** antes de ejecutarlas

---

## 6. Selector (Picker) de Recursos

### Funcionalidades principales
- **Modo picker** del Database Editor que permite seleccionar recursos desde otros editores
- **API estática** (`ResourcePickerAPI`) para abrir el picker desde cualquier editor
- **Soporte para múltiples tipos** de recursos:
  - Pokémon
  - Movimientos
  - Items
  - (Extensible para futuros tipos como Trainers)

### Características del modo picker
- **Interfaz simplificada**: solo muestra la pestaña del tipo de recurso solicitado
- **Búsqueda y filtrado** disponibles para encontrar recursos rápidamente
- **Vista de detalles** del recurso seleccionado
- **Botones de acción**:
  - **Seleccionar**: confirma la selección y devuelve el resultado
  - **Cancelar**: cierra el picker sin seleccionar nada
- **Botones de edición ocultos**: en modo picker se ocultan los botones de crear/editar/eliminar/duplicar

### API y uso
- **Métodos estáticos** para abrir pickers específicos:
  - `ResourcePickerAPI.open_pokemon_picker()`
  - `ResourcePickerAPI.open_move_picker()`
  - `ResourcePickerAPI.open_item_picker()`
  - `ResourcePickerAPI.open_resource_picker()` (genérico)
- **Callbacks** para manejar selección y cancelación
- **Resultado estructurado** (`ResourcePickerResult`) con:
  - ID del recurso
  - Path del archivo
  - Nombre para mostrar
  - Tipo de recurso
  - Recurso completo (opcional)

### Integración
- **Integrado en Event Commands**: ejemplo implementado en `StartBattleEventCommandEditor`
- **Selección de Pokémon salvajes**: permite seleccionar Pokémon para combates salvajes
- **Arquitectura extensible**: fácil de añadir nuevos tipos de recursos

### Características técnicas
- **Funciona solo en editor**: no disponible en runtime
- **Gestión de instancias**: crea y destruye ventanas correctamente
- **Manejo de errores**: validación de recursos y callbacks
- **Preselección**: soporte para preseleccionar un recurso al abrir el picker

---

## 🎯 Optimizaciones Implementadas

### Reducción de recursos cargados
- **Uso de IDs en lugar de referencias directas** para evitar cargar subrecursos innecesarios
- **Carga diferida** de pestañas: solo carga recursos cuando se activa una pestaña
- **Carga bajo demanda** de recursos relacionados (tipos, ailments, etc.)
- **Migración automática** de recursos antiguos a formato optimizado

### Compatibilidad
- **Compatibilidad hacia atrás** con recursos que usan referencias directas
- **Detección automática** del formato de recurso (antiguo vs nuevo)
- **Migración transparente** sin pérdida de datos

---

## 📁 Estructura de Archivos

```
addons/database_editor/
├── database_editor.gd          # Ventana principal
├── database_editor.tscn         # Escena principal
├── pokemon_editor_window.gd     # Editor de Pokémon
├── pokemon_editor_window.tscn
├── move_editor_window.gd        # Editor de Movimientos
├── move_editor_window.tscn
├── item_editor_window.gd        # Editor de Items
├── item_editor_window.tscn
├── resource_picker_api.gd       # API del picker
├── resource_picker_result.gd   # Resultado del picker
├── pokemon_tab.gd              # Pestaña de Pokémon
├── move_tab.gd                 # Pestaña de Movimientos
├── item_tab.gd                 # Pestaña de Items
├── resource_tab.gd             # Clase base para pestañas
└── plugin.gd                     # Plugin del editor
```

---

## ✅ Criterios de Aceptación Cumplidos

- ✅ Ventana principal funcional con pestañas
- ✅ Editores completos para Pokémon, Movimientos e Items
- ✅ Operaciones CRUD (Crear, Editar, Duplicar, Eliminar) implementadas
- ✅ Selector (Picker) funcional e integrado
- ✅ Optimización de recursos cargados
- ✅ Compatibilidad con recursos antiguos
- ✅ Validación y manejo de errores
- ✅ Detección de cambios sin guardar
- ✅ Integración con Event Commands
- ✅ Arquitectura extensible para futuros tipos de recursos




