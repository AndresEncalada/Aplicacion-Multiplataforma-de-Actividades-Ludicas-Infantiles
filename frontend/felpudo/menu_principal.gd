extends "res://base_ui.gd"

const ICO_CHECK     := "res://assets/iconos/check.svg"
const ICO_CHK_VERDE := "res://assets/iconos/check_verde.svg"
const ICO_CHK_MEDIO := "res://assets/iconos/check_medio.svg"
const ICO_CHK_GRIS  := "res://assets/iconos/check_gris.svg"
const ICO_REPORTE_OPT := "res://assets/iconos/reporte.png"
const ICO_PREGUNTAS   := "res://assets/iconos/preguntas.png"
const ICO_BEAR        := "res://assets/iconos/bear.png"

var _check_anim_btn: TextureButton
var _modal_confirmar_cerrar: ColorRect

func _ready():
	super._ready()
	_construir_ui()
	_construir_modal_confirmar()

# ---------------------------------------------------------------------------
# Interfaz principal
# ---------------------------------------------------------------------------

func _construir_ui():
	var vp    := get_viewport().get_visible_rect().size
	var vp_w: float = vp.x
	var vp_h: float = vp.y
	var mg: int     = int(vp_w * 0.02)

	var bg = ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_vbox = VBoxContainer.new()
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	add_child(_crear_toggle_animaciones())
	add_child(_crear_boton_cerrar_sesion())

	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", -OVERLAP)
	root_vbox.add_child(stack)

	stack.add_child(_crear_header_con_oso("Felpudo", vp_w))
	stack.add_child(_crear_panel_con_tarjetas(mg, vp_h))

# ---------------------------------------------------------------------------
# Botón X superior derecho (cierra sesión docente)
# ---------------------------------------------------------------------------

func _crear_boton_cerrar_sesion() -> Control:
	var btn_x = Button.new()
	btn_x.custom_minimum_size = Vector2(63, 63)
	btn_x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_x.offset_left   = -77
	btn_x.offset_top    = 12
	btn_x.offset_right  = -14
	btn_x.offset_bottom = 75
	btn_x.z_index = 10

	var empty = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn_x.add_theme_stylebox_override(state, empty)

	var ir = TextureRect.new()
	ir.texture = load(ICO_X) as Texture2D
	ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_x.add_child(ir)

	btn_x.pressed.connect(func():
		if _btn_bloqueado: return
		if _sfx_click: _sfx_click.play()
		if is_instance_valid(_modal_confirmar_cerrar):
			_modal_confirmar_cerrar.move_to_front()
			_modal_confirmar_cerrar.visible = true
	)
	return btn_x

# ---------------------------------------------------------------------------
# Toggle de animaciones (superior izquierdo)
# ---------------------------------------------------------------------------

func _crear_toggle_animaciones() -> Control:
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hbox.offset_left   = 10
	hbox.offset_top    = 10
	hbox.offset_right  = 170
	hbox.offset_bottom = 58
	hbox.add_theme_constant_override("separation", 6)
	hbox.z_index = 10
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP

	_check_anim_btn = TextureButton.new()
	_check_anim_btn.custom_minimum_size = Vector2(40, 40)
	_check_anim_btn.ignore_texture_size  = true
	_check_anim_btn.stretch_mode         = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_check_anim_btn.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	var activo_inicial: bool = true
	if has_node("/root/AnimManager"): activo_inicial = AnimManager.activas
	var tex_ini = load(ICO_CHK_VERDE if activo_inicial else ICO_CHK_GRIS) as Texture2D
	if tex_ini: _check_anim_btn.texture_normal = tex_ini
	hbox.add_child(_check_anim_btn)

	var lbl = _crear_label("Animaciones", 17, CREMA, false)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)

	_check_anim_btn.pressed.connect(_on_toggle_animaciones)
	return hbox

func _on_toggle_animaciones():
	if _btn_bloqueado: return
	_btn_bloqueado = true
	if _sfx_click: _sfx_click.play()

	var ir_a_activo: bool = true
	if has_node("/root/AnimManager"): ir_a_activo = not AnimManager.activas
	var tex_f = load(ICO_CHK_VERDE if ir_a_activo else ICO_CHK_GRIS) as Texture2D

	if is_instance_valid(_check_anim_btn):
		_check_anim_btn.pivot_offset = _check_anim_btn.size / 2.0
		var tw = create_tween()
		tw.tween_property(_check_anim_btn, "scale", Vector2(0.0, 0.0), 0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if not is_instance_valid(_check_anim_btn): return
			if tex_f: _check_anim_btn.texture_normal = tex_f
			if has_node("/root/AnimManager"): AnimManager.activas = ir_a_activo
		)
		tw.tween_property(_check_anim_btn, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): _btn_bloqueado = false)
	else:
		if has_node("/root/AnimManager"): AnimManager.activas = ir_a_activo
		get_tree().create_timer(0.4).timeout.connect(func(): _btn_bloqueado = false)

# ---------------------------------------------------------------------------
# Header: banner centrado con título + oso
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

	var tex_bear = load(ICO_BEAR) as Texture2D
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

# ---------------------------------------------------------------------------
# Panel con 2 botones: Actividades y Estadísticas Alumnos
# ---------------------------------------------------------------------------

func _crear_panel_con_tarjetas(mg: int, vp_h: float) -> Control:
	var margin_outer = MarginContainer.new()
	margin_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_outer.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin_outer.add_theme_constant_override("margin_left",   mg)
	margin_outer.add_theme_constant_override("margin_right",  mg)
	margin_outer.add_theme_constant_override("margin_top",    mg)
	margin_outer.add_theme_constant_override("margin_bottom", mg)
	margin_outer.z_index = 1

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
		sf.set_corner_radius_all(28)
		sf.set_content_margin_all(28)
		panel_pc.add_theme_stylebox_override("panel", sf)

	var center_inner = CenterContainer.new()
	panel_pc.add_child(center_inner)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 48)
	center_inner.add_child(hbox)

	hbox.add_child(_crear_tarjeta(
		"Actividades",
		"res://assets/iconos/actividades.png",
		MANDARINA,
		func(card: PanelContainer):
			if has_node("/root/SesionState"):
				SesionState.modo_seleccion = "actividades"
			_ir_a(card, "res://login_profesor.tscn")
	))

	var ico_est := ICO_REPORTE_OPT if ResourceLoader.exists(ICO_REPORTE_OPT) else ICO_PREGUNTAS
	hbox.add_child(_crear_tarjeta(
		"Estadísticas\nAlumnos",
		ico_est,
		TURQUESA,
		func(card: PanelContainer):
			if has_node("/root/SesionState"):
				SesionState.modo_seleccion = "estadisticas"
			_ir_a(card, "res://login_profesor.tscn")
	))

	return margin_outer

func _crear_tarjeta(nombre: String, icono: String, acento: Color, accion: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 200)
	card.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	card.mouse_filter         = Control.MOUSE_FILTER_STOP

	var tex_btn = load(ICO_BOTON) as Texture2D
	if tex_btn:
		var style = StyleBoxTexture.new()
		style.texture = tex_btn
		_aplicar_margenes_boton(style, tex_btn, 22, 16)
		card.add_theme_stylebox_override("panel", style)
	else:
		var sf = StyleBoxFlat.new()
		sf.bg_color = acento.lightened(0.55)
		sf.set_corner_radius_all(20)
		sf.set_content_margin_all(22)
		card.add_theme_stylebox_override("panel", sf)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var tex = load(icono) as Texture2D
	if tex:
		var ir = TextureRect.new()
		ir.texture               = tex
		ir.ignore_texture_size   = true
		ir.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.custom_minimum_size   = Vector2(76, 76)
		ir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(ir)
	else:
		vbox.add_child(_crear_label("▶", 48, acento, false))

	var lbl = _crear_label(nombre, 24, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch and ev.pressed:
			accion.call(card)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accion.call(card)
	)
	_iniciar_wobble(card)
	return card

# ---------------------------------------------------------------------------
# Animación de click y navegación
# ---------------------------------------------------------------------------

func _ir_a(card: PanelContainer, escena: String):
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

# ---------------------------------------------------------------------------
# Modal de confirmación: cerrar sesión
# ---------------------------------------------------------------------------

func _construir_modal_confirmar():
	_modal_confirmar_cerrar = ColorRect.new()
	_modal_confirmar_cerrar.color   = Color(0.04, 0.08, 0.20, 0.82)
	_modal_confirmar_cerrar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_confirmar_cerrar.visible = false
	_modal_confirmar_cerrar.z_index = 50
	add_child(_modal_confirmar_cerrar)

	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_confirmar_cerrar.add_child(cc)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(540, 220)
	var tex_panel = load(ICO_PANEL) as Texture2D
	if tex_panel:
		var style = StyleBoxTexture.new()
		style.texture = tex_panel
		_aplicar_margenes_panel(style, tex_panel)
		card.add_theme_stylebox_override("panel", style)
	cc.add_child(card)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	card.add_child(vb)

	var lbl_titulo = _crear_label("¿Cerrar sesión?", 28, NAVY, true)
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl_titulo)

	var lbl_desc = _crear_label("Se cerrará la sesión del profesor.", 18, NAVY, false)
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl_desc)

	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)

	var btn_cancelar = _crear_boton_confirmar("Cancelar", TURQUESA, func():
		_modal_confirmar_cerrar.visible = false
	)
	hb.add_child(btn_cancelar)

	var btn_cerrar = _crear_boton_confirmar("Cerrar sesión", Color(0.91, 0.11, 0.21), func():
		_modal_confirmar_cerrar.visible = false
		if has_node("/root/SesionState"):
			SesionState.cerrar_sesion_profesor()
		get_tree().change_scene_to_file("res://login_profesor.tscn")
	)
	hb.add_child(btn_cerrar)


func _crear_boton_confirmar(texto: String, color_fondo: Color, accion: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 60)
	card.mouse_filter        = Control.MOUSE_FILTER_STOP

	var sf = StyleBoxFlat.new()
	sf.bg_color = color_fondo
	sf.set_corner_radius_all(18)
	sf.border_color = color_fondo.darkened(0.25)
	sf.border_width_bottom = 5
	sf.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sf)

	var cc2 = CenterContainer.new()
	card.add_child(cc2)
	var lbl = _crear_label(texto, 20, Color.WHITE, true)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc2.add_child(lbl)

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch and ev.pressed:
			if _sfx_click: _sfx_click.play()
			accion.call()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _sfx_click: _sfx_click.play()
			accion.call()
	)
	_iniciar_wobble(card)
	return card
