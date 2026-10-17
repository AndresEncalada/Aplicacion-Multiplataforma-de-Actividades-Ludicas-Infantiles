extends Control

const MANDARINA := Color(1.00, 0.50, 0.08)
const TURQUESA  := Color(0.05, 0.68, 0.72)
const CREMA     := Color(1.00, 0.96, 0.86)
const AMBAR     := Color(0.98, 0.82, 0.08)
const NAVY      := Color(0.08, 0.18, 0.38)

const FONT_KFN   := "res://assets/fuente/Kenney Future Narrow.ttf"
const SND_CLICK  := "res://assets/sonidos/click.ogg"
const SND_EXITO  := "res://assets/sonidos/exito.ogg"
const SND_CERRAR := "res://assets/sonidos/cerrar.ogg"
const SND_DERROT := "res://assets/sonidos/sonido_derrota.wav"
const SND_VICTOR := "res://assets/sonidos/sonido_victoria.wav"
const ICO_PANEL  := "res://assets/iconos/panel.svg"
const ICO_BANNER := "res://assets/iconos/banner.svg"
const ICO_CHECK  := "res://assets/iconos/check.svg"
const ICO_X      := "res://assets/iconos/x.svg"
const BANNER_H: int = 135

# WebSocket
var websocket = WebSocketPeer.new()
var url = Config.WS_CUERPO
var ya_conectado = false
var reconectando = false
var tiempo_reconexion = 0.0
var estado_actual = ""
var victoria_reproducida = false
var reiniciando = false

var _btn_bloqueado := false
var _font: FontFile

# Audio
var _sfx_click: AudioStreamPlayer
var _sfx_exito: AudioStreamPlayer
var _sfx_error: AudioStreamPlayer
var _sfx_victoria: AudioStreamPlayer
var _sfx_cerrar: AudioStreamPlayer

# Activity UI refs
var _video_texture: TextureRect
var _instruccion_label: Label
var _progreso_label: Label
var _tiempo_label: Label
var _flash_overlay: ColorRect
var _check_icon: Sprite2D
var _btn_x: Button

# Wobble
var _wobble_data: Array = []
var _derrota_sonada := false
var _saliendo := false

func _ready():
	_font = load(FONT_KFN)
	_cargar_audio()
	_construir_ui()
	if has_node("/root/AnimManager"):
		AnimManager.changed.connect(_on_anim_changed)
	websocket.connect_to_url(url)

# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

func _cargar_audio():
	_sfx_click   = _mk_sfx(SND_CLICK,  -6.0)
	_sfx_exito   = _mk_sfx(SND_EXITO,  -3.0)
	_sfx_error   = _mk_sfx(SND_DERROT, -8.0)
	_sfx_victoria = _mk_sfx(SND_VICTOR, -3.0)
	_sfx_cerrar  = _mk_sfx(SND_CERRAR, -6.0)

func _mk_sfx(path: String, vol: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var s = load(path)
	if s: p.stream = s; p.volume_db = vol
	add_child(p)
	return p

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _construir_ui():
	# 1. Fondo NAVY
	var bg = ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 2. Cámara — llena el viewport (igual que CamaraTexture en actividad_preguntas)
	_video_texture = TextureRect.new()
	_video_texture.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_video_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_video_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video_texture)

	# 3. Flash overlay
	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(1, 1, 1, 0.0)
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_overlay)

	# 4. Icono check (posicionado con Sprite2D.position desde código)
	_check_icon = Sprite2D.new()
	_check_icon.texture = load(ICO_CHECK)
	_check_icon.scale   = Vector2(0.5, 0.5)
	_check_icon.visible = false
	_check_icon.z_index = 10
	add_child(_check_icon)

	# 5. BarraInstruccion — anclada al borde inferior (igual que en actividad_preguntas)
	add_child(_crear_barra_instruccion())

	# 6. FondoOscuro — overlay semitransparente mientras el diálogo está abierto
	var fondo_oscuro = ColorRect.new()
	fondo_oscuro.name = "FondoOscuro"
	fondo_oscuro.color = Color(0.04, 0.08, 0.20, 0.82)
	fondo_oscuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo_oscuro)

	# 7. Diálogo de bienvenida (CenterContainer overlay)
	var cc_bien = CenterContainer.new()
	cc_bien.name = "CCBienvenida"
	cc_bien.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc_bien)

	var win = _crear_ventana("", 520)
	cc_bien.add_child(win["wrapper"])
	var vbox_bien = win["vbox"] as VBoxContainer

	var lbl_desc = _crear_label("Párate frente a la cámara\ny sigue las indicaciones de Felpudo", 26, NAVY, true)
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_bien.add_child(lbl_desc)

	var btn_comenzar = _crear_boton("¡Comenzar!", Vector2(220, 96), TURQUESA)
	var cc_btn = CenterContainer.new()
	cc_btn.add_child(btn_comenzar)
	vbox_bien.add_child(cc_btn)
	btn_comenzar.pressed.connect(func(): _comenzar_actividad(fondo_oscuro, cc_bien))
	_iniciar_wobble(btn_comenzar)

	# 8. Botón X — AL FINAL para recibir input antes que los FULL_RECT
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
# BarraInstruccion — anclada al fondo, overlay sobre la cámara
# (igual que BarraInstruccion en actividad_preguntas)
# ---------------------------------------------------------------------------

func _crear_barra_instruccion() -> PanelContainer:
	var barra = PanelContainer.new()
	barra.anchor_left   = 0.0
	barra.anchor_top    = 1.0
	barra.anchor_right  = 1.0
	barra.anchor_bottom = 1.0
	barra.offset_left   = 0
	barra.offset_right  = 0
	barra.offset_bottom = 0
	barra.offset_top    = -80
	barra.grow_vertical = Control.GROW_DIRECTION_BEGIN
	barra.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# StyleBoxFlat igual al de BarraInstruccion en actividad_pictogramas.tscn
	var sf = StyleBoxFlat.new()
	sf.bg_color          = Color(0.07, 0.14, 0.3, 0.88)
	sf.border_width_top  = 1
	sf.border_color      = Color(0.9, 0.78, 0.3, 0.45)
	sf.set_content_margin_all(20)
	barra.add_theme_stylebox_override("panel", sf)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	barra.add_child(hbox)

	_instruccion_label = _crear_label("Sigue las indicaciones de Felpudo", 34, Color(0.9, 0.92, 1.0, 1.0), false)
	_instruccion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruccion_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_instruccion_label)

	var vbox_info = VBoxContainer.new()
	vbox_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox_info.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox_info)

	_progreso_label = _crear_label("", 18, Color(0.9, 0.92, 1.0, 0.7), false)
	_tiempo_label   = _crear_label("", 24, AMBAR, false)
	vbox_info.add_child(_progreso_label)
	vbox_info.add_child(_tiempo_label)

	return barra

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Helpers de UI
# ---------------------------------------------------------------------------

func _crear_ventana(titulo: String, ancho: float) -> Dictionary:
	var outer = VBoxContainer.new()
	outer.custom_minimum_size  = Vector2(ancho, 0)
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", -67)  # 50 % de 135 px

	if titulo != "":
		var tex_ban = load(ICO_BANNER) as Texture2D
		if tex_ban:
			var np = NinePatchRect.new()
			np.texture = tex_ban
			_aplicar_margenes_banner(np, tex_ban)
			np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			np.axis_stretch_vertical   = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
			np.custom_minimum_size     = Vector2(ancho, 135)
			np.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
			np.z_index = 2
			var lbl_t = _crear_label(titulo, 28, NAVY, true)
			lbl_t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lbl_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_t.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl_t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			np.add_child(lbl_t)
			outer.add_child(np)

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.z_index = 1
	var tex_panel = load(ICO_PANEL) as Texture2D
	if tex_panel:
		var style = StyleBoxTexture.new()
		style.texture = tex_panel
		_aplicar_margenes_panel(style, tex_panel)
		if titulo != "": style.content_margin_top = style.content_margin_top + 20
		panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	panel.add_child(vbox)
	outer.add_child(panel)
	return {"wrapper": outer, "vbox": vbox}

func _crear_boton(texto: String, tam: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = texto
	btn.custom_minimum_size = tam
	btn.add_theme_font_size_override("font_size", 26)
	if _font: btn.add_theme_font_override("font", _font)
	var n = StyleBoxFlat.new()
	n.bg_color = color; n.set_corner_radius_all(22)
	n.border_width_bottom = 8; n.border_color = color.darkened(0.28)
	n.shadow_color = Color(0.04, 0.08, 0.20, 0.35); n.shadow_size = 8; n.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", n)
	var h = StyleBoxFlat.new()
	h.bg_color = color.lightened(0.12); h.set_corner_radius_all(22)
	h.border_width_bottom = 8; h.border_color = color.darkened(0.22)
	btn.add_theme_stylebox_override("hover", h)
	var p = StyleBoxFlat.new()
	p.bg_color = color.darkened(0.08); p.set_corner_radius_all(22)
	p.border_width_bottom = 2; p.border_color = color.darkened(0.35)
	p.set_content_margin(SIDE_TOP, 5)
	btn.add_theme_stylebox_override("pressed", p)
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

func _crear_label(texto: String, tam: int, color: Color, _negrita: bool) -> Label:
	var lbl = Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	if _font: lbl.add_theme_font_override("font", _font)
	return lbl

# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------

func _comenzar_actividad(fondo: ColorRect, cc: CenterContainer):
	if _btn_bloqueado: return
	_btn_bloqueado = true
	if _sfx_click: _sfx_click.play()
	fondo.visible = false
	cc.visible    = false
	get_tree().create_timer(0.4).timeout.connect(func(): _btn_bloqueado = false)

func _salir_a_menu():
	if _btn_bloqueado: return
	_btn_bloqueado = true
	_saliendo = true
	websocket.close()
	var http_r = HTTPRequest.new()
	add_child(http_r)
	http_r.request_completed.connect(func(_a,_b,_c,_d): http_r.queue_free())
	http_r.request(Config.HTTP_REINICIAR, [], HTTPClient.METHOD_POST)
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

# ---------------------------------------------------------------------------
# Animaciones
# ---------------------------------------------------------------------------

func _iniciar_wobble(node: Control) -> void:
	if not is_instance_valid(node): return
	await get_tree().process_frame
	if not is_instance_valid(node): return
	node.pivot_offset = node.size / 2.0
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

func _animar_flash_exito():
	_flash_overlay.color = Color(1, 1, 1, 0.8)
	var tw = create_tween()
	tw.tween_property(_flash_overlay, "color:a", 0.0, 0.35)

func _animar_check(posicion: Vector2, escala: float):
	_check_icon.position  = posicion
	_check_icon.scale     = Vector2(escala * 0.6, escala * 0.6)
	_check_icon.modulate.a = 1.0
	_check_icon.visible   = true
	var tw = create_tween()
	tw.tween_property(_check_icon, "scale", Vector2(escala * 1.2, escala * 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_check_icon, "scale", Vector2(escala, escala), 0.08)
	tw.tween_interval(0.65)
	tw.tween_property(_check_icon, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): _check_icon.visible = false)

# ---------------------------------------------------------------------------
# NinePatch helpers
# ---------------------------------------------------------------------------

func _aplicar_margenes_panel(s: StyleBoxTexture, tex: Texture2D):
	var m: int = max(4, int(tex.get_width() * 0.156))
	s.texture_margin_left = m; s.texture_margin_right  = m
	s.texture_margin_top  = m; s.texture_margin_bottom = m
	var cm: int = m + 16
	s.content_margin_left = cm; s.content_margin_right  = cm
	s.content_margin_top  = cm; s.content_margin_bottom = cm

func _aplicar_margenes_banner(np: NinePatchRect, tex: Texture2D):
	var w := tex.get_width(); var h := tex.get_height()
	np.patch_margin_left   = max(4, int(w * 0.047))
	np.patch_margin_right  = max(4, int(w * 0.047))
	np.patch_margin_top    = max(4, int(h * 0.203))
	np.patch_margin_bottom = max(4, int(h * 0.203))

# ---------------------------------------------------------------------------
# _process — WebSocket polling
# ---------------------------------------------------------------------------

func _process(delta):
	if _saliendo:
		# Seguir poliando para que el frame CLOSE se envíe antes del cambio de escena
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
	var state = websocket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not ya_conectado: ya_conectado = true; reconectando = false
		while websocket.get_available_packet_count() > 0:
			var packet = websocket.get_packet()
			if packet.size() > 2 and packet[0] == 0xFF and packet[1] == 0xD8:
				_actualizar_video(packet)
			else:
				var data = JSON.parse_string(packet.get_string_from_utf8())
				if data: _procesar_mensaje(data)
	elif state == WebSocketPeer.STATE_CLOSED:
		if ya_conectado:
			ya_conectado = false
			if is_instance_valid(_instruccion_label):
				_instruccion_label.text = "Reconectando..."
			reconectando = true; tiempo_reconexion = 3.0

func _actualizar_video(frame_bytes: PackedByteArray):
	var img = Image.new()
	if img.load_jpg_from_buffer(frame_bytes) == OK:
		if _video_texture.texture == null:
			_video_texture.texture = ImageTexture.create_from_image(img)
		else:
			(_video_texture.texture as ImageTexture).update(img)

func _procesar_mensaje(data: Dictionary):
	var evento: String = data.get("evento", "")
	var mensaje: String = data.get("mensaje", "")
	var efecto: String  = data.get("efecto_visual", "ninguno")
	estado_actual = evento

	if efecto == "flash_exito":
		_animar_flash_exito()
		var pos_check: Vector2 = _video_texture.size / 2.0
		var escala_check: float = 0.15
		if data.has("centro_cuerpo"):
			var c = data["centro_cuerpo"]
			var calc = _calc_check_pos(c.x, c.y, c.ancho_hombros)
			pos_check   = calc["posicion"]
			escala_check = calc["escala"]
		_animar_check(pos_check, escala_check)
		if _sfx_exito: _sfx_exito.play()

	match evento:
		"tiempo_agotado":
			if is_instance_valid(_instruccion_label): _instruccion_label.text = "Se acabó el tiempo"
			if is_instance_valid(_progreso_label):    _progreso_label.text    = ""
			if is_instance_valid(_tiempo_label):      _tiempo_label.text      = ""
			if _sfx_error and not _derrota_sonada:
				_derrota_sonada = true
				_sfx_error.play()
			_reiniciar_juego()
		"instruccion_postura", "torso_detectado", "esperando_mano", "jugador_seleccionado":
			if is_instance_valid(_instruccion_label): _instruccion_label.text = mensaje
			if is_instance_valid(_progreso_label):    _progreso_label.text    = ""
			if is_instance_valid(_tiempo_label):      _tiempo_label.text      = ""
			victoria_reproducida = false
		"esperando_inicio", "instruccion_actividad":
			if is_instance_valid(_instruccion_label): _instruccion_label.text = mensaje
			if is_instance_valid(_progreso_label):    _progreso_label.text    = data.get("progreso", "")
			var tiempo: float = data.get("tiempo_restante", 0.0)
			if is_instance_valid(_tiempo_label):
				_tiempo_label.text = str(int(tiempo)) + "s" if tiempo > 0 else ""
				var color_tiempo = Color(0.82, 0.15, 0.15) if tiempo <= 5 else AMBAR
				_tiempo_label.add_theme_color_override("font_color", color_tiempo)
		"actividad_exitosa":
			if is_instance_valid(_instruccion_label): _instruccion_label.text = mensaje
			if is_instance_valid(_progreso_label):    _progreso_label.text    = data.get("progreso", "")
		"juego_completado", "juego_terminado":
			if is_instance_valid(_instruccion_label): _instruccion_label.text = "¡Felicidades! " + mensaje
			if is_instance_valid(_progreso_label):    _progreso_label.text    = "¡Completado!"
			if not victoria_reproducida:
				victoria_reproducida = true
				if _sfx_victoria: _sfx_victoria.play()

func _calc_check_pos(cx: float, cy: float, ancho_hombros: float) -> Dictionary:
	var vw = _video_texture.size.x; var vh = _video_texture.size.y
	var img_r = 640.0 / 480.0; var rect_r = vw / vh
	var dw = vw; var dh = vh; var ox = 0.0; var oy = 0.0
	if rect_r > img_r: dw = vh * img_r; ox = (vw - dw) / 2.0
	else: dh = vw / img_r; oy = (vh - dh) / 2.0
	var esc = clamp((ancho_hombros / 200.0) * 0.15, 0.08, 0.25)
	return {"posicion": Vector2(ox + cx * dw, oy + cy * dh), "escala": esc}

func _reiniciar_juego():
	if reiniciando: return
	reiniciando = true
	var http = HTTPRequest.new(); add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): reiniciando = false; _derrota_sonada = false; http.queue_free())
	if http.request(Config.HTTP_REINICIAR, [], HTTPClient.METHOD_POST) != OK:
		reiniciando = false; http.queue_free()
