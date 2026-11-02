extends Control

const MANDARINA := Color(1.00, 0.50, 0.08)
const TURQUESA  := Color(0.05, 0.68, 0.72)
const CREMA     := Color(1.00, 0.96, 0.86)
const AMBAR     := Color(0.98, 0.82, 0.08)
const NAVY      := Color(0.08, 0.18, 0.38)

const FONT_KFN   := "res://assets/fuente/Kenney Future Narrow.ttf"
const SND_CLICK  := "res://assets/sonidos/click.ogg"
const ICO_MICRO  := "res://assets/iconos/micro.png"
const ICO_CHECK  := "res://assets/iconos/check.svg"
const ICO_PANEL  := "res://assets/iconos/panel.svg"
const ICO_BANNER := "res://assets/iconos/banner.svg"
const ICO_X      := "res://assets/iconos/x.svg"
const ICO_BOTON  := "res://assets/iconos/boton.svg"
const SND_CERRAR := "res://assets/sonidos/cerrar.ogg"

const BANNER_H: int = 135
const OVERLAP:  int = 67   # 50 % de BANNER_H

var _font: FontFile
var _btn_bloqueado := false
var _sfx_click: AudioStreamPlayer
var _sfx_cerrar: AudioStreamPlayer
var _wobble_index: int = 0
var _wobble_data: Array = []

func _ready():
	_font = load(FONT_KFN)
	_sfx_click = AudioStreamPlayer.new()
	var snd = load(SND_CLICK)
	if snd:
		_sfx_click.stream    = snd
		_sfx_click.volume_db = -6.0
	add_child(_sfx_click)
	_sfx_cerrar = AudioStreamPlayer.new()
	var snd_c = load(SND_CERRAR)
	if snd_c:
		_sfx_cerrar.stream    = snd_c
		_sfx_cerrar.volume_db = -6.0
	add_child(_sfx_cerrar)
	_construir_ui()
	if has_node("/root/AnimManager"):
		AnimManager.changed.connect(_on_anim_changed)

# ---------------------------------------------------------------------------
# Interfaz
# ---------------------------------------------------------------------------

func _construir_ui():
	var vp    := get_viewport().get_visible_rect().size
	var vp_w: float = vp.x
	var vp_h: float = vp.y
	var mg: int = int(vp_w * 0.02)

	var bg = ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	# Stack con separación negativa → panel sube OVERLAP px bajo el banner
	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", -OVERLAP)
	root_vbox.add_child(stack)

	var titulo_banner := "Actividades"
	if has_node("/root/SesionState") and SesionState.tiene_alumno_seleccionado():
		titulo_banner = "Actividades - " + str(SesionState.alumno_actual.get("nombre", ""))

	var header = _crear_header_banner(titulo_banner, vp_w)
	header.z_index = 2
	stack.add_child(header)

	# Panel de fondo — márgenes iguales en los 4 lados
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
		style.content_margin_top = OVERLAP + 20
		style.content_margin_bottom = max(40, int(vp_h * 0.08))
		panel_pc.add_theme_stylebox_override("panel", style)
	else:
		var sf = StyleBoxFlat.new()
		sf.bg_color = CREMA
		sf.set_corner_radius_all(24)
		sf.set_content_margin_all(20)
		panel_pc.add_theme_stylebox_override("panel", sf)

	# VBoxContainer de tarjetas dentro del panel
	var vbox_tarjetas = VBoxContainer.new()
	vbox_tarjetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_tarjetas.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_tarjetas.add_theme_constant_override("separation", 36)
	panel_pc.add_child(vbox_tarjetas)

	vbox_tarjetas.add_child(_crear_tarjeta(
		"Preguntas",
		"Muestra pictogramas a Felpudo y realiza preguntas",
		"res://assets/iconos/preguntas.png",
		MANDARINA,
		"res://actividad_pictogramas.tscn"
	))
	vbox_tarjetas.add_child(_crear_tarjeta(
		"Reconocimiento del cuerpo",
		"Realiza movimientos corporales indicados por Felpudo",
		"res://assets/iconos/cuerpo.png",
		TURQUESA,
		"res://actividad_cuerpo.tscn"
	))

# ---------------------------------------------------------------------------
# Header: banner.svg (135 px) + título + botón X (esquina derecha, 28 px)
# ---------------------------------------------------------------------------

func _crear_header_banner(titulo: String, _vp_w: float) -> Control:
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

	var lbl = _crear_label(titulo, 46, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_right  = -50
	lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
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
			_volver_atras()
			return
		btn_x.pivot_offset = btn_x.size / 2.0
		var tw = create_tween()
		tw.tween_property(btn_x, "scale", Vector2(0.78, 0.78), 0.08).set_trans(Tween.TRANS_QUART)
		tw.tween_property(btn_x, "scale", Vector2(1.0, 1.0),   0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_volver_atras)
	)
	banner_wrap.add_child(btn_x)

	return banner_wrap

func _volver_atras():
	var destino := "res://menu_principal.tscn"
	if has_node("/root/SesionState") and SesionState.esta_autenticado():
		destino = "res://login_profesor.tscn"
		if SesionState.sesion_activa_id > 0:
			var http = HTTPRequest.new()
			add_child(http)
			var body = JSON.stringify({"sesion_id": SesionState.sesion_activa_id})
			http.request_completed.connect(func(_r, _c, _h, _b):
				http.queue_free()
				SesionState.limpiar_alumno_activo()
				get_tree().change_scene_to_file(destino)
			)
			var err = http.request(Config.HTTP_SESION_FIN, SesionState.obtener_headers_json(true), HTTPClient.METHOD_POST, body)
			if err == OK:
				return
			http.queue_free()
		SesionState.limpiar_alumno_activo()
	get_tree().change_scene_to_file(destino)

# ---------------------------------------------------------------------------
# Tarjetas de actividad — boton.svg + layout horizontal, responsivo
# ---------------------------------------------------------------------------

func _crear_tarjeta(nombre: String, desc: String, icono: String, acento: Color, escena: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size   = Vector2(0, 120)
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

	# Ícono a la izquierda
	var icon_cc = CenterContainer.new()
	icon_cc.custom_minimum_size = Vector2(80, 80)
	icon_cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_cc)
	var tex_ico = load(icono) as Texture2D
	if tex_ico:
		var ir = TextureRect.new()
		ir.texture             = tex_ico
		ir.ignore_texture_size = true
		ir.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.custom_minimum_size = Vector2(64, 64)
		icon_cc.add_child(ir)
	else:
		icon_cc.add_child(_crear_label("▶", 44, acento, false))

	# Nombre + descripción a la derecha
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(info_vbox)

	info_vbox.add_child(_crear_label(nombre, 26, Color.WHITE, true))

	var lbl_desc = _crear_label(desc, 16, Color(0.88, 0.92, 1.0), false)
	lbl_desc.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(lbl_desc)

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch and ev.pressed:
			_abrir_actividad(card, escena)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_abrir_actividad(card, escena)
	)
	_iniciar_wobble(card)
	return card

# ---------------------------------------------------------------------------
# Botón X (icono reducido al 30 %)
# ---------------------------------------------------------------------------

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
# Animaciones
# ---------------------------------------------------------------------------

func _abrir_actividad(card: PanelContainer, escena: String):
	if _btn_bloqueado: return
	_btn_bloqueado = true
	if _sfx_click: _sfx_click.play()
	if not (has_node("/root/AnimManager") and AnimManager.activas):
		await get_tree().create_timer(0.12).timeout
		get_tree().change_scene_to_file(escena)
		return
	card.pivot_offset = card.size / 2.0
	var tw = create_tween()
	tw.tween_property(card, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_QUART)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0),   0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): get_tree().change_scene_to_file(escena))

func _iniciar_wobble(node: Control):
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
		var phase: float = d["phase"]
		if phase > 0.0: tw.tween_interval(phase)
		tw.tween_property(node, "rotation_degrees",  d["angle"], d["speed"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(node, "rotation_degrees", -d["angle"], d["speed"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------------
# Helpers NinePatch
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

func _aplicar_margenes_boton(s: StyleBoxTexture, tex: Texture2D):
	var m: int = max(6, int(tex.get_width() * 0.25))
	s.texture_margin_left   = m
	s.texture_margin_right  = m
	s.texture_margin_top    = m
	s.texture_margin_bottom = m
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 10
	s.content_margin_bottom = 10

func _aplicar_margenes_banner(np: NinePatchRect, tex: Texture2D):
	var w: int = tex.get_width()
	var h: int = tex.get_height()
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
