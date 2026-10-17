"""
Convierte el modelo entrenado de PyTorch a ONNX y lo copia a modelos_clasificacion/.
Ejecutar desde la raíz del backend: uv run python scripts/convertir_a_onnx.py

Prerequisito: haber corrido scripts/entrenar_pictogramas.py primero.
"""
from ultralytics import YOLO
import os
import shutil

def convertir_modelo():
    model_path = "runs/cls/pictogramas_model/weights/best.pt"

    if not os.path.exists(model_path):
        print(f"Modelo no encontrado en {model_path}")
        print("Ejecuta primero: uv run python scripts/entrenar_pictogramas.py")
        return

    print(f"Cargando modelo desde {model_path}...")
    model = YOLO(model_path)

    print("Convirtiendo a ONNX (FP32, opset 12)...")
    model.export(format="onnx", imgsz=224, half=False, simplify=True, opset=12)

    onnx_src = model_path.replace('.pt', '.onnx')
    os.makedirs("modelos_clasificacion", exist_ok=True)
    shutil.copy(onnx_src, "modelos_clasificacion/best.onnx")
    shutil.copy(model_path, "modelos_clasificacion/best.pt")

    print("Modelos guardados en modelos_clasificacion/")
    print("  best.onnx  (usado en produccion)")
    print("  best.pt    (backup PyTorch)")

if __name__ == "__main__":
    convertir_modelo()
