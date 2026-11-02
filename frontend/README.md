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
├── project.godot                     # Configuración del proyecto (inicia en login_profesor.tscn)
├── config.gd                         # Autoload: constantes de red (WebSockets + API REST JWT)
├── anim_manager.gd                   # Autoload: toggle de animaciones global
├── sesion_state.gd                   # Autoload: estado del profesor (JWT), alumnos y sesión activa
│
├── login_profesor.tscn / .gd         # Login docente, lista de sus alumnos y panel de estadísticas/reportes
├── menu_principal.tscn / .gd         # Pantalla de inicio del alumno activo con bear mascota
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
| `SesionState` | `sesion_state.gd` | Conserva el token JWT del profesor, su lista de alumnos y la sesión activa |

---

## Guía de Imágenes y Assets (Dónde ponerlas y qué tipo sacar)

Todas las imágenes de interfaz van en la carpeta:
`frontend/felpudo/assets/iconos/`

El sistema ya funciona de inmediato usando los iconos actuales como respaldo automático, pero puedes colocar estas imágenes opcionales para personalizar aún más las nuevas vistas docentes:

| Nombre de archivo a colocar | Ruta completa en Godot | Qué tipo de imagen sacar / usar | Tamaño y Formato recomendado | Icono de respaldo actual |
| :--- | :--- | :--- | :--- | :--- |
| **`profesor.png`** | `res://assets/iconos/profesor.png` | Icono amigable de docente / profesora o birrete escolar estilo flat/cartoon. | PNG transparente, `128×128 px` o `256×256 px` | `bear.png` |
| **`alumno.png`** | `res://assets/iconos/alumno.png` | Avatar infantil (carita sonriente de niño/niña de 3 a 5 años) estilo colorido y redondeado. | PNG transparente, `128×128 px` | `cuerpo.png` |
| **`reporte.png`** | `res://assets/iconos/reporte.png` | Icono de hoja de calificación con estrella o gráfico de barras de progreso. | PNG o SVG transparente, `128×128 px` | `preguntas.png` |
| **`alerta.png`** | `res://assets/iconos/alerta.png` | Icono amigable de enchufe/red o aviso suave para los mensajes de verificación de conexión. | PNG o SVG transparente, `128×128 px` | `bear.png` |

> **¿De dónde sacarlas manteniendo el estilo visual?**
> 1. **[Kenney.nl](https://kenney.nl/assets)** *(Board Game Icons / Game Icons / UI Pack)* — Dominio público (CC0), mismo estilo exacto de bordes gruesos que el resto de la app.
> 2. **[ARASAAC](https://arasaac.org/pictograms/search)** — Busca *"maestro"*, *"niño"*, *"evaluación"* o *"conexión"* y descárgalos en PNG con fondo transparente (300×300 px).

---

## Escenas

### `login_profesor` (Escena inicial)
- **Vista 1 (Login):** Acceso exclusivo para el profesor con usuario y contraseña (`POST /api/auth/login` con OAuth2/JWT).
- **Vista 2 (Mis Alumnos):** Muestra únicamente los alumnos asignados al profesor autenticado (3 a 5 años, nivel único `Inicial`) con su resumen de intentos, aciertos, fallos y porcentaje de mejora.
- **Vista 3 (Estadísticas y Reporte):** Desglose por sesión y actividad con indicadores (`adquirido`, `proceso`, `iniciado`) y botón para abrir el **Reporte Imprimible (PDF / HTML)** en el navegador.

### `menu_principal`
UI procedural. Bear mascota con animación wobble. Muestra en la esquina superior derecha el nombre del alumno activo y el botón para finalizar la sesión y regresar al panel del profesor.

### `menu_actividades`
Dos tarjetas: **Reconocimiento del Cuerpo** y **Preguntas** (pictogramas). Botón X de vuelta al menú principal.

### `actividad_cuerpo`
- Se conecta al WebSocket `/ws`
- Muestra feed de cámara en pantalla completa con overlay de barra de instrucción inferior
- Diálogo de bienvenida overlay con botón "¡Comenzar!"
- Animación de flash blanco + check verde al completar una actividad (`centro_cuerpo` del backend determina la posición exacta)
- Registra automáticamente aciertos, tiempos y fallos en la sesión activa y envía comandos al Arduino (`MD4`, `MI5`, `CA3`, `OD2`, `BR1`, `CC`, `NA`)
- Muestra alerta amigable si se pierde la conexión con el servidor

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
