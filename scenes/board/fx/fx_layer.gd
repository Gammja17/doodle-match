class_name FxLayer
extends Control






signal sound(key: String, pitch: float)

const SCENES: = {
	kp = preload("res://scenes/board/fx/kp.tscn"), 
	shard = preload("res://scenes/board/fx/shard.tscn"), 
	text = preload("res://scenes/board/fx/float_text.tscn"), 
	line = preload("res://scenes/board/fx/ray.tscn"), 
	num = preload("res://scenes/board/fx/num_text.tscn"), 
}

const CAP: = {kp = 90, shard = 40, text = 12, line = 24, num = 12}
const FLY_MAX: = 16
const STOP_COOLDOWN: = 260
const TEX: = {
	circle_03 = preload("res://scenes/board/fx/k/circle_03.png"), circle_05 = preload("res://scenes/board/fx/k/circle_05.png"), 
	flare_01 = preload("res://scenes/board/fx/k/flare_01.png"), light_02 = preload("res://scenes/board/fx/k/light_02.png"), 
	magic_02 = preload("res://scenes/board/fx/k/magic_02.png"), slash_03 = preload("res://scenes/board/fx/k/slash_03.png"), 
	smoke_04 = preload("res://scenes/board/fx/k/smoke_04.png"), spark_05 = preload("res://scenes/board/fx/k/spark_05.png"), 
	star_04 = preload("res://scenes/board/fx/k/star_04.png"), star_06 = preload("res://scenes/board/fx/k/star_06.png"), 
	star_09 = preload("res://scenes/board/fx/k/star_09.png"), symbol_01 = preload("res://scenes/board/fx/k/symbol_01.png"), 
	twirl_01 = preload("res://scenes/board/fx/k/twirl_01.png"), dot = preload("res://scenes/board/fx/dot.svg"), 

	d_ring = preload("res://scenes/board/fx/doodle/ring.png"), d_star = preload("res://scenes/board/fx/doodle/star.png"), 
	d_spark = preload("res://scenes/board/fx/doodle/spark.png"), d_boom = preload("res://scenes/board/fx/doodle/boom.png"), 
	d_stars = preload("res://scenes/board/fx/doodle/stars.png"), 
	d_ink = preload("res://scenes/board/fx/doodle/ink.png"), 
	w_kwang = preload("res://scenes/board/fx/doodle/kwang.png"), w_pung = preload("res://scenes/board/fx/doodle/pung.png"), 
	w_seuk = preload("res://scenes/board/fx/doodle/seuk.png"), 
}
const CRUMB: = [preload("res://scenes/board/fx/doodle/crumb_1.png"), preload("res://scenes/board/fx/doodle/crumb_2.png"), preload("res://scenes/board/fx/doodle/crumb_3.png")]
const PAPER: = [preload("res://scenes/board/fx/doodle/paper_1.png"), preload("res://scenes/board/fx/doodle/paper_2.png"), preload("res://scenes/board/fx/doodle/paper_3.png"), preload("res://scenes/board/fx/doodle/paper_4.png")]
const SMUDGE: = preload("res://scenes/board/fx/doodle/smudge.png")
const CRAYON: = preload("res://scenes/board/fx/doodle/crayon.png")
const DASH: = preload("res://scenes/board/fx/doodle/dash.png")
const BOIL_MAT: = preload("res://shaders/materials/line_boil.tres")
const INK_MAT: = preload("res://shaders/materials/ink_spread.tres")
const INK: = Color("4a4262")
const GOLD: = Color("ffc83d")
const PASTEL: = [Color("ff8ab8"), Color("ffd84d"), Color("7be0a0"), Color("7cc4ec"), Color("b99cf0")]

var screen: Control
var S: = 56.0
var k: = 1.0

var _pools: = {}
var _busy: = {}
var _pop_t: = 0
var _pop_n: = 0
var _impact_t: = 0
var _flying: = 0
var _outer_scale: = 1.0
var _base_scale: = 1.0
var _stops: = 0
var _slow: = 1.0
var _ff: = 1.0
var _combo_n: = 0
var _last_stop: = -100000

@onready var _flash: ColorRect = $Flash
@onready var _dim: ColorRect = $Dim
@onready var _combo: Control = $Combo
@onready var _fever: Control = $Fever


func _ready() -> void :
	_outer_scale = Engine.time_scale
	_base_scale = _outer_scale * (1.5 if AppPrefs.get_value("fast_play") else 1.0)
	Engine.time_scale = _base_scale


func _exit_tree() -> void :
	Engine.time_scale = _outer_scale



func _scale() -> float:
	return _base_scale * _slow * _ff


func set_cell(cell: float) -> void :
	S = cell
	k = cell / 56.0



func active(kind: String) -> int:
	return _pools.get(kind, []).filter( func(n): return _busy.has(n)).size()



func flying() -> int:
	return _flying


func _take(kind: String) -> CanvasItem:
	var pool: Array = _pools.get_or_add(kind, [])
	for n in pool:
		if not _busy.has(n):
			_busy[n] = true
			return n
	if pool.size() >= CAP[kind]:
		return null
	var n: CanvasItem = SCENES[kind].instantiate()
	add_child(n)
	pool.append(n)
	_busy[n] = true
	return n


func _give(n: CanvasItem) -> void :
	_busy.erase(n)
	n.hide()
	n.material = null
	if n is Line2D:
		n.texture = null


func _local(at: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * at


func _ms() -> int:
	return Time.get_ticks_msec()




func sfx(key: String, pitch: = 1.0) -> void :
	sound.emit(key, pitch)
	var audio: = get_node_or_null("/root/Audio")
	if audio:
		audio.sfx(key, pitch)



func pop_sound(i: int) -> void :
	var audio: = get_node_or_null("/root/Audio")
	sound.emit("pop", audio.pop_pitch(i + 1) if audio else 1.0)
	if audio:
		audio.pop(i + 1)


func jingle(key: String) -> void :
	sound.emit("jingle_" + key, 1.0)
	var audio: = get_node_or_null("/root/Audio")
	if audio:
		audio.play_jingle(key)





func kp(tex, at: Vector2, size: float, color: Color, frames: Array, dur: float, ease = "ease", delay: = 0.0, mat: Material = null) -> TextureRect:
	var n: TextureRect = _take("kp")
	if n == null:
		return null
	n.material = mat
	n.texture = TEX[tex] if tex is String else tex
	n.size = Vector2.ONE * size
	n.pivot_offset = n.size / 2
	n.self_modulate = color
	n.z_index = 1
	n.show()
	Juice.play(n, _local(at) - n.size / 2, frames, dur, ease, delay, _give.bind(n))
	return n



func burst(at: Vector2, color: Color, n: = 6) -> void :
	if active("kp") > 60:
		n = ceili(n / 2.0)
	for i in n:
		var ang: = randf() * TAU
		var d: = (24.0 + randf() * 44.0) * k
		var rot: = (randf() - 0.5) * 300.0
		var star: = i % 3 != 2
		var sz: = (14.0 + randf() * 14.0 if star else 10.0 + randf() * 8.0) * k
		var v: = Vector2(cos(ang), sin(ang)) * d
		kp(("star_06" if i % 2 else "star_04") if star else "spark_05", at, sz, color if i % 2 else Color.WHITE, [
			{s = 0.4, a = 1.0}, 
			{t = 0.35, x = v.x * 0.7, y = v.y * 0.7, s = 1.2, r = rot / 2, a = 1.0}, 
			{x = v.x, y = v.y, s = 0.0, r = rot, a = 0.0}, 
		], 420.0 + randf() * 220.0, [0.2, 0.8, 0.4, 1.0])



func pop_sparkle(at: Vector2, color: Color) -> void :
	var now: = _ms()
	if now - _pop_t > 120:
		_pop_t = now
		_pop_n = 0
	_pop_n += 1
	if _pop_n > 10 or active("kp") > 70:
		return
	kp("light_02", at, S * 1.3, Color.WHITE, [{s = 0.3, a = 0.9}, {s = 1.1, a = 0.0}], 200.0, "ease-out")
	kp("circle_03", at, S * 1.6, color, [{s = 0.3, a = 0.9}, {s = 1.0, a = 0.0}], 340.0, [0.2, 0.8, 0.3, 1.0])
	for j in 3:
		var ang: = - PI / 2 + (j - 1) * 0.95 + (randf() - 0.5) * 0.5
		var d: = S * (0.5 + randf() * 0.35)
		var rot: = (randf() - 0.5) * 240.0
		var v: = Vector2(cos(ang), sin(ang)) * d
		kp("symbol_01" if j == 1 else "star_04", at, S * (0.3 + randf() * 0.12), color if j == 1 else [Color.WHITE, Color("fff3a8")][j >> 1], [
			{s = 0.3, a = 1.0}, 
			{t = 0.45, x = v.x, y = v.y, s = 1.0, r = rot / 2, a = 1.0}, 
			{x = v.x * 1.2, y = v.y + S * 0.55, s = 0.4, r = rot, a = 0.0}, 
		], 560.0, [0.25, 0.7, 0.5, 1.0])



func ring(at: Vector2, size: float, color: Color, dur: = 380.0) -> void :
	kp("circle_05", at, size, color, [{s = 0.1, a = 1.0}, {s = 1.0, a = 0.0}], dur, "ease-out")



func shards(at: Vector2, colors: Array, n: = 8, size: = 10.0, round: = false) -> void :
	if active("shard") > 30:
		n = ceili(n / 2.0)
	for i in n:
		var p: ColorRect = _take("shard")
		if p == null:
			return
		var w: = size * (0.6 + randf() * 0.8) * k
		var h: = (size if round else size * (0.5 + randf() * 0.5)) * k
		p.size = Vector2(w, h)
		p.pivot_offset = p.size / 2
		p.color = colors[i % colors.size()]
		p.material = null
		p.show()
		var dx: = (randf() - 0.5) * 120.0 * k
		var up: = (40.0 + randf() * 60.0) * k
		var rot: = (randf() - 0.5) * 720.0
		Juice.play(p, _local(at) - p.size / 2, [
			{a = 1.0}, 
			{t = 0.4, x = dx * 0.5, y = - up, r = rot / 2, a = 1.0}, 
			{x = dx, y = up * 0.8, r = rot, a = 0.0}, 
		], 650.0 + randf() * 250.0, [0.2, 0.6, 0.5, 1.0], 0.0, _give.bind(p))



func confetti_ring(at: Vector2, n: = 10) -> void :
	if active("kp") > 70:
		return
	for i in n:
		var a: = float(i) / n * TAU + randf() * 0.3
		var d: = S * (1.6 + randf() * 0.8)
		var v: = Vector2(cos(a), sin(a)) * d
		kp("star_06" if i % 3 else "symbol_01", at, S * 0.5, PASTEL[i % 5], [
			{s = 0.3, a = 1.0}, 
			{t = 0.5, x = v.x * 0.8, y = v.y * 0.8, s = 1.1, r = 120.0, a = 1.0}, 
			{x = v.x, y = v.y + S * 0.6, s = 0.3, r = 220.0, a = 0.0}, 
		], 700.0, [0.2, 0.8, 0.4, 1.0])



func confetti(n: = 14) -> void :
	var w: = get_viewport_rect().size
	for i in n:
		var at: = get_global_transform() * Vector2(randf() * w.x, -30.0 * k)
		var dx: = (randf() - 0.5) * 120.0 * k
		var dy: = w.y * (0.6 + randf() * 0.5)
		kp(["star_06", "symbol_01", "star_04"][i % 3], at, 34.0 * k, PASTEL[i % 5], [
			{s = 0.6, a = 1.0}, {x = dx, y = dy, r = (randf() - 0.5) * 720.0, s = 1.0, a = 0.9}, 
		], 1300.0 + randf() * 700.0, [0.3, 0.2, 0.6, 1.0], randf() * 300.0)



func embers(at: Vector2, color: Color, n: int) -> void :
	for i in n:
		var dx: = (randf() - 0.5) * S * 2.4
		var up: = S * (0.8 + randf())
		kp("star_06", at + Vector2(dx * 0.3, 0), S * (0.3 + randf() * 0.3), color, [
			{s = 1.0, a = 1.0}, {x = dx, y = - up, s = 0.0, a = 0.0}, 
		], 700.0 + randf() * 400.0, "ease-out", i * 40.0)



func impact(at: Vector2, color: Color, ang: = 0.0, big: = false) -> void :
	var now: = _ms()
	if not big and now - _impact_t < 30:
		return
	_impact_t = now
	kp("d_spark", at, S * (1.6 if big else 1.0), color, [{r = ang + 90.0, s = 0.5, a = 1.0}, {r = ang + 90.0, s = 1.2, a = 0.0}], 210.0, "ease-out")
	kp("d_star", at, S * (1.1 if big else 0.7), color, [{s = 0.3, a = 0.95}, {s = 1.0, r = 25.0, a = 0.0}], 250.0, "ease-out")





func float_num(at: Vector2, text: String, color: = Color.WHITE, crit: = false, small: = false) -> void :
	var px: = (43.0 if crit else 24.0 if small else 32.0) * k
	var parts: = WordArt.glyphs(text, crit)
	var l: Control
	if parts.is_empty():
		var lab: Label = _take("text")
		if lab == null:
			return
		lab.text = text
		lab.add_theme_color_override("font_color", GOLD if crit else color)
		lab.add_theme_font_size_override("font_size", roundi(px))
		lab.add_theme_constant_override("outline_size", roundi(7.0 * k))
		lab.size = Vector2(300, 80) * k
		l = lab
	else:
		var row: WordRow = _take("num")
		if row == null:
			return
		row.show_glyphs(parts, px * 1.3, Color.WHITE if crit else color)
		l = row
	l.z_index = 2
	l.pivot_offset = l.size / 2
	l.show()
	var h: = 80.0 * k
	Juice.play(l, _local(at) - l.size / 2, [
		{s = 0.3, a = 0.0}, 
		{t = 0.22, y = - h * 0.4, s = 1.3, a = 1.0}, 
		{t = 0.7, y = - h * 0.6, s = 1.0, a = 1.0}, 
		{y = - h * 1.2, s = 0.9, a = 0.0}, 
	], 950.0, "ease-out", 0.0, _give.bind(l))



func banner(text: String, hold: = 650.0) -> void :
	var vw: = get_viewport_rect().size
	var pic: = WordArt.of(text)
	if pic:
		_banner_pic(pic, hold, vw)
		return
	var l: Label = _take("text")
	if l == null:
		return
	l.text = text
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_font_size_override("font_size", roundi(minf(54.0, floorf(vw.x / k * 0.86 / maxf(4, text.length()))) * k))
	l.add_theme_constant_override("outline_size", roundi(9.0 * k))
	l.z_index = 3
	l.size = Vector2(vw.x, 120 * k)
	l.pivot_offset = l.size / 2
	l.show()
	var at: = get_global_transform() * Vector2(vw.x / 2, vw.y * 0.45)
	var h: = l.size.y
	Juice.play(l, _local(at) - l.size / 2, [
		{s = 0.0, r = -8.0, a = 0.0}, 
		{t = 0.12, s = 1.2, r = 3.0, a = 1.0}, 
		{t = 0.22, s = 1.0, a = 1.0}, 
		{t = 0.8, s = 1.0, a = 1.0}, 
		{y = - h * 0.1, s = 1.1, a = 0.0}, 
	], hold + 400.0, "ease-out", 0.0, _give.bind(l))



func _banner_pic(pic: Texture2D, hold: float, vw: Vector2) -> void :
	var n: TextureRect = _take("kp")
	if n == null:
		return
	var aspect: = float(pic.get_width()) / pic.get_height()
	var w: = minf(vw.x * 0.86, 110.0 * k * aspect)
	n.texture = pic
	n.material = null
	n.size = Vector2(w, w / aspect)
	n.pivot_offset = n.size / 2
	n.self_modulate = Color.WHITE
	n.z_index = 3
	n.show()
	var at: = get_global_transform() * Vector2(vw.x / 2, vw.y * 0.45)
	var h: = n.size.y
	Juice.play(n, _local(at) - n.size / 2, [
		{s = 0.0, r = -8.0, a = 0.0}, 
		{t = 0.12, s = 1.2, r = 3.0, a = 1.0}, 
		{t = 0.22, s = 1.0, a = 1.0}, 
		{t = 0.8, s = 1.0, a = 1.0}, 
		{y = - h * 0.1, s = 1.1, a = 0.0}, 
	], hold + 400.0, "ease-out", 0.0, _give.bind(n))



func _word_or_label(label: Label, pic: TextureRect, text: String, h: float) -> Control:
	var t: = WordArt.of(text)
	label.text = text
	label.visible = t == null
	pic.visible = t != null
	if t:
		pic.texture = t
		pic.custom_minimum_size = Vector2(h * t.get_width() / t.get_height(), h)
	return pic if t else label





func fly_tile(tex: Texture2D, from: Vector2, to: Vector2, color: Color, on_hit: = Callable(), delay: = 0.0) -> bool:
	if _flying >= FLY_MAX:
		return false
	var n: TextureRect = _take("kp")
	if n == null:
		return false
	_flying += 1
	n.texture = tex
	n.size = Vector2.ONE * S
	n.pivot_offset = n.size / 2
	n.self_modulate = Color.WHITE
	n.z_index = 2
	n.show()
	var d: = to - from
	var side: = (randf() - 0.5) * S * 2.2
	var lift: = S * (0.9 + randf() * 0.7)
	var spin: = signf(side if side != 0.0 else 1.0) * (20.0 + randf() * 30.0)
	var frames: = []
	for j in 11:
		var u: = j / 10.0
		var arc: = sin(PI * u)
		frames.append({t = u, x = d.x * u + side * arc * 0.6, y = d.y * u - lift * arc, r = spin * u, 
			s = 1.0 + u * 1.3 if u < 0.2 else 1.26 - (u - 0.2) * 0.75})
	var dur: = 330.0 + minf(260.0, d.length() / k * 0.28)
	var land: = func() -> void :
		_flying -= 1
		_give(n)
		impact(to, color, rad_to_deg(d.angle()) + 180.0)
		if on_hit.is_valid():
			on_hit.call()
	Juice.play(n, _local(from) - n.size / 2, frames, dur, [0.4, 0.0, 0.85, 0.6], delay, land)
	return true



func plane_fly(tex: Texture2D, from: Vector2, to: Vector2, dur: = 600.0) -> void :
	sfx("plane", 0.75)
	var n: TextureRect = _take("kp")
	if n == null:
		return
	n.texture = tex
	n.size = Vector2.ONE * S * 1.25
	n.pivot_offset = n.size / 2
	n.self_modulate = Color.WHITE
	n.z_index = 2
	n.show()
	var d: = to - from
	var lift: = maxf(80.0 * k, d.length() * 0.45)
	var pt: = func(t: float) -> Vector2: return Vector2(d.x * t, d.y * t - lift * 4.0 * t * (1.0 - t))
	var frames: = []
	for j in 13:
		var t: = j / 12.0
		var p: Vector2 = pt.call(t)
		var p2: Vector2 = pt.call(minf(1.0, t + 0.05))
		frames.append({t = t, x = p.x, y = p.y, r = rad_to_deg((p2 - p).angle()) + 40.0, s = 0.8 + sin(t * PI) * 0.5})
	var path: = PackedVector2Array()
	for j in 25:
		path.append(from + pt.call(j / 24.0))
	pencil_dots(path, dur)
	await Juice.play(n, _local(from) - n.size / 2, frames, dur, "ease-in-out", 0.0, _give.bind(n)).finished



func beam(from: Vector2, to: Vector2, color: Color, delay: = 0.0) -> void :
	var l: Line2D = _take("line")
	if l == null:
		return
	var a: = _local(from)
	var b: = _local(to)
	l.width = 6.0 * k
	l.default_color = color
	l.gradient = null
	l.points = PackedVector2Array([a, a])
	l.modulate.a = 1.0
	l.z_index = 1
	l.show()
	var tw: = l.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay / 1000.0)
	tw.tween_method( func(u: float): l.set_point_position(1, a.lerp(b, u)), 0.0, 1.0, 0.15)
	tw.tween_property(l, "modulate:a", 0.0, 0.15)
	tw.tween_callback(_give.bind(l))



func trail(from: Vector2, to: Vector2, dur: float) -> void :
	var l: Line2D = _take("line")
	if l == null:
		return
	var a: = _local(from)
	var b: = _local(to)
	l.width = S * 0.42
	l.default_color = Color(0.86, 0.95, 1.0)
	l.gradient = null
	l.points = PackedVector2Array([a, a])
	l.modulate.a = 1.0
	l.z_index = 1
	l.show()
	var tw: = l.create_tween()
	tw.tween_method( func(u: float): l.set_point_position(1, a.lerp(b, u)), 0.0, 1.0, dur * 0.55 / 1000.0)
	tw.tween_property(l, "width", S * 0.08, dur * 0.45 / 1000.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, dur * 0.45 / 1000.0)
	tw.tween_callback(_give.bind(l))



func after_line(from: Vector2, to: Vector2) -> void :
	var l: Line2D = _take("line")
	if l == null:
		return
	l.width = 10.0 * k
	l.default_color = Color.WHITE
	l.gradient = null
	l.points = PackedVector2Array([_local(from), _local(to)])
	l.modulate = Color(0.75, 0.92, 1.0, 0.9)
	l.z_index = 1
	l.show()
	var tw: = l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	var done: = func() -> void :
		l.modulate = Color.WHITE
		_give(l)
	tw.tween_callback(done)



func fly_off(tex: Texture2D, at: Vector2, size: float) -> void :
	var dx: = (-1.0 if randf() < 0.5 else 1.0) * (40.0 + randf() * 40.0) * k
	kp(tex, at, size, Color.WHITE, [
		{s = 1.0, a = 1.0}, 
		{t = 0.35, x = dx * 0.5, y = -70.0 * k, s = 1.25, r = dx / k * 2.0, a = 1.0}, 
		{x = dx, y = 60.0 * k, s = 0.7, r = dx / k * 5.0, a = 0.0}, 
	], 750.0, "ease-out")



func toss_piece(tex: Texture2D, at: Vector2, size: float, dir: float, delay: = 0.0) -> void :
	var dx: = dir * (40.0 + randf() * 30.0) * k
	kp(tex, at, size, Color.WHITE, [
		{s = 0.8, a = 1.0}, 
		{t = 0.4, x = dx * 0.5, y = - size * 0.9, s = 1.0, r = dir * 120.0, a = 1.0}, 
		{x = dx, y = size * 0.9, s = 0.8, r = dir * 300.0, a = 0.0}, 
	], 640.0, "ease-out", delay)



func pull_out(tex: Texture2D, at: Vector2, size: float) -> void :
	var dx: = (-1.0 if randf() < 0.5 else 1.0) * (18.0 + randf() * 22.0) * k
	kp(tex, at, size, Color.WHITE, [
		{a = 1.0}, 
		{t = 0.14, x = -3 * k, y = -6 * k, r = -6.0}, 
		{t = 0.26, x = 2 * k, r = 4.0}, 
		{t = 0.4, x = -2 * k, y = -12 * k, s = 1.02, r = -8.0}, 
		{t = 0.5, y = -4 * k, r = 2.0}, 
		{t = 0.72, x = dx * 0.4, y = - size * 1.1, s = 1.12, r = dx / k * 0.6, a = 1.0}, 
		{x = dx, y = - size * 1.6, s = 0.9, r = dx / k * 1.6, a = 0.0}, 
	], 720.0, "ease-out")





func doodle_ring(at: Vector2, size: float, color: Color, dur: = 380.0) -> void :
	var r: = randf() * 360.0
	kp("d_ring", at, size, color, [{s = 0.2, r = r, a = 1.0}, {t = 0.6, s = 0.85, r = r + 25.0, a = 0.9}, {s = 1.0, r = r + 35.0, a = 0.0}], dur, "ease-out")



func scribbles(at: Vector2, color: Color, n: = 6) -> void :
	if active("kp") > 60:
		n = ceili(n / 2.0)
	for i in n:
		var ang: = randf() * TAU
		var d: = (24.0 + randf() * 44.0) * k
		var star: = i % 3 != 2
		var v: = Vector2(cos(ang), sin(ang)) * d
		var rot: = (randf() - 0.5) * 300.0 if star else rad_to_deg(ang) + 90.0
		var sz: = (16.0 + randf() * 12.0 if star else 22.0 + randf() * 8.0) * k
		kp("d_star" if star else "d_spark", at, sz, color if i % 2 else Color.WHITE, [
			{s = 0.4, r = 0.0 if star else rot, a = 1.0}, 
			{t = 0.35, x = v.x * 0.7, y = v.y * 0.7, s = 1.2, r = rot / 2 if star else rot, a = 1.0}, 
			{x = v.x, y = v.y, s = 0.0, r = rot, a = 0.0}, 
		], 420.0 + randf() * 220.0, [0.2, 0.8, 0.4, 1.0])



func crumbs(at: Vector2, n: = 4, delay: = 0.0) -> void :
	if active("kp") > 70:
		n = mini(n, 2)
	for i in n:
		var dx: = (randf() - 0.5) * S * 1.4
		var up: = S * (0.25 + randf() * 0.35)
		var rot: = (randf() - 0.5) * 540.0
		kp(CRUMB[i % 3], at + Vector2((randf() - 0.5) * S * 0.4, 0), S * (0.26 + randf() * 0.1), Color.WHITE, [
			{s = 0.6, a = 1.0}, 
			{t = 0.35, x = dx * 0.5, y = - up, s = 1.0, r = rot / 2, a = 1.0}, 
			{x = dx, y = S * 0.55, s = 0.9, r = rot, a = 0.0}, 
		], 560.0 + randf() * 200.0, [0.2, 0.6, 0.5, 1.0], delay)



func paper_bits(at: Vector2, n: = 6, reach: = 1.0) -> void :
	if active("kp") > 60:
		n = ceili(n / 2.0)
	for i in n:
		var ang: = float(i) / n * TAU + randf() * 0.6
		var v: = Vector2(cos(ang), sin(ang)) * S * reach * (1.0 + randf() * 0.9)
		var rot: = (randf() - 0.5) * 720.0
		kp(PAPER[i % 4], at, S * (0.36 + randf() * 0.2), Color.WHITE, [
			{s = 0.5, a = 1.0}, 
			{t = 0.35, x = v.x * 0.8, y = v.y * 0.8 - S * 0.3, s = 1.0, r = rot * 0.4, a = 1.0}, 
			{x = v.x, y = v.y + S * 0.9, s = 0.85, r = rot, a = 0.0}, 
		], 700.0 + randf() * 250.0, [0.2, 0.7, 0.4, 1.0])



func smudge(from: Vector2, to: Vector2, dur: float) -> void :
	var l: = _line_tex(SMUDGE, Line2D.LINE_TEXTURE_TILE, S * 0.6, Color(1, 1, 1, 0.85))
	if l == null:
		return
	var a: = _local(from)
	var b: = _local(to)
	l.points = PackedVector2Array([a, a])
	var tw: = l.create_tween()
	tw.tween_method( func(u: float): l.set_point_position(1, a.lerp(b, u)), 0.0, 1.0, dur * 0.55 / 1000.0)
	tw.tween_interval(0.25)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_give.bind(l))



func crayon_line(from: Vector2, to: Vector2, color: Color, delay: = 0.0) -> void :
	var l: = _line_tex(CRAYON, Line2D.LINE_TEXTURE_STRETCH, 10.0 * k, color)
	if l == null:
		return
	l.material = BOIL_MAT
	var a: = _local(from)
	var b: = _local(to)
	l.points = PackedVector2Array([a, a])
	var tw: = l.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay / 1000.0)
	tw.tween_method( func(u: float): l.set_point_position(1, a.lerp(b, u)), 0.0, 1.0, 0.15)
	tw.tween_property(l, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_give.bind(l))



func pencil_dots(path: PackedVector2Array, dur: float) -> void :
	var l: = _line_tex(DASH, Line2D.LINE_TEXTURE_TILE, 7.0 * k, Color.WHITE)
	if l == null:
		return
	var pts: = PackedVector2Array()
	for q in path:
		pts.append(_local(q))
	l.points = PackedVector2Array([pts[0], pts[0]])
	var last: = pts.size() - 1
	var grow: = func(u: float) -> void :
		var f: = u * last
		var m: = mini(last, floori(f) + 1)
		var part: = pts.slice(0, m + 1)
		part[m] = pts[m - 1].lerp(pts[m], clampf(f - (m - 1), 0.0, 1.0))
		l.points = part
	var tw: = l.create_tween()
	tw.tween_method(grow, 0.0, 1.0, dur / 1000.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_give.bind(l))



func ink_splat(at: Vector2, size: float, dur: = 900.0, delay: = 0.0) -> void :
	var m: ShaderMaterial = INK_MAT.duplicate()
	m.set_shader_parameter("use_texture_shape", true)
	m.set_shader_parameter("spread", 0.0)
	var n: = kp("d_ink", at, size, Color.WHITE, [{s = 0.55, r = randf() * 360.0, a = 1.0}, {t = 0.2, s = 1.0, a = 1.0}, {t = 0.65, s = 1.04, a = 0.85}, {s = 1.08, a = 0.0}], 
		dur, "ease-out", delay, m)
	if n:
		n.z_index = 0
		var tw: = n.create_tween()
		tw.tween_interval(delay / 1000.0)
		tw.tween_method( func(v: float): m.set_shader_parameter("spread", v), 0.0, 1.0, dur * 0.3 / 1000.0)



func boom_doodle(at: Vector2, size: float, a: = 1.0, dur: = 520.0) -> void :
	var r: = (randf() - 0.5) * 30.0
	var n: = kp("d_boom", at, size, Color(1, 1, 1, a), [{s = 0.2, r = r - 12.0, a = 1.0}, {t = 0.3, s = 1.08, r = r + 4.0, a = 1.0}, {t = 0.7, s = 1.0, r = r, a = 1.0}, {s = 1.12, r = r, a = 0.0}], 
		dur, "ease-out", 0.0, BOIL_MAT)
	if n:
		n.z_index = 0



func word(tex: String, at: Vector2, size: float, tilt: = -8.0, dur: = 620.0) -> void :
	var n: = kp(tex, at, size, Color.WHITE, [
		{s = 0.2, r = tilt * 2.0, a = 0.0}, 
		{t = 0.18, s = 1.25, r = tilt, a = 1.0}, 
		{t = 0.3, s = 1.0, r = tilt, a = 1.0}, 
		{t = 0.75, y = - size * 0.08, s = 1.0, r = tilt, a = 1.0}, 
		{y = - size * 0.2, s = 0.95, r = tilt, a = 0.0}, 
	], dur, "ease-out")
	if n:
		n.z_index = 6



func _line_tex(tex: Texture2D, mode: Line2D.LineTextureMode, width: float, color: Color) -> Line2D:
	var l: Line2D = _take("line")
	if l == null:
		return null
	l.texture = tex
	l.texture_mode = mode
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.width = width
	l.default_color = color
	l.gradient = null
	l.modulate = Color.WHITE
	l.z_index = 1
	l.show()
	return l




func _screen() -> Control:
	return screen if screen else get_parent() as Control



func shake(power: = 6.0, dur: = 300.0) -> void :
	var s: = _screen()
	if s == null:
		return
	var p: = power * k
	var frames: = []
	for i in 6:
		frames.append({x = (randf() - 0.5) * p * 2, y = (randf() - 0.5) * p * 2})
	frames.append({})
	var base: Vector2 = s.get_meta("shake_base", s.position)
	s.set_meta("shake_base", base)
	var fs: = Juice.normalize(frames)
	var step: = func(u: float) -> void :
		var f: = Juice._at(fs, u)
		s.position = base + Vector2(f.x, f.y)
	var done: = func() -> void :
		s.position = base
		s.remove_meta("shake_base")
	var tw: = s.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur / 1000.0)
	tw.tween_callback(done)



func flash(color: = Color("ff4d6d"), peak: = 0.45) -> void :
	_flash.color = color
	_flash.modulate.a = peak
	_flash.show()
	var tw: = _flash.create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_flash.hide)



func zoom(at: Vector2, scale_to: = 1.08, dur: = 420.0) -> void :
	var s: = _screen()
	if s == null:
		return
	s.pivot_offset = s.get_global_transform().affine_inverse() * at
	var c: = [0.2, 0.8, 0.3, 1.0]
	var step: = func(u: float) -> void :
		var p: = Juice.ease_value(c, u)
		var v: = lerpf(1.0, scale_to, p / 0.25) if p < 0.25 else lerpf(scale_to, 1.0, (p - 0.25) / 0.75)
		s.scale = Vector2.ONE * v
	s.create_tween().tween_method(step, 0.0, 1.0, dur / 1000.0)




func stop(ms: = 70.0) -> void :
	var now: = Time.get_ticks_msec()
	if now - _last_stop < STOP_COOLDOWN:
		return
	_last_stop = now
	_stops += 1
	Engine.time_scale = 0.0
	var resume: = func() -> void :
		_stops -= 1
		if _stops <= 0:
			Engine.time_scale = _scale()
	get_tree().create_timer(ms / 1000.0, true, false, true).timeout.connect(resume)



func slow(ms: = 450.0, rate: = 0.3) -> void :
	_slow = rate
	if _stops <= 0:
		Engine.time_scale = _scale()
	var resume: = func() -> void :
		_slow = 1.0
		if _stops <= 0:
			Engine.time_scale = _scale()
	get_tree().create_timer(ms / 1000.0, true, false, true).timeout.connect(resume)



func fast_forward(rate: = 4.0, hint: = true) -> void :
	_ff = rate
	if _stops <= 0:
		Engine.time_scale = _scale()
	$FastHint.visible = hint


func fast_forward_end() -> void :
	_ff = 1.0
	if _stops <= 0:
		Engine.time_scale = _scale()
	$FastHint.hide()




const PRAISE: = ["", "", "좋아!", "멋져!", "대단해!", "굉장해!"]




func combo_show(n: int, at: Vector2) -> void :
	if n < 2:
		return
	_combo_n = n
	var col: = Color.from_hsv(fmod(n * 47.0, 360.0) / 360.0, 0.75, 0.95)
	var s: = 1.0 + mini(n, 8) * 0.08
	var num: Label = $Combo / Row / Num
	var num_pic: WordRow = $Combo / Row / NumPic
	var digits: = WordArt.glyphs(str(n))
	num.text = str(n)
	num.add_theme_color_override("font_color", col)
	num.visible = digits.is_empty()
	num_pic.visible = not digits.is_empty()
	if num_pic.visible:
		num_pic.show_glyphs(digits, 110.0, col)
	_word_or_label($Combo / Row / Word, $Combo / Row / WordPic, "콤보", 74.0)
	_word_or_label($Combo / Praise, $Combo / PraisePic, PRAISE[n] if n < PRAISE.size() else "최고!", 66.0)
	_combo.show()
	_combo.size = _combo.get_combined_minimum_size()
	_combo.pivot_offset = _combo.size / 2
	var ks: = k * 0.6
	Juice.play(_combo, _local(at) - _combo.size / 2, [
		{s = s * 1.5 * ks, r = -8.0 if n % 2 else 8.0, a = 1.0}, {t = 0.55, s = s * 0.9 * ks}, {s = s * ks}, 
	], 320.0, "ease-out")
	if n >= 3:
		burst(at, col, 6 + mini(n, 8))



func combo_end() -> void :
	if _combo_n == 0:
		return
	_combo_n = 0
	var base: = _combo.position
	var h: = _combo.size.y
	var s: = _combo.scale.x
	Juice.play(_combo, base, [
		{s = s, a = 1.0}, {t = 0.35, y = - h * 0.3, s = s * 1.15, a = 1.0}, {y = - h * 0.8, s = s * 0.7, a = 0.0}, 
	], 420.0, "ease-in", 0.0, _combo.hide)



func fever_show(sub: String) -> void :
	sfx("crayon", 1.1)
	sfx("skill", 1.25)
	for i in 7:
		get_tree().create_timer((80 + i * 70) / 1000.0).timeout.connect(pop_sound.bind(i))
	flash(Color("ff9ec4"), 0.55)
	_dim.modulate.a = 0.0
	_dim.show()
	_dim.create_tween().tween_property(_dim, "modulate:a", 0.6, 0.16)
	_fever.show()
	_fever.modulate.a = 1.0
	var title: Control = $Fever / Title
	var pic: = WordArt.of(($Fever / Title as Label).text)
	$Fever / TitlePic.texture = pic
	$Fever / TitlePic.visible = pic != null
	title.visible = pic == null
	if pic:
		title = $Fever / TitlePic
	var subl: Label = $Fever / Sub
	subl.text = sub
	title.pivot_offset = title.size / 2
	Juice.play(title, title.position, [{s = 0.0, r = -12.0}, {t = 0.5, s = 1.35, r = 4.0}, {s = 1.0, r = -3.0}], 420.0, "ease-out", 120.0)
	Juice.play(subl, subl.position, [{y = 10.0 * k, a = 0.0}, {a = 1.0}], 260.0, "ease", 380.0)
	confetti(22)
	get_tree().create_timer(0.35).timeout.connect(confetti.bind(16))
	var vw: = get_viewport_rect().size
	for i in 6:
		var at: = get_global_transform() * Vector2(vw.x * (0.15 + randf() * 0.7), vw.y * (0.2 + randf() * 0.5))
		get_tree().create_timer((150 + i * 140) / 1000.0).timeout.connect(burst.bind(at, PASTEL[i % 4], 10))
	shake(6, 300)
	await get_tree().create_timer(1.3).timeout
	var tw: = create_tween().set_parallel()
	tw.tween_property(_dim, "modulate:a", 0.0, 0.22)
	tw.tween_property(_fever, "modulate:a", 0.0, 0.22)
	await tw.finished
	_dim.hide()
	_fever.hide()



func skill_finish(at: Vector2, color: Color) -> void :
	flash(color, 0.22)
	sfx("star", 1.2)
	kp("star_09", at, S * 3.4, color, [{s = 0.2, a = 1.0}, {s = 1.1, r = 40.0, a = 0.0}], 520.0, "ease-out")
	kp("circle_03", at, S * 6, Color.WHITE, [{s = 0.1, a = 1.0}, {s = 1.0, a = 0.0}], 460.0, [0.2, 0.8, 0.3, 1.0])
	var cols: = [color, Color.WHITE, color]
	for i in 10:
		var ang: = float(i) / 10 * TAU
		var v: = Vector2(cos(ang), sin(ang)) * S * 2.4
		kp("star_04" if i % 2 else "star_06", at, S * 0.7, cols[i % 3], [
			{s = 0.3, a = 1.0}, {t = 0.5, x = v.x * 0.8, y = v.y * 0.8, s = 1.1, r = 120.0, a = 1.0}, {x = v.x, y = v.y, s = 0.0, r = 200.0, a = 0.0}, 
		], 620.0, [0.2, 0.8, 0.4, 1.0])
