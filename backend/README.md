# Felpudo — Backend

Backend FastAPI para la aplicación educativa Felpudo. Corre localmente en una Raspberry Pi y expone WebSockets y endpoints HTTP que consume el frontend Godot 4.

---

## Arquitectura

```
backend/
├── main.py                         # Servidor FastAPI (entry point)
├── camera_manager.py               # Singleton de cámara con hilo dedicado
├── pyproject.toml                  # Dependencias (gestor: uv)
│
├── actividad_cuerpo/               # Actividad 1: Reconocimiento Corporal
│   ├── detector.py                 # PoseDetector — inferencia YOLO-Pose
│   ├── actividades.py              # ActivityManager — lógica de detección de poses
│   ├── game_manager.py             # GameManager — secuencia de 10 actividades
│   └── procesamiento.py            # ImageProcessor — efectos visuales (confeti)
│
├── actividad_pictogramas/          # Actividad 2: Pictogramas
│   ├── recognizer.py               # PictogramRecognizer — inferencia ONNX
│   └── conocimiento.py             # Base de conocimientos (18 pictogramas + Q&A)
│
├── modelos_clasificacion/          # Modelos del clasificador (incluidos en repo)
│   ├── best.onnx                   # Clasificador ONNX — PRODUCCIÓN
│   └── best.pt                     # Backup PyTorch
│
├── modelos_pose/                   # Modelo de pose (incluido en repo)
│   └── yolo26n-pose.pt             # YOLO-Pose — actividad corporal
│
├── pictogramas_originales/         # 18 PNGs originales (ARASAAC)
│
├── scripts/                        # Utilidades (no son parte del servidor)
│   ├── instalar_modelos.py         # Descarga Whisper + LLM (~1.5 GB)
│   ├── verificar_instalacion.py    # Verifica que todo esté listo
│   ├── generar_dataset.py          # Genera dataset sintético de entrenamiento
│   ├── entrenar_pictogramas.py     # Entrena el clasificador YOLO-cls
│   ├── convertir_a_onnx.py         # Convierte best.pt → best.onnx
│   └── yolo26n-cls.pt              # Modelo base YOLO-cls (solo entrenamiento)
│
├── modelos_whisper/                # Whisper.cpp — NO incluido, descargar
│   └── ggml-small.bin              # ~465 MB
│
└── modelos_llm/                    # LLM local — NO incluido, descargar
    └── qwen2.5-1.5b-instruct-q4_k_m.gguf  # ~1.06 GB
```

---

## Endpoints

### WebSocket `/ws` — Actividad Corporal
Streaming de frames de cámara + detección de poses YOLO. El cliente recibe:
- Bytes JPEG del frame procesado
- JSON con el estado del juego y la instrucción actual

**Flujo del juego:**
1. `esperando_torso` → detecta que el jugador está de frente a la cámara
2. `esperando_mano` → levanta una mano para seleccionarse como jugador
3. `seleccionado` → cuenta regresiva de 3 segundos
4. `jugando` → 10 actividades aleatorias (poses, toques de zonas corporales)
5. `terminado` → efecto de confeti

**Actividades disponibles (pool de 10 aleatorias):**
- Levantar mano derecha / izquierda / ambas
- Cruzar brazos
- Tocar cabeza, orejas, cuello, hombros, pecho, cintura

### WebSocket `/ws_pictogramas` — Actividad de Pictogramas
Escanea un pictograma físico con la cámara y responde preguntas en audio.

**Flujo:**
1. Cliente envía `{"accion": "iniciar_escaneo"}`
2. Backend escanea por 5 s, busca el pictograma con mayor confianza (>0.7)
3. Propone el resultado → cliente confirma o rechaza (máx. 2 intentos)
4. Modo Q&A: cliente envía `{"comando": "iniciar_grabacion"}` → graba audio → `{"comando": "detener_grabacion"}`
5. Backend transcribe con Whisper.cpp y genera respuesta con LLM o base de conocimientos
6. Cliente envía `{"comando": "volver"}` para reiniciar

**Pictogramas reconocidos (18):**
capibara, cocinero, detective, erizo, escorpion, ganadero, gorila, jardinera, lenador, leon, minero, panadera, pastelera, pescador, policia, raton, serpiente, tarantula

### POST `/reiniciar`
Reinicia el estado del juego corporal sin reiniciar el servidor.

### POST `/liberar_camara`
Libera la cámara y reinicia el juego. Útil cuando el frontend cierra la escena.

---

## Modelos

| Modelo | Tamaño | Fuente | Notas |
|--------|--------|--------|-------|
| `modelos_clasificacion/best.onnx` | 5.95 MB | Incluido en repo | Clasificador ONNX de pictogramas |
| `modelos_clasificacion/best.pt` | 3.08 MB | Incluido en repo | Backup PyTorch |
| `modelos_pose/yolo26n-pose.pt` | 7.51 MB | Incluido en repo | Detección de keypoints corporales |
| `modelos_whisper/ggml-small.bin` | ~465 MB | Descargar | Whisper.cpp, voz→texto en español |
| `modelos_llm/qwen2.5-1.5b-instruct-q4_k_m.gguf` | ~1.06 GB | Descargar | LLM local para respuestas |

Los tres modelos pequeños se incluyen directamente en el repositorio.
Los dos modelos grandes deben descargarse con el instalador.

---

## Instalación

### 1. Requisitos previos
- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (`pip install uv`)
- Cámara USB o módulo de cámara
- Micrófono (para la actividad de pictogramas)

### 2. Instalar dependencias
```bash
cd backend
uv sync
```

### 3. Descargar modelos grandes
```bash
uv run python scripts/instalar_modelos.py
```
Descarga ~1.5 GB (Whisper.cpp small + Qwen 2.5 1.5B).

### 4. Verificar instalación
```bash
uv run python scripts/verificar_instalacion.py
```

### 5. Iniciar el servidor
```bash
uv run python main.py
```
Servidor disponible en `http://127.0.0.1:8000`

---

## Re-entrenar el clasificador de pictogramas

Solo necesario si se agregan nuevos pictogramas. Los modelos entrenados ya se incluyen en el repo.

```bash
# 1. Generar dataset sintético a partir de los PNGs originales
uv run python scripts/generar_dataset.py

# 2. Entrenar el modelo (5-10 min en CPU)
uv run python scripts/entrenar_pictogramas.py

# 3. Exportar a ONNX y copiar a producción
uv run python scripts/convertir_a_onnx.py
```

Para el entrenamiento se necesita `scripts/yolo26n-cls.pt` (modelo base de Ultralytics).
Si no está disponible, se descarga automáticamente al instalar Ultralytics:
```python
from ultralytics import YOLO; YOLO('yolo26n-cls.pt')
```

---

## Notas técnicas

- La cámara se gestiona con un hilo dedicado (`camera_manager.py`) para no bloquear el event loop de asyncio.
- YOLO-Pose corre en un `ThreadPoolExecutor` (`loop.run_in_executor`) para no congelar los WebSockets.
- El LLM tiene un límite de 35 tokens y temperatura 0.2 para respuestas cortas y precisas (público: niños de 3 años).
- Si un pictograma tiene una respuesta directa en `conocimiento.py`, se usa esa en lugar del LLM.
- El servidor maneja desconexiones de WebSocket de forma silenciosa (`WebSocketDisconnect`).
