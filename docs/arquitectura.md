# Arquitectura del sistema

## Visión general

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Dispositivo (Godot 4)                          │
│                                                                         │
│  login_profesor (OAuth2/JWT) → Selección de Alumno (3-5 años)           │
│         │                              │                                │
│  Panel Estadísticas/Reportes   menu_principal → menu_actividades        │
│                                        │                  │             │
│                                 actividad_cuerpo    actividad_pictogramas│
└──────────────┬─────────────────────────┬──────────────────┬─────────────┘
               │ HTTP REST (Bearer JWT)  │ WebSocket frames │ WebSocket + Audio
               ▼                         ▼                  ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                     FastAPI — backend/main.py (:8000)                    │
│                                                                          │
│  /api/auth/login         /ws                      /ws_pictogramas        │
│  /api/alumnos            CameraManager            CameraManager          │
│  /api/sesion/*           PoseDetector (YOLO)      PictogramRecognizer    │
│  /api/estadisticas/*     ActivityManager          WhisperModel + Llama   │
│  /api/reportes/*         GameManager                                     │
│                                                                          │
│  integracion/: Seguridad JWT · Mapeo Pedagógico · Estadísticas/Reportes  │
└──────────────┬────────────────────────────────────────────┬──────────────┘
               │ HTTP REST (con Fallback Local)             │ TCP Socket (:41798)
               ▼                                            ▼
┌──────────────────────────────────────┐     ┌─────────────────────────────┐
│   Raspberry Pi — Django REST (:8000) │     │ Raspberry Pi — server.py    │
│   PostgreSQL (base_tesis)            │     │ Serial USB (/dev/ttyUSB*)   │
│   Profesores · Alumnos · Calificación│     │ Arduino (Peluche Felpudo)   │
└──────────────────────────────────────┘     └─────────────────────────────┘
```

---

## Componentes del backend

### `main.py` — Servidor FastAPI
Entry point. Define el ciclo de vida (`lifespan`): carga todos los modelos al iniciar y libera la cámara al detener. Expone los endpoints WebSocket de juego e integra las rutas REST de autenticación, alumnos, sesiones, estadísticas y reportes.

### `camera_manager.py` — Singleton de cámara
Hilo dedicado de captura (`_capture_loop`) que lee frames continuamente y los almacena en `_latest_frame` con un `threading.Lock`. Los WebSocket clients llaman a `read()` (no bloqueante) para obtener el último frame disponible. Esto evita que la cámara bloquee el event loop de asyncio.

### `actividad_cuerpo/` — Actividad Corporal
| Módulo | Responsabilidad |
|--------|----------------|
| `detector.py` | Wraps YOLO-Pose; corre en `ThreadPoolExecutor` vía `loop.run_in_executor` |
| `actividades.py` | Lógica de detección: torso visible, manos levantadas, toques de zonas corporales |
| `game_manager.py` | Estado del juego (5 estados: `esperando_torso` → `jugando` → `terminado`), secuencia de 10 actividades aleatorias |
| `procesamiento.py` | Efecto visual de confeti sobre el frame OpenCV |

### `actividad_pictogramas/` — Actividad Pictogramas
| Módulo | Responsabilidad |
|--------|----------------|
| `recognizer.py` | ONNX Runtime con `ORT_ENABLE_ALL`; preprocesa a 224×224 RGB normalizado |
| `conocimiento.py` | Base de conocimientos estática (18 pictogramas × preguntas comunes); evita alucinaciones del LLM |

### `integracion/` — Seguridad, Raspberry Pi, Arduino y Reportes
| Módulo | Responsabilidad |
|--------|----------------|
| `seguridad.py` | Hashing de contraseñas `PBKDF2-SHA256` (compatible con Django `auth_user`) y emisión/validación de tokens **JWT (`HS256`)** con flujo OAuth2 |
| `mapeo_pedagogico.py` | Asociación entre posturas de YOLO / pictogramas ONNX, códigos de órdenes de `backup_tesis.sql` (`a2_17`, `a3_07`, etc.) y comandos del Arduino (`MD4`, `CA3`, `CC`, `NA`) |
| `arduino_client.py` | Cliente TCP no bloqueante (*fire-and-forget*, timeout 150 ms) hacia `server.py` (`192.168.1.200:41798`) |
| `django_client.py` | Sincronizador HTTP con la API de Django en la Raspberry Pi y almacén espejo local (`datos_locales.json`) para operación offline/portátil |
| `reportes.py` | Motor de estadísticas (intentos, aciertos, fallos, tiempos de respuesta, porcentaje de mejora entre sesiones) y generador de reportes HTML/PDF |

---

## Endpoints

### `WebSocket /ws` — Actividad Corporal

**Protocolo de paquetes (servidor → cliente):**
- Bytes JPEG (magic `0xFF 0xD8`): frame de cámara
- JSON: estado y evento del juego

**Eventos JSON enviados:**

| `evento` | Descripción |
|----------|-------------|
| `instruccion_postura` | Pide al niño que se ponga frente a la cámara |
| `torso_detectado` | Confirmación de posición, pide levantar mano |
| `esperando_mano` | Espera que el niño levante una mano |
| `jugador_seleccionado` | Mano detectada, cuenta regresiva de 3 s |
| `instruccion_actividad` | Nueva actividad; incluye `progreso`, `tiempo_restante`, `tipo`, `objetivo` |
| `actividad_exitosa` | Actividad completada; incluye `efecto_visual: "flash_exito"` y `centro_cuerpo` |
| `tiempo_agotado` | Se acabó el tiempo de la actividad actual |
| `juego_completado` | Todas las 10 actividades completadas |

### `WebSocket /ws_pictogramas` — Actividad Pictogramas

**Protocolo (cliente → servidor):**

| Comando | Descripción |
|---------|-------------|
| `{"accion": "iniciar_escaneo"}` | Inicia escaneo de 5 s |
| `{"accion": "confirmar"}` | Acepta el pictograma propuesto, entra en modo Q&A |
| `{"accion": "rechazar"}` | Rechaza y reintenta (máx. 2 intentos) |
| `{"comando": "iniciar_grabacion"}` | Abre el stream de audio (sounddevice) |
| `{"comando": "detener_grabacion"}` | Cierra el stream y procesa con Whisper + LLM |
| `{"comando": "volver"}` | Sale del modo Q&A y vuelve al escaneo |

**Eventos JSON enviados:**

| `evento` | Descripción |
|----------|-------------|
| `propuesta_pictograma` | Nombre y score del pictograma detectado |
| `fallo_deteccion` | No se pudo identificar; `tipo`: `no_detectado` o `rechazado_2_veces` |
| `grabacion_iniciada` | Confirmación de inicio de grabación |
| `respuesta_audio` | `texto_usuario` (Whisper) + `respuesta_sistema` (base de conocimientos o LLM) |
| `error_audio` | Error en transcripción o LLM |

### `POST /reiniciar`
Reinicia `GameManager` al estado inicial sin reiniciar el servidor.

### `POST /liberar_camara`
Libera el recurso de cámara y reinicia el juego. Usar al salir de la actividad de pictogramas.

### Endpoints de Autenticación, Alumnos, Estadísticas y Reportes (`/api/*`)

| Método y Ruta | Protección | Descripción |
| :--- | :---: | :--- |
| `POST /api/auth/login` | Público | Autentica al profesor (`username`, `password`) con hash `PBKDF2-SHA256` o contra Django; devuelve `access_token` JWT (`HS256`) y datos del docente |
| `GET /api/estado` | Público | Diagnóstico del sistema (estado de cámara, modelos de IA, conexión a Raspberry Pi y Arduino) |
| `GET /api/alumnos` | `Bearer JWT` | Lista los alumnos (3 a 5 años, nivel único `Inicial`) asignados al profesor autenticado junto con su resumen de progreso |
| `POST /api/sesion/iniciar` | `Bearer JWT` | Crea una nueva sesión de terapia/juego para el alumno seleccionado |
| `POST /api/sesion/finalizar` | `Bearer JWT` | Cierra la sesión activa y calcula las estadísticas de desempeño logradas |
| `GET /api/estadisticas/alumno/{nn_id}` | `Bearer JWT` | Devuelve métricas acumuladas y por sesión: **intentos, aciertos (no fallaron), fallos, tiempo promedio y % de mejora** |
| `GET /api/reportes/alumno/{nn_id}/html` | Público / Token | Genera el reporte oficial imprimible (HTML/PDF) con identificación del alumno, métricas de evolución y tabla de indicadores (`adquirido`, `proceso`, `iniciado`) |

→ Para el detalle completo de la base de datos `base_tesis`, endpoints nativos de Django y protocolo serial del Arduino, consulta [`docs/raspberry_pi.md`](raspberry_pi.md).

---

## Flujo de audio (actividad de pictogramas)

```
Niño habla → sounddevice (16 kHz, int16, mono)
           → cola de chunks (audio_queue)
           → concatenar chunks → float32 normalizado (-1.0 a 1.0)
           → Whisper.cpp (n_threads=4, language='es')
           → texto transcrito
           → buscar en conocimiento.py (coincidencia por palabra clave)
           → si no hay match: Qwen 2.5 1.5B (max_tokens=35, temperature=0.2)
           → respuesta enviada por WebSocket
```

---

## Decisiones de diseño

- **ONNX vs PyTorch en producción**: ONNX Runtime es ~30 % más rápido en CPU y no requiere cargar Ultralytics completo en producción.
- **Whisper.cpp vs API**: corre completamente offline, esencial para Raspberry Pi sin internet.
- **LLM cuantizado Q4_K_M**: balance entre calidad y velocidad en CPU de Raspberry Pi 4/5.
- **Base de conocimientos directa**: para las 18 clases conocidas, respuestas prefabricadas evitan alucinaciones del modelo pequeño con niños de 3 a 5 años como audiencia.
- **`ThreadPoolExecutor` para YOLO**: YOLO-Pose es síncrono; `run_in_executor` lo mueve a un hilo del pool para no congelar el event loop de asyncio mientras el modelo infiere.
- **Arquitectura Híbrida (Raspberry Pi + Fallback Local)**: sincroniza sesiones y calificaciones con el servidor Django/PostgreSQL de la Raspberry Pi y el Arduino por socket TCP, manteniendo respaldo local automático para funcionar sin interrupciones en cualquier entorno.
