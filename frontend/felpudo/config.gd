extends Node

## Configuración central del servidor.
## Cambia SERVER_HOST para apuntar a una IP distinta (ej: IP de la Raspberry Pi en la red local).
const SERVER_HOST := "127.0.0.1:8000"

const WS_CUERPO      := "ws://"  + SERVER_HOST + "/ws"
const WS_PICTOGRAMAS := "ws://"  + SERVER_HOST + "/ws_pictogramas"
const HTTP_REINICIAR     := "http://" + SERVER_HOST + "/reiniciar"
const HTTP_LIBERAR_CAMARA := "http://" + SERVER_HOST + "/liberar_camara"
