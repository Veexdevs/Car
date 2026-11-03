extends Control
class_name RaceHUD
## Landscape-first, pointer-ID-safe touch HUD. The windshield and the pilot remain unobstructed.
var game: Node3D
var router: InputRouter
var car: VehicleController
var track: SerraTrack
var race: RaceDirector
var font: Font
var toast_text := ""
var toast_timer := 0.0
var paused := false
var pause_layer: Control
var settings_box: VBoxContainer
var credits_box: VBoxContainer
var quality_option: OptionButton
var motion_slider: HSlider
var volume_slider: HSlider
var _panel: StyleBoxFlat
var _button: StyleBoxFlat
var _button_active: StyleBoxFlat
var _accent := Color(1.0, 0.38, 0.14)
var _text := Color(0.91, 0.93, 0.92)
var _muted := Color(0.55, 0.62, 0.63)
const IDS := [&"steer", &"gear", &"throttle", &"brake", &"handbrake", &"horn", &"reverse", &"recenter", &"pause"]

func setup(owner_game: Node3D, input_router: InputRouter) -> void:
	game = owner_game
	router = input_router
	car = game.car
	track = game.track
	race = game.race
	font = load("res://UI/BarlowCondensed-SemiBold.ttf")
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.025, 0.035, 0.043, 0.76)
	_panel.border_color = Color(0.65, 0.72, 0.72, 0.16)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(8)
	_button = StyleBoxFlat.new()
	_button.bg_color = Color(0.035, 0.05, 0.06, 0.66)
	_button.border_color = Color(0.7, 0.78, 0.78, 0.28)
	_button.set_border_width_all(1)
	_button.set_corner_radius_all(10)
	_button_active = _button.duplicate()
	_button_active.bg_color = Color(0.75, 0.20, 0.065, 0.78)
	_button_active.border_color = _accent
	for id in IDS:
		router.register_control(id, Callable(self, "control_rect").bind(id))
	_build_pause_menu()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	toast_timer = maxf(0, toast_timer - delta)
	queue_redraw()

func show_toast(message: String) -> void:
	toast_text = message
	toast_timer = 3.4

func margins() -> Vector2:
	var left := 24.0
	var right := 24.0
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var window := DisplayServer.window_get_size()
		if window.x > 0 and safe.size.x > 0:
			var scale := size.x / float(window.x)
			left = maxf(left, safe.position.x * scale + 12)
			right = maxf(right, (window.x - safe.end.x) * scale + 12)
	return Vector2(left, right)

func control_rect(id: StringName) -> Rect2:
	var w := size.x
	var h := size.y
	var m := margins()
	# Compact on 16:9; expand spacing on wider phones without stretching touch targets.
	match id:
		&"steer": return Rect2(m.x, h - 214, 320, 184)
		&"gear": return Rect2(w - m.y - 514, h - 204, 184, 174)
		&"throttle": return Rect2(w - m.y - 122, h - 238, 112, 208)
		&"brake": return Rect2(w - m.y - 252, h - 208, 108, 178)
		&"handbrake": return Rect2(w - m.y - 616, h - 132, 82, 102)
		&"horn": return Rect2(w - m.y - 710, h - 112, 74, 82)
		&"reverse": return Rect2(w - m.y - 514, h - 254, 184, 40)
		&"recenter": return Rect2(w - m.y - 104, 20, 44, 38)
		&"pause": return Rect2(w - m.y - 48, 20, 44, 38)
	return Rect2()

func _draw() -> void:
	if not font or not is_instance_valid(car):
		return
	_draw_session()
	_draw_minimap()
	_draw_telemetry()
	_draw_steering()
	_draw_pedals()
	_draw_shifter()
	_draw_aux_controls()
	_draw_top_buttons()
	if toast_timer > 0:
		var rect := Rect2(size.x * 0.5 - 280, 76, 560, 40)
		draw_style_box(_panel, rect)
		_center_text(rect, toast_text, 21, _text)
	elif not paused and race.session_time < 20 and not (car.powertrain.gear > 0 and car.speed_kmh > 8):
		var hint := Rect2(size.x * 0.5 - 330, 22, 660, 42)
		draw_style_box(_panel, hint)
		_center_text(hint, "1  PRIMEIRA MARCHA     •     SEGURE ACELERAR     •     ARRASTE DIREÇÃO", 19, _text)

func _draw_session() -> void:
	var m := margins()
	var rect := Rect2(m.x, 20, 260, 94)
	draw_style_box(_panel, rect)
	_label(Vector2(rect.position.x + 16, 42), "SERRA INTERNATIONAL  /  TIME ATTACK", 15, _muted)
	_label(Vector2(rect.position.x + 16, 76), "VOLTA %02d" % maxi(race.lap_number, 1), 20, _accent)
	_label(Vector2(rect.position.x + 112, 78), RaceDirector.format_time(race.lap_time) if race.timing else "00:00.000", 30, _text)
	_label(Vector2(rect.position.x + 16, 101), "MELHOR  " + RaceDirector.format_time(race.best_time), 15, _muted)
	if not race.valid_lap:
		_label(Vector2(rect.position.x + 170, 101), "INVÁLIDA", 15, Color(1, 0.3, 0.2))

func _draw_minimap() -> void:
	var m := margins()
	var rect := Rect2(size.x - m.y - 196, 72, 192, 118)
	draw_style_box(_panel, rect)
	if not track or track.points.is_empty():
		return
	var bounds := track.map_bounds
	var scale := minf((rect.size.x - 26) / bounds.size.x, (rect.size.y - 22) / bounds.size.y)
	var offset := rect.position + rect.size * 0.5 - bounds.get_center() * scale
	var line := PackedVector2Array()
	for i in range(0, track.points.size(), 3):
		line.append(Vector2(track.points[i].x, track.points[i].z) * scale + offset)
	line.append(line[0])
	draw_polyline(line, Color(0.55, 0.63, 0.64, 0.8), 2.0, true)
	var start := Vector2(track.points[0].x, track.points[0].z) * scale + offset
	draw_line(start + Vector2(-4, 0), start + Vector2(4, 0), _text, 2.0)
	var sample := track.nearest(car.global_position)
	var at := track.point_at(float(sample.progress))
	var dot := Vector2(at.x, at.z) * scale + offset
	draw_circle(dot, 4.5, _accent)
	draw_circle(dot, 2.0, _text)

func _draw_telemetry() -> void:
	var center := Vector2(size.x * 0.5 - 30, size.y - 88)
	var rect := Rect2(center.x - 142, center.y - 82, 284, 126)
	draw_style_box(_panel, rect)
	var rpm_ratio := clampf(car.powertrain.rpm / 9000.0, 0, 1)
	for i in range(26):
		var lit := float(i) / 26.0 < rpm_ratio
		var color := _muted * Color(1,1,1,0.28)
		if lit:
			color = Color(0.35, 0.85, 0.65) if i < 17 else (_accent if i < 23 else Color(1, 0.12, 0.08))
		draw_rect(Rect2(rect.position.x + 16 + i * 9.7, rect.position.y + 13, 7, 5), color)
	_label(Vector2(center.x - 118, center.y + 15), "%03d" % int(car.speed_kmh), 76, _text)
	_label(Vector2(center.x - 112, center.y + 36), "KM/H", 16, _muted)
	draw_line(Vector2(center.x + 35, center.y - 42), Vector2(center.x + 35, center.y + 28), Color(1,1,1,0.12), 1)
	_label(Vector2(center.x + 64, center.y + 14), car.powertrain.gear_label(), 72, _accent)
	_label(Vector2(center.x + 58, center.y + 36), "MARCHA", 14, _muted)
	_label(Vector2(center.x - 12, center.y - 28), "%d" % int(car.powertrain.rpm), 19, _muted)
	_label(Vector2(center.x - 12, center.y - 12), "RPM", 12, _muted)

func _draw_steering() -> void:
	var rect := control_rect(&"steer")
	draw_style_box(_button_active if router.has_role("steer") else _button, rect)
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.53)
	var angle := car.steer_normalized * 1.8
	draw_arc(center, 58, 0, TAU, 64, Color(0.7, 0.77, 0.77, 0.35), 3.0, true)
	draw_arc(center, 48, 0, TAU, 64, Color(0.7, 0.77, 0.77, 0.12), 1.0, true)
	for base in [0.0, TAU/3.0, TAU*2.0/3.0]:
		var a: float = base + angle
		draw_line(center + Vector2(cos(a), sin(a))*18, center + Vector2(cos(a), sin(a))*54, _text if not router.has_role("steer") else _accent, 3.0, true)
	draw_circle(center, 16, Color(0.05, 0.07, 0.08, 0.9))
	_center_text(Rect2(rect.position.x, rect.end.y - 28, rect.size.x, 22), "DIREÇÃO  ·  ARRASTE", 16, _muted)

func _draw_pedals() -> void:
	for id in [&"brake", &"throttle"]:
		var rect := control_rect(id)
		var value: float = car.driving.brake if id == &"brake" else car.driving.throttle
		draw_style_box(_button, rect)
		var fill := Rect2(rect.position.x + 5, rect.end.y - 5 - (rect.size.y - 10) * value, rect.size.x - 10, (rect.size.y - 10) * value)
		if value > 0.01:
			draw_style_box(_button_active if id == &"throttle" else _button, fill)
		var title := "FREIO" if id == &"brake" else "ACELERAR"
		_center_text(Rect2(rect.position.x, rect.position.y + 12, rect.size.x, 24), title, 18, _text)
		_center_text(Rect2(rect.position.x, rect.end.y - 34, rect.size.x, 24), "%d%%" % int(value * 100), 20, _text)
		for i in range(5):
			var y := rect.position.y + 52 + i * 18
			draw_line(Vector2(rect.position.x + 22, y), Vector2(rect.end.x - 22, y), Color(1,1,1,0.13), 1)

func _draw_shifter() -> void:
	var rect := control_rect(&"gear")
	draw_style_box(_panel, rect)
	_center_text(Rect2(rect.position.x, rect.position.y + 5, rect.size.x, 20), "CÂMBIO MANUAL  H", 15, _muted)
	var xs := [0.14, 0.38, 0.62, 0.86]
	var top := rect.position.y + rect.size.y * 0.27
	var bottom := rect.position.y + rect.size.y * 0.78
	var neutral := rect.position.y + rect.size.y * 0.525
	for x in xs:
		draw_line(Vector2(rect.position.x + rect.size.x*x, top), Vector2(rect.position.x + rect.size.x*x, bottom), Color(0.6,0.67,0.68,0.45), 2.0)
	draw_line(Vector2(rect.position.x + rect.size.x*xs[0], neutral), Vector2(rect.position.x + rect.size.x*xs[3], neutral), Color(0.6,0.67,0.68,0.45), 2.0)
	var labels_top := ["1", "3", "5", "R"]
	var labels_bottom := ["2", "4", "6", ""]
	for i in range(4):
		var x: float = rect.position.x + rect.size.x*xs[i]
		_center_text(Rect2(x-14, top-22, 28, 22), labels_top[i], 21, _text)
		_center_text(Rect2(x-14, bottom+2, 28, 22), labels_bottom[i], 21, _text)
	var gear := car.powertrain.gear
	var marker := Vector2(rect.position.x + rect.size.x*0.5, neutral)
	if gear > 0:
		var col := (gear - 1) / 2
		marker = Vector2(rect.position.x + rect.size.x*xs[col], top if gear % 2 == 1 else bottom)
	elif gear == -1:
		marker = Vector2(rect.position.x + rect.size.x*xs[3], top)
	draw_circle(marker, 10, _accent)
	draw_circle(marker, 4, _text)
	var reverse := control_rect(&"reverse")
	draw_style_box(_button_active if gear == -1 else _button, reverse)
	_center_text(reverse, "R  ·  ENGATAR RÉ", 17, _text)

func _draw_aux_controls() -> void:
	var hb := control_rect(&"handbrake")
	draw_style_box(_button_active if car.driving.handbrake > 0 else _button, hb)
	_center_text(Rect2(hb.position.x, hb.position.y + 15, hb.size.x, 30), "P", 32, _text)
	_center_text(Rect2(hb.position.x, hb.end.y - 34, hb.size.x, 28), "FREIO\nMÃO", 14, _muted)
	var horn := control_rect(&"horn")
	draw_style_box(_button_active if car.driving.horn else _button, horn)
	_center_text(Rect2(horn.position.x, horn.position.y + 14, horn.size.x, 26), "SOM", 20, _text)
	_center_text(Rect2(horn.position.x, horn.end.y - 30, horn.size.x, 22), "BUZINA", 14, _muted)

func _draw_top_buttons() -> void:
	for id in [&"recenter", &"pause"]:
		var rect := control_rect(id)
		draw_style_box(_button, rect)
		if id == &"pause":
			draw_rect(Rect2(rect.position.x + 15, rect.position.y + 11, 4, 16), _text)
			draw_rect(Rect2(rect.position.x + 25, rect.position.y + 11, 4, 16), _text)
		else:
			draw_arc(rect.get_center(), 9, 0.3, TAU - 0.3, 24, _text, 2, true)
			draw_line(rect.get_center() + Vector2(4,-10), rect.get_center() + Vector2(10,-6), _text, 2)

func _label(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center_text(rect: Rect2, text: String, font_size: int, color: Color) -> void:
	var lines := text.split("\n")
	var line_height := font_size * 1.05
	var y := rect.get_center().y - (lines.size()-1)*line_height*0.5 + font_size*0.34
	for line in lines:
		var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(rect.get_center().x - width*0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y += line_height

func _build_pause_menu() -> void:
	pause_layer = Control.new()
	pause_layer.name = "PauseMenu"
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.visible = false
	add_child(pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.02, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var style := _panel.duplicate()
	style.bg_color = Color(0.035, 0.045, 0.052, 0.97)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "SERRA  /  RS-01"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", _text)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "SESSÃO PAUSADA  ·  COCKPIT EXPERIMENTAL"
	subtitle.add_theme_font_override("font", font)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", _muted)
	box.add_child(subtitle)
	_menu_button(box, "CONTINUAR", func(): game.set_paused(false))
	_menu_button(box, "REPOSICIONAR NA PISTA", func(): game.reset_car(); game.set_paused(false))
	_menu_button(box, "REINICIAR SESSÃO", func(): game.restart_session())
	_menu_button(box, "CONFIGURAÇÕES", func(): settings_box.visible = not settings_box.visible; credits_box.visible = false)
	settings_box = VBoxContainer.new()
	settings_box.visible = false
	box.add_child(settings_box)
	var quality_label := Label.new()
	quality_label.text = "QUALIDADE GRÁFICA"
	_menu_style(quality_label, 16)
	settings_box.add_child(quality_label)
	quality_option = OptionButton.new()
	quality_option.add_item("Baixa — espelhos centrais / sem sombras")
	quality_option.add_item("Média — equilíbrio para Android")
	quality_option.add_item("Alta — sombras e espelhos completos")
	quality_option.select(1)
	_menu_style(quality_option, 17)
	quality_option.item_selected.connect(func(index): game.apply_quality(index))
	settings_box.add_child(quality_option)
	var motion_label := Label.new()
	motion_label.text = "MOVIMENTO DA CABEÇA"
	_menu_style(motion_label, 16)
	settings_box.add_child(motion_label)
	motion_slider = HSlider.new()
	motion_slider.min_value = 0
	motion_slider.max_value = 1.5
	motion_slider.step = 0.05
	motion_slider.value = 1.0
	motion_slider.value_changed.connect(func(value): game.set_motion(value))
	settings_box.add_child(motion_slider)
	var volume_label := Label.new()
	volume_label.text = "VOLUME"
	_menu_style(volume_label, 16)
	settings_box.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.05
	volume_slider.value = 0.8
	volume_slider.value_changed.connect(func(value): game.set_volume(value))
	settings_box.add_child(volume_slider)
	_menu_button(box, "CRÉDITOS E LICENÇAS", func(): credits_box.visible = not credits_box.visible; settings_box.visible = false)
	credits_box = VBoxContainer.new()
	credits_box.visible = false
	box.add_child(credits_box)
	var credits := Label.new()
	credits.text = "Modelo Ferrari 458 Italia: vicent091036, CC BY 4.0.\nAdaptado para cockpit e materiais PBR. Sem afiliação à Ferrari.\nÁudio motor/pneus/impacto: Kenney Starter Kit Racing, CC0.\nFonte Barlow Condensed: Jeremy Tribby, SIL OFL 1.1.\nCódigo, circuito, texturas e piloto: SERRA RS, MIT."
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.custom_minimum_size = Vector2(400, 0)
	_menu_style(credits, 15)
	credits_box.add_child(credits)

func _menu_style(control: Control, font_size: int) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", _text)

func _menu_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	_menu_style(button, 20)
	button.pressed.connect(callback)
	parent.add_child(button)

func set_paused(value: bool) -> void:
	paused = value
	pause_layer.visible = value
