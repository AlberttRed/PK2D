# Primeros pasos

## Requisitos

- Godot **4.7** (ver `project.godot`)
- Python 3 + pip (solo para la documentación)

## Abrir el proyecto

1. Abre la carpeta del repo en Godot.
2. Escena principal: `Scenes/Main.tscn`.
3. Plugins de editor habilitados:
   - `addons/database_editor`
   - `addons/event_tools`

## Documentación local

Usa un entorno virtual (recomendado en Linux modernos):

```bash
# Una vez: crear venv e instalar dependencias
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r requirements-docs.txt

# Servidor con recarga en caliente
mkdocs serve
```

Por defecto: [http://127.0.0.1:8000](http://127.0.0.1:8000).

Para generar el sitio estático:

```bash
mkdocs build
```

La salida va a `site/` (ignorada por git). Añade `.venv-docs/` al `.gitignore` local si aún no está.

## Dónde está el código relevante

| Área | Ruta |
| --- | --- |
| Scripts de juego | `Scripts/` |
| Escenas | `Scenes/` |
| Recursos de datos | `Resources/` |
| Servicios / estado | `Services/`, `Scripts/AutoLoads/` |
| Addons de editor | `addons/` |
