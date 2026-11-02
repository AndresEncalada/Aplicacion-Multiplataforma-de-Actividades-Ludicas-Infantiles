extends Control

# ==============================================================================
# GUÍA DE IMÁGENES / ASSETS PARA ESTA ESCENA (login_profesor.gd)
# ==============================================================================
# Todas las imágenes deben ubicarse en: frontend/felpudo/assets/iconos/
# Formato recomendado: PNG o SVG con fondo transparente, 128x128 px o 256x256 px.
#
# Si aún no colocas los archivos opcionales de abajo, el código utiliza
# automáticamente los iconos ya incluidos en el repositorio como respaldo:
#
# 1. ICO_PROFESOR_OPT ("res://assets/iconos/profesor.png") -> Respaldo: bear.png
# 2. ICO_ALUMNO_OPT   ("res://assets/iconos/alumno.png")   -> Respaldo: cuerpo.png
# 3. ICO_REPORTE_OPT  ("res://assets/iconos/reporte.png")  -> Respaldo: preguntas.png
# 4. ICO_ALERTA_OPT   ("res://assets/iconos/alerta.png")   -> Respaldo: bear.png
# ==============================================================================

const MANDARINA := Color(1.00, 0.50, 0.08)
const TURQUESA  := Color(0.05, 0.68, 0.72)
const CREMA     := Color(1.00, 0.96, 0.86)
const AMBAR     := Color(0.98, 0.82, 0.08)
const NAVY      := Color(0.08, 0.18, 0.38)

const FONT_KFN   := "res://assets/fuente/Kenney Future Narrow.ttf"
const SND_CLICK  := "res://assets/sonidos/click.ogg"
const SND_EXITO  := "res://assets/sonidos/exito.ogg"
const SND_CERRAR := "res://assets/sonidos/cerrar.ogg"

const ICO_PANEL  := "res://assets/iconos/panel.svg"
const ICO_BANNER := "res://assets/iconos/banner.svg"
const ICO_BOTON  := "res://assets/iconos/boton.svg"
const ICO_X      := "res://assets/iconos/x.svg"
const ICO_BEAR   := "res://assets/iconos/bear.png"
const ICO_CUERPO := "res://assets/iconos/cuerpo.png"
const ICO_PREG   := "res://assets/iconos/preguntas.png"

const ICO_PROFESOR_OPT := "res://assets/iconos/profesor.png"
const ICO_ALUMNO_OPT   := "res://assets/iconos/alumno.png"
const ICO_REPORTE_OPT  := "res://assets/iconos/reporte.png"
const ICO_ALERTA_OPT   := "res://assets/iconos/alerta.png"

# Proporciones exactas de menu_principal.gd y menu_actividades.gd
const BANNER_H: int = 135
const OVERLAP:  int = 67   # 50 % de BANNER_H

var _font: FontFile
var _btn_bloqueado := false
var _sfx_click: AudioStreamPlayer
var _sfx_exito: AudioStreamPlayer
var _sfx_cerrar: AudioStreamPlayer
var _wobble_index: int = 0
var _wobble_data: Array = []

var _ui_root: Control
var _input_user: LineEdit
var _input_pass: LineEdit
var _lbl_btn_login: Label

# Modal de alertas amigables
var _modal_alerta: ColorRect
var _lbl_alerta_titulo: Label
var _lbl_alerta_mensaje: Label

func _ready():
	_font = load(FONT_KFN)
	_sfx_click  = _crear_sfx(SND_CLICK, -6.0)
	_sfx_exito  = _crear_sfx(SND_EXITO, -4.0)
	_sfx_cerrar = _crear_sfx(SND_CERRAR, -6.0)

	var bg = ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_root)

	_construir_modal_alerta()

	if has_node("/root/AnimManager"):
		AnimManager.changed.connect(_on_anim_changed)

	if has_node("/root/SesionState") and SesionState.esta_autenticado():
		_solicitar_alumnos_actualizados()
	else:
		_construir_vista_login()

func _crear_sfx(ruta: String, vol: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var s = load(ruta)
	if s:
		p.stream    = s
		p.volume_db = vol
	add_child(p)
	return p

func _cargar_icono_con_fallback(ruta_opcional: String, ruta_respaldo: String) -> Texture2D:
	if ResourceLoader.exists(ruta_opcional):
		var tex = load(ruta_opcional) as Texture2D
		if tex:
			return tex
	return load(ruta_respaldo) as Texture2D

func _limpiar_ui_root():
	_btn_bloqueado = false
	for d in _wobble_data:
		if is_instance_valid(d["tween"]):
			d["tween"].kill()
	_wobble_data.clear()
	_wobble_index = 0
	for child in _ui_root.get_children():
		child.queue_free()

# ---------------------------------------------------------------------------
# Armazón base idéntico a menu_principal.gd / menu_actividades.gd
# ---------------------------------------------------------------------------

func _crear_panel_base(con_oso: bool, titulo_banner: String, accion_cerrar: Callable) -> PanelContainer:
	_limpiar_ui_root()

	var vp    := get_viewport().get_visible_rect().size
	var vp_w: float = vp.x
	var vp_h: float = vp.y
	var mg: int     = int(vp_w * 0.02)

	var root_vbox = VBoxContainer.new()
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(root_vbox)

	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", -OVERLAP)
	root_vbox.add_child(stack)

	if con_oso:
		stack.add_child(_crear_header_con_oso(titulo_banner, vp_w))
	else:
		var header = _crear_header_banner(titulo_banner, vp_w, accion_cerrar)
		header.z_index = 2
		stack.add_child(header)

	var margin_outer = MarginContainer.new()
	margin_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_outer.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin_outer.add_theme_constant_override("margin_left",   mg)
	margin_outer.add_theme_constant_override("margin_right",  mg)
	margin_outer.add_theme_constant_override("margin_top",    mg)
	margin_outer.add_theme_constant_override("margin_bottom", mg)
	margin_outer.z_index = 1
	stack.add_child(margin_outer)

	var panel_pc = PanelContainer.new()
	panel_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_pc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin_outer.add_child(panel_pc)

	var tex_panel = load(ICO_PANEL) as Texture2D
	if tex_panel:
		var style = StyleBoxTexture.new()
		style.texture = tex_panel
		_aplicar_margenes_panel(style, tex_panel)
		style.content_margin_top    = OVERLAP + 20
		style.content_margin_bottom = max(40, int(vp_h * 0.08))
		panel_pc.add_theme_stylebox_override("panel", style)
	else:
		var sf = StyleBoxFlat.new()
		sf.bg_color = CREMA
		sf.set_corner_radius_all(24)
		sf.set_content_margin_all(20)
		panel_pc.add_theme_stylebox_override("panel", sf)

	return panel_pc

# ---------------------------------------------------------------------------
# VISTA 1: Login del Profesor (proporciones idénticas a menu_principal.gd)
# ---------------------------------------------------------------------------

func _construir_vista_login():
	var panel_pc := _crear_panel_base(true, "Felpudo", Callable())

	var center_inner = CenterContainer.new()
	center_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_inner.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel_pc.add_child(center_inner)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(420, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center_inner.add_child(vbox)

	var lbl_tit = _crear_label("Ingreso Profesor", 30, NAVY, true)
	lbl_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_tit)

	_input_user = _crear_input("Usuario (ej: prof_maria)", false)
	vbox.add_child(_input_user)

	_input_pass = _crear_input("Contraseña", true)
	_input_pass.text_submitted.connect(func(_t): _on_login_pressed())
	vbox.add_child(_input_pass)

	var btn_box = CenterContainer.new()
	vbox.add_child(btn_box)

	var card_btn = _crear_boton_svg("Ingresar", Vector2(240, 68), 24, func(c: PanelContainer):
		_animar_click(c, _on_login_pressed)
	)
	btn_box.add_child(card_btn)

func _on_login_pressed():
	var u := _input_user.text.strip_edges()
	var p := _input_pass.text.strip_edges()

	if u == "" or p == "":
		_btn_bloqueado = false
		_mostrar_alerta_amigable(
			"Datos incompletos",
			"Por favor, ingrese su usuario y contraseña de profesor."
		)
		return

	if is_instance_valid(_lbl_btn_login):
		_lbl_btn_login.text = "Conectando..."

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_login_response.bind(http))

	var body = JSON.stringify({"username": u, "password": p})
	var headers = PackedStringArray(["Content-Type: application/json"])
	var err = http.request(Config.HTTP_LOGIN, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_btn_bloqueado = false
		if is_instance_valid(_lbl_btn_login):
			_lbl_btn_login.text = "Ingresar"
		_mostrar_alerta_amigable(
			"Aviso de conexión",
			"Por favor, verifique las conexiones o contacte al administrador."
		)

func _on_login_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	_btn_bloqueado = false
	if is_instance_valid(_lbl_btn_login):
		_lbl_btn_login.text = "Ingresar"

	if result != HTTPRequest.RESULT_SUCCESS or response_code == 0:
		_mostrar_alerta_amigable(
			"Servidor no disponible",
			"Por favor, verifique las conexiones o contacte al administrador."
		)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 401 or not (data is Dictionary) or not data.has("access_token"):
		var msg_err := "Usuario o contraseña incorrectos."
		if data is Dictionary and data.has("detail"):
			msg_err = str(data["detail"])
		_mostrar_alerta_amigable("Acceso denegado", msg_err)
		return

	if _sfx_exito: _sfx_exito.play()
	if has_node("/root/SesionState"):
		SesionState.guardar_login(
			str(data.get("access_token", "")),
			data.get("profesor", {}),
			data.get("alumnos", [])
		)

	# Al iniciar sesión va directo a la ventana con los 2 botones (Actividades y Estadísticas Alumnos)
	get_tree().change_scene_to_file("res://menu_principal.tscn")

# ---------------------------------------------------------------------------
# VISTA 2: Selección de Alumno (proporciones idénticas a menu_actividades.gd)
# ---------------------------------------------------------------------------

func _solicitar_alumnos_actualizados():
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if data is Dictionary and data.has("alumnos"):
				SesionState.alumnos = data["alumnos"]
				_construir_vista_alumnos()
				return
		elif code == 401:
			SesionState.cerrar_sesion_profesor()
			_construir_vista_login()
			return

		_construir_vista_alumnos()
		_mostrar_alerta_amigable(
			"Aviso de conexión",
			"Por favor, verifique las conexiones o contacte al administrador."
		)
	)
	var err = http.request(Config.HTTP_ALUMNOS, SesionState.obtener_headers_json(true), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		_construir_vista_alumnos()

func _construir_vista_alumnos():
	var es_estadisticas := (has_node("/root/SesionState") and SesionState.modo_seleccion == "estadisticas")
	var titulo := "Estadísticas Alumnos" if es_estadisticas else "Seleccionar Alumno"

	var panel_pc := _crear_panel_base(false, titulo, func():
		get_tree().change_scene_to_file("res://menu_principal.tscn")
	)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel_pc.add_child(scroll)

	var vbox_tarjetas = VBoxContainer.new()
	vbox_tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_tarjetas.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox_tarjetas.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_tarjetas.add_theme_constant_override("separation", 20)
	scroll.add_child(vbox_tarjetas)

	for al in SesionState.alumnos:
		var nombre_completo := str(al.get("nombre", "")) + " " + str(al.get("apellido", ""))
		var edad := str(al.get("edad", 4))
		var stats: Dictionary = al.get("estadisticas", {})
		var intentos_n := int(stats.get("total_intentos", 0))
		var aciertos_n := int(stats.get("total_aciertos", 0))
		var fallos_n   := int(stats.get("total_fallos", 0))
		var mejora_pct := float(stats.get("mejora_pct", 0.0))
		var signo := "+" if mejora_pct > 0 else ""

		var desc: String
		if es_estadisticas:
			desc = "Intentos: " + str(intentos_n) + "  |  Aciertos: " + str(aciertos_n) + "  |  Fallos: " + str(fallos_n) + "  |  Mejora: " + signo + str(mejora_pct) + "%"
		else:
			desc = "Edad: " + edad + " años  —  Toca para elegir la actividad"

		var ico_al := ICO_ALUMNO_OPT if ResourceLoader.exists(ICO_ALUMNO_OPT) else ICO_CUERPO
		vbox_tarjetas.add_child(_crear_tarjeta_horizontal(
			nombre_completo + " (" + edad + " años)",
			desc,
			ico_al,
			TURQUESA,
			func(card: PanelContainer):
				_animar_click(card, func():
					if es_estadisticas:
						_abrir_estadisticas_alumno(int(al.get("id", 1)))
					else:
						_iniciar_sesion_y_abrir_actividades(al)
				)
		))

func _iniciar_sesion_y_abrir_actividades(alumno: Dictionary):
	var http = HTTPRequest.new()
	add_child(http)
	var nn_id := int(alumno.get("id", 1))

	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		_btn_bloqueado = false
		if result != HTTPRequest.RESULT_SUCCESS or code == 0:
			_mostrar_alerta_amigable(
				"Aviso de conexión",
				"Por favor, verifique las conexiones o contacte al administrador."
			)
			return

		var data = JSON.parse_string(body.get_string_from_utf8())
		var id_sesion: int = -1
		if data is Dictionary and data.has("sesion") and data["sesion"] is Dictionary:
			id_sesion = int(data["sesion"].get("id", -1))

		SesionState.seleccionar_alumno(alumno, id_sesion)
		get_tree().change_scene_to_file("res://menu_actividades.tscn")
	)

	var payload = JSON.stringify({"nn_id": nn_id, "categoria_id": 1})
	var err = http.request(Config.HTTP_SESION_INICIAR, SesionState.obtener_headers_json(true), HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		_btn_bloqueado = false
		_mostrar_alerta_amigable(
			"Aviso de conexión",
			"Por favor, verifique las conexiones o contacte al administrador."
		)

# ---------------------------------------------------------------------------
# VISTA 3: Estadísticas del Alumno (proporciones idénticas a menu_actividades.gd)
# ---------------------------------------------------------------------------

func _abrir_estadisticas_alumno(nn_id: int):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		_btn_bloqueado = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_mostrar_alerta_amigable(
				"Aviso de conexión",
				"Por favor, verifique las conexiones o contacte al administrador."
			)
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data is Dictionary:
			_construir_vista_estadisticas(data)
	)
	var url = Config.HTTP_ESTADISTICAS + str(nn_id)
	var err = http.request(url, SesionState.obtener_headers_json(true), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		_btn_bloqueado = false
		_mostrar_alerta_amigable(
			"Aviso de conexión",
			"Por favor, verifique las conexiones o contacte al administrador."
		)

func _construir_vista_estadisticas(stats: Dictionary):
	var al: Dictionary  = stats.get("alumno", {})
	var res: Dictionary = stats.get("resumen", {})
	var sesiones: Array = stats.get("sesiones", [])
	var nn_id: int      = int(al.get("id", 1))
	var nombre_completo := str(al.get("nombre_completo", "Estudiante"))

	var panel_pc := _crear_panel_base(false, nombre_completo, func():
		_solicitar_alumnos_actualizados()
	)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	panel_pc.add_child(vbox)

	# Fila 1: Tarjetas de indicadores principales con boton.svg
	var kpi_hbox = HBoxContainer.new()
	kpi_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kpi_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(kpi_hbox)

	var mejora_val := float(res.get("mejora_pct", 0.0))
	var signo := "+" if mejora_val > 0 else ""

	kpi_hbox.add_child(_crear_kpi_svg("Intentos", str(res.get("total_intentos", 0))))
	kpi_hbox.add_child(_crear_kpi_svg("No Falló", str(res.get("total_aciertos", 0))))
	kpi_hbox.add_child(_crear_kpi_svg("Fallos", str(res.get("total_fallos", 0))))
	kpi_hbox.add_child(_crear_kpi_svg("Mejora", signo + str(mejora_val) + "%"))

	# Fila 2: Lista de actividades y sesiones con scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var hist_vbox = VBoxContainer.new()
	hist_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hist_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(hist_vbox)

	for s in sesiones:
		for ev in s.get("eventos", []):
			var ok: bool = ev.get("exito", false)
			var estado_txt := "LOGRADO" if ok else "FALLÓ"
			var sub_txt := (
				"Sesión #" + str(s.get("sesion_id", "")) +
				"  |  Resultado: " + estado_txt +
				"  |  Tiempo: " + str(ev.get("tiempo_seg", 0.0)) + "s" +
				"  |  Nivel: " + str(ev.get("indicador", "iniciado")).to_upper()
			)
			hist_vbox.add_child(_crear_item_historial(
				str(ev.get("instruccion", "Actividad")),
				sub_txt
			))

	# Fila 3: Botón para abrir el reporte imprimible HTML / PDF
	var center_btn = CenterContainer.new()
	vbox.add_child(center_btn)

	var btn_rep = _crear_boton_svg("Abrir Reporte PDF / HTML", Vector2(360, 60), 20, func(c: PanelContainer):
		_animar_click(c, func():
			_btn_bloqueado = false
			OS.shell_open(Config.HTTP_REPORTE_HTML + str(nn_id) + "/html")
		)
	)
	center_btn.add_child(btn_rep)

# ---------------------------------------------------------------------------
# Componentes visuales con las proporciones exactas del proyecto
# ---------------------------------------------------------------------------

func _crear_header_con_oso(titulo: String, vp_w: float) -> Control:
	var row = CenterContainer.new()
	row.custom_minimum_size   = Vector2(0, BANNER_H)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.z_index = 2

	var banner_w: int = int(vp_w * 0.55)
	var banner_wrap = Control.new()
	banner_wrap.custom_minimum_size = Vector2(banner_w, BANNER_H)
	row.add_child(banner_wrap)

	var tex_banner = load(ICO_BANNER) as Texture2D
	if tex_banner:
		var np = NinePatchRect.new()
		np.texture = tex_banner
		_aplicar_margenes_banner(np, tex_banner)
		np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		np.axis_stretch_vertical   = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		np.z_index = 0
		banner_wrap.add_child(np)

	var lbl = _crear_label(titulo, 54, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 1
	banner_wrap.add_child(lbl)

	var tex_bear = _cargar_icono_con_fallback(ICO_PROFESOR_OPT, ICO_BEAR)
	if tex_bear:
		var bear = TextureRect.new()
		bear.texture             = tex_bear
		bear.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bear.custom_minimum_size = Vector2(82, 82)
		bear.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		bear.offset_left   = -94
		bear.offset_top    = -82
		bear.offset_right  = -12
		bear.offset_bottom = 14
		bear.z_index = 5
		banner_wrap.add_child(bear)
		_iniciar_jiggle(bear)

	return row

func _crear_header_banner(titulo: String, _vp_w: float, accion_cerrar: Callable) -> Control:
	var banner_wrap = Control.new()
	banner_wrap.custom_minimum_size   = Vector2(0, BANNER_H)
	banner_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tex_banner = load(ICO_BANNER) as Texture2D
	if tex_banner:
		var np = NinePatchRect.new()
		np.texture = tex_banner
		_aplicar_margenes_banner(np, tex_banner)
		np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		np.axis_stretch_vertical   = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		np.z_index = 0
		banner_wrap.add_child(np)

	var lbl = _crear_label(titulo, 44, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_right = -50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 1
	banner_wrap.add_child(lbl)

	var btn_x = _crear_btn_x()
	btn_x.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	btn_x.offset_left   = -73
	btn_x.offset_top    = -32
	btn_x.offset_right  = -10
	btn_x.offset_bottom = 31
	btn_x.z_index = 5
	btn_x.pressed.connect(func():
		if _btn_bloqueado: return
		_btn_bloqueado = true
		if _sfx_cerrar: _sfx_cerrar.play()
		if not (has_node("/root/AnimManager") and AnimManager.activas):
			await get_tree().create_timer(0.12).timeout
			accion_cerrar.call()
			return
		btn_x.pivot_offset = btn_x.size / 2.0
		var tw = create_tween()
		tw.tween_property(btn_x, "scale", Vector2(0.78, 0.78), 0.08).set_trans(Tween.TRANS_QUART)
		tw.tween_property(btn_x, "scale", Vector2(1.0, 1.0),   0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(accion_cerrar)
	)
	banner_wrap.add_child(btn_x)

	return banner_wrap

func _crear_tarjeta_horizontal(nombre: String, desc: String, icono: String, acento: Color, accion: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size   = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter          = Control.MOUSE_FILTER_STOP

	var tex_btn = load(ICO_BOTON) as Texture2D
	if tex_btn:
		var style = StyleBoxTexture.new()
		style.texture = tex_btn
		_aplicar_margenes_boton(style, tex_btn)
		card.add_theme_stylebox_override("panel", style)
	else:
		var sf = StyleBoxFlat.new()
		sf.bg_color = CREMA
		sf.set_corner_radius_all(20)
		sf.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", sf)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var icon_cc = CenterContainer.new()
	icon_cc.custom_minimum_size = Vector2(72, 72)
	icon_cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_cc)
	var tex_ico = load(icono) as Texture2D
	if tex_ico:
		var ir = TextureRect.new()
		ir.texture             = tex_ico
		ir.ignore_texture_size = true
		ir.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.custom_minimum_size = Vector2(60, 60)
		icon_cc.add_child(ir)
	else:
		icon_cc.add_child(_crear_label("▶", 40, acento, false))

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	info_vbox.add_child(_crear_label(nombre, 25, Color.WHITE, true))

	var lbl_desc = _crear_label(desc, 16, Color(0.88, 0.92, 1.0), false)
	lbl_desc.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(lbl_desc)

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch and ev.pressed:
			accion.call(card)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accion.call(card)
	)
	_iniciar_wobble(card)
	return card

func _crear_boton_svg(texto: String, min_size: Vector2, tam_fuente: int, accion: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = min_size
	card.mouse_filter        = Control.MOUSE_FILTER_STOP

	var tex_btn = load(ICO_BOTON) as Texture2D
	if tex_btn:
		var style = StyleBoxTexture.new()
		style.texture = tex_btn
		_aplicar_margenes_boton(style, tex_btn)
		card.add_theme_stylebox_override("panel", style)

	var cc = CenterContainer.new()
	card.add_child(cc)

	var lbl = _crear_label(texto, tam_fuente, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(lbl)
	if texto == "Ingresar":
		_lbl_btn_login = lbl

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch and ev.pressed:
			accion.call(card)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accion.call(card)
	)
	_iniciar_wobble(card)
	return card

func _crear_kpi_svg(titulo: String, valor: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size   = Vector2(0, 82)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tex_btn = load(ICO_BOTON) as Texture2D
	if tex_btn:
		var style = StyleBoxTexture.new()
		style.texture = tex_btn
		_aplicar_margenes_boton(style, tex_btn)
		card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var l1 = _crear_label(titulo, 15, Color(0.88, 0.92, 1.0), false)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l1)

	var l2 = _crear_label(valor, 24, Color.WHITE, true)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l2)

	return card

func _crear_item_historial(titulo: String, subtitulo: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size   = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tex_btn = load(ICO_BOTON) as Texture2D
	if tex_btn:
		var style = StyleBoxTexture.new()
		style.texture = tex_btn
		_aplicar_margenes_boton(style, tex_btn)
		card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	vbox.add_child(_crear_label(titulo, 20, Color.WHITE, true))
	vbox.add_child(_crear_label(subtitulo, 15, Color(0.88, 0.92, 1.0), false))
	return card

func _crear_input(placeholder: String, es_password: bool) -> LineEdit:
	var inp = LineEdit.new()
	inp.placeholder_text    = placeholder
	inp.secret              = es_password
	inp.custom_minimum_size = Vector2(400, 48)
	inp.alignment           = HORIZONTAL_ALIGNMENT_CENTER
	inp.add_theme_font_size_override("font_size", 20)
	if _font:
		inp.add_theme_font_override("font", _font)
	inp.add_theme_color_override("font_color", NAVY)
	inp.add_theme_color_override("font_placeholder_color", Color(0.45, 0.52, 0.62))

	var st = StyleBoxFlat.new()
	st.bg_color = Color.WHITE
	st.border_color = Color(0.70, 0.50, 0.28)
	st.set_border_width_all(3)
	st.set_corner_radius_all(14)
	st.content_margin_left  = 16
	st.content_margin_right = 16
	inp.add_theme_stylebox_override("normal", st)
	inp.add_theme_stylebox_override("focus", st)
	return inp

func _crear_btn_x() -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(63, 63)
	var empty = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	var ir = TextureRect.new()
	ir.texture = load(ICO_X) as Texture2D
	ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ir)
	return btn

# ---------------------------------------------------------------------------
# Modal de alerta amigable (con panel.svg y boton.svg)
# ---------------------------------------------------------------------------

func _construir_modal_alerta():
	_modal_alerta = ColorRect.new()
	_modal_alerta.color = Color(0.04, 0.08, 0.20, 0.80)
	_modal_alerta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_alerta.visible = false
	_modal_alerta.z_index = 50
	add_child(_modal_alerta)

	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_alerta.add_child(cc)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 250)
	var tex_panel = load(ICO_PANEL) as Texture2D
	if tex_panel:
		var style = StyleBoxTexture.new()
		style.texture = tex_panel
		_aplicar_margenes_panel(style, tex_panel)
		card.add_theme_stylebox_override("panel", style)
	cc.add_child(card)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	card.add_child(vb)

	_lbl_alerta_titulo = _crear_label("Aviso del Sistema", 26, NAVY, true)
	_lbl_alerta_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lbl_alerta_titulo)

	_lbl_alerta_mensaje = _crear_label(
		"Por favor, verifique las conexiones o contacte al administrador.",
		18,
		NAVY,
		false
	)
	_lbl_alerta_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_alerta_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_lbl_alerta_mensaje)

	var hb = CenterContainer.new()
	vb.add_child(hb)

	var btn_ok = _crear_boton_svg("Entendido", Vector2(200, 58), 20, func(_c: PanelContainer):
		if _sfx_click: _sfx_click.play()
		_modal_alerta.visible = false
	)
	hb.add_child(btn_ok)

func _mostrar_alerta_amigable(titulo: String, mensaje: String):
	if is_instance_valid(_lbl_alerta_titulo):
		_lbl_alerta_titulo.text = titulo
	if is_instance_valid(_lbl_alerta_mensaje):
		_lbl_alerta_mensaje.text = mensaje
	if is_instance_valid(_modal_alerta):
		_modal_alerta.visible = true

# ---------------------------------------------------------------------------
# Animaciones y Helpers NinePatch idénticos a menu_principal.gd / menu_actividades.gd
# ---------------------------------------------------------------------------

func _animar_click(card: PanelContainer, callback: Callable):
	if _btn_bloqueado: return
	_btn_bloqueado = true
	if _sfx_click: _sfx_click.play()
	if not (has_node("/root/AnimManager") and AnimManager.activas):
		await get_tree().create_timer(0.12).timeout
		callback.call()
		return
	card.pivot_offset = card.size / 2.0
	var tw = create_tween()
	tw.tween_property(card, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_QUART)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0),   0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(callback)

func _iniciar_wobble(node: Control) -> void:
	var idx := _wobble_index
	_wobble_index += 1
	var phase: float = idx * 0.41
	var speed: float = 0.75 + idx * 0.105
	var angle: float = 0.24
	await get_tree().process_frame
	if not is_instance_valid(node): return
	node.pivot_offset = node.size / 2.0
	var tw = create_tween().set_loops()
	if phase > 0.0: tw.tween_interval(phase)
	tw.tween_property(node, "rotation_degrees",  angle, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation_degrees", -angle, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_data.append({"node": node, "tween": tw, "type": "wobble", "phase": phase, "speed": speed, "angle": angle})
	if has_node("/root/AnimManager") and not AnimManager.activas:
		tw.pause(); node.rotation_degrees = 0.0

func _iniciar_jiggle(node: Control) -> void:
	node.pivot_offset = Vector2(node.custom_minimum_size.x / 2.0, node.custom_minimum_size.y)
	var tw = create_tween().set_loops()
	tw.tween_property(node, "rotation_degrees",  5.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation_degrees", -5.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation_degrees",  2.5, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation_degrees",  0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(2.5)
	_wobble_data.append({"node": node, "tween": tw, "type": "jiggle", "phase": 0.0, "speed": 0.0, "angle": 0.0})
	if has_node("/root/AnimManager") and not AnimManager.activas:
		tw.pause(); node.rotation_degrees = 0.0

func _on_anim_changed(activo: bool):
	if activo:
		_recrear_wobbles()
	else:
		for d in _wobble_data:
			if is_instance_valid(d["tween"]): d["tween"].pause()
			if is_instance_valid(d["node"]): d["node"].rotation_degrees = 0.0

func _recrear_wobbles():
	for d in _wobble_data:
		if not is_instance_valid(d["node"]): continue
		if is_instance_valid(d["tween"]): d["tween"].kill()
		var node: Control = d["node"]
		node.rotation_degrees = 0.0
		var tw = create_tween().set_loops()
		d["tween"] = tw
		if d["type"] == "wobble":
			var phase: float = d["phase"]
			if phase > 0.0: tw.tween_interval(phase)
			tw.tween_property(node, "rotation_degrees",  d["angle"], d["speed"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(node, "rotation_degrees", -d["angle"], d["speed"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif d["type"] == "jiggle":
			node.pivot_offset = Vector2(node.custom_minimum_size.x / 2.0, node.custom_minimum_size.y)
			tw.tween_property(node, "rotation_degrees",  5.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "rotation_degrees", -5.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(node, "rotation_degrees",  2.5, 0.10).set_trans(Tween.TRANS_SINE)
			tw.tween_property(node, "rotation_degrees",  0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_interval(2.5)

func _aplicar_margenes_panel(s: StyleBoxTexture, tex: Texture2D):
	var m: int = max(4, int(tex.get_width() * 0.156))
	s.texture_margin_left   = m; s.texture_margin_right  = m
	s.texture_margin_top    = m; s.texture_margin_bottom = m
	var cm: int = m + 16
	s.content_margin_left   = cm; s.content_margin_right  = cm
	s.content_margin_top    = cm; s.content_margin_bottom = cm

func _aplicar_margenes_boton(s: StyleBoxTexture, tex: Texture2D):
	var m: int = max(6, int(tex.get_width() * 0.25))
	s.texture_margin_left   = m; s.texture_margin_right  = m
	s.texture_margin_top    = m; s.texture_margin_bottom = m
	s.content_margin_left   = 14; s.content_margin_right  = 14
	s.content_margin_top    = 10; s.content_margin_bottom = 10

func _aplicar_margenes_banner(np: NinePatchRect, tex: Texture2D):
	var w: int = tex.get_width(); var h: int = tex.get_height()
	np.patch_margin_left   = max(4, int(w * 0.047))
	np.patch_margin_right  = max(4, int(w * 0.047))
	np.patch_margin_top    = max(4, int(h * 0.203))
	np.patch_margin_bottom = max(4, int(h * 0.203))

func _crear_label(texto: String, tam: int, color: Color, _negrita: bool) -> Label:
	var lbl = Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	if _font: lbl.add_theme_font_override("font", _font)
	return lbl
