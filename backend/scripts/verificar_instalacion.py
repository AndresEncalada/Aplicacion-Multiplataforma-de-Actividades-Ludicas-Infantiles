"""
Verifica que todos los modelos y dependencias estén instalados.
Ejecutar desde la raíz del backend: uv run python scripts/verificar_instalacion.py
"""
import sys
from pathlib import Path

def verificar_archivo(ruta, descripcion):
    p = Path(ruta)
    if p.exists():
        tamaño = p.stat().st_size / (1024 * 1024)
        print(f"  OK  {descripcion} ({tamaño:.1f} MB)")
        return True
    else:
        print(f"  FALTA  {descripcion}")
        print(f"         Ruta esperada: {ruta}")
        return False

def verificar_dependencias():
    print("\nDependencias Python:")
    print("-" * 60)

    dependencias = [
        ("fastapi", "FastAPI"),
        ("uvicorn", "Uvicorn"),
        ("cv2", "OpenCV"),
        ("numpy", "NumPy"),
        ("ultralytics", "Ultralytics YOLO"),
        ("onnxruntime", "ONNX Runtime"),
        ("sounddevice", "SoundDevice"),
        ("pywhispercpp", "Whisper.cpp"),
        ("llama_cpp", "LLaMA C++"),
    ]

    ok = 0
    for modulo, nombre in dependencias:
        try:
            __import__(modulo)
            print(f"  OK  {nombre}")
            ok += 1
        except ImportError:
            print(f"  FALTA  {nombre}  →  uv sync")

    print(f"\nDependencias: {ok}/{len(dependencias)}")
    return ok == len(dependencias)

def main():
    print("\n" + "="*60)
    print("VERIFICACION DE INSTALACION - Felpudo Backend")
    print("="*60)

    print("\nModelos incluidos en el repo:")
    print("-" * 60)
    onnx_ok = verificar_archivo("modelos_clasificacion/best.onnx", "Pictogramas ONNX (clasificador)")
    pose_ok = verificar_archivo("modelos_pose/yolo26n-pose.pt", "Pose YOLO (actividad corporal)")

    print("\nModelos a descargar (scripts/instalar_modelos.py):")
    print("-" * 60)
    whisper_ok = verificar_archivo("modelos_whisper/ggml-small.bin", "Whisper.cpp small (voz→texto)")
    llm_ok = verificar_archivo("modelos_llm/qwen2.5-1.5b-instruct-q4_k_m.gguf", "Qwen 2.5 1.5B (LLM)")

    deps_ok = verificar_dependencias()

    todo_ok = onnx_ok and pose_ok and whisper_ok and llm_ok and deps_ok

    print("\n" + "="*60)
    if todo_ok:
        print("Todo listo. Ejecuta: uv run python main.py")
    else:
        print("Faltan componentes:")
        if not (whisper_ok and llm_ok):
            print("  → Descarga modelos: uv run python scripts/instalar_modelos.py")
        if not (onnx_ok and pose_ok):
            print("  → Los modelos del repo deben estar en modelos_clasificacion/ y modelos_pose/")
        if not deps_ok:
            print("  → Instala dependencias: uv sync")
    print("="*60 + "\n")

    return 0 if todo_ok else 1

if __name__ == "__main__":
    sys.exit(main())
