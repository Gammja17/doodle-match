class_name TileView
extends Control






const INK_MAT: = preload("res://shaders/materials/ink_spread.tres")
const ERASE_MAT: = preload("res://shaders/materials/eraser_dissolve.tres")
const INSET: = 5.0

var tile: BoardTile
var k: = 1.0

var _idle: Tween
var _one: Tween
var _mat: Material

@onready var _art: TextureRect = $Art
@onready var _tape: TextureRect = $Tape
@onready var _glow: TextureRect = $Glow
@onready var _badge: Label = $Badge


func show_tile(t: BoardTile, art: TileArt) -> void :
	tile = t
	_art.texture = art.texture_for(t)
	_mat = art.material_for(t)
	_art.material = _mat
	_tape.texture = art.tape
	_tape.material = art.tape_mat
	_tape.visible = t.taped
	var tape_grow: = size.x * art.pad
	_tape.offset_left = - tape_grow
	_tape.offset_top = - tape_grow
	_tape.offset_right = tape_grow
	_tape.offset_bottom = tape_grow
	var item: = t.special != &""
	var inset: = INSET + (size.x * 0.1 if item else 0.0)
	if item or t.block != &"":
		inset -= (size.x - inset * 2) * art.pad
	_art.offset_left = inset
	_art.offset_top = inset
	_art.offset_right = - inset
	_art.offset_bottom = - inset
	_art.pivot_offset = (size - Vector2.ONE * inset * 2) / 2
	_glow.visible = item
	_glow.modulate = Color.WHITE

	var layers: = t.hp if t.block == Board.CRUMBS or t.block == Board.STICKY else 0
	_badge.visible = layers >= 2
	_badge.text = str(layers)
	_reset_art()
	if item:
		_breathe()
	else:
		_stop_idle()



func _art_base() -> Vector2:
	return Vector2(_art.offset_left, _art.offset_top)


func _reset_art() -> void :
	_art.scale = Vector2.ONE
	_art.rotation = 0.0
	_art.modulate = Color.WHITE


func _stop_idle() -> void :
	if _idle and _idle.is_valid():
		_idle.kill()
	_idle = null



func _breathe() -> void :
	_stop_idle()
	var base: = _art_base()
	var step: = func(u: float) -> void :
		var w: = (1.0 - cos(u * TAU)) / 2.0
		_art.position = base
		_art.scale = Vector2.ONE * (1.0 + 0.06 * w)
		_glow.modulate.a = 0.7 + 0.3 * w
	_idle = _art.create_tween().set_loops()
	_idle.tween_method(step, 0.0, 1.0, 1.6)



func select(on: bool) -> void :
	_stop_idle()
	_reset_art()
	_art.position = _art_base()
	if not on:
		if tile and tile.special != &"":
			_breathe()
		return
	var base: = _art_base()
	var step: = func(u: float) -> void :
		_art.position = base
		_art.scale = Vector2.ONE * (1.0 + 0.06 * (1.0 - cos(u * TAU)) / 2.0)
		_art.modulate = Color(1.15, 1.15, 1.15)
	_idle = _art.create_tween().set_loops()
	_idle.tween_method(step, 0.0, 1.0, 0.5)



func anim(frames: Array, dur: float, ease = "ease", delay: = 0.0, done: = Callable()) -> Tween:
	_stop_idle()
	if _one and _one.is_valid():
		_one.kill()
	_one = Juice.play(_art, _art_base(), frames, dur, ease, delay, done)
	return _one



func squish(delay: = 0.0) -> void :
	anim([{}, {t = 0.3, sx = 1.16, sy = 0.82}, {t = 0.65, sx = 0.94, sy = 1.06}, {}], 280.0, "ease-out", delay, 
		_breathe if tile and tile.special != &"" else Callable())




func pop(delay: float, fly: = false) -> void :
	z_index = 3
	if not fly:
		var m: ShaderMaterial = ERASE_MAT.duplicate()
		m.set_shader_parameter("rub_dir", Vector2(1.0, 0.3).rotated(randf() * TAU))
		_art.material = m
		var tw: = create_tween()
		tw.tween_interval((delay + 80.0) / 1000.0)
		tw.tween_method( func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, 0.15)
	var h: = _art.size.y
	var last: Dictionary = {s = 1.1, y = - h * 0.16} if fly else {s = 0.0, y = - h * 0.2, r = 25.0}
	anim([{}, {t = 0.38, sx = 1.3, sy = 0.68}, {t = 0.72, sx = 0.84, sy = 1.26, y = - h * 0.1}, last], 
		140.0 if fly else 230.0, "ease-out", delay)
	get_tree().create_timer((delay + (140.0 if fly else 240.0)) / 1000.0).timeout.connect(queue_free)



func pop_item(delay: float) -> void :
	z_index = 3
	_glow.hide()
	anim([{a = 1.0}, {t = 0.2, sx = 1.18, sy = 0.86, a = 1.0}, {t = 0.45, s = 1.38, a = 1.0}, {s = 0.0, r = 30.0, a = 0.0}], 
		260.0, "ease-in", delay, queue_free)



func gather(d: Vector2, delay: float) -> void :
	z_index = 4
	anim([{}, {t = 0.3, x = - d.x * 0.08, y = - d.y * 0.08, s = 1.12}, {x = d.x, y = d.y, s = 0.4, a = 0.8}], 
		180.0, [0.55, 0.0, 0.85, 0.4], minf(delay, 40.0))
	get_tree().create_timer((minf(delay, 40.0) + 200.0) / 1000.0).timeout.connect(queue_free)



func knock(push_from: Vector2, power: float, delay: float) -> void :
	z_index = 5
	var S: = size.x
	var dd: = (position + size / 2) - push_from
	var dist: = dd.length() if dd.length() > 0.0 else 1.0
	var vx: = (dd.x / dist if dd.x != 0.0 else randf() - 0.5) * S * (1.1 + randf() * 0.9) * power
	var vy: = dd.y / dist * S * 0.7 * power
	var up: = S * (0.7 + randf() * 0.6)
	var fall: = S * 3.2
	var rot: = (-1.0 if vx < 0 else 1.0) * (220.0 + randf() * 280.0)
	var frames: = []
	for j in 9:
		var u: = j / 8.0
		frames.append({t = u, x = vx * u, y = vy * u * 0.6 - up * 4.0 * u * (1.0 - u) + fall * u * u, r = rot * u, 
			s = 1.0 + 0.18 * sin(PI * u) - u * 0.3, a = 1.0 if u < 0.7 else 1.0 - (u - 0.7) / 0.3})
	anim(frames, 600.0, "linear", delay, queue_free)



func appear_item(delay: = 180.0) -> void :
	_art.scale = Vector2.ZERO
	anim([{s = 0.0, r = -90.0}, {t = 0.6, s = 1.35, r = 10.0}, {}], 380.0, "ease-out", delay, _breathe)



func ink_in() -> void :
	var m: ShaderMaterial = INK_MAT.duplicate()
	m.set_shader_parameter("use_texture_shape", true)
	_art.material = m
	anim([{s = 0.0}, {t = 0.6, s = 1.25}, {}], 360.0, "ease-out")
	create_tween().tween_method( func(v: float): m.set_shader_parameter("spread", v), 0.0, 1.0, 0.4)
	get_tree().create_timer(0.42).timeout.connect( func(): _art.material = _mat)





func wiggle(dur: = 90.0) -> void :
	anim([{}, {s = 1.25, r = -6.0}, {s = 1.25, r = 6.0}], dur, "ease")



func inflate(dur: = 320.0) -> void :
	anim([{b = 1.0}, {t = 0.3, s = 1.25, r = -8.0, b = 1.3}, {t = 0.6, s = 1.3, r = 8.0, b = 1.6}, {s = 1.55, b = 2.5}], dur, "ease")



func spin_up(dur: = 260.0) -> void :
	anim([{}, {s = 1.45, r = 360.0}], dur, "ease-in")



func lift(dur: = 120.0) -> void :
	anim([{}, {s = 1.3, r = -15.0, y = - _art.size.y * 0.2}], dur, "ease")



func kick(dur: = 120.0) -> void :
	anim([{}, {sx = 1.25, sy = 0.8}, {}], dur, "ease-out")



func merge_spin() -> void :
	z_index = 5
	anim([{s = 1.0, r = 0.0}, {t = 0.7, s = 1.35, r = 200.0}, {s = 1.6, r = 360.0, b = 2.0}], 380.0, "ease-in")



func jolt() -> void :
	var h: = _art.size.y
	anim([{}, {y = - h * 0.1, r = -6.0}, {r = 4.0}, {}], 260.0, "ease")


func hide_art() -> void :
	_stop_idle()
	_art.modulate.a = 0.0
	_glow.hide()
	_badge.hide()


func hide_tape() -> void :
	_tape.hide()
