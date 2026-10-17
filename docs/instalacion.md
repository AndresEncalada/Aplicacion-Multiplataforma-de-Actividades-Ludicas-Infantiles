# Guía de instalación

## Requisitos previos

| Herramienta | Versión mínima | Instalación |
|-------------|---------------|-------------|
| Python | 3.11 | [python.org](https://www.python.org/) |
| uv | cualquiera | `pip install uv` o `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Godot | 4.x | [godotengine.org](https://godotengine.org/) |
| Git LFS | — | No requerido (modelos pequeños están versionados directamente) |

Hardware requerido: cámara USB o integrada, micrófono, 4 GB RAM mínimo (8 GB recomendado para el LLM).

---

## Backend

### 1. Clonar e instalar dependencias

```bash
git clone <url-del-repo>
cd Felpudo/backend
uv sync
```

`uv sync` lee `pyproject.toml` y crea `.venv/` con todas las dependencias. No requiere activar el entorno manualmente; todos los comandos se ejecutan con `uv run`.

### 2. Descargar modelos grandes

```bash
uv run python scripts/instalar_modelos.py
```

Descarga y coloca automáticamente:

| Modelo | Destino | Tamaño |
|--------|---------|--------|
| Whisper.cpp small | `modelos_whisper/ggml-small.bin` | ~465 MB |
| Qwen 2.5 1.5B Q4_K_M | `modelos_llm/qwen2.5-1.5b-instruct-q4_k_m.gguf` | ~1.06 GB |

Los modelos pequeños (YOLO-Pose y clasificador ONNX) **ya están en el repositorio** en `modelos_pose/` y `modelos_clasificacion/`.

### 3. Verificar instalación

```bash
uv run python scripts/verificar_instalacion.py
```

Debe reportar todos los componentes como `OK`. Si falta alguno, el script indica el comando exacto para repararlo.

### 4. Iniciar el servidor

```bash
uv run python main.py
```

El servidor queda en `http://127.0.0.1:8000`. Déjalo corriendo mientras usas la aplicación.

Para cambiar el puerto, edita la última línea de `main.py`:
```python
uvicorn.run(app, host="0.0.0.0", port=8000)  # 0.0.0.0 para aceptar conexiones externas
```

> **Raspberry Pi:** usa `host="0.0.0.0"` para que la tablet pueda conectarse desde la red local.

---

## Frontend

### 1. Abrir el proyecto en Godot

1. Abre Godot 4.
2. Haz clic en **Import** → navega a `frontend/felpudo/` → selecciona `project.godot`.
3. Godot generará `.godot/` (caché del editor) en el primer import. Es normal y está gitignoreado.

### 2. Configurar la IP del servidor

Edita `frontend/felpudo/config.gd`:

```gdscript
const SERVER_HOST := "127.0.0.1:8000"   # localhost (mismo equipo)
# const SERVER_HOST := "192.168.1.42:8000"  # Raspberry Pi en red local
```

Cambia solo esa constante; todas las URLs del proyecto la usan automáticamente.

### 3. Ejecutar o exportar

- **Desarrollo:** F5 en el editor Godot.
- **Tablet:** Project → Export → selecciona la plataforma (Android / iOS / Linux ARM) y exporta.

---

## Resolución de problemas

### La cámara no se detecta

```bash
# Listar índices de cámara disponibles
uv run python -c "import cv2; [print(i, cv2.VideoCapture(i).isOpened()) for i in range(5)]"
```

Cambia el índice `0` en `backend/camera_manager.py` línea 17.

### Whisper o LLM no cargan

El servidor arranca igualmente pero con esa funcionalidad deshabilitada (muestra un warning en consola). Verifica con `scripts/verificar_instalacion.py` y re-ejecuta `scripts/instalar_modelos.py` si es necesario.

### Puerto 8000 ocupado

```bash
# Linux / macOS
lsof -i :8000
# Windows
netstat -ano | findstr :8000
```

### El frontend no conecta con el backend

1. Confirma que el servidor esté corriendo (`uv run python main.py`).
2. Verifica que `SERVER_HOST` en `config.gd` apunte a la IP correcta.
3. En Raspberry Pi, asegúrate de que el firewall permita el puerto 8000: `sudo ufw allow 8000`.
