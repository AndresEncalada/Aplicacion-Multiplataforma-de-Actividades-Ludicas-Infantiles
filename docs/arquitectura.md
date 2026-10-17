# Arquitectura del sistema

## Visión general

```
┌─────────────────────────────────────────────────────────────┐
│                    Tablet (Godot 4)                         │
│                                                             │
│  menu_principal → menu_actividades                          │
│         │                  │                               │
│  actividad_cuerpo    actividad_pictogramas                  │
└──────────┬───────────────────┬──────────────────────────────┘
           │ WebSocket frames  │ WebSocket frames + JSON
           │ + JSON eventos    │ + comandos de audio
           ▼                   ▼
┌──────────────────────────────────────────────────────────────┐
│              FastAPI — backend/main.py (:8000)               │
│                                                              │
│  /ws                     /ws_pictogramas                     │
│  CameraManager           CameraManager (compartida)          │
│  PoseDetector            PictogramRecognizer (ONNX)          │
│  ActivityManager         WhisperModel                        │
│  GameManager             Llama (LLM)                         │
│                                                              │
│  POST /reiniciar         POST /liberar_camara                │
└──────────────────────────────────────────────────────────────┘
           │                   │
     YOLO-Pose            ONNX + Whisper.cpp + Qwen
  (modelos_pose/)      (modelos_clasificacion/ + modelos_*)
```

---

## Componentes del backend

### `main.py` — Servidor FastAPI
Entry point. Define el ciclo de vida (`lifespan`): carga todos los modelos al iniciar y libera la cámara al detener. Expone los cuatro endpoints.

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
- **Base de conocimientos directa**: para las 18 clases conocidas, respuestas prefabricadas evitan alucinaciones del modelo pequeño con niños como audiencia.
- **`ThreadPoolExecutor` para YOLO**: YOLO-Pose es síncrono; `run_in_executor` lo mueve a un hilo del pool para no congelar el event loop de asyncio mientras el modelo infiere.
