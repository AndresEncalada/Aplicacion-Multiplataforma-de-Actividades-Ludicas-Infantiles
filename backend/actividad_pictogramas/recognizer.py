import onnxruntime as ort
import cv2
import numpy as np
import os
from ultralytics import YOLO

class PictogramRecognizer:
    def __init__(self, model_path: str = "modelos_clasificacion/best.onnx"):
        print(f"Cargando modelo ONNX desde {model_path}...")
        
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"❌ Modelo ONNX no encontrado en {model_path}\nEjecuta: uv run python actividad_pictogramas/convertir_a_onnx.py")
        
        # Optimizaciones de ONNX Runtime para CPU
        sess_options = ort.SessionOptions()
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        sess_options.intra_op_num_threads = 4
        
        self.session = ort.InferenceSession(model_path, sess_options, providers=['CPUExecutionProvider'])
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name
        
        # Leer nombres de clases del .pt original
        pt_path = model_path.replace('.onnx', '.pt')
        if os.path.exists(pt_path):
            pt_model = YOLO(pt_path)
            self.classes = pt_model.names
        else:
            self.classes = {i: f"clase_{i}" for i in range(18)}
            
        print(f"Modelo ONNX cargado. Clases: {len(self.classes)}")
    
    def reconocer(self, frame_recortado):
        try:
            img = cv2.resize(frame_recortado, (224, 224))
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
            img = np.transpose(img, (2, 0, 1))
            img = np.expand_dims(img, axis=0)

            outputs = self.session.run([self.output_name], {self.input_name: img})
            probs = outputs[0][0]

            top_idx = np.argmax(probs)
            top_prob = float(probs[top_idx])
            nombre = self.classes[top_idx]

            return nombre, top_prob, None
        except Exception as e:
            print(f"Error en reconocimiento ONNX: {e}")
            return None, 0.0, None