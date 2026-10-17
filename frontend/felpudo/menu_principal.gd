extends Control

const MANDARINA := Color(1.00, 0.50, 0.08)
const TURQUESA  := Color(0.05, 0.68, 0.72)
const CREMA     := Color(1.00, 0.96, 0.86)
const AMBAR     := Color(0.98, 0.82, 0.08)
const NAVY      := Color(0.08, 0.18, 0.38)

const FONT_KFN      := "res://assets/fuente/Kenney Future Narrow.ttf"
const SND_CLICK     := "res://assets/sonidos/click.ogg"
const ICO_CHECK     := "res://assets/iconos/check.svg"
const ICO_PANEL     := "res://assets/iconos/panel.svg"
const ICO_BANNER    := "res://assets/iconos/banner.svg"
const ICO_BEAR      := "res://assets/iconos/bear.png"
const ICO_BOTON     := "res://assets/iconos/boton.svg"
const ICO_CHK_VERDE := "res://assets/iconos/check_verde.svg"
const ICO_CHK_MEDIO := "res://assets/iconos/check_medio.svg"
const ICO_CHK_GRIS  := "res://assets/iconos/check_gris.svg"

const BANNER_H : int = 135
const OVERLAP  : int = 67  # 50 % de BANNER_H

var _font: FontFile
var _btn_bloqueado := false
var _sfx_click: AudioStreamPlayer
var _wobble_index: int = 0
# {"node": Control, "tween": Tween, "type": "wobble"|"jiggle", "phase": float, "speed": float, "angle": float}
var _wobble_data: Array = []
var _check_anim_btn: TextureButton

func _ready():
	_font = load(FONT_KFN)
	_sfx_click = AudioStreamPlayer.new()
	var snd = load(SND_CLICK)
	if snd:
		_sfx_click.stream    = snd
		_sfx_click.volume_db = -6.0
	add_child(_sfx_click)
	_construir_ui()
	if has_node("/root/AnimManager"):
		AnimManager.changed.connect(_on_anim_changed)

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

	# Toggle añadido AL FINAL para que reciba input antes que root_vbox (FULL_RECT)
	add_child(_crear_toggle_animaciones())

	# Stack: separación negativa → panel sube OVERLAP px bajo el banner
	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical   = Control.SIZE_EXPAND_FILL  # llena el viewport
	stack.add_theme_constant_override("separation", -OVERLAP)
	root_vbox.add_child(stack)

	stack.add_child(_crear_header_con_oso("Felpudo", vp_w))
	stack.add_child(_crear_panel_con_tarjetas(mg, vp_h))

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
	# Estado inicial según AnimManager
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
# Fila 1: banner centrado con título + oso
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
# Fila 2: panel.svg de fondo (todo el ancho, margen uniforme) + tarjetas
# ---------------------------------------------------------------------------

func _crear_panel_con_tarjetas(mg: int, vp_h: float) -> Control:
	var margin_outer = MarginContainer.new()
	margin_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_outer.size_flags_vertical   = Control.SIZE_EXPAND_FILL  # llena el espacio restante
	margin_outer.add_theme_constant_override("margin_left",   mg)
	margin_outer.add_theme_constant_override("margin_right",  mg)
	margin_outer.add_theme_constant_override("margin_top",    mg)  # igual al horizontal
	margin_outer.add_theme_constant_override("margin_bottom", mg)
	margin_outer.z_index = 1

	var panel_pc = PanelContainer.new()
	panel_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_pc.size_flags_vertical   = Control.SIZE_EXPAND_FILL  # panel llena el margen exterior
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
	hbox.add_theme_constant_override("separation", 28)
	center_inner.add_child(hbox)

	hbox.add_child(_crear_tarjeta(
		"Actividades",
		"res://assets/iconos/actividades.png",
		MANDARINA,
		"res://menu_actividades.tscn"
	))

	return margin_outer

# ---------------------------------------------------------------------------
# Tarjeta con boton.svg
# ---------------------------------------------------------------------------

func _crear_tarjeta(nombre: String, icono: String, acento: Color, escena: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(176, 192)
	card.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	card.mouse_filter         = Control.MOUSE_FILTER_STOP

	var tex_btn = load(ICO_BOTON) as Texture2D
	if tex_btn:
		var style = StyleBoxTexture.new()
		style.texture = tex_btn
		_aplicar_margenes_boton(style, tex_btn)
		card.add_theme_stylebox_override("panel", style)
	else:
		var sf = StyleBoxFlat.new()
		sf.bg_color = acento.lightened(0.55)
		sf.set_corner_radius_all(20)
		sf.set_content_margin_all(22)
		card.add_theme_stylebox_override("panel", sf)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
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

	vbox.add_child(_crear_label(nombre, 24, Color.WHITE, true))

	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch and ev.pressed:
			_ir_a(card, escena)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_ir_a(card, escena)
	)
	_iniciar_wobble(card)
	return card

# ---------------------------------------------------------------------------
# Animaciones
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

# ---------------------------------------------------------------------------
# Helpers NinePatch (proporcionales)
# ---------------------------------------------------------------------------

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
	s.content_margin_left   = 22; s.content_margin_right  = 22
	s.content_margin_top    = 16; s.content_margin_bottom = 16

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
