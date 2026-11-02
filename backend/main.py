from contextlib import asynccontextmanager
from typing import Any, Dict, Optional
from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import cv2
import asyncio
import time
import math
import numpy as np
import sounddevice as sd
import queue

# Importación de Whisper.cpp y LLM
from pywhispercpp.model import Model as WhisperModel
from llama_cpp import Llama

# Módulos locales
from camera_manager import CameraManager
from actividad_cuerpo.detector import PoseDetector
from actividad_cuerpo.actividades import ActivityManager
from actividad_cuerpo.procesamiento import ImageProcessor
from actividad_cuerpo.game_manager import GameManager
from actividad_pictogramas.recognizer import PictogramRecognizer
from actividad_pictogramas.conocimiento import obtener_contexto, obtener_respuesta_directa

# Módulos de Integración (Seguridad JWT, Arduino, Django y Estadísticas/Reportes)
from integracion.seguridad import crear_jwt_token, obtener_profesor_actual
from integracion.arduino_client import arduino_client
from integracion.django_client import gestor_datos
from integracion.mapeo_pedagogico import (
    ARDUINO_CMD_EXITO,
    ARDUINO_CMD_FALLO,
    calcular_indicador_corporal,
    calcular_indicador_pictograma,
    obtener_info_actividad_cuerpo,
    obtener_info_pictograma,
)
from integracion.reportes import (
    calcular_estadisticas_alumno,
    calcular_estadisticas_sesion,
    generar_reporte_html_alumno,
)

# Instancia global
cam_manager = CameraManager()
running = False
detector = None
activity_manager = None
image_processor = None
game_manager = None
pictogram_recognizer = None
llm_model = None
whisper_model = None

# Variables de audio
audio_queue = queue.Queue()
recording = False
audio_stream = None

def callback_audio(indata, _frames, _time_info, _status):
    if recording:
        audio_queue.put(indata.copy())

@asynccontextmanager
async def lifespan(app: FastAPI):
    global running, detector, activity_manager, image_processor, game_manager, pictogram_recognizer, whisper_model, llm_model
    print("Iniciando servidor...")
    
    # Actividad 1: Reconocimiento Corporal
    detector = PoseDetector(model_path='modelos_pose/yolo26n-pose.pt', conf_threshold=0.5)
    activity_manager = ActivityManager()
    image_processor = ImageProcessor()
    game_manager = GameManager()
    
    # Actividad 2: Pictogramas
    pictogram_recognizer = PictogramRecognizer()
    
    # Modelos de IA
    try:
        whisper_model = WhisperModel(
            'modelos_whisper/ggml-small.bin',
            n_threads=4,
            language='es',
            print_progress=False
        )
        print("Whisper.cpp cargado correctamente.")
    except Exception as e:
        print(f"Error cargando Whisper: {e}")
        whisper_model = None

    try:
        llm_model = Llama(
            model_path="modelos_llm/qwen2.5-1.5b-instruct-q4_k_m.gguf",
            n_ctx=512,
            n_threads=4,
            verbose=False
        )
        print("LLM cargado en CPU.")
    except Exception as e:
        print(f"Error cargando LLM: {e}")
    
    running = True
    yield
    running = False
    cam_manager.liberar_todo()

app = FastAPI(lifespan=lifespan)

# ==========================================
# ENDPOINT 1: Actividad de Reconocimiento Corporal
# ==========================================
@app.websocket("/ws")
async def websocket_cuerpo(websocket: WebSocket):
    await websocket.accept()
    cam = cam_manager.conectar_cliente()
    loop = asyncio.get_event_loop()

    try:
        while running:
            ret, frame = cam.read()
            if not ret:
                await asyncio.sleep(0.01)
                continue

            # YOLO en hilo separado: no bloquea el event loop
            keypoints = await loop.run_in_executor(None, detector.detectar_keypoints, frame)
            mensaje_enviar = {}
            frame_procesado = frame.copy()
            
            if game_manager.estado == "esperando_torso":
                if keypoints is not None and activity_manager.detectar_torso_completo(keypoints):
                    mensaje_enviar = game_manager.torso_detectado()
                else:
                    mensaje_enviar = {"evento": "instruccion_postura", "mensaje": "Parate frente a la camara"}
            elif game_manager.estado == "esperando_mano":
                actividad = activity_manager.evaluar_actividad_simple(keypoints)
                if actividad in ["mano_derecha_levantada", "mano_izquierda_levantada"]:
                    mensaje_enviar = game_manager.seleccionar_jugador()
                    await arduino_client.enviar_comando("A3", "Inicio Actividad Corporal")
                else:
                    mensaje_enviar = {"evento": "esperando_mano", "mensaje": "Levanta la mano para comenzar!"}
            elif game_manager.estado == "seleccionado":
                if time.time() - game_manager.tiempo_seleccion > 3.0:
                    mensaje_enviar = game_manager.iniciar_juego()
                else:
                    mensaje_enviar = {"evento": "esperando_inicio", "mensaje": "Preparate!"}
            elif game_manager.estado == "jugando":
                act_simple = activity_manager.evaluar_actividad_simple(keypoints)
                act_ambas = activity_manager.evaluar_ambas_manos_arriba(keypoints)
                evento_a_verificar = "ambas_manos_arriba" if act_ambas else act_simple
                
                coincide, respuesta = game_manager.verificar_actividad(evento_a_verificar, keypoints, activity_manager)
                if coincide:
                    mensaje_enviar = respuesta
                    mensaje_enviar["efecto_visual"] = "flash_exito"

                    # Enviar comando de éxito al Arduino y registrar estadística de acierto
                    id_act = mensaje_enviar.get("id_actividad", "")
                    tiempo_resp = float(mensaje_enviar.get("tiempo_respuesta", 5.0))
                    info_map = obtener_info_actividad_cuerpo(id_act)
                    ind_ped = calcular_indicador_corporal(True, tiempo_resp)

                    await arduino_client.enviar_comando(ARDUINO_CMD_EXITO, f"Acierto: {info_map['instruccion']}")
                    gestor_datos.registrar_evento_actividad(
                        tipo="cuerpo",
                        codigo_bd=info_map["codigo_bd"],
                        area_ref=info_map["area_ref"],
                        area_nombre=info_map["area_nombre"],
                        actividad_nombre=info_map["actividad_nombre"],
                        instruccion=info_map["instruccion"],
                        exito=True,
                        tiempo_seg=tiempo_resp,
                        indicador=ind_ped,
                        intentos=1,
                        orden_id=info_map["orden_id"],
                    )
                    if gestor_datos.sesion_activa_id:
                        await gestor_datos.sincronizar_django_async(
                            "/servicios/addCalificacion_Orden/",
                            {
                                "orden": info_map["orden_id"],
                                "sesion": gestor_datos.sesion_activa_id,
                                "indicador": ind_ped,
                            },
                        )
                else:
                    mensaje_enviar = game_manager.obtener_instruccion_actual()

                    # Si acaba de asignarse una nueva instrucción, enviar estímulo al Arduino
                    if mensaje_enviar.get("evento") == "instruccion_actividad" and mensaje_enviar.get("nueva_instruccion"):
                        info_map = obtener_info_actividad_cuerpo(mensaje_enviar.get("id_actividad", ""))
                        await arduino_client.enviar_comando(info_map["arduino_cmd"], info_map["instruccion"])

                    # Si se agotó el tiempo por primera vez en esta actividad, registrar fallo y notificar Arduino
                    elif mensaje_enviar.get("evento") == "tiempo_agotado" and mensaje_enviar.get("nuevo_fallo"):
                        info_map = obtener_info_actividad_cuerpo(mensaje_enviar.get("id_actividad", ""))
                        tiempo_lim = float(mensaje_enviar.get("tiempo_respuesta", 15.0))
                        await arduino_client.enviar_comando(ARDUINO_CMD_FALLO, f"Tiempo agotado: {info_map['instruccion']}")
                        gestor_datos.registrar_evento_actividad(
                            tipo="cuerpo",
                            codigo_bd=info_map["codigo_bd"],
                            area_ref=info_map["area_ref"],
                            area_nombre=info_map["area_nombre"],
                            actividad_nombre=info_map["actividad_nombre"],
                            instruccion=info_map["instruccion"],
                            exito=False,
                            tiempo_seg=tiempo_lim,
                            indicador="iniciado",
                            intentos=1,
                            orden_id=info_map["orden_id"],
                        )
                        if gestor_datos.sesion_activa_id:
                            await gestor_datos.sincronizar_django_async(
                                "/servicios/addCalificacion_Orden/",
                                {
                                    "orden": info_map["orden_id"],
                                    "sesion": gestor_datos.sesion_activa_id,
                                    "indicador": "iniciado",
                                },
                            )
            elif game_manager.estado == "terminado":
                mensaje_enviar = {"evento": "juego_completado", "mensaje": "Felicidades, completaste todas las actividades"}
                frame_procesado = image_processor.crear_confeti_exito(frame_procesado)
            
            if mensaje_enviar.get("efecto_visual") == "flash_exito" and keypoints is not None and len(keypoints) >= 7:
                kp = keypoints.tolist() if hasattr(keypoints, 'tolist') else keypoints
                h_izq, h_der = kp[5], kp[6]
                if float(h_izq[2]) > 0.5 and float(h_der[2]) > 0.5:
                    cx = (float(h_izq[0]) + float(h_der[0])) / 2.0
                    cy = (float(h_izq[1]) + float(h_der[1])) / 2.0
                    ancho = math.hypot(float(h_izq[0]) - float(h_der[0]), float(h_izq[1]) - float(h_der[1]))
                    mensaje_enviar["centro_cuerpo"] = {"x": cx / 640.0, "y": cy / 480.0, "ancho_hombros": ancho}
            
            frame_to_send = cv2.flip(frame_procesado, 1)
            _, buffer = cv2.imencode('.jpg', frame_to_send, [int(cv2.IMWRITE_JPEG_QUALITY), 65])
            try:
                await websocket.send_bytes(buffer.tobytes())
                await websocket.send_json(mensaje_enviar)
            except Exception:
                break
    except WebSocketDisconnect:
        print("Cliente desconectado")
    finally:
        cam_manager.desconectar_cliente()
        try: await websocket.close()
        except Exception: pass

# ==========================================
# ENDPOINT 2: Actividad de Pictogramas
# ==========================================
@app.websocket("/ws_pictogramas")
async def websocket_pictogramas(websocket: WebSocket):
    global recording, audio_stream
    await websocket.accept()
    cam = cam_manager.conectar_cliente()
    recv_task = None

    try:
        while running:
            # Transmitir frames en vivo mientras se espera el comando de inicio
            recv_task = asyncio.create_task(websocket.receive_json())
            while not recv_task.done():
                ret, frame = cam.read()
                if ret:
                    _, buf = cv2.imencode('.jpg', cv2.flip(frame, 1), [int(cv2.IMWRITE_JPEG_QUALITY), 50])
                    await websocket.send_bytes(buf.tobytes())
                await asyncio.sleep(0.05)
            data = await recv_task
            recv_task = None
            if data.get("accion") != "iniciar_escaneo":
                continue
            intentos = 0
            max_intentos = 2
            await arduino_client.enviar_comando("A1", "Escaneo de Pictograma")

            # FASE 1: DETECCIÓN DEL PICTOGRAMA
            while intentos < max_intentos:
                scan_start = time.time()
                best_score, best_name = -1.0, None

                while time.time() - scan_start < 5.0:
                    ret, frame = cam.read()
                    if not ret:
                        await asyncio.sleep(0.01)
                        continue
                    if frame is None: continue
                    
                    h, w = frame.shape[:2]
                    lado = int(min(w, h) * 0.60)
                    cx, cy = w // 2, h // 2
                    zona_escaneo = frame[cy - lado//2 : cy + lado//2, cx - lado//2 : cx + lado//2]
                    
                    nombre, score, _ = pictogram_recognizer.reconocer(zona_escaneo)
                    
                    if score > 0.9:
                        best_score, best_name = score, nombre
                        break

                    if score > best_score:
                        best_score, best_name = score, nombre
                    
                    _, buffer = cv2.imencode('.jpg', cv2.flip(frame, 1), [int(cv2.IMWRITE_JPEG_QUALITY), 50])
                    try:
                        await websocket.send_bytes(buffer.tobytes())
                    except Exception:
                        return
                    await asyncio.sleep(0.033)
                
                tiempo_escaneo = round(time.time() - scan_start, 2)
                if best_score < 0.7:
                    try:
                        await arduino_client.enviar_comando(ARDUINO_CMD_FALLO, "Pictograma no detectado")
                        gestor_datos.registrar_evento_actividad(
                            tipo="pictogramas",
                            codigo_bd="pic_no_detectado",
                            area_ref="area1_6",
                            area_nombre="Socialización y Comprensión Verbal (Pictogramas)",
                            actividad_nombre="Pictogramas/NoDetectado",
                            instruccion="Escaneo de pictograma sin detección clara",
                            exito=False,
                            tiempo_seg=tiempo_escaneo,
                            indicador="iniciado",
                            intentos=intentos + 1,
                        )
                        await websocket.send_json({"evento": "fallo_deteccion", "tipo": "no_detectado"})
                        await asyncio.sleep(2.0)
                    except Exception: pass
                    break
                
                try:
                    await websocket.send_json({
                        "evento": "propuesta_pictograma",
                        "nombre": best_name or "desconocido",
                        "score": float(best_score)
                    })
                    
                    data_resp = await websocket.receive_json()
                    if data_resp.get("accion") == "confirmar":
                        pictograma_confirmado = best_name or "desconocido"
                        info_pic = obtener_info_pictograma(pictograma_confirmado)
                        ind_pic = calcular_indicador_pictograma(True, intentos + 1)
                        await arduino_client.enviar_comando(ARDUINO_CMD_EXITO, f"Pictograma confirmado: {pictograma_confirmado}")

                        preguntas_realizadas = 0
                        # FASE 2: MODO DE PREGUNTAS ILIMITADAS
                        while running:
                            msg = await websocket.receive_json()
                            cmd = msg.get("comando")
                            
                            if cmd == "iniciar_grabacion":
                                recording = True
                                while not audio_queue.empty(): audio_queue.get_nowait()
                                
                                audio_stream = sd.InputStream(
                                    samplerate=16000, channels=1, dtype='int16', callback=callback_audio
                                )
                                audio_stream.start()
                                await websocket.send_json({"evento": "grabacion_iniciada"})
                                
                            elif cmd == "detener_grabacion":
                                recording = False
                                if audio_stream:
                                    audio_stream.stop()
                                    audio_stream.close()
                                
                                audio_chunks = []
                                while not audio_queue.empty():
                                    try: audio_chunks.append(audio_queue.get_nowait())
                                    except: break
                                
                                if audio_chunks:
                                    preguntas_realizadas += 1
                                    audio_data = np.concatenate(audio_chunks, axis=0)
                                    await _procesar_audio(websocket, audio_data, pictograma_confirmado)
                            
                            elif cmd == "volver":
                                break

                        # Registrar el logro del pictograma y las preguntas realizadas en las estadísticas
                        gestor_datos.registrar_evento_actividad(
                            tipo="pictogramas",
                            codigo_bd=info_pic["codigo_bd"],
                            area_ref=info_pic["area_ref"],
                            area_nombre=info_pic["area_nombre"],
                            actividad_nombre=info_pic["actividad_nombre"],
                            instruccion=f"Pictograma: {pictograma_confirmado} ({preguntas_realizadas} preguntas)",
                            exito=True,
                            tiempo_seg=tiempo_escaneo,
                            indicador=ind_pic,
                            intentos=intentos + 1,
                            actividad_juego_id=info_pic["actividad_juego_id"],
                        )
                        if gestor_datos.sesion_activa_id:
                            await gestor_datos.sincronizar_django_async(
                                "/servicios/addCalificacion_Juego/",
                                {
                                    "actividad_juego": info_pic["actividad_juego_id"],
                                    "sesion": gestor_datos.sesion_activa_id,
                                    "indicador": ind_pic,
                                },
                            )
                        
                        break  # Salir del bucle de intentos
                        
                    elif data_resp.get("accion") == "rechazar":
                        intentos += 1
                except Exception as e:
                    print(f"Error en comunicación: {e}")
                    break
            
            if intentos >= max_intentos:
                try:
                    await arduino_client.enviar_comando(ARDUINO_CMD_FALLO, "Pictograma rechazado 2 veces")
                    gestor_datos.registrar_evento_actividad(
                        tipo="pictogramas",
                        codigo_bd="pic_rechazado",
                        area_ref="area1_6",
                        area_nombre="Socialización y Comprensión Verbal (Pictogramas)",
                        actividad_nombre="Pictogramas/Rechazado",
                        instruccion="Escaneo rechazado en 2 intentos",
                        exito=False,
                        tiempo_seg=10.0,
                        indicador="iniciado",
                        intentos=max_intentos,
                    )
                    await websocket.send_json({"evento": "fallo_deteccion", "tipo": "rechazado_2_veces"})
                    await asyncio.sleep(2.0)
                except Exception: pass
                
    except WebSocketDisconnect:
        print("Cliente desconectado.")
    finally:
        if recv_task and not recv_task.done():
            recv_task.cancel()
        if audio_stream:
            audio_stream.close()
        cam_manager.desconectar_cliente()

# ==========================================
# PROCESAMIENTO DE AUDIO (Whisper.cpp + LLM)
# ==========================================

async def _procesar_audio(websocket: WebSocket, audio_data: np.ndarray, pictograma: str):
    try:
        if not whisper_model or not llm_model:
            await websocket.send_json({"evento": "error_audio", "mensaje": "Modelos no cargados."})
            return
        
        # PREPROCESAMIENTO: Convertir int16 a float32 y normalizar (-1.0 a 1.0)
        audio_float = audio_data.astype(np.float32) / 32768.0
        
        # Transcribir con Whisper.cpp
        segments = whisper_model.transcribe(audio_float, n_threads=4)
        texto_usuario = " ".join([segment.text for segment in segments]).strip()
        
        print(f"Entrada de audio: '{texto_usuario}'")
        
        if not texto_usuario or len(texto_usuario) < 3:
            await websocket.send_json({
                "evento": "respuesta_audio",
                "texto_usuario": "(No se escuchó claramente)",
                "respuesta_sistema": "No te escuché bien, ¿puedes hablar más cerca?"
            })
            return
        
        # 1. Buscar respuesta directa en la base de conocimientos
        respuesta_directa = obtener_respuesta_directa(pictograma, texto_usuario)
        
        if respuesta_directa:
            respuesta_ia = respuesta_directa
        else:
            # 2. Si no hay respuesta directa, usar el LLM con un prompt ULTRA SIMPLE
            contexto_real = obtener_contexto(pictograma)
            
            # PROMPT SIMPLIFICADO: Adaptado a niños de 3 a 5 años
            prompt = f"""Eres un amigo que habla con niños de 3 a 5 años.
Tema: {pictograma.upper()}
Dato real: {contexto_real}
Pregunta del niño: "{texto_usuario}"

Responde con una sola oración corta, alegre y basada SOLO en el dato real. No repitas las reglas.
Respuesta:"""
            
            output = llm_model(
                prompt, 
                max_tokens=35,          # Límite estricto de longitud
                temperature=0.2,        # Baja creatividad para evitar invenciones
                repeat_penalty=1.5,     # Castigo fuerte a la repetición
                stop=["\n", "Reglas", "Respuesta:", "Niño:"] # Detenerse si intenta escribir instrucciones
            )
            
            respuesta_ia = output["choices"][0]["text"].strip()
            
            # LIMPIEZA AGRESIVA: Eliminar comillas y cualquier rastro de instrucciones
            respuesta_ia = respuesta_ia.strip('"\'')
            
            # Si el modelo escribió algo como "Responde con...", lo descartamos y usamos el dato real
            if "responde" in respuesta_ia.lower() or "regla" in respuesta_ia.lower():
                respuesta_ia = f"El {pictograma} es muy interesante y tiene cosas increíbles por descubrir."
            
            # Cortar si sigue siendo muy largo
            palabras = respuesta_ia.split()
            if len(palabras) > 18:
                for i, palabra in enumerate(palabras):
                    if palabra.endswith((".", "!", "?")) and i > 5:
                        respuesta_ia = " ".join(palabras[:i+1])
                        break
                else:
                    respuesta_ia = " ".join(palabras[:15]) + "..."
        
        await websocket.send_json({
            "evento": "respuesta_audio",
            "texto_usuario": texto_usuario,
            "respuesta_sistema": respuesta_ia
        })
        
    except Exception as e:
        print(f"ERROR CRÍTICO en audio: {e}")
        import traceback
        traceback.print_exc()
        await websocket.send_json({
            "evento": "error_audio", 
            "mensaje": "Ups, algo falló. ¡Intenta preguntar de nuevo!"
        })

# ==========================================
# ENDPOINT 3: Reiniciar Juego
# ==========================================
@app.post("/reiniciar")
async def reiniciar_juego():
    game_manager.reiniciar()
    return {"mensaje": "ok"}

# ==========================================
# ENDPOINT 4: Liberar Cámara
# ==========================================
@app.post("/liberar_camara")
async def liberar_camara():
    cam_manager.liberar_todo()
    game_manager.reiniciar()
    return {"mensaje": "ok"}

# ==========================================
# ENDPOINTS 5+: Seguridad OAuth2/JWT, Alumnos, Sesiones, Estadísticas y Reportes
# ==========================================

class LoginRequest(BaseModel):
    username: str
    password: str

class IniciarSesionRequest(BaseModel):
    nn_id: int
    categoria_id: int = 1

class FinalizarSesionRequest(BaseModel):
    sesion_id: Optional[int] = None


def _enriquecer_alumnos_con_estadisticas(alumnos: list) -> list:
    resultado = []
    for a in alumnos:
        stats = calcular_estadisticas_alumno(int(a["id"]))
        resumen = stats["resumen"] if stats else {
            "total_sesiones": 0,
            "total_intentos": 0,
            "total_aciertos": 0,
            "total_fallos": 0,
            "tasa_exito_pct": 0.0,
            "mejora_pct": 0.0,
            "estado_evolucion": "Sin sesiones",
            "detalle_evolucion": "",
        }
        item = dict(a)
        item["estadisticas"] = resumen
        resultado.append(item)
    return resultado


@app.get("/api/estado")
async def estado_sistema():
    """Diagnóstico del sistema para alertas amigables en Godot."""
    return {
        "servidor": "ok",
        "modelos": {
            "pose_yolo": detector is not None,
            "pictogramas_onnx": pictogram_recognizer is not None,
            "whisper_voz": whisper_model is not None,
            "llm_qwen": llm_model is not None,
        },
        "arduino": arduino_client.estado(),
        "django_raspberry_pi": {
            "sincronizado_en_red": gestor_datos.django_online,
            "modo_respaldo_local": True,
        },
        "sesion_activa_id": gestor_datos.sesion_activa_id,
        "alumno_activo_id": gestor_datos.alumno_activo_id,
    }


@app.post("/api/auth/login")
async def login_profesor(datos: LoginRequest):
    """
    Autenticación exclusiva del profesor mediante usuario y contraseña (PBKDF2-SHA256).
    Emite un token JWT firmado con HS256 y devuelve los alumnos asignados al profesor.
    """
    profesor = gestor_datos.autenticar_profesor(datos.username, datos.password)
    if not profesor:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos. Por favor verifique sus datos o contacte al administrador.",
        )

    token = crear_jwt_token(profesor)
    alumnos = gestor_datos.listar_alumnos_por_profesor(int(profesor["id"]))
    alumnos_con_stats = _enriquecer_alumnos_con_estadisticas(alumnos)

    # Sincronización no bloqueante con Django en la Raspberry Pi
    await gestor_datos.sincronizar_django_async(
        "/servicios/api-token-auth/",
        {"username": datos.username, "password": datos.password},
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "profesor": profesor,
        "alumnos": alumnos_con_stats,
    }


@app.get("/api/alumnos")
async def obtener_alumnos_profesor(profesor_actual: Dict[str, Any] = Depends(obtener_profesor_actual)):
    """
    Devuelve únicamente los alumnos asignados al profesor autenticado (nivel único 'Inicial')
    junto con sus estadísticas acumuladas de intentos, aciertos, fallos y mejora.
    """
    prof_id = int(profesor_actual["profesor_id"])
    alumnos = gestor_datos.listar_alumnos_por_profesor(prof_id)
    return {
        "profesor": profesor_actual,
        "alumnos": _enriquecer_alumnos_con_estadisticas(alumnos),
    }


@app.post("/api/sesion/iniciar")
async def api_iniciar_sesion(
    req: IniciarSesionRequest,
    profesor_actual: Dict[str, Any] = Depends(obtener_profesor_actual),
):
    """Inicia una sesión pedagógica para el alumno seleccionado."""
    alumno = gestor_datos.obtener_alumno(req.nn_id)
    if not alumno:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado.")

    prof_id = int(profesor_actual["profesor_id"])
    sesion = gestor_datos.iniciar_sesion(nn_id=req.nn_id, profesor_id=prof_id, categoria_id=req.categoria_id)
    game_manager.reiniciar()

    await gestor_datos.sincronizar_django_async(
        "/servicios/addSesion/",
        {"nn": req.nn_id, "categoria": req.categoria_id},
    )

    return {
        "mensaje": "Sesión iniciada correctamente",
        "sesion": sesion,
        "alumno": alumno,
    }


@app.post("/api/sesion/finalizar")
async def api_finalizar_sesion(
    req: FinalizarSesionRequest,
    profesor_actual: Dict[str, Any] = Depends(obtener_profesor_actual),
):
    """Finaliza la sesión activa y devuelve las estadísticas de la sesión y la evolución del alumno."""
    sesion_cerrada = gestor_datos.finalizar_sesion(req.sesion_id)
    if not sesion_cerrada:
        return {"mensaje": "No había sesión activa para cerrar", "sesion": None}

    await gestor_datos.sincronizar_django_async(
        f"/servicios/updateSesion/{sesion_cerrada['id']}/",
        {"area_visitada": sesion_cerrada.get("area_visitada", "General")},
    )

    stats_sesion = calcular_estadisticas_sesion(sesion_cerrada)
    stats_alumno = calcular_estadisticas_alumno(int(sesion_cerrada["nn"]))

    return {
        "mensaje": "Sesión finalizada correctamente",
        "estadisticas_sesion": stats_sesion,
        "estadisticas_alumno": stats_alumno,
    }


@app.get("/api/estadisticas/alumno/{nn_id}")
async def api_estadisticas_alumno(
    nn_id: int,
    profesor_actual: Dict[str, Any] = Depends(obtener_profesor_actual),
):
    """Obtiene el historial completo de intentos, aciertos, fallos y mejora de un alumno."""
    stats = calcular_estadisticas_alumno(nn_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado.")
    return stats


@app.get("/api/reportes/alumno/{nn_id}/html", response_class=HTMLResponse)
async def api_reporte_alumno_html(nn_id: int, sesion_id: Optional[int] = None):
    """
    Genera y devuelve el reporte oficial individual en HTML listo para imprimir o guardar en PDF.
    """
    html_content = generar_reporte_html_alumno(nn_id=nn_id, sesion_id=sesion_id)
    if not html_content:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado.")
    return HTMLResponse(content=html_content, status_code=200)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)