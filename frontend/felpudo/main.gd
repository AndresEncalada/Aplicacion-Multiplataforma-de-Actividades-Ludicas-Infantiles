extends Control

var websocket = WebSocketPeer.new()
var url = Config.WS_CUERPO
var ya_conectado = false
var reconectando = false
var tiempo_reconexion = 0.0

@onready var titulo_label = $ContenedorPrincipal/ContenidoVBox/TarjetaSuperior/ContenidoSuperior/TituloLabel
@onready var instruccion_label = $ContenedorPrincipal/ContenidoVBox/TarjetaSuperior/ContenidoSuperior/InstruccionLabel
@onready var progreso_label = $ContenedorPrincipal/ContenidoVBox/TarjetaSuperior/ContenidoSuperior/InfoContainer/ProgresoLabel
@onready var tiempo_label = $ContenedorPrincipal/ContenidoVBox/TarjetaSuperior/ContenidoSuperior/InfoContainer/TiempoLabel
@onready var video_texture = $ContenedorPrincipal/ContenidoVBox/TarjetaInferior/VideoTexture

var estado_actual = ""
var esperando_frame = true

var flash_overlay: ColorRect
var check_icon: Sprite2D

var sonido_campana: AudioStreamPlayer
var sonido_derrota: AudioStreamPlayer
var sonido_victoria: AudioStreamPlayer
var victoria_reproducida = false

# Debounce para evitar múltiples HTTPRequest simultáneos
var reiniciando = false

func _ready():
	_aplicar_fuente()
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0.0)
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ContenedorPrincipal/ContenidoVBox/TarjetaInferior.add_child(flash_overlay)

	check_icon = Sprite2D.new()
	check_icon.texture = load("res://assets/iconos/check.svg")
	check_icon.scale = Vector2(0.5, 0.5)
	check_icon.visible = false
	check_icon.z_index = 10
	$ContenedorPrincipal/ContenidoVBox/TarjetaInferior.add_child(check_icon)

	sonido_campana = AudioStreamPlayer.new()
	add_child(sonido_campana)
	var audio_file = load("res://assets/sonidos/exito.ogg")
	if audio_file:
		sonido_campana.stream = audio_file
		sonido_campana.volume_db = -3.0
	else:
		print("⚠️ No se encontró el archivo de audio en res://assets/sonidos/exito.ogg")

	sonido_derrota = AudioStreamPlayer.new()
	var audio_derrota = load("res://assets/sonidos/sonido_derrota.wav")
	if audio_derrota:
		sonido_derrota.stream = audio_derrota
		sonido_derrota.volume_db = -3.0
		add_child(sonido_derrota)
	else:
		print("⚠️ No se encontró res://assets/sonido_derrota.wav")

	sonido_victoria = AudioStreamPlayer.new()
	var audio_victoria = load("res://assets/sonidos/sonido_victoria.wav")
	if audio_victoria:
		sonido_victoria.stream = audio_victoria
		sonido_victoria.volume_db = -3.0
		add_child(sonido_victoria)
	else:
		print("⚠️ No se encontró res://assets/sonido_victoria.wav")

	conectar_websocket()
	_crear_btn_menu()

func _aplicar_fuente():
	var font = load("res://assets/fuente/Kenney Future Narrow.ttf")
	if not font: return
	titulo_label.add_theme_font_override("font", font)
	instruccion_label.add_theme_font_override("font", font)
	progreso_label.add_theme_font_override("font", font)
	tiempo_label.add_theme_font_override("font", font)

func conectar_websocket():
	if reconectando:
		return
	var err = websocket.connect_to_url(url)
	if err != OK:
		instruccion_label.text = "Error de conexion"
		iniciar_reconexion()

func iniciar_reconexion():
	reconectando = true
	tiempo_reconexion = 3.0

func _process(delta):
	if reconectando:
		tiempo_reconexion -= delta
		if tiempo_reconexion <= 0:
			reconectando = false
			websocket = WebSocketPeer.new()
			conectar_websocket()
		return

	websocket.poll()
	var state = websocket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not ya_conectado:
			ya_conectado = true
			reconectando = false

		while websocket.get_available_packet_count() > 0:
			var packet = websocket.get_packet()
			# Detectar JPEG por magic bytes: más robusto que el flag alternado
			if packet.size() > 2 and packet[0] == 0xFF and packet[1] == 0xD8:
				actualizar_video(packet)
				esperando_frame = false
			else:
				var json_string = packet.get_string_from_utf8()
				var data = JSON.parse_string(json_string)
				if data:
					procesar_mensaje(data)
				esperando_frame = true

	elif state == WebSocketPeer.STATE_CLOSED:
		if ya_conectado:
			ya_conectado = false
			instruccion_label.text = "Reconectando..."
			iniciar_reconexion()

func actualizar_video(frame_bytes):
	var image = Image.new()
	if image.load_jpg_from_buffer(frame_bytes) == OK:
		if video_texture.texture == null:
			video_texture.texture = ImageTexture.create_from_image(image)
		else:
			(video_texture.texture as ImageTexture).update(image)

func _obtener_posicion_y_escala(centro_x_norm: float, centro_y_norm: float, ancho_hombros_px: float) -> Dictionary:
	var video_w = video_texture.size.x
	var video_h = video_texture.size.y
	var img_ratio = 640.0 / 480.0
	var rect_ratio = video_w / video_h

	var draw_w = video_w
	var draw_h = video_h
	var offset_x = 0.0
	var offset_y = 0.0

	if rect_ratio > img_ratio:
		draw_w = video_h * img_ratio
		offset_x = (video_w - draw_w) / 2.0
	else:
		draw_h = video_w / img_ratio
		offset_y = (video_h - draw_h) / 2.0

	var pos_x = offset_x + (centro_x_norm * draw_w)
	var pos_y = offset_y + (centro_y_norm * draw_h)

	var factor_escala = (ancho_hombros_px / 200.0) * 0.15
	factor_escala = clamp(factor_escala, 0.08, 0.25)

	return {"posicion": Vector2(pos_x, pos_y), "escala": factor_escala}

func _animar_flash_exito():
	flash_overlay.color = Color(1, 1, 1, 0.8)
	var tween = create_tween()
	tween.tween_property(flash_overlay, "color:a", 0.0, 0.35)

func _animar_check(posicion: Vector2, escala: float):
	check_icon.position = posicion
	check_icon.scale = Vector2(escala * 0.6, escala * 0.6)
	check_icon.modulate.a = 1.0
	check_icon.visible = true

	var tween = create_tween()
	tween.tween_property(check_icon, "scale", Vector2(escala * 1.2, escala * 1.2), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(check_icon, "scale", Vector2(escala, escala), 0.08)
	tween.tween_interval(0.65)
	tween.tween_property(check_icon, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): check_icon.visible = false)

func procesar_mensaje(data):
	var evento = data.get("evento", "")
	var mensaje = data.get("mensaje", "")
	var efecto = data.get("efecto_visual", "ninguno")

	estado_actual = evento

	if efecto == "flash_exito":
		_animar_flash_exito()

		var pos_check: Vector2 = video_texture.size / 2.0
		var escala_check: float = 0.15

		if data.has("centro_cuerpo"):
			var centro = data["centro_cuerpo"]
			var datos_calc = _obtener_posicion_y_escala(centro.x, centro.y, centro.ancho_hombros)
			pos_check = datos_calc["posicion"]
			escala_check = datos_calc["escala"]

		_animar_check(pos_check, escala_check)
		sonido_campana.play()

	match evento:
		"tiempo_agotado":
			instruccion_label.text = "Se acabó el tiempo"
			progreso_label.text = ""
			tiempo_label.text = ""
			if sonido_derrota:
				sonido_derrota.play()
			reiniciar_juego()
		"instruccion_postura":
			victoria_reproducida = false
			instruccion_label.text = mensaje
			progreso_label.text = ""
			tiempo_label.text = ""
		"torso_detectado":
			instruccion_label.text = mensaje
			progreso_label.text = ""
			tiempo_label.text = ""
		"esperando_mano":
			instruccion_label.text = mensaje
			progreso_label.text = ""
			tiempo_label.text = ""
		"jugador_seleccionado":
			instruccion_label.text = "Preparate para jugar!"
			progreso_label.text = ""
			tiempo_label.text = ""
		"esperando_inicio":
			instruccion_label.text = mensaje
		"instruccion_actividad":
			instruccion_label.text = mensaje
			progreso_label.text = data.get("progreso", "")
			var tiempo = data.get("tiempo_restante", 0)
			tiempo_label.text = str(int(tiempo)) + "s"
			# Alerta visual cuando quedan ≤5 s
			var color_tiempo = Color(0.82, 0.15, 0.15) if tiempo <= 5 else Color(0.75, 0.62, 0.15)
			tiempo_label.add_theme_color_override("font_color", color_tiempo)
		"actividad_exitosa":
			instruccion_label.text = mensaje
			progreso_label.text = data.get("progreso", "")
		"juego_completado", "juego_terminado":
			titulo_label.text = "Felicidades!"
			instruccion_label.text = mensaje
			progreso_label.text = "Completaste las 10 actividades!"
			tiempo_label.text = "Presiona ESPACIO"
			if not victoria_reproducida:
				victoria_reproducida = true
				if sonido_victoria:
					sonido_victoria.play()
		_:
			pass

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if estado_actual in ["juego_completado", "juego_terminado"]:
			reiniciar_juego()

func reiniciar_juego():
	if reiniciando:
		return
	reiniciando = true
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, _body):
		reiniciando = false
		http.queue_free()
	)
	if http.request(Config.HTTP_REINICIAR, [], HTTPClient.METHOD_POST) != OK:
		reiniciando = false
		http.queue_free()

func _crear_btn_menu():
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(96, 96)
	btn.flat = true
	var tex = load("res://assets/iconos/x.svg") as Texture2D
	if tex: btn.icon = tex
	btn.expand_icon = false
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left   = -96
	btn.offset_top    = 0
	btn.offset_right  = 0
	btn.offset_bottom = 96
	btn.z_index = 20
	btn.pressed.connect(_volver_al_menu)
	add_child(btn)

func _volver_al_menu():
	get_tree().change_scene_to_file("res://menu_actividades.tscn")
