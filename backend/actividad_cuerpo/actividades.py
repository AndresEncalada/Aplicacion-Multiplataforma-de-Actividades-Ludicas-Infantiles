import math

class ActivityManager:
    def __init__(self):
        self.last_activity_time = 0
        self.cooldown_seconds = 1.5
        
    def calcular_tamano_cuerpo(self, keypoints):
        """Calcula el tamaño del cuerpo usando la distancia entre hombros."""
        try:
            h_izq = keypoints[5] if float(keypoints[5][2]) > 0.5 else None
            h_der = keypoints[6] if float(keypoints[6][2]) > 0.5 else None
            
            if h_izq is None or h_der is None:
                return None
            
            # math.hypot es más rápido y limpio que sqrt(x² + y²)
            tamano = math.hypot(float(h_izq[0]) - float(h_der[0]), float(h_izq[1]) - float(h_der[1]))
            return tamano if tamano > 50 else None
        except Exception:
            return None
    
    def estimar_posicion_dedos(self, codo, muneca, extension=0.6):
        """Estima la posición de los dedos extrapolando el vector codo→muñeca."""
        try:
            if codo is None or muneca is None:
                return (float(muneca[0]), float(muneca[1])) if muneca else None
            
            vx = float(muneca[0]) - float(codo[0])
            vy = float(muneca[1]) - float(codo[1])
            
            return (float(muneca[0]) + (vx * extension), float(muneca[1]) + (vy * extension))
        except Exception:
            return (float(muneca[0]), float(muneca[1])) if muneca else None

    def calcular_distancia(self, p1, p2):
        """Calcula distancia euclidiana entre dos puntos (x, y)."""
        if p1 is None or p2 is None:
            return float('inf')
        return math.hypot(p1[0] - p2[0], p1[1] - p2[1])
    
    def detectar_torso_completo(self, keypoints):
        """Verifica si el torso es visible (al menos hombros)."""
        try:
            h_izq = keypoints[5] if float(keypoints[5][2]) > 0.5 else None
            h_der = keypoints[6] if float(keypoints[6][2]) > 0.5 else None
            return h_izq is not None and h_der is not None
        except Exception:
            return False
    
    def evaluar_actividad_simple(self, keypoints):
        """Evalúa actividades simples (manos levantadas) sin cálculos de distancia."""
        try:
            if keypoints is None or len(keypoints) < 17:
                return None
            
            h_izq = keypoints[5] if float(keypoints[5][2]) > 0.5 else None
            h_der = keypoints[6] if float(keypoints[6][2]) > 0.5 else None
            m_izq = keypoints[9] if float(keypoints[9][2]) > 0.5 else None
            m_der = keypoints[10] if float(keypoints[10][2]) > 0.5 else None
            
            if m_der is not None and h_der is not None and float(m_der[1]) < (float(h_der[1]) - 30):
                return "mano_derecha_levantada"
            
            if m_izq is not None and h_izq is not None and float(m_izq[1]) < (float(h_izq[1]) - 30):
                return "mano_izquierda_levantada"
            
            return None
        except Exception:
            return None
    
    def evaluar_actividad_toque(self, keypoints, objetivo):
        """Evalúa actividades de 'tocar X' extrapolando la posición de los dedos."""
        try:
            if keypoints is None or len(keypoints) < 17:
                return False
            
            # Convertir a lista nativa para evitar conflictos de NumPy
            kp = keypoints.tolist() if hasattr(keypoints, 'tolist') else keypoints
            
            nariz = kp[0] if float(kp[0][2]) > 0.5 else None
            oreja_izq = kp[3] if float(kp[3][2]) > 0.5 else None
            oreja_der = kp[4] if float(kp[4][2]) > 0.5 else None
            hombro_izq = kp[5] if float(kp[5][2]) > 0.5 else None
            hombro_der = kp[6] if float(kp[6][2]) > 0.5 else None
            codo_izq = kp[7] if float(kp[7][2]) > 0.5 else None
            codo_der = kp[8] if float(kp[8][2]) > 0.5 else None
            muneca_izq = kp[9] if float(kp[9][2]) > 0.5 else None
            muneca_der = kp[10] if float(kp[10][2]) > 0.5 else None
            cadera_izq = kp[11] if float(kp[11][2]) > 0.5 else None
            cadera_der = kp[12] if float(kp[12][2]) > 0.5 else None
            
            tamano_cuerpo = self.calcular_tamano_cuerpo(keypoints)
            if tamano_cuerpo is None:
                return False
            
            # Estimar posición de los dedos (extrapolación 0.6)
            dedos = []
            if codo_izq is not None and muneca_izq is not None:
                dedos.append(self.estimar_posicion_dedos(codo_izq, muneca_izq, 0.6))
            if codo_der is not None and muneca_der is not None:
                dedos.append(self.estimar_posicion_dedos(codo_der, muneca_der, 0.6))
            
            # Fallback a muñeca si no hay codo detectado
            if not dedos:
                if muneca_izq is not None:
                    dedos.append((float(muneca_izq[0]), float(muneca_izq[1])))
                if muneca_der is not None:
                    dedos.append((float(muneca_der[0]), float(muneca_der[1])))
            
            if not dedos:
                return False
            
            # Evaluar según el objetivo
            if objetivo == "cabeza":
                puntos = [p for p in [nariz, oreja_izq, oreja_der] if p is not None]
                if not puntos:
                    return False
                umbral = tamano_cuerpo * 0.50
                for mx, my in dedos:
                    for px, py, _ in puntos:
                        if self.calcular_distancia((mx, my), (float(px), float(py))) < umbral:
                            return True

            elif objetivo == "orejas":
                puntos = [p for p in [oreja_izq, oreja_der] if p is not None]
                if not puntos:
                    return False
                umbral = tamano_cuerpo * 0.40
                for mx, my in dedos:
                    for px, py, _ in puntos:
                        if self.calcular_distancia((mx, my), (float(px), float(py))) < umbral:
                            return True

            elif objetivo == "hombros":
                puntos = [p for p in [hombro_izq, hombro_der] if p is not None]
                if not puntos:
                    return False
                umbral = tamano_cuerpo * 0.40
                for mx, my in dedos:
                    for px, py, _ in puntos:
                        if self.calcular_distancia((mx, my), (float(px), float(py))) < umbral:
                            return True

            elif objetivo == "cintura":
                if cadera_izq is None or cadera_der is None:
                    return False
                centro_x = (float(cadera_izq[0]) + float(cadera_der[0])) / 2.0
                centro_y = (float(cadera_izq[1]) + float(cadera_der[1])) / 2.0
                umbral = tamano_cuerpo * 0.45
                for mx, my in dedos:
                    if self.calcular_distancia((mx, my), (centro_x, centro_y)) < umbral:
                        return True
            elif objetivo == "pecho":
                # El centro del pecho está a mitad de camino entre los hombros y las caderas
                if hombro_izq is None or cadera_der is None:
                    return False
                
                # Usamos el centro geométrico del torso
                centro_x = (float(hombro_izq[0]) + float(cadera_der[0])) / 2.0
                centro_y = (float(hombro_izq[1]) + float(cadera_der[1])) / 2.0
                
                # Umbral amplio porque el pecho es una zona grande
                umbral = tamano_cuerpo * 0.45
                
                for mx, my in dedos:
                    if self.calcular_distancia((mx, my), (centro_x, centro_y)) < umbral:
                        return True

            elif objetivo == "cuello":
                # El cuello está entre los hombros y la nariz
                if hombro_izq is None or nariz is None:
                    return False
                
                centro_x = (float(hombro_izq[0]) + float(nariz[0])) / 2.0
                centro_y = (float(hombro_izq[1]) + float(nariz[1])) / 2.0
                
                # Umbral pequeño porque el cuello es una zona reducida
                umbral = tamano_cuerpo * 0.25
                
                for mx, my in dedos:
                    if self.calcular_distancia((mx, my), (centro_x, centro_y)) < umbral:
                        return True

            elif objetivo == "cruzar_brazos":
                # Para cruzar los brazos, AMBAS manos deben estar tocando los hombros
                # (Mano izquierda en hombro derecho y viceversa, o ambas en el centro)
                if hombro_izq is None or hombro_der is None:
                    return False
                
                umbral = tamano_cuerpo * 0.40
                
                # Verificar si hay al menos una mano cerca de CADA hombro
                mano_en_hombro_izq = False
                mano_en_hombro_der = False
                
                for mx, my in dedos:
                    if self.calcular_distancia((mx, my), (float(hombro_izq[0]), float(hombro_izq[1]))) < umbral:
                        mano_en_hombro_izq = True
                    if self.calcular_distancia((mx, my), (float(hombro_der[0]), float(hombro_der[1]))) < umbral:
                        mano_en_hombro_der = True
                
                # Solo se valida si ambas condiciones son verdaderas
                if mano_en_hombro_izq and mano_en_hombro_der:
                    return True
            return False
            
        except Exception:
            return False
    def evaluar_ambas_manos_arriba(self, keypoints):
        """Detecta si ambas manos están levantadas por encima de los hombros."""
        try:
            if keypoints is None or len(keypoints) < 17:
                return False
            
            kp = keypoints.tolist() if hasattr(keypoints, 'tolist') else keypoints
            
            hombro_izq = kp[5] if float(kp[5][2]) > 0.5 else None
            hombro_der = kp[6] if float(kp[6][2]) > 0.5 else None
            muneca_izq = kp[9] if float(kp[9][2]) > 0.5 else None
            muneca_der = kp[10] if float(kp[10][2]) > 0.5 else None
            
            if hombro_izq and hombro_der and muneca_izq and muneca_der:
                # En imágenes, Y es menor cuanto más arriba está
                mano_izq_arriba = float(muneca_izq[1]) < (float(hombro_izq[1]) - 30)
                mano_der_arriba = float(muneca_der[1]) < (float(hombro_der[1]) - 30)
                return mano_izq_arriba and mano_der_arriba
            
            return False
        except Exception:
            return False