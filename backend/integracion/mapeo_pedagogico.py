"""
Mapeador Pedagógico entre:
1. Actividades Corporales (YOLO-Pose) y Pictogramas (ONNX + Voz)
2. Base de datos de la Raspberry Pi (backup_tesis.sql: areas_orden, areas_area, juegos_actividad_juego)
3. Protocolo Serial del Arduino del peluche Felpudo (A1..A3, MD4, MI5, CA3, OD2, BR1, CC, NA)

Diseñado para niños de 3 a 5 años en un único nivel estándar ("Inicial").
"""
from typing import Any, Dict

# Mapeo de las 10 actividades corporales de game_manager.py hacia backup_tesis.sql y Arduino
MAPEO_ACTIVIDADES_CUERPO: Dict[str, Dict[str, Any]] = {
    "mano_derecha_levantada": {
        "orden_id": 65,
        "codigo_bd": "a2_17",
        "instruccion": "Levanta tu mano derecha",
        "area_id": 2,
        "area_ref": "area2",
        "area_nombre": "Aspectos de Lateralidad",
        "actividad_id": 7,
        "actividad_nombre": "Lateralidad/LevantaManoDerecha",
        "arduino_area": "A2",
        "arduino_cmd": "MD4",
    },
    "mano_izquierda_levantada": {
        "orden_id": 66,
        "codigo_bd": "a2_18",
        "instruccion": "Levanta tu mano izquierda",
        "area_id": 2,
        "area_ref": "area2",
        "area_nombre": "Aspectos de Lateralidad",
        "actividad_id": 7,
        "actividad_nombre": "Lateralidad/LevantaManoIzquierda",
        "arduino_area": "A2",
        "arduino_cmd": "MI5",
    },
    "ambas_manos_arriba": {
        "orden_id": 49,
        "codigo_bd": "a1_60",
        "instruccion": "Levanta ambas manos",
        "area_id": 1,
        "area_ref": "area1_5",
        "area_nombre": "Socialización",
        "actividad_id": 5,
        "actividad_nombre": "Palmas/LevantaAmbasManos",
        "arduino_area": "A1",
        "arduino_cmd": "BR3",
    },
    "cruzar_brazos": {
        "orden_id": 98,
        "codigo_bd": "a3_08",
        "instruccion": "Cruza los brazos",
        "area_id": 3,
        "area_ref": "area3",
        "area_nombre": "Reconocimiento de las Partes del Cuerpo",
        "actividad_id": 8,
        "actividad_nombre": "Cuerpo/CruzaBrazos",
        "arduino_area": "A3",
        "arduino_cmd": "BR1",
    },
    "tocar_cabeza": {
        "orden_id": 97,
        "codigo_bd": "a3_07",
        "instruccion": "Toca tu cabeza",
        "area_id": 3,
        "area_ref": "area3",
        "area_nombre": "Reconocimiento de las Partes del Cuerpo",
        "actividad_id": 8,
        "actividad_nombre": "Cuerpo/TocaCabeza",
        "arduino_area": "A3",
        "arduino_cmd": "CA3",
    },
    "tocar_orejas": {
        "orden_id": 75,
        "codigo_bd": "a2_10",
        "instruccion": "Toca tus orejas",
        "area_id": 2,
        "area_ref": "area2",
        "area_nombre": "Aspectos de Lateralidad",
        "actividad_id": 7,
        "actividad_nombre": "Lateralidad/TocaOrejas",
        "arduino_area": "A2",
        "arduino_cmd": "OD2",
    },
    "tocar_cuello": {
        "orden_id": 94,
        "codigo_bd": "a3_04",
        "instruccion": "Toca tu cuello",
        "area_id": 3,
        "area_ref": "area3",
        "area_nombre": "Reconocimiento de las Partes del Cuerpo",
        "actividad_id": 8,
        "actividad_nombre": "Cuerpo/TocaCuello",
        "arduino_area": "A3",
        "arduino_cmd": "CA2",
    },
    "tocar_hombros": {
        "orden_id": 95,
        "codigo_bd": "a3_05",
        "instruccion": "Toca tus hombros",
        "area_id": 3,
        "area_ref": "area3",
        "area_nombre": "Reconocimiento de las Partes del Cuerpo",
        "actividad_id": 8,
        "actividad_nombre": "Cuerpo/TocaHombros",
        "arduino_area": "A3",
        "arduino_cmd": "BR0",
    },
    "tocar_pecho": {
        "orden_id": 92,
        "codigo_bd": "a3_02",
        "instruccion": "Toca tu pecho",
        "area_id": 3,
        "area_ref": "area3",
        "area_nombre": "Reconocimiento de las Partes del Cuerpo",
        "actividad_id": 8,
        "actividad_nombre": "Cuerpo/TocaPecho",
        "arduino_area": "A3",
        "arduino_cmd": "BR1",
    },
    "tocar_cintura": {
        "orden_id": 99,
        "codigo_bd": "a3_09",
        "instruccion": "Pon las manos en la cintura",
        "area_id": 3,
        "area_ref": "area3",
        "area_nombre": "Reconocimiento de las Partes del Cuerpo",
        "actividad_id": 8,
        "actividad_nombre": "Cuerpo/ManosEnCintura",
        "arduino_area": "A3",
        "arduino_cmd": "PI2",
    },
}

# Comandos generales del Arduino
ARDUINO_CMD_EXITO = "CC"      # Celebración cuando el niño acierta
ARDUINO_CMD_FALLO = "NA"      # Cuando el tiempo se agota o falla
ARDUINO_CMD_TOQUE = "TT"      # Habilitar lectura de sensores del peluche


def obtener_info_actividad_cuerpo(id_actividad: str) -> Dict[str, Any]:
    """Devuelve el mapeo pedagógico y comando de Arduino para una actividad corporal."""
    return MAPEO_ACTIVIDADES_CUERPO.get(
        id_actividad,
        {
            "orden_id": 97,
            "codigo_bd": "a3_07",
            "instruccion": id_actividad,
            "area_id": 3,
            "area_ref": "area3",
            "area_nombre": "Reconocimiento de las Partes del Cuerpo",
            "actividad_id": 8,
            "actividad_nombre": f"Cuerpo/{id_actividad}",
            "arduino_area": "A3",
            "arduino_cmd": "CA3",
        },
    )


def obtener_info_pictograma(nombre_pictograma: str) -> Dict[str, Any]:
    """
    Vincula cada pictograma reconocido con la estructura de juegos de la base de datos.
    """
    nombre_limpio = (nombre_pictograma or "desconocido").strip().lower()
    return {
        "actividad_juego_id": 6,
        "codigo_bd": f"pic_{nombre_limpio[:12]}",
        "area_id": 1,
        "area_ref": "area1_6",
        "area_nombre": "Socialización y Comprensión Verbal (Pictogramas)",
        "actividad_nombre": f"Pictogramas/{nombre_limpio.capitalize()}",
        "arduino_area": "A1",
        "arduino_cmd": "CC",
    }


def calcular_indicador_corporal(exito: bool, tiempo_respuesta_seg: float) -> str:
    """
    Calcula el indicador cualitativo oficial de Educación Inicial (igual a sesion1.html):
    - 'adquirido': Logrado con éxito en <= 8.0 segundos (respuesta fluida para niño de 3-5 años).
    - 'proceso': Logrado con éxito pero tardó más de 8.0 segundos.
    - 'iniciado': No logró completar dentro del tiempo límite (fallo / tiempo agotado).
    """
    if not exito:
        return "iniciado"
    if tiempo_respuesta_seg <= 8.0:
        return "adquirido"
    return "proceso"


def calcular_indicador_pictograma(exito: bool, intentos_escaneo: int = 1) -> str:
    """
    Calcula el indicador para la actividad de pictogramas:
    - 'adquirido': Identificado y confirmado al primer intento.
    - 'proceso': Identificado en el segundo intento.
    - 'iniciado': Fallo de detección o rechazado dos veces.
    """
    if not exito:
        return "iniciado"
    if intentos_escaneo <= 1:
        return "adquirido"
    return "proceso"
