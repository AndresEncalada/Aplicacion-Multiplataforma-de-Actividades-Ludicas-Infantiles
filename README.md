# Felpudo

Aplicación educativa interactiva para **niños de 3 a 5 años** (nivel Inicial). Combina visión por computadora, reconocimiento de voz, un LLM local, gestión docente con estadísticas de evolución y conexión con el peluche físico robotizado (Raspberry Pi + Arduino):

- **Acceso Docente y Gestión de Alumnos** — ingreso exclusivo del profesor (OAuth2 + JWT), selección de sus alumnos asignados, registro de sesiones, seguimiento de intentos/aciertos/fallos/mejora y generación de reportes individuales.
- **Actividad Corporal** — el niño sigue instrucciones de movimiento y lateralidad detectadas por cámara con YOLO-Pose y sincronizadas con el peluche Felpudo.
- **Actividad de Pictogramas** — muestra un pictograma a la cámara y hace preguntas en voz alta; el sistema responde de forma adaptada a niños de 3 a 5 años.

**Stack:** Godot 4 · FastAPI · YOLO-Pose · Whisper.cpp · Qwen 2.5 1.5B · Django REST + PostgreSQL · Arduino

---

## Estructura

```
Felpudo/
├── backend/          # Servidor FastAPI (IA, OAuth2/JWT, Estadísticas, Integración Pi/Arduino)
├── frontend/felpudo/ # Aplicación Godot 4 (Login Profesor, Alumnos, Juegos, Reportes)
└── docs/             # Documentación técnica detallada
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
2. Si el backend corre en otra máquina, edita `SERVER_HOST` en [`frontend/felpudo/config.gd`](frontend/felpudo/config.gd)
3. Ejecuta con **F5** o exporta al dispositivo

---

## Requisitos

| | Versión |
|---|---|
| Python | 3.11+ con `uv` |
| Godot | 4.x |
| OS | Linux / Raspberry Pi OS / Windows / macOS |

---

## Documentación

| Archivo | Contenido |
|---------|-----------|
| [`docs/instalacion.md`](docs/instalacion.md) | Guía de instalación detallada, variables de entorno, resolución de problemas |
| [`docs/arquitectura.md`](docs/arquitectura.md) | Diseño del sistema, endpoints WebSocket/HTTP, flujo de datos y seguridad JWT |
| [`docs/raspberry_pi.md`](docs/raspberry_pi.md) | Ecosistema Raspberry Pi: Django REST, base de datos `base_tesis`, protocolo serial Arduino y batería UPS |
| [`docs/modelos.md`](docs/modelos.md) | Tabla de modelos, descarga, pipeline de re-entrenamiento |
| [`backend/README.md`](backend/README.md) | Referencia técnica del servidor |
| [`frontend/README.md`](frontend/README.md) | Escenas Godot, configuración de red, assets, créditos |

---

## Flujo general

```
Dispositivo (Godot 4) ──HTTP JWT / WebSocket──▶ FastAPI (:8000)
 (Profesor + Alumno)                                  │
                            ┌─────────────────────────┼─────────────────────────┐
                            ▼                         ▼                         ▼
                  YOLO-Pose / ONNX / LLM     Django REST + PostgreSQL   server.py (:41798)
                  (Cuerpo, Pictogramas,      (Sesiones, Calificaciones,  └──▶ Arduino Serial
                   Voz y Estadísticas)        Reportes en Raspberry Pi)       (Peluche Felpudo)
```
