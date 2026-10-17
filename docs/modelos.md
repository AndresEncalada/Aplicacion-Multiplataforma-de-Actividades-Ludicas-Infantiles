# Modelos de IA

## Resumen

| Modelo | Archivo | Tamaño | En repo | Uso |
|--------|---------|--------|---------|-----|
| YOLOv8-Pose | `modelos_pose/yolo26n-pose.pt` | 7.51 MB | ✅ | Detección de keypoints corporales |
| Clasificador ONNX | `modelos_clasificacion/best.onnx` | 5.95 MB | ✅ | Clasificación de 18 pictogramas |
| Clasificador PyTorch | `modelos_clasificacion/best.pt` | 3.08 MB | ✅ | Backup del clasificador |
| Whisper.cpp small | `modelos_whisper/ggml-small.bin` | ~465 MB | ❌ | Transcripción de voz en español |
| Qwen 2.5 1.5B Q4_K_M | `modelos_llm/qwen2.5-1.5b-instruct-q4_k_m.gguf` | ~1.06 GB | ❌ | LLM local para respuestas |

Los modelos marcados ❌ deben descargarse antes de correr el servidor.

---

## Descargar modelos grandes

```bash
cd backend
uv run python scripts/instalar_modelos.py
```

El script descarga automáticamente desde Hugging Face y coloca cada archivo en su carpeta. Muestra progreso en MB y permite re-descargar si el archivo ya existe.

**Fuentes originales (descarga manual si es necesario):**
- Whisper: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin`
- Qwen: `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf`

---

## Pictogramas reconocidos (18 clases)

Los pictogramas provienen de [ARASAAC](https://arasaac.org/). Los PNGs originales están en `backend/pictogramas_originales/`.

| Clase | Clase | Clase |
|-------|-------|-------|
| capibara | cocinero | detective |
| erizo | escorpion | ganadero |
| gorila | jardinera | lenador |
| leon | minero | panadera |
| pastelera | pescador | policia |
| raton | serpiente | tarantula |

---

## Re-entrenar el clasificador de pictogramas

Solo necesario si se agregan nuevas clases o se quiere mejorar la precisión.

### Paso 1 — Generar dataset sintético

```bash
cd backend
uv run python scripts/generar_dataset.py
```

Lee los PNGs de `pictogramas_originales/`, aplica augmentación (rotación, escala, brillo, desenfoque, ruido, compresión JPEG) y los compone sobre fondos realistas (papel, madera, concreto). Genera 30 imágenes de entrenamiento + 10 de validación por clase en `dataset_pictogramas/`.

### Paso 2 — Entrenar

```bash
uv run python scripts/entrenar_pictogramas.py
```

Necesita `scripts/yolo26n-cls.pt` (modelo base de Ultralytics). Si no está disponible, se descarga automáticamente al ejecutar el script la primera vez (requiere internet).

Parámetros del entrenamiento: 50 epochs, `imgsz=224`, `batch=16`, `device=cpu`, `patience=10`. Dura ~5–10 minutos en CPU. El modelo queda en `runs/cls/pictogramas_model/weights/best.pt`.

### Paso 3 — Exportar a ONNX y desplegar

```bash
uv run python scripts/convertir_a_onnx.py
```

Convierte `best.pt` a ONNX (FP32, opset 12, grafo simplificado) y copia los archivos a `modelos_clasificacion/`. El servidor carga automáticamente el nuevo modelo en el próximo inicio.

### Agregar una nueva clase

1. Agrega el PNG de la nueva clase a `pictogramas_originales/` (formato PNG con canal alfa preferible).
2. Agrega su entrada en `actividad_pictogramas/conocimiento.py` (dato + preguntas comunes).
3. Ejecuta los tres pasos anteriores.
4. El servidor reconocerá la nueva clase automáticamente.

---

## Detalles técnicos del clasificador

- **Arquitectura**: YOLOv8n-cls (clasificación, no detección)
- **Input**: 224 × 224 px, RGB, normalizado [0, 1], formato CHW batch
- **Output**: vector de probabilidades softmax (18 dimensiones)
- **Umbral de confianza**: score > 0.7 para proponer, score > 0.9 para confirmar inmediatamente
- **Zona de escaneo**: recorte central del 60 % del frame de cámara
- **Runtime**: ONNX Runtime CPU con `ORT_ENABLE_ALL` y 4 threads

## Detalles del detector de pose

- **Arquitectura**: YOLOv8n-pose (COCO 17 keypoints)
- **Input**: `imgsz=416`
- **Umbral de confianza**: 0.5 por keypoint
- **Keypoints usados**: nariz (0), orejas (3, 4), hombros (5, 6), codos (7, 8), muñecas (9, 10), caderas (11, 12)
