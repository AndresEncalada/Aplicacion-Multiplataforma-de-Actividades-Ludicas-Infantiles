# Frontend — Godot 4

## Estructura del proyecto

```
frontend/felpudo/
├── project.godot                  # Configuración del proyecto
├── config.gd                      # Autoload: constantes de red (SERVER_HOST)
├── anim_manager.gd                # Autoload: toggle de animaciones global
│
├── menu_principal.tscn / .gd      # Pantalla de inicio con bear mascota
├── menu_actividades.tscn / .gd    # Selección de actividad
├── actividad_cuerpo.tscn / .gd    # Actividad de reconocimiento corporal
├── actividad_pictogramas.tscn / .gd  # Actividad de pictogramas + Q&A
├── main.tscn / .gd                # (legacy, mantiene compatibilidad)
│
└── assets/
    ├── fuente/    # Kenney Future Narrow.ttf, Kenney Future.ttf
    ├── iconos/    # SVGs y PNGs de UI
    └── sonidos/   # OGG / WAV para feedback
```

---

## Configuración de red

Toda la configuración de red está centralizada en `config.gd`:

```gdscript
const SERVER_HOST := "127.0.0.1:8000"  # ← cambiar por la IP del servidor

const WS_CUERPO           := "ws://"  + SERVER_HOST + "/ws"
const WS_PICTOGRAMAS      := "ws://"  + SERVER_HOST + "/ws_pictogramas"
const HTTP_REINICIAR      := "http://" + SERVER_HOST + "/reiniciar"
const HTTP_LIBERAR_CAMARA := "http://" + SERVER_HOST + "/liberar_camara"
```

Para apuntar a una Raspberry Pi en la red local, cambia solo `SERVER_HOST`:
```gdscript
const SERVER_HOST := "192.168.1.42:8000"
```

---

## Autoloads

| Singleton | Archivo | Descripción |
|-----------|---------|-------------|
| `Config` | `config.gd` | Constantes de red; primera en cargarse |
| `AnimManager` | `anim_manager.gd` | Signal `changed(activo)` que activa/desactiva tweens en toda la app |

---

## Escenas

### `menu_principal`
UI procedural. Bear mascota con animación wobble. Un botón de acceso a actividades y un toggle para habilitar/deshabilitar animaciones (persiste en `AnimManager`).

### `menu_actividades`
Dos tarjetas: **Reconocimiento del Cuerpo** y **Preguntas** (pictogramas). Botón X de vuelta al menú principal.

### `actividad_cuerpo`
- Se conecta al WebSocket `/ws`
- Muestra feed de cámara en pantalla completa con overlay de barra de instrucción inferior
- Diálogo de bienvenida overlay con botón "¡Comenzar!"
- Animación de flash blanco + check verde al completar una actividad (`centro_cuerpo` del backend determina la posición exacta)
- Botón X: cierra WebSocket + llama `POST /reiniciar` + navega al menú

### `actividad_pictogramas`
- Se conecta al WebSocket `/ws_pictogramas`
- Tres estados visuales: pantalla inicial → popup de confirmación → pantalla de preguntas
- Botón de micrófono push-to-talk: `button_down` → `iniciar_grabacion`, `button_up` → `detener_grabacion`
- Botón X: cierra WebSocket + llama `POST /liberar_camara` + navega al menú

---

## Protocolo WebSocket en cliente

Los paquetes mixtos (JPEG + JSON) se distinguen por los magic bytes del JPEG:

```gdscript
var packet = websocket.get_packet()
if packet.size() > 2 and packet[0] == 0xFF and packet[1] == 0xD8:
    # Es un frame JPEG → actualizar TextureRect
else:
    # Es JSON → procesar evento del juego
```

El cliente reconecta automáticamente tras 3 segundos si el WebSocket se cierra inesperadamente.

---

## Diseño visual

Tokens de diseño definidos como constantes en cada script:

| Constante | Color | Uso |
|-----------|-------|-----|
| `NAVY` | `#14305F` | Fondo principal |
| `TURQUESA` | `#0DADB8` | Acciones primarias / confirmar |
| `MANDARINA` | `#FF8014` | Acciones secundarias / escanear |
| `AMBAR` | `#FAD114` | Temporizador, alertas |
| `CREMA` | `#FFF5DC` | Fondo de tarjetas |

Reglas de UI:
- Botones interactivos: mínimo 96 × 96 px
- Efecto 3D gomoso: `border_width_bottom = 8` + color oscurecido
- Debounce de 400 ms en todos los botones (`_btn_bloqueado`)
- Animaciones con `create_tween()` respetando `AnimManager.activas`

---

## Assets incluidos

| Archivo | Descripción |
|---------|-------------|
| `iconos/banner.svg` | Banner de título de dialogs |
| `iconos/panel.svg` | Fondo de panel de dialogs (NinePatch) |
| `iconos/check.svg` | Icono de éxito animado |
| `iconos/x.svg` | Botón de cierre/volver |
| `iconos/bear.png` | Mascota principal |
| `iconos/micro.png` | Botón de micrófono |
| `iconos/actividades.png`, `cuerpo.png`, `preguntas.png` | Tarjetas de menú |
| `sonidos/click.ogg` | Feedback táctil de botón |
| `sonidos/exito.ogg` | Actividad completada |
| `sonidos/cerrar.ogg` | Cerrar escena |
| `sonidos/sonido_derrota.wav` | Tiempo agotado |
| `sonidos/sonido_victoria.wav` | Juego completado |

---

## Exportar a tablet

1. En Godot: **Project → Export**
2. Añade el preset de plataforma (Android, iOS, o Linux ARM para Raspberry Pi con pantalla)
3. Configura `SERVER_HOST` en `config.gd` con la IP definitiva del servidor antes de exportar
4. Asegúrate de que el modo de orientación esté en **Landscape**
