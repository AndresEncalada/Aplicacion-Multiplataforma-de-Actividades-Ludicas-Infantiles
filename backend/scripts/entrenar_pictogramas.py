"""
Entrena el clasificador de pictogramas (YOLO-cls).
Ejecutar desde la raíz del backend: uv run python scripts/entrenar_pictogramas.py

Requisitos previos:
  1. Generar dataset: uv run python scripts/generar_dataset.py
  2. Tener scripts/yolo26n-cls.pt (base model de ultralytics)
     Descarga: from ultralytics import YOLO; YOLO('yolo26n-cls.pt')

El modelo entrenado quedará en: runs/cls/pictogramas_model/weights/best.pt
Luego convierte a ONNX: uv run python scripts/convertir_a_onnx.py
"""
from ultralytics import YOLO

def entrenar_modelo():
    print("Cargando modelo base YOLO-cls...")
    model = YOLO('scripts/yolo26n-cls.pt')

    print("Iniciando entrenamiento (5-10 min en CPU)...\n")
    results = model.train(
        data='dataset_pictogramas',
        epochs=50,
        imgsz=224,
        batch=16,
        name='pictogramas_model',
        project='runs/cls',
        patience=10,
        save=True,
        device='cpu',
        verbose=True
    )

    print("\n" + "=" * 60)
    print("ENTRENAMIENTO COMPLETADO")
    print("Modelo: runs/cls/pictogramas_model/weights/best.pt")
    acc = results.results_dict.get('metrics/accuracy_top1', 0)
    print(f"Precision validacion: {acc:.2%}")
    print("Siguiente: uv run python scripts/convertir_a_onnx.py")
    print("=" * 60)

    return results

if __name__ == "__main__":
    entrenar_modelo()
