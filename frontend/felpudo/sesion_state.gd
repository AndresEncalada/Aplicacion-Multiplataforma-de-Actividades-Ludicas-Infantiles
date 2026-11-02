extends Node

## Singleton global (Autoload) que conserva el estado de autenticación JWT del profesor,
## sus alumnos asignados y la sesión activa del estudiante seleccionado.

var jwt_token: String = ""
var profesor: Dictionary = {}
var alumnos: Array = []
var alumno_actual: Dictionary = {}
var sesion_activa_id: int = -1
var ultimo_resumen_sesion: Dictionary = {}
var modo_seleccion: String = "actividades" # "actividades" | "estadisticas"


func esta_autenticado() -> bool:
	return jwt_token != "" and not profesor.is_empty()


func tiene_alumno_seleccionado() -> bool:
	return not alumno_actual.is_empty()


func obtener_nombre_alumno_activo() -> String:
	if alumno_actual.is_empty():
		return "Modo Libre"
	return str(alumno_actual.get("nombre", "")) + " " + str(alumno_actual.get("apellido", ""))


func obtener_headers_json(con_auth: bool = true) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if con_auth and jwt_token != "":
		headers.append("Authorization: Bearer " + jwt_token)
	return headers


func guardar_login(token: String, datos_profesor: Dictionary, lista_alumnos: Array) -> void:
	jwt_token = token
	profesor = datos_profesor
	alumnos = lista_alumnos


func seleccionar_alumno(datos_alumno: Dictionary, id_sesion: int = -1) -> void:
	alumno_actual = datos_alumno
	sesion_activa_id = id_sesion


func limpiar_alumno_activo() -> void:
	alumno_actual = {}
	sesion_activa_id = -1


func cerrar_sesion_profesor() -> void:
	jwt_token = ""
	profesor = {}
	alumnos = []
	alumno_actual = {}
	sesion_activa_id = -1
	ultimo_resumen_sesion = {}
