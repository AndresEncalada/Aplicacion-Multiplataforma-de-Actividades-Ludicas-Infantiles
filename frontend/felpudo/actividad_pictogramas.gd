extends Control

const MANDARINA := Color(1.00, 0.50, 0.08)
const TURQUESA  := Color(0.05, 0.68, 0.72)
const CREMA     := Color(1.00, 0.96, 0.86)
const AMBAR     := Color(0.98, 0.82, 0.08)
const NAVY      := Color(0.08, 0.18, 0.38)

# Paths de assets
const FONT_KFN   := "res://assets/fuente/Kenney Future Narrow.ttf"
const SND_CLICK  := "res://assets/sonidos/click.ogg"
const SND_EXITO  := "res://assets/sonidos/exito.ogg"
const SND_ERROR  := "res://assets/sonidos/sonido_derrota.wav"
const ICO_PANEL  := "res://assets/iconos/panel.svg"
const ICO_BANNER := "res://assets/iconos/banner.svg"
const ICO_X      := "res://assets/iconos/x.svg"
const SND_CERRAR := "res://assets/sonidos/cerrar.ogg"

@onready var camara_texture = $CamaraTexture
@onready var fondo_blanco   = $FondoBlanco
@onready var fondo_oscuro   = $FondoOscuro

var websocket = WebSocketPeer.new()
var url = Config.WS_PICTOGRAMAS
var reconectando = false
var tiempo_reconexion = 0.0

var estado = "INICIAL"
var nombre_detectado = ""
var is_recording = false

var _btn_bloqueado = false
var _saliendo := false

var _tex_micro: Texture2D

var _font: FontFile

var _sfx_click: AudioStreamPlayer
var _sfx_exito: AudioStreamPlayer
var _sfx_error: AudioStreamPlayer
var _sfx_cerrar: AudioStreamPlayer

var _btn_x: Button
var _wobble_data: Array = []

# Nodos de UI
var contenedor_inicial: CenterContainer
var contenedor_popup: CenterContainer
var popup_label: Label
var btn_si: Button
var btn_no: Button
var btn_ok: Button
var contenedor_exito: CenterContainer
var titulo_exito_label: Label
var pregunta_label: Label
var btn_microfono: TextureButton
var btn_volver_act: Button

func _ready():
	print("🔌 Conectando al backend de pictogramas...")
	websocket.connect_to_url(url)

	_tex_micro = load("res://assets/iconos/micro.png")
	_font      = load(FONT_KFN)

	_cargar_audio()
	_crear_interfaz()
	_iniciar_wobble(btn_ok)
	_iniciar_wobble(btn_microfono)
	if has_node("/root/AnimManager"):
		AnimManager.changed.connect(_on_anim_changed)

# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

func _cargar_audio():
	_sfx_click = AudioStreamPlayer.new()
	var s_click = load(SND_CLICK)
	if s_click:
		_sfx_click.stream    = s_click
		_sfx_click.volume_db = -6.0
	add_child(_sfx_click)

	_sfx_exito = AudioStreamPlayer.new()
	var s_exito = load(SND_EXITO)
	if s_exito:
		_sfx_exito.stream    = s_exito
		_sfx_exito.volume_db = -3.0
	add_child(_sfx_exito)

	_sfx_error = AudioStreamPlayer.new()
	var s_error = load(SND_ERROR)
	if s_error:
		_sfx_error.stream    = s_error
		_sfx_error.volume_db = -8.0
	add_child(_sfx_error)

	_sfx_cerrar = AudioStreamPlayer.new()
	var s_cerrar = load(SND_CERRAR)
	if s_cerrar:
		_sfx_cerrar.stream    = s_cerrar
		_sfx_cerrar.volume_db = -6.0
	add_child(_sfx_cerrar)

# ---------------------------------------------------------------------------
# Interfaz
# ---------------------------------------------------------------------------

func _crear_interfaz():
	# --- Pantalla Inicial ---
	contenedor_inicial = CenterContainer.new()
	contenedor_inicial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(contenedor_inicial)

	var win_inicial = _crear_ventana("", 520)
	contenedor_inicial.add_child(win_inicial["wrapper"])

	var vbox_inicial = win_inicial["vbox"] as VBoxContainer
	vbox_inicial.add_child(
		_crear_label("Alista el dibujo que quieras", 30, NAVY, true, true)
	)

	btn_ok = _crear_boton("Conectando...", Vector2(200, 96), MANDARINA)
	btn_ok.disabled = true
	btn_ok.pressed.connect(_on_btn_ok_pressed)
	var cc_ok = CenterContainer.new()
	cc_ok.add_child(btn_ok)
	vbox_inicial.add_child(cc_ok)

	# --- Popup (fallos de detección) ---
	contenedor_popup = CenterContainer.new()
	contenedor_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor_popup.visible = false
	add_child(contenedor_popup)

	var win_popup = _crear_ventana("", 540)
	contenedor_popup.add_child(win_popup["wrapper"])

	var vbox_popup = win_popup["vbox"] as VBoxContainer
	popup_label = _crear_label("", 28, NAVY, false, true)
	popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_popup.add_child(popup_label)

	var hbox_popup = HBoxContainer.new()
	hbox_popup.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_popup.add_theme_constant_override("separation", 20)
	vbox_popup.add_child(hbox_popup)

	btn_si = _crear_boton("Sí", Vector2(130, 96), MANDARINA)
	btn_si.pressed.connect(_on_btn_si_pressed)
	hbox_popup.add_child(btn_si)

	btn_no = _crear_boton("No", Vector2(130, 96), Color(0.88, 0.22, 0.18))
	btn_no.pressed.connect(_on_btn_no_pressed)
	hbox_popup.add_child(btn_no)

	# --- Pantalla de preguntas (Éxito) ---
	contenedor_exito = CenterContainer.new()
	contenedor_exito.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor_exito.visible = false
	add_child(contenedor_exito)

	var win_exito = _crear_ventana("", 580)
	contenedor_exito.add_child(win_exito["wrapper"])

	var vbox_exito = win_exito["vbox"] as VBoxContainer

	titulo_exito_label = _crear_label("", 44, MANDARINA.darkened(0.08), true, true)
	vbox_exito.add_child(titulo_exito_label)

	pregunta_label = _crear_label("¿Qué quieres saber?", 24, Color(0.35, 0.45, 0.65), false, true)
	pregunta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_exito.add_child(pregunta_label)

	var hbox_acciones = HBoxContainer.new()
	hbox_acciones.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_acciones.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox_acciones.add_theme_constant_override("separation", 20)
	vbox_exito.add_child(hbox_acciones)

	btn_microfono = TextureButton.new()
	btn_microfono.ignore_texture_size = true
	btn_microfono.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_microfono.custom_minimum_size = Vector2(96, 96)
	btn_microfono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_microfono.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	if _tex_micro:
		btn_microfono.texture_normal = _tex_micro
	btn_microfono.button_down.connect(_on_microfono_down)
	btn_microfono.button_up.connect(_on_microfono_up)
	hbox_acciones.add_child(btn_microfono)

	# Botón Volver (debajo del micrófono, regresa al escaneo)
	btn_volver_act = _crear_boton("Volver", Vector2(130, 64), Color(0.3, 0.4, 0.6))
	btn_volver_act.add_theme_font_size_override("font_size", 20)
	btn_volver_act.pressed.connect(_volver_a_actividad)
	var cc_volver = CenterContainer.new()
	cc_volver.add_child(btn_volver_act)
	vbox_exito.add_child(cc_volver)

	# Mostrar overlay oscuro en estado inicial (cámara visible detrás)
	fondo_oscuro.visible = true

	# Botón X añadido AL FINAL para que reciba input antes que los contenedores FULL_RECT
	_btn_x = _crear_btn_x()
	_btn_x.pressed.connect(_salir_a_menu)
	_btn_x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_x.offset_left   = -73
	_btn_x.offset_top    = -4
	_btn_x.offset_right  = -10
	_btn_x.offset_bottom = 59
	_btn_x.z_index = 20
	add_child(_btn_x)

# ---------------------------------------------------------------------------
# Ventana con panel.svg + banner.svg de título (diseño dialog)
# ---------------------------------------------------------------------------

func _crear_ventana(titulo: String, ancho: float) -> Dictionary:
	# VBoxContainer que apila banner + panel con solapamiento
	var outer = VBoxContainer.new()
	outer.custom_minimum_size = Vector2(ancho, 0)
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", -67)  # 50 % de 135 px

	# Banner de título (solo si hay título)
	if titulo != "":
		var tex_ban = load(ICO_BANNER) as Texture2D
		if tex_ban:
			var np = NinePatchRect.new()
			np.texture = tex_ban
			_aplicar_margenes_banner(np, tex_ban)
			np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			np.axis_stretch_vertical   = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			np.custom_minimum_size = Vector2(ancho, 135)
			np.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			np.z_index = 2

			var lbl_titulo = _crear_label(titulo, 32, NAVY, true, true)
			lbl_titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_titulo.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			np.add_child(lbl_titulo)

			outer.add_child(np)

	# Panel de contenido con panel.svg
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.z_index = 1

	var tex_panel = load(ICO_PANEL) as Texture2D
	if tex_panel:
		var style = StyleBoxTexture.new()
		style.texture = tex_panel
		_aplicar_margenes_panel(style, tex_panel)
		# Solapamiento del banner: si hay título, el panel cede espacio en la cima
		if titulo != "":
			style.content_margin_top = style.content_margin_top + 20
		panel.add_theme_stylebox_override("panel", style)
	else:
		var sf = StyleBoxFlat.new()
		sf.bg_color = CREMA
		sf.set_corner_radius_all(24)
		sf.set_content_margin_all(20)
		panel.add_theme_stylebox_override("panel", sf)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	panel.add_child(vbox)

	outer.add_child(panel)
	return {"wrapper": outer, "vbox": vbox}

# ---------------------------------------------------------------------------
# Helpers de UI
# ---------------------------------------------------------------------------

func _crear_boton(texto: String, tam: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.custom_minimum_size = tam
	btn.add_theme_font_size_override("font_size", 26)
	if _font: btn.add_theme_font_override("font", _font)

	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(22)
	normal.border_width_bottom = 8
	normal.border_color = color.darkened(0.28)
	normal.shadow_color = Color(0.04, 0.08, 0.20, 0.35)
	normal.shadow_size  = 8
	normal.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.12)
	hover.set_corner_radius_all(22)
	hover.border_width_bottom = 8
	hover.border_color = color.darkened(0.22)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_s = StyleBoxFlat.new()
	pressed_s.bg_color = color.darkened(0.08)
	pressed_s.set_corner_radius_all(22)
	pressed_s.border_width_bottom = 2
	pressed_s.border_color = color.darkened(0.35)
	pressed_s.set_content_margin(SIDE_TOP, 5)
	btn.add_theme_stylebox_override("pressed", pressed_s)

	btn.add_theme_color_override("font_color",         Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	return btn

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

func _crear_label(texto: String, tam: int, color: Color, _negrita: bool, centrado: bool = false) -> Label:
	var lbl = Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	if centrado: lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font: lbl.add_theme_font_override("font", _font)
	return lbl

func _iniciar_wobble(node: Control):
	if not is_instance_valid(node): return
	await get_tree().process_frame
	if not is_instance_valid(node): return
	var sz = node.size if node.size.x > 1 else node.custom_minimum_size
	node.pivot_offset = sz / 2.0
	var angle: float = 0.24; var speed: float = 0.75
	var tw = create_tween().set_loops()
	tw.tween_property(node, "rotation_degrees",  angle, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation_degrees", -angle, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_data.append({"node": node, "tween": tw, "type": "wobble", "phase": 0.0, "speed": speed, "angle": angle})
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
		tw.tween_property(node, "rotation_degrees",  d["angle"], d["speed"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(node, "rotation_degrees", -d["angle"], d["speed"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _tocar_boton(btn: Control, sfx: AudioStreamPlayer = null) -> bool:
	if _btn_bloqueado: return false
	_btn_bloqueado = true
	if has_node("/root/AnimManager") and AnimManager.activas:
		btn.pivot_offset = btn.size / 2.0
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(0.91, 0.91), 0.07).set_trans(Tween.TRANS_QUART)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0),   0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.4).timeout.connect(func(): _btn_bloqueado = false)
	var player: AudioStreamPlayer = sfx if sfx else _sfx_click
	if player: player.play()
	return true

# ---------------------------------------------------------------------------
# NinePatch helpers (proporcionales)
# ---------------------------------------------------------------------------

func _aplicar_margenes_panel(s: StyleBoxTexture, tex: Texture2D):
	var m: int = max(4, int(tex.get_width() * 0.156))
	s.texture_margin_left   = m
	s.texture_margin_right  = m
	s.texture_margin_top    = m
	s.texture_margin_bottom = m
	var cm: int = m + 16
	s.content_margin_left   = cm
	s.content_margin_right  = cm
	s.content_margin_top    = cm
	s.content_margin_bottom = cm

func _aplicar_margenes_banner(np: NinePatchRect, tex: Texture2D):
	var w := tex.get_width()
	var h := tex.get_height()
	np.patch_margin_left   = max(4, int(w * 0.047))
	np.patch_margin_right  = max(4, int(w * 0.047))
	np.patch_margin_top    = max(4, int(h * 0.203))
	np.patch_margin_bottom = max(4, int(h * 0.203))

# ---------------------------------------------------------------------------
# _process
# ---------------------------------------------------------------------------

func _process(delta):
	if _saliendo:
		websocket.poll()
		return
	if reconectando:
		tiempo_reconexion -= delta
		if tiempo_reconexion <= 0:
			reconectando = false
			websocket = WebSocketPeer.new()
			websocket.connect_to_url(url)
		return

	websocket.poll()
	var ws_state = websocket.get_ready_state()

	if btn_ok:
		if ws_state == WebSocketPeer.STATE_OPEN:
			if btn_ok.disabled:
				btn_ok.disabled = false
				btn_ok.text = "Ok"
		elif ws_state == WebSocketPeer.STATE_CLOSED:
			if not btn_ok.disabled:
				btn_ok.disabled = true
				btn_ok.text = "Conectando..."
			if not reconectando:
				reconectando = true
				tiempo_reconexion = 3.0

	if ws_state == WebSocketPeer.STATE_OPEN:
		while websocket.get_available_packet_count() > 0:
			var packet = websocket.get_packet()
			if packet.size() >= 2 and packet[0] == 0xFF and packet[1] == 0xD8:
				if estado == "INICIAL" or estado == "ESCANEO":
					var image = Image.new()
					if image.load_jpg_from_buffer(packet) == OK:
						if camara_texture.texture == null:
							camara_texture.texture = ImageTexture.create_from_image(image)
						else:
							(camara_texture.texture as ImageTexture).update(image)
			else:
				var data = JSON.parse_string(packet.get_string_from_utf8())
				if data: _manejar_mensaje(data)

# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

func _on_btn_ok_pressed():
	if not _tocar_boton(btn_ok): return
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	_ocultar_todos_los_contenedores()
	estado = "ESCANEO"
	websocket.send_text(JSON.stringify({"accion": "iniciar_escaneo"}))

func _on_btn_si_pressed():
	if not _tocar_boton(btn_si): return
	_ir_a_preguntas()

func _on_btn_no_pressed():
	if not _tocar_boton(btn_no): return
	_ocultar_todos_los_contenedores()
	if estado == "FALLO":
		estado = "INICIAL"
		contenedor_inicial.visible = true
		btn_no.text = "No"
	else:
		estado = "ESCANEO"
		websocket.send_text(JSON.stringify({"accion": "rechazar"}))

func _on_microfono_down():
	if is_recording: return
	if _sfx_click: _sfx_click.play()
	websocket.send_text(JSON.stringify({"comando": "iniciar_grabacion"}))
	is_recording = true
	pregunta_label.text = "Grabando... habla ahora"
	var sz = btn_microfono.size if btn_microfono.size.x > 1 else btn_microfono.custom_minimum_size
	btn_microfono.pivot_offset = sz / 2.0
	if has_node("/root/AnimManager") and AnimManager.activas:
		var tw = create_tween()
		tw.tween_property(btn_microfono, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_microfono_up():
	if not is_recording: return
	websocket.send_text(JSON.stringify({"comando": "detener_grabacion"}))
	is_recording = false
	pregunta_label.text = "Procesando tu pregunta..."
	if has_node("/root/AnimManager") and AnimManager.activas:
		var tw = create_tween()
		tw.tween_property(btn_microfono, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		btn_microfono.scale = Vector2(1.0, 1.0)

func _volver_a_actividad():
	if not _tocar_boton(btn_volver_act): return
	_ocultar_todos_los_contenedores()
	estado = "ESCANEO"
	camara_texture.visible = true
	fondo_blanco.visible = false
	is_recording = false
	btn_microfono.scale = Vector2(1.0, 1.0)
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		websocket.send_text(JSON.stringify({"comando": "volver"}))
		websocket.send_text(JSON.stringify({"accion": "iniciar_escaneo"}))

func _salir_a_menu():
	if _btn_bloqueado: return
	_btn_bloqueado = true
	_saliendo = true
	websocket.close()
	var http_r = HTTPRequest.new()
	add_child(http_r)
	http_r.request_completed.connect(func(_a, _b, _c, _d): http_r.queue_free())
	http_r.request(Config.HTTP_LIBERAR_CAMARA, [], HTTPClient.METHOD_POST)
	if _sfx_cerrar: _sfx_cerrar.play()
	if is_instance_valid(_btn_x) and has_node("/root/AnimManager") and AnimManager.activas:
		_btn_x.pivot_offset = _btn_x.size / 2.0
		var tw = create_tween()
		tw.tween_property(_btn_x, "scale", Vector2(0.78, 0.78), 0.08).set_trans(Tween.TRANS_QUART)
		tw.tween_property(_btn_x, "scale", Vector2(1.0, 1.0),   0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://menu_actividades.tscn"))
	else:
		await get_tree().create_timer(0.12).timeout
		get_tree().change_scene_to_file("res://menu_actividades.tscn")

func _ir_a_preguntas():
	_ocultar_todos_los_contenedores()
	estado = "EXITO"
	camara_texture.visible = false
	fondo_blanco.visible = true
	contenedor_exito.visible = true
	titulo_exito_label.text = "Es " + nombre_detectado
	pregunta_label.text = "¿Qué quieres saber?"
	btn_microfono.visible = true
	btn_microfono.scale = Vector2(1.0, 1.0)
	is_recording = false
	websocket.send_text(JSON.stringify({"accion": "confirmar"}))

# ---------------------------------------------------------------------------
# Mensajes WebSocket
# ---------------------------------------------------------------------------

func _manejar_mensaje(data):
	var evento = data.get("evento", "")
	if evento == "propuesta_pictograma":
		nombre_detectado = data.get("nombre", "desconocido")
		if _sfx_exito: _sfx_exito.play()  # Sonido de éxito al detectar
		_ir_a_preguntas()
	elif evento == "fallo_deteccion":
		estado = "FALLO"
		var tipo = data.get("tipo", "no_detectado")
		popup_label.text = "No pude detectar\nningún pictograma." \
			if tipo == "no_detectado" \
			else "No pude identificar\nel pictograma,\nintenta con otro."
		btn_si.visible = false
		btn_no.text = "Reintentar"
		if _sfx_error: _sfx_error.play()
		_mostrar_solo_popup()
	elif evento == "grabacion_iniciada":
		pregunta_label.text = "Grabando... habla ahora"
	elif evento == "respuesta_audio" or evento == "error_audio":
		var respuesta = data.get("respuesta_sistema", data.get("mensaje", "No pude entender eso."))
		pregunta_label.text = respuesta
		btn_microfono.visible = true
		is_recording = false
		btn_microfono.scale = Vector2(1.0, 1.0)

# ---------------------------------------------------------------------------
# Visibilidad
# ---------------------------------------------------------------------------

func _ocultar_todos_los_contenedores():
	contenedor_inicial.visible = false
	contenedor_popup.visible   = false
	contenedor_exito.visible   = false
	fondo_oscuro.visible       = false

func _mostrar_solo_popup():
	_ocultar_todos_los_contenedores()
	fondo_oscuro.visible     = true
	contenedor_popup.visible = true
