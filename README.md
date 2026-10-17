# Felpudo

Aplicación educativa interactiva para niños de 3 años. Usa visión por computadora, reconocimiento de voz y un LLM local para dos actividades:

- **Actividad Corporal** — el niño sigue instrucciones de movimiento detectadas por cámara con YOLO-Pose.
- **Actividad de Pictogramas** — muestra un pictograma a la cámara y hace preguntas en voz alta; el sistema responde.

**Stack:** Godot 4 · FastAPI · YOLO · Whisper.cpp · Qwen 2.5 1.5B

---

## Estructura

```
Felpudo/
├── backend/          # Servidor FastAPI (Python 3.11+)
├── frontend/felpudo/ # Aplicación Godot 4
└── docs/             # Documentación detallada
```

→ Documentación completa en [`docs/`](docs/)

---

## Inicio rápido

### Backend

```bash
cd backend
pip install uv          # una sola vez
uv sync                 # instala dependencias
uv run python scripts/instalar_modelos.py   # descarga ~1.5 GB (Whisper + LLM)
uv run python scripts/verificar_instalacion.py  # comprueba que todo esté listo
uv run python main.py   # inicia el servidor en http://127.0.0.1:8000
```

> Los modelos pequeños (YOLO-Pose y clasificador ONNX, ~17 MB) ya están en el repositorio.

### Frontend

1. Abre Godot 4 e importa `frontend/felpudo/`
2. Si el backend corre en otra máquina (ej. Raspberry Pi), edita `SERVER_HOST` en [`frontend/felpudo/config.gd`](frontend/felpudo/config.gd)
3. Ejecuta con **F5** o exporta al dispositivo

---

## Requisitos

| | Mínimo |
|---|---|
| Python | 3.11+ con `uv` |
| Godot | 4.x |
| RAM | 4 GB (8 GB recomendado) |
| Cámara | USB o módulo integrado |
| Micrófono | Requerido para actividad de pictogramas |
| OS | Linux / Raspberry Pi OS / Windows / macOS |

---

## Documentación

| Archivo | Contenido |
|---------|-----------|
| [`docs/instalacion.md`](docs/instalacion.md) | Guía de instalación detallada, variables de entorno, resolución de problemas |
| [`docs/arquitectura.md`](docs/arquitectura.md) | Diseño del sistema, endpoints WebSocket/HTTP, flujo de datos |
| [`docs/modelos.md`](docs/modelos.md) | Tabla de modelos, descarga, pipeline de re-entrenamiento |
| [`backend/README.md`](backend/README.md) | Referencia técnica del servidor |
| [`frontend/README.md`](frontend/README.md) | Escenas Godot, configuración de red, assets, créditos |

---

## Flujo general

```
Dispositivo (Godot 4)  ──WebSocket/HTTP──▶  Raspberry Pi (FastAPI :8000)
                                                       │
                                          ┌────────────┼────────────┐
                                       YOLO-Pose   ONNX cls    Whisper+LLM
                                    (actividad    (pictogramas) (preguntas
                                    corporal)                  de voz)
```
