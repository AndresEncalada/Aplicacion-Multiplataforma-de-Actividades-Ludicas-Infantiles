from ultralytics import YOLO

class PoseDetector:
    """Detector de pose usando YOLO-Pose. Solo retorna keypoints."""
    
    def __init__(self, model_path: str = 'modelos_pose/yolo26n-pose.pt', conf_threshold: float = 0.5):
        self.model = YOLO(model_path)
        self.conf_threshold = conf_threshold
    
    def detectar_keypoints(self, frame):
        """
        Detecta keypoints de pose en el frame.
        Retorna: numpy array de keypoints o None si no detecta.
        """
        try:
            results = self.model(frame, verbose=False, imgsz=416)
            
            if results[0].keypoints is not None and len(results[0].keypoints.data) > 0:
                return results[0].keypoints.data[0].cpu().numpy()
            
            return None
        except Exception as e:
            return None