import cv2
import threading

class CameraManager:
    def __init__(self):
        self.camera = None
        self.clientes_conectados = 0
        self._latest_frame = None
        self._frame_lock = threading.Lock()
        self._capture_thread = None
        self._capturing = False

    def conectar_cliente(self):
        self.clientes_conectados += 1
        if self.camera is None or not self.camera.isOpened():
            print("Abriendo cámara...")
            self.camera = cv2.VideoCapture(0)
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.camera.set(cv2.CAP_PROP_FPS, 30)
            for _ in range(5):
                self.camera.read()
            self._capturing = True
            self._latest_frame = None
            self._capture_thread = threading.Thread(
                target=self._capture_loop, daemon=True, name="cam-capture"
            )
            self._capture_thread.start()
        return self

    def _capture_loop(self):
        """Hilo dedicado: lee frames continuamente sin bloquear el event loop."""
        while self._capturing and self.camera and self.camera.isOpened():
            ret, frame = self.camera.read()
            if ret:
                with self._frame_lock:
                    self._latest_frame = frame

    def read(self):
        """Retorna el frame más reciente (no bloquea)."""
        with self._frame_lock:
            if self._latest_frame is None:
                return False, None
            return True, self._latest_frame.copy()

    def desconectar_cliente(self):
        self.clientes_conectados -= 1
        if self.clientes_conectados <= 0:
            self.clientes_conectados = 0
            self._capturing = False
            if self._capture_thread and self._capture_thread.is_alive():
                self._capture_thread.join(timeout=1.0)
            self._capture_thread = None
            if self.camera is not None and self.camera.isOpened():
                self.camera.release()
            self.camera = None
            self._latest_frame = None
            print("Cámara liberada.")

    def liberar_todo(self):
        self._capturing = False
        self.clientes_conectados = 0
        if self._capture_thread and self._capture_thread.is_alive():
            self._capture_thread.join(timeout=1.0)
        self._capture_thread = None
        if self.camera is not None and self.camera.isOpened():
            self.camera.release()
        self.camera = None
        self._latest_frame = None
