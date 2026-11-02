"""
Motor de Estadísticas de Evolución y Generador de Reportes Individuales (JSON y HTML/PDF).
Calcula intentos, aciertos (no fallaron), fallos, tiempos de respuesta, indicadores cualitativos
('adquirido', 'proceso', 'iniciado') y porcentaje de mejora entre sesiones para niños de 3 a 5 años.
"""
import html
from typing import Any, Dict, List, Optional

from integracion.django_client import gestor_datos


def calcular_estadisticas_sesion(sesion: Dict[str, Any]) -> Dict[str, Any]:
    eventos = sesion.get("eventos", [])
    total_actividades = len(eventos)
    total_intentos = 0
    aciertos = 0
    fallos = 0
    tiempos: List[float] = []
    conteo_indicadores = {"adquirido": 0, "proceso": 0, "iniciado": 0}

    for ev in eventos:
        intentos_ev = int(ev.get("intentos", 1))
        exito_ev = bool(ev.get("exito", False))
        tiempo_ev = float(ev.get("tiempo_seg", 0.0))
        ind_ev = str(ev.get("indicador", "iniciado")).lower()

        total_intentos += intentos_ev
        if exito_ev:
            aciertos += 1
            # Si necesitó más de 1 intento para lograrlo, los intentos previos fueron fallos parciales
            if intentos_ev > 1:
                fallos += intentos_ev - 1
        else:
            fallos += intentos_ev

        if tiempo_ev > 0:
            tiempos.append(tiempo_ev)

        if ind_ev in conteo_indicadores:
            conteo_indicadores[ind_ev] += 1

    base_calculo = max(1, aciertos + fallos)
    tasa_exito = round((aciertos / base_calculo) * 100.0, 1) if total_actividades > 0 else 0.0
    tiempo_promedio = round(sum(tiempos) / len(tiempos), 2) if tiempos else 0.0

    return {
        "sesion_id": sesion.get("id"),
        "fecha_ini": sesion.get("fecha_ini", ""),
        "fecha_fin": sesion.get("fecha_fin", ""),
        "area_visitada": sesion.get("area_visitada", ""),
        "estado": sesion.get("estado", "finalizada"),
        "total_actividades": total_actividades,
        "total_intentos": total_intentos,
        "aciertos": aciertos,
        "no_fallaron": aciertos,
        "fallos": fallos,
        "tasa_exito_pct": tasa_exito,
        "tiempo_promedio_seg": tiempo_promedio,
        "indicadores": conteo_indicadores,
        "eventos": eventos,
    }


def calcular_estadisticas_alumno(nn_id: int) -> Optional[Dict[str, Any]]:
    alumno = gestor_datos.obtener_alumno(nn_id)
    if not alumno:
        return None

    profesor = gestor_datos.obtener_profesor_por_id(int(alumno.get("usuario", 1)))
    sesiones_raw = gestor_datos.obtener_sesiones_alumno(nn_id)
    # Considerar sesiones con al menos 1 evento o cerradas
    sesiones_calc = [calcular_estadisticas_sesion(s) for s in sesiones_raw]
    sesiones_con_datos = [s for s in sesiones_calc if s["total_actividades"] > 0]

    total_sesiones = len(sesiones_con_datos)
    total_actividades = sum(s["total_actividades"] for s in sesiones_con_datos)
    total_intentos = sum(s["total_intentos"] for s in sesiones_con_datos)
    total_aciertos = sum(s["aciertos"] for s in sesiones_con_datos)
    total_fallos = sum(s["fallos"] for s in sesiones_con_datos)

    indicadores_globales = {"adquirido": 0, "proceso": 0, "iniciado": 0}
    todos_tiempos: List[float] = []

    for s in sesiones_con_datos:
        for k in indicadores_globales:
            indicadores_globales[k] += s["indicadores"].get(k, 0)
        for ev in s["eventos"]:
            t = float(ev.get("tiempo_seg", 0.0))
            if t > 0:
                todos_tiempos.append(t)

    base_global = max(1, total_aciertos + total_fallos)
    tasa_exito_global = round((total_aciertos / base_global) * 100.0, 1) if total_actividades > 0 else 0.0
    tiempo_promedio_global = round(sum(todos_tiempos) / len(todos_tiempos), 2) if todos_tiempos else 0.0

    # Cálculo de Evolución y Mejora entre sesiones
    mejora_pct = 0.0
    reduccion_tiempo_seg = 0.0
    estado_evolucion = "Sin sesiones registradas"
    detalle_evolucion = "Aún no se han completado sesiones con este estudiante."

    if len(sesiones_con_datos) == 1:
        unica = sesiones_con_datos[0]
        estado_evolucion = "En evaluación inicial"
        detalle_evolucion = (
            f"Primera sesión completada con {unica['tasa_exito_pct']}% de acierto "
            f"({unica['aciertos']} aciertos en {unica['total_intentos']} intentos)."
        )
    elif len(sesiones_con_datos) >= 2:
        primera = sesiones_con_datos[0]
        previas = sesiones_con_datos[:-1]
        ultima = sesiones_con_datos[-1]

        promedio_previo_tasa = sum(p["tasa_exito_pct"] for p in previas) / len(previas)
        promedio_previo_tiempo = sum(p["tiempo_promedio_seg"] for p in previas) / len(previas)

        mejora_pct = round(ultima["tasa_exito_pct"] - promedio_previo_tasa, 1)
        reduccion_tiempo_seg = round(promedio_previo_tiempo - ultima["tiempo_promedio_seg"], 2)

        if mejora_pct > 2.0 or (mejora_pct >= 0.0 and reduccion_tiempo_seg > 0.5):
            estado_evolucion = "Mejoró"
            signo = "+" if mejora_pct >= 0 else ""
            extra_t = f" y redujo su tiempo en {reduccion_tiempo_seg}s" if reduccion_tiempo_seg > 0 else ""
            detalle_evolucion = (
                f"Evolución positiva ({signo}{mejora_pct}% de efectividad frente a sesiones previas{extra_t}). "
                f"Pasó de {primera['tasa_exito_pct']}% en su primera sesión a {ultima['tasa_exito_pct']}% en la última."
            )
        elif -2.0 <= mejora_pct <= 2.0:
            estado_evolucion = "Estable"
            detalle_evolucion = (
                f"Desempeño constante ({ultima['tasa_exito_pct']}% de aciertos en la última sesión)."
            )
        else:
            estado_evolucion = "Requiere refuerzo"
            detalle_evolucion = (
                f"Variación de {mejora_pct}% en la última sesión ({ultima['tasa_exito_pct']}% de aciertos). "
                "Se recomienda reforzar actividades de lateralidad y pictogramas."
            )

    return {
        "alumno": {
            "id": alumno["id"],
            "nombre": alumno["nombre"],
            "apellido": alumno["apellido"],
            "nombre_completo": f"{alumno['nombre']} {alumno['apellido']}",
            "fec_nacimiento": alumno.get("fec_nacimiento", ""),
            "edad": alumno.get("edad", 4),
            "nivel": "Inicial",
            "discapacidad": alumno.get("discapacidad", "Ninguna"),
            "profesor_id": alumno.get("usuario", 1),
            "profesor_nombre": profesor["name"] if profesor else "Docente Asignado",
        },
        "resumen": {
            "total_sesiones": total_sesiones,
            "total_actividades": total_actividades,
            "total_intentos": total_intentos,
            "total_aciertos": total_aciertos,
            "no_fallaron": total_aciertos,
            "total_fallos": total_fallos,
            "tasa_exito_pct": tasa_exito_global,
            "tiempo_promedio_seg": tiempo_promedio_global,
            "mejora_pct": mejora_pct,
            "reduccion_tiempo_seg": reduccion_tiempo_seg,
            "estado_evolucion": estado_evolucion,
            "detalle_evolucion": detalle_evolucion,
            "indicadores": indicadores_globales,
        },
        "sesiones": sesiones_con_datos,
    }


def generar_reporte_html_alumno(nn_id: int, sesion_id: Optional[int] = None) -> Optional[str]:
    """
    Genera el reporte individual en HTML listo para imprimir o guardar como PDF,
    respetando el encabezado y formato de Educación Inicial de la Raspberry Pi (sesion1.html)
    e incorporando las estadísticas de intentos, aciertos, fallos y mejora.
    """
    stats = calcular_estadisticas_alumno(nn_id)
    if not stats:
        return None

    al = stats["alumno"]
    res = stats["resiones"] if "resiones" in stats else stats["resumen"]
    sesiones = stats["sesiones"]

    if sesion_id is not None:
        sesiones_filtradas = [s for s in sesiones if int(s["sesion_id"]) == int(sesion_id)]
        if sesiones_filtradas:
            sesiones = sesiones_filtradas

    fecha_ini_rep = sesiones[0]["fecha_ini"] if sesiones else "Sin registro"
    fecha_fin_rep = sesiones[-1]["fecha_fin"] if sesiones else "Sin registro"

    signo_mejora = "+" if res["mejora_pct"] > 0 else ""
    color_evolucion = "#1b7e3c" if res["estado_evolucion"] == "Mejoró" else ("#b86b00" if res["estado_evolucion"] != "Requiere refuerzo" else "#b81d1d")

    filas_sesiones_html = ""
    for idx, s in enumerate(sesiones, start=1):
        filas_sesiones_html += f"""
        <tr>
            <td style="text-align:center;">Sesión #{s['sesion_id']}</td>
            <td>{html.escape(s['fecha_ini'])} — {html.escape(s['fecha_fin'])}</td>
            <td>{html.escape(s['area_visitada'])}</td>
            <td style="text-align:center;"><b>{s['total_intentos']}</b></td>
            <td style="text-align:center; color:#1b7e3c;"><b>{s['aciertos']}</b></td>
            <td style="text-align:center; color:#b81d1d;"><b>{s['fallos']}</b></td>
            <td style="text-align:center;"><b>{s['tasa_exito_pct']}%</b></td>
            <td style="text-align:center;">{s['tiempo_promedio_seg']} s</td>
        </tr>
        """

    if not filas_sesiones_html:
        filas_sesiones_html = """
        <tr><td colspan="8" style="text-align:center; padding:14px;">No hay sesiones registradas todavía para este estudiante.</td></tr>
        """

    filas_actividades_html = ""
    for s in sesiones:
        for ev in s["eventos"]:
            ind = str(ev.get("indicador", "iniciado")).lower()
            badge_bg = "#d4edda" if ind == "adquirido" else ("#fff3cd" if ind == "proceso" else "#f8d7da")
            badge_fg = "#155724" if ind == "adquirido" else ("#856404" if ind == "proceso" else "#721c24")
            resultado_txt = "No falló (Acierto)" if ev.get("exito") else "Falló / Tiempo agotado"
            filas_actividades_html += f"""
            <tr>
                <td style="text-align:center;">#{s['sesion_id']}</td>
                <td>{html.escape(str(ev.get('area_ref', 'area')))} - {html.escape(str(ev.get('area_nombre', '')))}</td>
                <td>{html.escape(str(ev.get('actividad_nombre', '')))}<br><small style="color:#555;">{html.escape(str(ev.get('instruccion', '')))}</small></td>
                <td style="text-align:center;">{ev.get('intentos', 1)}</td>
                <td style="text-align:center;">{resultado_txt}</td>
                <td style="text-align:center;">{ev.get('tiempo_seg', 0)} s</td>
                <td style="text-align:center;">
                    <span style="background:{badge_bg}; color:{badge_fg}; padding:4px 10px; border-radius:12px; font-weight:bold; text-transform:uppercase; font-size:12px;">
                        {html.escape(ind)}
                    </span>
                </td>
            </tr>
            """

    if not filas_actividades_html:
        filas_actividades_html = """
        <tr><td colspan="7" style="text-align:center; padding:14px;">Sin actividades registradas en este periodo.</td></tr>
        """

    html_doc = f"""<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte Individual - {html.escape(al['nombre_completo'])} - Felpudo</title>
    <style>
        body {{
            font-family: 'Segoe UI', Arial, sans-serif;
            color: #1e293b;
            background: #f1f5f9;
            margin: 0;
            padding: 24px;
        }}
        .page {{
            max-width: 960px;
            margin: 0 auto;
            background: #ffffff;
            padding: 36px 44px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
        }}
        .toolbar {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 14px;
            border-bottom: 2px solid #e2e8f0;
        }}
        .btn-print {{
            background: #0d9488;
            color: #fff;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            font-size: 15px;
            font-weight: bold;
            cursor: pointer;
        }}
        .btn-print:hover {{ background: #0f766e; }}
        h1, h2, h3 {{ margin: 6px 0; text-align: center; }}
        h1 {{ color: #142e61; font-size: 22px; }}
        h2 {{ color: #0d9488; font-size: 17px; }}
        h3.section-title {{
            text-align: left;
            background: #142e61;
            color: #ffffff;
            padding: 8px 14px;
            border-radius: 6px;
            margin-top: 26px;
            margin-bottom: 12px;
            font-size: 15px;
            letter-spacing: 0.5px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 16px;
            font-size: 14px;
        }}
        th, td {{
            border: 1px solid #cbd5e1;
            padding: 9px 12px;
        }}
        th {{
            background: #f8fafc;
            color: #142e61;
            font-weight: 700;
        }}
        .info-table td {{ border: none; padding: 6px 10px; }}
        .info-label {{ font-weight: bold; color: #334155; width: 32%; }}
        .kpi-grid {{
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 12px;
            margin: 16px 0;
        }}
        .kpi-card {{
            background: #f8fafc;
            border: 1px solid #cbd5e1;
            border-radius: 10px;
            padding: 12px;
            text-align: center;
        }}
        .kpi-value {{
            font-size: 24px;
            font-weight: 800;
            color: #142e61;
            margin-top: 4px;
        }}
        .kpi-label {{
            font-size: 12px;
            color: #64748b;
            text-transform: uppercase;
            font-weight: bold;
        }}
        .evolucion-box {{
            background: #f0fdf4;
            border-left: 5px solid {color_evolucion};
            padding: 14px 18px;
            border-radius: 6px;
            margin-bottom: 18px;
        }}
        @media print {{
            body {{ background: #fff; padding: 0; }}
            .page {{ box-shadow: none; padding: 10px; max-width: 100%; }}
            .toolbar {{ display: none; }}
        }}
    </style>
</head>
<body>
    <div class="page">
        <div class="toolbar">
            <div><strong>Sistema Educativo Felpudo</strong> · Reporte Pedagógico (3 a 5 años)</div>
            <button class="btn-print" onclick="window.print()">Imprimir / Guardar en PDF</button>
        </div>

        <h1>UNIDAD EDUCATIVA "SANTA MARIANA DE JESÚS" — PROYECTO FELPUDO</h1>
        <h2>EDUCACIÓN BÁSICA INICIAL (NIÑOS DE 3 A 5 AÑOS)</h2>
        <p style="text-align:center; font-weight:bold; color:#475569; margin-top:2px;">REGISTRO INDIVIDUAL DE DESEMPEÑO Y EVOLUCIÓN</p>

        <h3 class="section-title">1. IDENTIFICACIÓN PERSONAL</h3>
        <table class="info-table">
            <tr>
                <td class="info-label">Nombres y Apellidos del Alumno:</td>
                <td><b>{html.escape(al['nombre_completo'])}</b> ({al['edad']} años)</td>
                <td class="info-label">Profesor Asignado:</td>
                <td><b>{html.escape(al['profesor_nombre'])}</b></td>
            </tr>
            <tr>
                <td class="info-label">Fecha de Nacimiento:</td>
                <td>{html.escape(al['fec_nacimiento'])}</td>
                <td class="info-label">Nivel:</td>
                <td>{html.escape(al['nivel'])} (Único)</td>
            </tr>
            <tr>
                <td class="info-label">Condición / Observación:</td>
                <td>{html.escape(al['discapacidad'])}</td>
                <td class="info-label">Periodo Evaluado:</td>
                <td>{html.escape(fecha_ini_rep)} a {html.escape(fecha_fin_rep)}</td>
            </tr>
        </table>

        <h3 class="section-title">2. ESTADÍSTICAS DE INTENTOS, ACIERTOS, FALLOS Y MEJORA</h3>
        <div class="kpi-grid">
            <div class="kpi-card">
                <div class="kpi-label">Intentos Totales</div>
                <div class="kpi-value">{res['total_intentos']}</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Aciertos (No Fallaron)</div>
                <div class="kpi-value" style="color:#1b7e3c;">{res['total_aciertos']}</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Fallos</div>
                <div class="kpi-value" style="color:#b81d1d;">{res['total_fallos']}</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Tasa de Éxito</div>
                <div class="kpi-value">{res['tasa_exito_pct']}%</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-label">Evolución / Mejora</div>
                <div class="kpi-value" style="color:{color_evolucion};">{signo_mejora}{res['mejora_pct']}%</div>
            </div>
        </div>

        <div class="evolucion-box">
            <strong style="color:{color_evolucion};">Estado de Evolución: {html.escape(res['estado_evolucion'].upper())}</strong><br>
            <span>{html.escape(res['detalle_evolucion'])}</span><br>
            <small style="color:#475569;">
                Resumen de Indicadores: <b>Adquirido:</b> {res['indicadores']['adquirido']} ·
                <b>En Proceso:</b> {res['indicadores']['proceso']} ·
                <b>Iniciado:</b> {res['indicadores']['iniciado']} ·
                <b>Tiempo Promedio de Respuesta:</b> {res['tiempo_promedio_seg']} segundos.
            </small>
        </div>

        <h3 class="section-title">3. EVOLUCIÓN POR SESIÓN</h3>
        <table>
            <thead>
                <tr>
                    <th>Sesión</th>
                    <th>Fecha Inicio — Fin</th>
                    <th>Áreas Trabajadas</th>
                    <th>Intentos</th>
                    <th>Aciertos</th>
                    <th>Fallos</th>
                    <th>% Éxito</th>
                    <th>Tiempo Prom.</th>
                </tr>
            </thead>
            <tbody>
                {filas_sesiones_html}
            </tbody>
        </table>

        <h3 class="section-title">4. DETALLE DE RESULTADOS OBTENIDOS POR ACTIVIDAD</h3>
        <table>
            <thead>
                <tr>
                    <th>Sesión</th>
                    <th>Área Pedagógica</th>
                    <th>Actividad / Orden Evaluada</th>
                    <th>Intentos</th>
                    <th>Resultado</th>
                    <th>Tiempo</th>
                    <th>Indicador</th>
                </tr>
            </thead>
            <tbody>
                {filas_actividades_html}
            </tbody>
        </table>
    </div>
</body>
</html>
"""
    return html_doc
