import time
import random

class GameManager:
    def __init__(self):
        self.estado = "esperando_torso"
        self.tiempo_seleccion = 0
        self.cooldown_hasta = 0
        
        # Pool de todas las actividades posibles
        self.pool_actividades = [
            # Manos y brazos
            {"id": "mano_derecha_levantada", "instruccion": "Levanta tu mano derecha", "tipo": "simple"},
            {"id": "mano_izquierda_levantada", "instruccion": "Levanta tu mano izquierda", "tipo": "simple"},
            {"id": "ambas_manos_arriba", "instruccion": "Levanta ambas manos", "tipo": "simple"},
            {"id": "cruzar_brazos", "instruccion": "Cruza los brazos", "tipo": "toque", "objetivo": "cruzar_brazos"},
            # Cabeza y cara
            {"id": "tocar_cabeza", "instruccion": "Toca tu cabeza", "tipo": "toque", "objetivo": "cabeza"},
            {"id": "tocar_orejas", "instruccion": "Toca tus orejas", "tipo": "toque", "objetivo": "orejas"},
            {"id": "tocar_cuello", "instruccion": "Toca tu cuello", "tipo": "toque", "objetivo": "cuello"},
            # Torso
            {"id": "tocar_hombros", "instruccion": "Toca tus hombros", "tipo": "toque", "objetivo": "hombros"},
            {"id": "tocar_pecho", "instruccion": "Toca tu pecho", "tipo": "toque", "objetivo": "pecho"},
            {"id": "tocar_cintura", "instruccion": "Pon las manos en la cintura", "tipo": "toque", "objetivo": "cintura"}
        ]
        
        self.secuencia_actividades = []
        self.indice_actividad_actual = 0
        self.tiempo_inicio_actividad = 0
        self.tiempo_limite_actividad = 15.0
        
    def torso_detectado(self):
        self.estado = "esperando_mano"
        return {"evento": "torso_detectado", "mensaje": "Muy bien, ahora levanta la mano"}
    
    def seleccionar_jugador(self):
        self.estado = "seleccionado"
        self.tiempo_seleccion = time.time()
        return {"evento": "jugador_seleccionado", "mensaje": "Te elegi a ti"}
    
    def iniciar_juego(self):
        self.estado = "jugando"
        self.indice_actividad_actual = 0
        self.tiempo_inicio_actividad = time.time()
        
        # ELEGIR 10 ACTIVIDADES AL AZAR DEL POOL
        self.secuencia_actividades =  random.choices(self.pool_actividades, k=10)
        
        return self.obtener_instruccion_actual()
    
    def obtener_instruccion_actual(self):
        if self.indice_actividad_actual >= len(self.secuencia_actividades):
            return self.completar_juego()
        
        actividad = self.secuencia_actividades[self.indice_actividad_actual]
        
        # Calcular tiempo restante
        tiempo_restante = self.tiempo_limite_actividad - (time.time() - self.tiempo_inicio_actividad)
        
        # Si el tiempo se acabó, enviar evento de derrota
        if tiempo_restante <= 0:
            return {"evento": "tiempo_agotado", "mensaje": "Se acabó el tiempo"}
        
        return {
            "evento": "instruccion_actividad",
            "mensaje": actividad["instruccion"],
            "progreso": f"{self.indice_actividad_actual + 1}/10",
            "tiempo_restante": tiempo_restante,
            "tipo": actividad["tipo"],
            "objetivo": actividad.get("objetivo")
        }
    
    def actividad_completada(self):
        self.indice_actividad_actual += 1
        self.tiempo_inicio_actividad = time.time()
        self.cooldown_hasta = time.time() + 2.0
        
        # Acelerar gradualmente: de 15s a 8s
        progreso = self.indice_actividad_actual / 10.0
        self.tiempo_limite_actividad = 15.0 - (progreso * 7.0)
        
        if self.indice_actividad_actual >= 10:
            return self.completar_juego()
        
        return {
            "evento": "actividad_exitosa",
            "mensaje": "Muy bien",
            "progreso": f"{self.indice_actividad_actual}/10"
        }
    
    def completar_juego(self):
        self.estado = "terminado"
        return {"evento": "juego_completado", "mensaje": "Felicidades, completaste todas las actividades"}
    
    def reiniciar(self):
        self.estado = "esperando_torso"
        self.indice_actividad_actual = 0
        self.tiempo_limite_actividad = 15.0
        self.cooldown_hasta = 0
        self.secuencia_actividades = []
    
    def verificar_actividad(self, evento_actividad, keypoints, activity_manager):
        if self.estado != "jugando":
            return False, None
        
        if time.time() < self.cooldown_hasta:
            return False, None
        
        actividad_actual = self.secuencia_actividades[self.indice_actividad_actual]
        
        if actividad_actual["tipo"] == "simple":
            if evento_actividad == actividad_actual["id"]:
                return True, self.actividad_completada()
            return False, None
        
        if actividad_actual["tipo"] == "toque":
            if activity_manager.evaluar_actividad_toque(keypoints, actividad_actual["objetivo"]):
                return True, self.actividad_completada()
            return False, None
        
        return False, None