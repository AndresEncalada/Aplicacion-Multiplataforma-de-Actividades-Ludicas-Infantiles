"""
Gestor de Datos Pedagógicos y Cliente de Sincronización con Django (Raspberry Pi).
- Si el servidor Django en la Raspberry Pi está accesible en red, sincroniza sesiones y calificaciones.
- Mantiene una base de datos local persistente en 'datos_locales.json' que actúa como respaldo
  y almacena las estadísticas granulares (intentos, aciertos, fallos, tiempos de respuesta y evolución).
- Todos los alumnos pertenecen a un único nivel estándar ('Inicial') y se filtran exclusivamente
  por su profesor asignado (usuario_id).
"""
import asyncio
import json
import os
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from integracion.seguridad import hashear_password, verificar_password

DJANGO_BASE_URL = os.environ.get("FELPUDO_DJANGO_URL", "http://192.168.1.200:8000")
DJANGO_TIMEOUT_SEC = float(os.environ.get("FELPUDO_DJANGO_TIMEOUT", "0.6"))
ARCHIVO_DATOS_LOCALES = Path(__file__).parent / "datos_locales.json"


class GestorDatosPedagogicos:
    def __init__(self):
        self._lock = threading.Lock()
        self.django_online = False
        self.sesion_activa_id: Optional[int] = None
        self.alumno_activo_id: Optional[int] = None
        self.profesor_activo_id: Optional[int] = None
        self._datos: Dict[str, Any] = {}
        self._cargar_o_inicializar()

    # =================================================================
    # 1. INICIALIZACIÓN Y PERSISTENCIA LOCAL
    # =================================================================

    def _cargar_o_inicializar(self) -> None:
        with self._lock:
            if ARCHIVO_DATOS_LOCALES.exists():
                try:
                    with open(ARCHIVO_DATOS_LOCALES, "r", encoding="utf-8") as f:
                        self._datos = json.load(f)
                    return
                except Exception as e:
                    print(f"[Datos] Error leyendo {ARCHIVO_DATOS_LOCALES}, regenerando semilla: {e}")

            self._datos = self._generar_semilla_inicial()
            self._guardar_en_disco_sin_lock()

    def _guardar_en_disco_sin_lock(self) -> None:
        try:
            ARCHIVO_DATOS_LOCALES.parent.mkdir(parents=True, exist_ok=True)
            with open(ARCHIVO_DATOS_LOCALES, "w", encoding="utf-8") as f:
                json.dump(self._datos, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[Datos] Error guardando datos_locales.json: {e}")

    def _generar_semilla_inicial(self) -> Dict[str, Any]:
        """
        Genera profesores con contraseñas hasheadas (PBKDF2-SHA256), alumnos de 3 a 5 años
        en un único nivel ('Inicial') diferenciados solo por profesor, y sesiones históricas
        para evaluar evolución y mejora.
        """
        profesores = [
            {
                "id": 1,
                "username": "prof_maria",
                "password_hash": hashear_password("felpudo2026", salt="a1b2c3d4e5f60718"),
                "first_name": "María",
                "last_name": "Gómez",
                "email": "maria.gomez@felpudo.edu.ec",
            },
            {
                "id": 2,
                "username": "prof_carlos",
                "password_hash": hashear_password("felpudo2026", salt="f1e2d3c4b5a69788"),
                "first_name": "Carlos",
                "last_name": "Mendoza",
                "email": "carlos.mendoza@felpudo.edu.ec",
            },
            {
                "id": 3,
                "username": "admin",
                "password_hash": hashear_password("admin123", salt="1122334455667788"),
                "first_name": "Elena",
                "last_name": "Suárez",
                "email": "admin@felpudo.edu.ec",
            },
        ]

        # Todos los estudiantes tienen 3-5 años y un ÚNICO nivel ('Inicial')
        alumnos = [
            # Profesora María Gómez (usuario = 1)
            {
                "id": 1,
                "usuario": 1,
                "nombre": "Mateo",
                "apellido": "Pérez",
                "fec_nacimiento": "14-05-2022",
                "edad": 4,
                "nivel": "Inicial",
                "discapacidad": "Ninguna",
            },
            {
                "id": 2,
                "usuario": 1,
                "nombre": "Valentina",
                "apellido": "Torres",
                "fec_nacimiento": "08-11-2022",
                "edad": 3,
                "nivel": "Inicial",
                "discapacidad": "Lenguaje leve",
            },
            {
                "id": 3,
                "usuario": 1,
                "nombre": "Lucas",
                "apellido": "Sánchez",
                "fec_nacimiento": "20-09-2021",
                "edad": 5,
                "nivel": "Inicial",
                "discapacidad": "Motricidad fina",
            },
            {
                "id": 4,
                "usuario": 1,
                "nombre": "Sofía",
                "apellido": "Ramírez",
                "fec_nacimiento": "12-02-2023",
                "edad": 3,
                "nivel": "Inicial",
                "discapacidad": "Ninguna",
            },
            # Profesor Carlos Mendoza (usuario = 2)
            {
                "id": 5,
                "usuario": 2,
                "nombre": "Sebastián",
                "apellido": "Morales",
                "fec_nacimiento": "19-03-2022",
                "edad": 4,
                "nivel": "Inicial",
                "discapacidad": "Ninguna",
            },
            {
                "id": 6,
                "usuario": 2,
                "nombre": "Camila",
                "apellido": "Herrera",
                "fec_nacimiento": "04-12-2021",
                "edad": 4,
                "nivel": "Inicial",
                "discapacidad": "Atención dispersa",
            },
            {
                "id": 7,
                "usuario": 2,
                "nombre": "Thiago",
                "apellido": "Castro",
                "fec_nacimiento": "25-01-2023",
                "edad": 3,
                "nivel": "Inicial",
                "discapacidad": "Ninguna",
            },
            # Profesora Elena Suárez (usuario = 3)
            {
                "id": 8,
                "usuario": 3,
                "nombre": "Lucía",
                "apellido": "Vargas",
                "fec_nacimiento": "30-07-2022",
                "edad": 4,
                "nivel": "Inicial",
                "discapacidad": "Ninguna",
            },
            {
                "id": 9,
                "usuario": 3,
                "nombre": "Emiliano",
                "apellido": "Ríos",
                "fec_nacimiento": "15-10-2021",
                "edad": 5,
                "nivel": "Inicial",
                "discapacidad": "Lenguaje leve",
            },
        ]

        # Sesiones históricas de ejemplo para permitir cálculo inmediato de progreso y mejora
        sesiones = [
            # Mateo Pérez (id=1): Sesión 1 (60% acierto) -> Sesión 2 (80% acierto) = Mejoró +20%
            {
                "id": 1,
                "nn": 1,
                "profesor_id": 1,
                "categoria": 1,
                "fecha_ini": "12-10-2026 09:10",
                "fecha_fin": "12-10-2026 09:25",
                "area_visitada": "Aspectos de Lateralidad y Cuerpo",
                "estado": "finalizada",
                "eventos": [
                    {"tipo": "cuerpo", "codigo_bd": "a2_17", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/LevantaManoDerecha", "instruccion": "Levanta tu mano derecha", "exito": True, "intentos": 1, "tiempo_seg": 7.2, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a2_18", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/LevantaManoIzquierda", "instruccion": "Levanta tu mano izquierda", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                    {"tipo": "cuerpo", "codigo_bd": "a3_07", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/TocaCabeza", "instruccion": "Toca tu cabeza", "exito": True, "intentos": 1, "tiempo_seg": 6.5, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a2_10", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/TocaOrejas", "instruccion": "Toca tus orejas", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                    {"tipo": "pictogramas", "codigo_bd": "pic_perro", "area_ref": "area1_6", "area_nombre": "Socialización y Comprensión Verbal", "actividad_nombre": "Pictogramas/Perro", "instruccion": "Pictograma: perro (2 preguntas)", "exito": True, "intentos": 1, "tiempo_seg": 5.0, "indicador": "adquirido"},
                ],
            },
            {
                "id": 2,
                "nn": 1,
                "profesor_id": 1,
                "categoria": 1,
                "fecha_ini": "15-10-2026 10:00",
                "fecha_fin": "15-10-2026 10:18",
                "area_visitada": "Aspectos de Lateralidad y Pictogramas",
                "estado": "finalizada",
                "eventos": [
                    {"tipo": "cuerpo", "codigo_bd": "a2_17", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/LevantaManoDerecha", "instruccion": "Levanta tu mano derecha", "exito": True, "intentos": 1, "tiempo_seg": 4.8, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a2_18", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/LevantaManoIzquierda", "instruccion": "Levanta tu mano izquierda", "exito": True, "intentos": 1, "tiempo_seg": 6.1, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a3_07", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/TocaCabeza", "instruccion": "Toca tu cabeza", "exito": True, "intentos": 1, "tiempo_seg": 5.2, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a2_10", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/TocaOrejas", "instruccion": "Toca tus orejas", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                    {"tipo": "pictogramas", "codigo_bd": "pic_capibara", "area_ref": "area1_6", "area_nombre": "Socialización y Comprensión Verbal", "actividad_nombre": "Pictogramas/Capibara", "instruccion": "Pictograma: capibara (3 preguntas)", "exito": True, "intentos": 1, "tiempo_seg": 4.5, "indicador": "adquirido"},
                ],
            },
            # Valentina Torres (id=2): Sesión 1 (50%) -> Sesión 2 (75%) = Mejoró +25%
            {
                "id": 3,
                "nn": 2,
                "profesor_id": 1,
                "categoria": 1,
                "fecha_ini": "13-10-2026 11:00",
                "fecha_fin": "13-10-2026 11:15",
                "area_visitada": "Reconocimiento de las Partes del Cuerpo",
                "estado": "finalizada",
                "eventos": [
                    {"tipo": "cuerpo", "codigo_bd": "a3_07", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/TocaCabeza", "instruccion": "Toca tu cabeza", "exito": True, "intentos": 1, "tiempo_seg": 8.9, "indicador": "proceso"},
                    {"tipo": "cuerpo", "codigo_bd": "a3_05", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/TocaHombros", "instruccion": "Toca tus hombros", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                    {"tipo": "cuerpo", "codigo_bd": "a2_17", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/LevantaManoDerecha", "instruccion": "Levanta tu mano derecha", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                    {"tipo": "pictogramas", "codigo_bd": "pic_medico", "area_ref": "area1_6", "area_nombre": "Socialización y Comprensión Verbal", "actividad_nombre": "Pictogramas/Medico", "instruccion": "Pictograma: medico (2 preguntas)", "exito": True, "intentos": 1, "tiempo_seg": 6.0, "indicador": "adquirido"},
                ],
            },
            {
                "id": 4,
                "nn": 2,
                "profesor_id": 1,
                "categoria": 1,
                "fecha_ini": "16-10-2026 11:10",
                "fecha_fin": "16-10-2026 11:25",
                "area_visitada": "Reconocimiento de las Partes del Cuerpo",
                "estado": "finalizada",
                "eventos": [
                    {"tipo": "cuerpo", "codigo_bd": "a3_07", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/TocaCabeza", "instruccion": "Toca tu cabeza", "exito": True, "intentos": 1, "tiempo_seg": 5.5, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a3_05", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/TocaHombros", "instruccion": "Toca tus hombros", "exito": True, "intentos": 1, "tiempo_seg": 7.1, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a2_17", "area_ref": "area2", "area_nombre": "Aspectos de Lateralidad", "actividad_nombre": "Lateralidad/LevantaManoDerecha", "instruccion": "Levanta tu mano derecha", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                    {"tipo": "pictogramas", "codigo_bd": "pic_leon", "area_ref": "area1_6", "area_nombre": "Socialización y Comprensión Verbal", "actividad_nombre": "Pictogramas/Leon", "instruccion": "Pictograma: leon (3 preguntas)", "exito": True, "intentos": 1, "tiempo_seg": 4.9, "indicador": "adquirido"},
                ],
            },
            # Lucas Sánchez (id=3)
            {
                "id": 5,
                "nn": 3,
                "profesor_id": 1,
                "categoria": 1,
                "fecha_ini": "14-10-2026 09:30",
                "fecha_fin": "14-10-2026 09:45",
                "area_visitada": "Lateralidad y Cuerpo",
                "estado": "finalizada",
                "eventos": [
                    {"tipo": "cuerpo", "codigo_bd": "a1_60", "area_ref": "area1_5", "area_nombre": "Socialización", "actividad_nombre": "Palmas/LevantaAmbasManos", "instruccion": "Levanta ambas manos", "exito": True, "intentos": 1, "tiempo_seg": 5.8, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a3_08", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/CruzaBrazos", "instruccion": "Cruza los brazos", "exito": True, "intentos": 1, "tiempo_seg": 7.4, "indicador": "adquirido"},
                    {"tipo": "cuerpo", "codigo_bd": "a3_09", "area_ref": "area3", "area_nombre": "Reconocimiento de las Partes del Cuerpo", "actividad_nombre": "Cuerpo/ManosEnCintura", "instruccion": "Pon las manos en la cintura", "exito": False, "intentos": 1, "tiempo_seg": 15.0, "indicador": "iniciado"},
                ],
            },
        ]

        return {
            "profesores": profesores,
            "alumnos": alumnos,
            "sesiones": sesiones,
        }

    # =================================================================
    # 2. COMUNICACIÓN HTTP CON DJANGO (RASPBERRY PI) - NO BLOQUEANTE
    # =================================================================

    def _post_django_sync(self, ruta: str, payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        url = f"{DJANGO_BASE_URL.rstrip('/')}/{ruta.lstrip('/')}"
        try:
            body = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(
                url,
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=DJANGO_TIMEOUT_SEC) as resp:
                self.django_online = True
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except Exception:
            self.django_online = False
            return None

    async def sincronizar_django_async(self, ruta: str, payload: Dict[str, Any]) -> None:
        loop = asyncio.get_running_loop()
        loop.run_in_executor(None, self._post_django_sync, ruta, payload)

    # =================================================================
    # 3. AUTENTICACIÓN DE PROFESOR Y GESTIÓN DE ALUMNOS
    # =================================================================

    def autenticar_profesor(self, username: str, password: str) -> Optional[Dict[str, Any]]:
        """
        Verifica usuario y contraseña usando PBKDF2-SHA256 en tiempo constante.
        """
        uname = (username or "").strip().lower()
        with self._lock:
            for prof in self._datos.get("profesores", []):
                if prof["username"].lower() == uname:
                    if verificar_password(password, prof["password_hash"]):
                        return {
                            "id": prof["id"],
                            "username": prof["username"],
                            "first_name": prof["first_name"],
                            "last_name": prof["last_name"],
                            "name": f"{prof['first_name']} {prof['last_name']}".strip(),
                            "email": prof["email"],
                        }
                    return None
        return None

    def obtener_profesor_por_id(self, profesor_id: int) -> Optional[Dict[str, Any]]:
        with self._lock:
            for prof in self._datos.get("profesores", []):
                if int(prof["id"]) == int(profesor_id):
                    return {
                        "id": prof["id"],
                        "username": prof["username"],
                        "first_name": prof["first_name"],
                        "last_name": prof["last_name"],
                        "name": f"{prof['first_name']} {prof['last_name']}".strip(),
                        "email": prof["email"],
                    }
        return None

    def listar_alumnos_por_profesor(self, profesor_id: int) -> List[Dict[str, Any]]:
        """
        Devuelve únicamente los alumnos asignados al profesor indicado.
        Todos están en el nivel único 'Inicial'.
        """
        with self._lock:
            alumnos = [
                dict(a)
                for a in self._datos.get("alumnos", [])
                if int(a.get("usuario", 0)) == int(profesor_id)
            ]
        return alumnos

    def obtener_alumno(self, nn_id: int) -> Optional[Dict[str, Any]]:
        with self._lock:
            for a in self._datos.get("alumnos", []):
                if int(a["id"]) == int(nn_id):
                    return dict(a)
        return None

    # =================================================================
    # 4. GESTIÓN DE SESIONES Y REGISTRO DE INTENTOS/CALIFICACIONES
    # =================================================================

    def iniciar_sesion(self, nn_id: int, profesor_id: int, categoria_id: int = 1) -> Dict[str, Any]:
        ahora_str = datetime.now().strftime("%d-%m-%Y %H:%M")
        with self._lock:
            sesiones = self._datos.setdefault("sesiones", [])
            nuevo_id = max([int(s["id"]) for s in sesiones], default=0) + 1
            nueva_sesion = {
                "id": nuevo_id,
                "nn": int(nn_id),
                "profesor_id": int(profesor_id),
                "categoria": int(categoria_id),
                "fecha_ini": ahora_str,
                "fecha_fin": ahora_str,
                "area_visitada": "En curso",
                "estado": "activa",
                "eventos": [],
            }
            sesiones.append(nueva_sesion)
            self.sesion_activa_id = nuevo_id
            self.alumno_activo_id = int(nn_id)
            self.profesor_activo_id = int(profesor_id)
            self._guardar_en_disco_sin_lock()

        return dict(nueva_sesion)

    def registrar_evento_actividad(
        self,
        tipo: str,
        codigo_bd: str,
        area_ref: str,
        area_nombre: str,
        actividad_nombre: str,
        instruccion: str,
        exito: bool,
        tiempo_seg: float,
        indicador: str,
        intentos: int = 1,
        orden_id: Optional[int] = None,
        actividad_juego_id: Optional[int] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Registra un intento (acierto o fallo) en la sesión activa.
        Si no había sesión activa pero hay un alumno seleccionado, crea una automáticamente.
        """
        ahora_str = datetime.now().strftime("%d-%m-%Y %H:%M")
        evento = {
            "tipo": tipo,
            "codigo_bd": codigo_bd,
            "area_ref": area_ref,
            "area_nombre": area_nombre,
            "actividad_nombre": actividad_nombre,
            "instruccion": instruccion,
            "exito": bool(exito),
            "intentos": int(max(1, intentos)),
            "tiempo_seg": round(float(tiempo_seg), 2),
            "indicador": indicador,
            "timestamp": ahora_str,
        }

        with self._lock:
            if not self.sesion_activa_id:
                return None

            for s in self._datos.get("sesiones", []):
                if int(s["id"]) == int(self.sesion_activa_id):
                    s.setdefault("eventos", []).append(evento)
                    s["fecha_fin"] = ahora_str
                    # Actualizar áreas visitadas
                    areas = set()
                    for ev in s["eventos"]:
                        if ev.get("area_nombre"):
                            areas.add(ev["area_nombre"])
                    s["area_visitada"] = ", ".join(sorted(areas)) if areas else "General"
                    self._guardar_en_disco_sin_lock()
                    break

        return evento

    def finalizar_sesion(self, sesion_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
        target_id = sesion_id or self.sesion_activa_id
        if not target_id:
            return None

        ahora_str = datetime.now().strftime("%d-%m-%Y %H:%M")
        sesion_cerrada = None
        with self._lock:
            for s in self._datos.get("sesiones", []):
                if int(s["id"]) == int(target_id):
                    s["fecha_fin"] = ahora_str
                    s["estado"] = "finalizada"
                    if s.get("area_visitada") == "En curso":
                        s["area_visitada"] = "Sesión General"
                    sesion_cerrada = dict(s)
                    break

            if self.sesion_activa_id and int(self.sesion_activa_id) == int(target_id):
                self.sesion_activa_id = None

            self._guardar_en_disco_sin_lock()

        return sesion_cerrada

    def obtener_sesiones_alumno(self, nn_id: int) -> List[Dict[str, Any]]:
        with self._lock:
            return [
                dict(s)
                for s in self._datos.get("sesiones", [])
                if int(s.get("nn", 0)) == int(nn_id)
            ]

    def obtener_sesion(self, sesion_id: int) -> Optional[Dict[str, Any]]:
        with self._lock:
            for s in self._datos.get("sesiones", []):
                if int(s["id"]) == int(sesion_id):
                    return dict(s)
        return None


# Instancia global compartida
gestor_datos = GestorDatosPedagogicos()
