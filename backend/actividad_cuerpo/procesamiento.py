import cv2
import numpy as np

class ImageProcessor:
    def __init__(self):
        pass
    
    def crear_confeti_exito(self, frame):
        """
        Agrega confeti de colores al frame cuando se completa una actividad.
        Es ligero y solo se dibuja sobre el frame actual.
        """
        try:
            resultado = frame.copy()
            
            num_particulas = 50
            colores_confeti = [
                (255, 100, 100),  # Rojo
                (100, 255, 100),  # Verde
                (100, 100, 255),  # Azul
                (255, 255, 100),  # Amarillo
                (255, 100, 255),  # Magenta
            ]
            
            for _ in range(num_particulas):
                x = np.random.randint(0, frame.shape[1])
                y = np.random.randint(0, frame.shape[0] // 2)  # Solo mitad superior
                color = colores_confeti[np.random.randint(0, len(colores_confeti))]
                radio = np.random.randint(3, 8)
                
                cv2.circle(resultado, (x, y), radio, color, -1)
            
            return resultado
        except Exception:
            return frame