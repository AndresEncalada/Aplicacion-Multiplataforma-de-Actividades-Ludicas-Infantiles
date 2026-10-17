# Felpudo — Frontend

Aplicación Godot 4 para tablet táctil (landscape). Interfaz diseñada para niños de 3 años: sin texto obligatorio, paleta lúdica, botones de mínimo 96×96 px con efecto 3D gomoso, animaciones elásticas y debounce de 400 ms.

Requiere el [backend](../backend/README.md) corriendo para funcionar.

---

## Abrir el proyecto

1. Instala [Godot 4.x](https://godotengine.org/)
2. **Import** → selecciona esta carpeta (`frontend/felpudo/`) → abre `project.godot`
3. Godot generará `.godot/` (caché del editor) — es normal, está gitignoreado

---

## Configurar la IP del servidor

Edita una sola línea en [`config.gd`](felpudo/config.gd):

```gdscript
const SERVER_HOST := "127.0.0.1:8000"   # mismo equipo
# const SERVER_HOST := "192.168.1.42:8000"  # Raspberry Pi en red local
```

Todas las URLs (WebSocket + HTTP) se derivan de esta constante automáticamente.

---

## Ejecutar

- **Editor:** F5
- **Tablet:** Project → Export → selecciona plataforma → configura `SERVER_HOST` antes de exportar

---

## Escenas

| Escena | Descripción |
|--------|-------------|
| `menu_principal` | Pantalla de inicio, bear mascota, acceso a actividades |
| `menu_actividades` | Selección entre las dos actividades |
| `actividad_cuerpo` | Feed de cámara + instrucciones de movimiento (WebSocket `/ws`) |
| `actividad_pictogramas` | Escaneo de pictogramas + Q&A por voz (WebSocket `/ws_pictogramas`) |

→ Documentación completa en [`docs/frontend.md`](../docs/frontend.md)

---

## Autoloads

- **`Config`** (`config.gd`) — constantes de red; cargado primero
- **`AnimManager`** (`anim_manager.gd`) — toggle global de animaciones
