extends Node

## Configuración central del servidor.
## Cambia SERVER_HOST para apuntar a una IP distinta (ej: IP de la PC o Raspberry Pi en la red local).
const SERVER_HOST := "127.0.0.1:8000"

# WebSockets de Actividades Interactivas
const WS_CUERPO      := "ws://"  + SERVER_HOST + "/ws"
const WS_PICTOGRAMAS := "ws://"  + SERVER_HOST + "/ws_pictogramas"

# Endpoints de Control de Cámara y Juego
const HTTP_REINICIAR      := "http://" + SERVER_HOST + "/reiniciar"
const HTTP_LIBERAR_CAMARA := "http://" + SERVER_HOST + "/liberar_camara"

# Endpoints de Seguridad OAuth2/JWT, Alumnos, Sesiones, Estadísticas y Reportes
const HTTP_ESTADO         := "http://" + SERVER_HOST + "/api/estado"
const HTTP_LOGIN          := "http://" + SERVER_HOST + "/api/auth/login"
const HTTP_ALUMNOS        := "http://" + SERVER_HOST + "/api/alumnos"
const HTTP_SESION_INICIAR := "http://" + SERVER_HOST + "/api/sesion/iniciar"
const HTTP_SESION_FIN     := "http://" + SERVER_HOST + "/api/sesion/finalizar"
const HTTP_ESTADISTICAS   := "http://" + SERVER_HOST + "/api/estadisticas/alumno/"
const HTTP_REPORTE_HTML   := "http://" + SERVER_HOST + "/api/reportes/alumno/"
