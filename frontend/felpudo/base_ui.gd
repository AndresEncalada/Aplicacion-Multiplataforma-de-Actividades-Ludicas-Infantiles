extends Control

## Base class shared by all UI scenes.
## Provides design tokens, audio helpers, NinePatch utilities, and the wobble/jiggle system.

const MANDARINA := Color(1.00, 0.50, 0.08)
const TURQUESA  := Color(0.05, 0.68, 0.72)
const CREMA     := Color(1.00, 0.96, 0.86)
const AMBAR     := Color(0.98, 0.82, 0.08)
const NAVY      := Color(0.08, 0.18, 0.38)

const FONT_KFN   := "res://assets/fuente/Kenney Future Narrow.ttf"
const SND_CLICK  := "res://assets/sonidos/click.ogg"
const SND_CERRAR := "res://assets/sonidos/cerrar.ogg"

const ICO_PANEL  := "res://assets/iconos/panel.svg"
const ICO_BANNER := "res://assets/iconos/banner.svg"
const ICO_BOTON  := "res://assets/iconos/boton.svg"
const ICO_X      := "res://assets/iconos/x.svg"

const BANNER_H: int = 135
const OVERLAP:  int = 67   # 50 % de BANNER_H

var _font: FontFile
var _btn_bloqueado := false
var _sfx_click: AudioStreamPlayer
var _sfx_cerrar: AudioStreamPlayer
var _wobble_index: int = 0
var _wobble_data: Array = []


func _ready() -> void:
	_font       = load(FONT_KFN)
	_sfx_click  = _crear_sfx(SND_CLICK,  -6.0)
	_sfx_cerrar = _crear_sfx(SND_CERRAR, -6.0)
	if has_node("/root/AnimManager"):
		AnimManager.changed.connect(_on_anim_changed)


# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

func _crear_sfx(ruta: String, vol: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var s = load(ruta)
	if s:
		p.stream    = s
		p.volume_db = vol
	add_child(p)
	return p


# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _normalizar(s: String) -> String:
	return s.to_lower()\
		.replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u")\
		.replace("ñ","n").replace("ü","u")

func _crear_label(texto: String, tam: int, color: Color, _negrita: bool) -> Label:
	var lbl = Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", tam)
	lbl.add_theme_color_override("font_color", color)
	if _font: lbl.add_theme_font_override("font", _font)
	return lbl


func _crear_btn_x() -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(63, 63)
	var empty = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	var ir = TextureRect.new()
	ir.texture      = load(ICO_X) as Texture2D
	ir.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ir)
	return btn


# ---------------------------------------------------------------------------
# NinePatch helpers
# ---------------------------------------------------------------------------

func _aplicar_margenes_panel(s: StyleBoxTexture, tex: Texture2D) -> void:
	var m: int = max(4, int(tex.get_width() * 0.156))
	s.texture_margin_left   = m; s.texture_margin_right  = m
	s.texture_margin_top    = m; s.texture_margin_bottom = m
	var cm: int = m + 16
	s.content_margin_left   = cm; s.content_margin_right  = cm
	s.content_margin_top    = cm; s.content_margin_bottom = cm


func _aplicar_margenes_boton(s: StyleBoxTexture, tex: Texture2D, cm_lr: int = 14, cm_tb: int = 10) -> void:
	var m: int = max(6, int(tex.get_width() * 0.25))
	s.texture_margin_left   = m; s.texture_margin_right  = m
	s.texture_margin_top    = m; s.texture_margin_bottom = m
	s.content_margin_left   = cm_lr; s.content_margin_right  = cm_lr
	s.content_margin_top    = cm_tb; s.content_margin_bottom = cm_tb


func _aplicar_margenes_banner(np: NinePatchRect, tex: Texture2D) -> void:
	var w: int = tex.get_width(); var h: int = tex.get_height()
	np.patch_margin_left   = max(4, int(w * 0.047))
	np.patch_margin_right  = max(4, int(w * 0.047))
	np.patch_margin_top    = max(4, int(h * 0.203))
	np.patch_margin_bottom = max(4, int(h * 0.203))


# ---------------------------------------------------------------------------
# Wobble / jiggle system
# ---------------------------------------------------------------------------

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


func _on_anim_changed(activo: bool) -> void:
	if activo:
		_recrear_wobbles()
	else:
		for d in _wobble_data:
			if is_instance_valid(d["tween"]): d["tween"].pause()
			if is_instance_valid(d["node"]): d["node"].rotation_degrees = 0.0


func _recrear_wobbles() -> void:
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
