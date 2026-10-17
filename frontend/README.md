# Felpudo — Frontend

Aplicación Godot 4 para PC/Móviles (landscape). Interfaz diseñada para niños de 3 años: sin texto obligatorio, paleta lúdica, botones de mínimo 96×96 px con efecto 3D gomoso, animaciones elásticas y debounce de 400 ms.

Requiere el [backend](../backend/README.md) corriendo para funcionar.

---

## Abrir el proyecto

1. Instala [Godot 4.x](https://godotengine.org/)
2. **Import** → selecciona `frontend/felpudo/` → abre `project.godot`
3. Godot generará `.godot/` (caché del editor) — es normal, está gitignoreado

---

## Configurar la IP del servidor

Edita una sola línea en [`config.gd`](felpudo/config.gd):

```gdscript
const SERVER_HOST := "127.0.0.1:8000"   # mismo equipo
# const SERVER_HOST := "192.168.1.42:8000"  # Raspberry Pi en red local
```

Todas las URLs (WebSocket + HTTP) se derivan de esta constante automáticamente:

```gdscript
const WS_CUERPO           := "ws://"  + SERVER_HOST + "/ws"
const WS_PICTOGRAMAS      := "ws://"  + SERVER_HOST + "/ws_pictogramas"
const HTTP_REINICIAR      := "http://" + SERVER_HOST + "/reiniciar"
const HTTP_LIBERAR_CAMARA := "http://" + SERVER_HOST + "/liberar_camara"
```

---

## Ejecutar o exportar

- **Editor:** F5
- **Dispositivo:** Project → Export → selecciona plataforma → asegúrate de que la orientación sea **Landscape** → configura `SERVER_HOST` antes de exportar

---

## Estructura del proyecto

```
frontend/felpudo/
├── project.godot                     # Configuración del proyecto
├── config.gd                         # Autoload: constantes de red (SERVER_HOST)
├── anim_manager.gd                   # Autoload: toggle de animaciones global
│
├── menu_principal.tscn / .gd         # Pantalla de inicio con bear mascota
├── menu_actividades.tscn / .gd       # Selección de actividad
├── actividad_cuerpo.tscn / .gd       # Actividad de reconocimiento corporal
├── actividad_pictogramas.tscn / .gd  # Actividad de pictogramas + Q&A
├── main.tscn / .gd                   # (legacy, mantiene compatibilidad)
│
└── assets/
    ├── fuente/    # Kenney Future Narrow.ttf, Kenney Future.ttf
    ├── iconos/    # SVGs y PNGs de UI
    └── sonidos/   # OGG / WAV para feedback
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

## Assets y créditos

Los elementos gráficos de UI (iconos, paneles, tipografía) y sonidos de feedback provienen de [kenney.nl](https://kenney.nl) — licencia **CC0 / Dominio público**.

Los pictogramas en `backend/pictogramas_originales/` son de [ARASAAC](https://arasaac.org) — licencia **CC BY-NC-SA**.

### Kenney (kenney.nl)
Fuentes, iconos, paneles y sonidos de UI distribuidos bajo **Creative Commons Zero (CC0)**. No se requiere atribución, pero se recomienda mencionarla:

> *"Assets by Kenney (kenney.nl) — Licensed CC0 / Public Domain"*

### ARASAAC
Los pictogramas originales provienen del [Portal Aragonés de la Comunicación Aumentativa y Alternativa](https://arasaac.org). Licencia **CC BY-NC-SA** — requiere atribución, uso no comercial y compartir con la misma licencia:

> *"Pictographic symbols used are the property of the Government of Aragón and have been created by Sergio Palao for ARASAAC (https://arasaac.org), distributed under Creative Commons License BY-NC-SA."*
