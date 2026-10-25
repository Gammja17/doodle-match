class_name CutIn
extends Control






signal _closed

const HOLD: = 1.5
const DOUBLE_TAP: = 0.4

var _n: = 0
var _open: = false
var _last_tap: = -1.0
var _tws: Array = []
var _rest: = {}

@onready var _dim: ColorRect = $Dim
@onready var _lines: TextureRect = $Lines
@onready var _body: TextureRect = $Body
@onready var _name: Label = $SkillName
@onready var _name_pic: TextureRect = $SkillPic
@onready var _dark: Polygon2D = $Bands / Dark
@onready var _light: Polygon2D = $Bands / Light
@onready var _streaks: Node2D = $Bands / Dark / Streaks



func play(tex: Texture2D, color: Color, fx: FxLayer, skill_name: = "", name_pic: Texture2D = null) -> void :
	var k: = size.x / 420.0
	_body.texture = tex
	_name.text = "" if name_pic else skill_name
	_name.add_theme_color_override("font_outline_color", color.darkened(0.45))
	_name_pic.texture = name_pic
	_name_pic.self_modulate = color.lightened(0.15)
	_name_pic.visible = name_pic != null
	for n in [_lines, _body, _name, _name_pic]:
		n.pivot_offset = n.size / 2
	for n in [_lines, _body, _name, _name_pic, _dark, _light]:
		if not _rest.has(n):
			_rest[n] = n.position
	show()
	_n += 1
	var n: = _n
	_open = true
	_last_tap = -1.0
	fx.sfx("skill")
	_dim.modulate.a = 0.0
	_tws = []
	var dim_in: = _dim.create_tween()
	dim_in.tween_property(_dim, "modulate:a", 0.6, 0.14)
	_tws.append(dim_in)

	var reach: = size.x * 1.5
	_dark.color = color.darkened(0.25)
	_light.color = color.lightened(0.35)
	_dark.position = _rest[_dark] - Vector2(reach, 0)
	_light.position = _rest[_light] + Vector2(reach, 0)
	_tws.append(Juice.play(_dark, _rest[_dark], [{x = - reach}, {t = 0.7, x = 40 * k}, {}], 240.0, "ease-out", 60.0, _drift.bind(_dark, 1.0, n, k)))
	_tws.append(Juice.play(_light, _rest[_light], [{x = reach}, {t = 0.7, x = -40 * k}, {}], 240.0, "ease-out", 110.0, _drift.bind(_light, -1.0, n, k)))
	_streaks.position.x = -160 * k
	var streak: = _streaks.create_tween()
	streak.tween_property(_streaks, "position:x", 160 * k, HOLD)
	_tws.append(streak)
	_tws.append(Juice.play(_lines, _rest[_lines], [{a = 0.0, s = 1.4}, {a = 1.0, s = 1.0, r = 25.0}], HOLD * 1000.0 + 120.0, "ease"))
	var hit: = func() -> void :
		if not (_open and n == _n):
			return
		fx.shake(8, 220)
		fx.flash(Color.WHITE, 0.35)
		fx.sfx("hit", 1.2)
	get_tree().create_timer(0.23).timeout.connect(hit)
	_body.modulate.a = 0.0
	_tws.append(Juice.play(_body, _rest[_body], [
		{x = - _body.size.x * 0.6, y = 40 * k, s = 0.5, r = -15.0, a = 0.0}, 
		{t = 0.6, x = _body.size.x * 0.04, y = -12 * k, s = 1.15, r = 4.0, a = 1.0}, 
		{t = 0.8, sx = 0.97, sy = 1.03}, 
		{a = 1.0}, 
	], 420.0, "ease-out", 120.0))
	var sparkle: = func() -> void :
		if not (_open and n == _n):
			return
		var c: = _body.get_global_rect().get_center()
		fx.burst(c, color, 14)
		fx.burst(c, Color.WHITE, 10)
		fx.kp("star_09", c, 260.0 * k, Color("fff6c8"), [{s = 0.3, a = 1.0}, {s = 1.2, r = 90.0, a = 0.0}], 600.0)
	get_tree().create_timer(0.38).timeout.connect(sparkle)

	_name.visible_characters = 0
	_name.modulate.a = 1.0
	var letters: = _name.text.length()
	if letters > 0:
		var tw: = _name.create_tween()
		tw.tween_interval(0.32)
		tw.tween_property(_name, "visible_characters", letters, letters * 0.05).from(0)
		_tws.append(tw)
		_tws.append(Juice.play(_name, _rest[_name], [{s = 0.6}, {t = 0.7, s = 1.12}, {s = 1.0}], 300.0, "ease-out", 320.0))
		for i in letters:
			get_tree().create_timer(0.32 + i * 0.05).timeout.connect( func():
				if _open and n == _n:
					fx.sfx("pop", 1.6 + i * 0.08))
	if name_pic:
		_name_pic.modulate.a = 0.0
		_tws.append(Juice.play(_name_pic, _rest[_name_pic], [{s = 0.3, r = -6.0, a = 0.0}, {t = 0.6, s = 1.15, r = 2.0, a = 1.0}, {s = 1.0, r = 0.0, a = 1.0}], 300.0, "ease-out", 320.0))
		get_tree().create_timer(0.32).timeout.connect( func():
			if _open and n == _n:
				fx.sfx("pop", 1.6))
	get_tree().create_timer(HOLD).timeout.connect( func():
		if n == _n:
			_close())
	await _closed
	for tw: Tween in _tws:
		if tw.is_valid():
			tw.kill()
	_name.visible_characters = -1
	fx.sfx("eraser", 1.3)
	fx.flash(Color.WHITE, 0.5)
	var out: = [0.42, 0.0, 1.0, 1.0]
	Juice.play(_body, _rest[_body], [{a = 1.0}, {x = _body.size.x * 1.4, s = 1.2, a = 0.0}], 220.0, out)
	Juice.play(_name, _rest[_name], [{a = 1.0}, {x = _name.size.x * 1.4, s = 1.2, a = 0.0}], 220.0, out)
	if name_pic:
		Juice.play(_name_pic, _rest[_name_pic], [{a = 1.0}, {x = _name_pic.size.x * 1.4, s = 1.2, a = 0.0}], 220.0, out)
	Juice.play(_dark, _dark.position, [{}, {x = reach}], 200.0, out)
	Juice.play(_light, _light.position, [{}, {x = - reach}], 200.0, out)
	_lines.create_tween().tween_property(_lines, "modulate:a", 0.0, 0.22)
	await _dim.create_tween().tween_property(_dim, "modulate:a", 0.0, 0.24).finished
	hide()



func _drift(band: Polygon2D, dir: float, n: int, k: float) -> void :
	if not (_open and n == _n):
		return
	var tw: = band.create_tween()
	tw.tween_property(band, "position:x", _rest[band].x + dir * 24.0 * k, HOLD)
	_tws.append(tw)


func _close() -> void :
	if _open:
		_open = false
		_closed.emit()


func _input(event: InputEvent) -> void :
	if not (_open and event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	var now: = Time.get_ticks_msec() / 1000.0
	if _last_tap >= 0.0 and now - _last_tap <= DOUBLE_TAP:
		_close()
	_last_tap = now
