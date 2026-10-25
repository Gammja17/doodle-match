class_name BoardView
extends Control




signal changed
signal message(text: String)
signal finished(won: bool, stars: int)

const TILE_SCENE: = preload("res://scenes/board/tile_view.tscn")
const CELL_SCENE: = preload("res://scenes/board/cell_view.tscn")
const ZONE_SCENE: = preload("res://scenes/board/zone.tscn")
const NO_CELL: = Board.NO_CELL

const FUSE: = {&"eraser_h": 90.0, &"eraser_v": 90.0, &"pushpin": 320.0, &"crayon": 260.0, &"paper_plane": 120.0}

const CHAIN_BEAT: = 140.0
const CHAIN_FUSE: = 0.55
const KICK_MS: = 120.0

const ZONE_TINT: = {&"eraser_h": Color("7cc4ec"), &"eraser_v": Color("7cc4ec"), &"pushpin": Color("ffb020"), 
	&"crayon": Color("ff8ab8"), &"paper_plane": Color("7cc4ec"), &"combo": Color("ffd84d")}

const POWER: = {&"eraser_h": 1.3, &"eraser_v": 1.3, &"pushpin": 1.7, &"crayon": 0.8, &"paper_plane": 1.2}


const BONUS_PACE: = 2.0
const BONUS_TAP: = 5.0
const BONUS_MAX_SEC: = 2.6
const RAINBOW: = [Color("ff8ab8"), Color("ffd84d"), Color("7cc4ec"), Color("a6d96a"), Color("b99cf0")]

const LOCK_ALPHA: = 0.35

@export var art: TileArt

@export var fx: FxLayer

var game
var cell_size: = 80.0
var busy: = false

var fly_to: Callable

var goal_at: Callable
var goal_bump: Callable

var bonus_from: Callable

var _views: = {}
var _cells: = {}
var _down: = NO_CELL
var _down_at: = Vector2.ZERO
var _moved: = false
var _sel: = NO_CELL
var _from: = {}
var _last_swap: = {}
var _dying: = {}
var _land_wait: = false
var _bonus: = false
var _bonus_i: = 0
var _ffwd: = false
var _skip: = false
var _skip_pts: = 0
var _hold: = 0
var _bonus_n: = 0
var _zones: Array = []
var _zone_layer: Control
var _only: Array = []

@onready var _cell_layer: Control = $Cells
@onready var _tile_layer: Control = $Tiles


func setup(g, area: Vector2) -> void :
	game = g
	var b: Board = g.board
	for n in _cell_layer.get_children() + _tile_layer.get_children():
		n.queue_free()
	if _zone_layer == null:
		_zone_layer = Control.new()
		_zone_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_zone_layer)
	_views.clear()
	_cells.clear()
	_sel = NO_CELL
	_down = NO_CELL
	_from = {}
	busy = false
	cell_size = floorf(minf(area.x / b.cols, area.y / b.rows))
	size = Vector2(b.cols, b.rows) * cell_size
	pivot_offset = size / 2
	if fx:
		fx.set_cell(cell_size)
	for y in b.rows:
		for x in b.cols:
			var p: = Vector2i(x, y)
			if b.hole(p):
				continue
			var c: CellView = CELL_SCENE.instantiate()
			_cell_layer.add_child(c)
			c.position = _pos(p)
			c.size = Vector2.ONE * cell_size
			c.setup(art)
			c.set_painted(b.painted(p))
			_cells[p] = c
	for p in b.cells():
		_add_view(b.at(p), p)
	_only = []


func _pos(p: Vector2i) -> Vector2:
	return Vector2(p) * cell_size


func _add_view(t: BoardTile, p: Vector2i) -> TileView:
	var v: TileView = TILE_SCENE.instantiate()
	_tile_layer.add_child(v)
	v.size = Vector2.ONE * cell_size
	v.pivot_offset = v.size / 2
	v.position = _pos(p)
	v.k = cell_size / 56.0
	v.show_tile(t, art)
	_views[t.id] = v
	return v



func cell_center(p: Vector2i) -> Vector2:
	return get_global_transform() * (_pos(p) + Vector2.ONE * cell_size / 2)


func _sfx(key: String, pitch: = 1.0) -> void :
	if fx:
		fx.sfx(key, pitch)


func _view(t: BoardTile) -> TileView:
	return _views.get(t.id) if t else null


func _cell_at(at: Vector2) -> Vector2i:
	var p: = Vector2i((at / cell_size).floor())
	return p if game.board.inside(p) and not game.board.hole(p) else NO_CELL



func _after(ms: float, f: Callable) -> void :
	if ms <= 0.0:
		f.call()
	else:
		get_tree().create_timer(ms / 1000.0).timeout.connect(f)


func _wait(sec: float) -> void :
	await get_tree().create_timer(sec).timeout



func _color(t: BoardTile) -> Color:
	if t.type >= 0 and t.type < art.colors.size():
		return art.colors[t.type]
	return Color("ffd84d")






func allow_only(a: Vector2i, b: Vector2i) -> void :
	_only = [] if a == NO_CELL and b == NO_CELL else [a, b]
	_select(NO_CELL)
	_apply_lock()


func allow_all() -> void :
	_only = []
	_apply_lock()


func _allowed(p: Vector2i) -> bool:
	return _only.is_empty() or p in _only



func _apply_lock() -> void :
	for p in _cells:
		_cells[p].modulate.a = 1.0 if _allowed(p) else LOCK_ALPHA
	var b: Board = game.board
	for p in b.cells():
		var v: = _view(b.at(p))
		if v:
			v.modulate.a = 1.0 if _allowed(p) else LOCK_ALPHA



func _input(event: InputEvent) -> void :
	if not _bonus or not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	_hold += 1
	if not event.pressed:
		return
	var n: = _hold
	get_tree().create_timer(0.5, true, false, true).timeout.connect( func():
		if _hold == n and _bonus:
			_skip_rest())
	skip_tap()



func skip_tap() -> void :
	if not _bonus or _skip:
		return
	if _ffwd:
		_skip_rest()
		return
	_ffwd = true
	if fx:
		fx.fast_forward(BONUS_TAP)


func _skip_rest(hint: = true) -> void :
	if _skip:
		return
	_skip = true
	_land_wait = false
	if fx and not _ffwd:
		_ffwd = true
		fx.fast_forward(BONUS_TAP, hint)


func _gui_input(event: InputEvent) -> void :
	if game == null or busy or game.over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = _cell_at(event.position)
			if not _allowed(_down):
				_down = NO_CELL
			_down_at = event.position
			_moved = false
		elif _down != NO_CELL:
			var d: = _down
			_down = NO_CELL
			if not _moved:
				_tap(d)
	elif event is InputEventMouseMotion and _down != NO_CELL and not _moved:
		var delta: Vector2 = event.position - _down_at
		if delta.length() < cell_size * 0.35:
			return
		_moved = true
		_select(NO_CELL)
		var dir: = Vector2i(signi(int(delta.x)), 0) if absf(delta.x) > absf(delta.y) else Vector2i(0, signi(int(delta.y)))
		if _allowed(_down + dir):
			swipe(_down, dir)



func swipe(from: Vector2i, dir: Vector2i) -> void :
	var to: = from + dir
	if Board.movable(game.board.at(to)):
		await play(game.try_swap(from, to))
	elif game.board.at(from) != null and game.board.at(from).special != &"":
		await play(game.activate(from))


func _tap(p: Vector2i) -> void :
	if not _allowed(p):
		return
	if _sel != NO_CELL:
		var s: = _sel
		_select(NO_CELL)
		if (s - p).abs().x + (s - p).abs().y == 1:
			await play(game.try_swap(s, p))
			return
		if s == p:
			if game.board.at(p).special != &"":
				await play(game.activate(p))
			return
	if Board.movable(game.board.at(p)):
		_select(p)
		_sfx("button", 1.4)


func _select(p: Vector2i) -> void :
	if _sel != NO_CELL:
		var old: = _view(game.board.at(_sel))
		if old:
			old.select(false)
	_sel = p
	if p != NO_CELL:
		_view(game.board.at(p)).select(true)



func drop_in(text: = "") -> void :
	var b: Board = game.board
	var last: = 0.0
	for q in b.cells():
		var v: = _view(b.at(q))
		var from: = _pos(q) - Vector2(0, (b.rows + 1) * cell_size)
		var delay: = q.x * 35.0 + (b.rows - q.y) * 25.0
		Juice.play(v, Vector2.ZERO, [{x = from.x, y = from.y}, {x = _pos(q).x, y = _pos(q).y}], 420.0, [0.5, 0.0, 1.0, 1.0], delay, v.squish)
		last = maxf(last, delay + 420.0)
	_after(450, _sfx.bind("swap", 0.6))
	if fx and text != "":
		fx.banner(text)
	await _wait(last / 1000.0)




func play(events: Array) -> void :
	if events.is_empty():
		return
	busy = true
	for e in events:
		if _skip and e.kind not in ["bonus_end", "win", "fail"]:
			_skip_pts += _points(e)
			continue
		if _land_wait and e.kind not in ["convert", "replace"]:
			await _wait_landing()
		await _show(e)
	if _land_wait:
		await _wait_landing()
	if fx:
		fx.combo_end()
	if not _only.is_empty():
		_apply_lock()
	busy = false
	changed.emit()



func _points(e: Dictionary) -> int:
	match e.kind:
		"step":
			return e.get("points", 0)
		"convert":
			return 150
		"collect":
			return e.got.size() * 500
	return 0



func _wait_landing() -> void :
	_land_wait = false
	var t: = 0.0
	while fx and fx.flying() > 0 and t < 1.2:
		await get_tree().process_frame
		t += get_process_delta_time()


func _show(e: Dictionary) -> void :
	match e.kind:
		"swap":
			_last_swap = e
			_sfx("swap", 1.15)
			await _slide([[e.ta, e.b], [e.tb, e.a]], 100.0, [0.3, 0.7, 0.4, 1.0])
		"swap_back":
			_sfx("swap_back", 1.2)
			await _slide([[e.ta, e.a], [e.tb, e.b]], 220.0, [0.3, 1.6, 0.6, 1.0])
		"combo":
			await _show_combo(e.combo)
		"activate":
			var v: = _view(e.tile)
			if v:
				await v.anim([{}, {s = 1.35}, {s = 1.1}], 140.0, "ease-out").finished
		"step":
			await _show_step(e.res, e.combo, e.get("points", 0))
			changed.emit()
		"fall":
			await _fall(e.paths)
		"collect":
			_show_collect(e.got)
			await _wait(0.2)
			changed.emit()
		"shuffle":
			message.emit("섞는 중…")
			_sfx("shuffle")
			await _wait(0.4)
			await _slide(e.tiles.map( func(x): return [x.tile, x.pos]), 380.0, [0.3, 1.4, 0.6, 1.0])
		"gift":
			var v: = _view(e.tile)
			v.show_tile(e.tile, art)
			v.squish()
		"convert":
			_show_convert(e)
			if _bonus:
				await _wait(0.07)
		"ink_spread", "replace":
			await _show_replace(e)
		"bonus_start":
			_bonus = true
			_bonus_i = 0
			_ffwd = false
			_skip = false
			_skip_pts = 0
			_bonus_n += 1
			var bn: = _bonus_n
			get_tree().create_timer(BONUS_MAX_SEC, true, false, true).timeout.connect( func():
				if _bonus and _bonus_n == bn:
					_skip_rest(false))
			if fx:
				fx.fast_forward(BONUS_PACE, false)
			message.emit("보너스 타임!")
			_sfx("reward")
			await _wait(0.35)
		"bonus_end":
			_bonus = false
			if fx:
				fx.fast_forward_end()
			var pts: int = _skip_pts + e.rest * 500
			_skip = false
			_skip_pts = 0
			if fx and pts > 0:
				fx.float_num(get_global_rect().get_center(), "+%d" % pts, Color("e07b39"), true)
			changed.emit()
		"win":
			finished.emit(true, e.stars)
		"fail":
			finished.emit(false, 0)



func _slide(moves: Array, dur: float, ease) -> void :
	var tw: Tween
	for m in moves:
		var v: = _view(m[0])
		if v:
			tw = Juice.play(v, Vector2.ZERO, [{x = v.position.x, y = v.position.y}, {x = _pos(m[1]).x, y = _pos(m[1]).y}], dur, ease)
	if tw:
		await tw.finished



func _fall(paths: Array) -> void :
	var total: = 0.0
	var ends: = []
	for p in paths:
		var path: Array = p.path
		var v: = _view(p.tile)
		if v == null:
			v = _add_view(p.tile, Vector2i(path[-1].x, path[-1].y))
		var t0: int = path[0].z
		var span: = maxi(1, path[-1].z - t0)
		var frames: = []
		for i in path.size():
			var q: = _pos(Vector2i(path[i].x, path[i].y))
			var f: = {t = float(path[i].z - t0) / span, x = q.x, y = q.y}
			if p.fresh:
				f.a = 0.0 if i == 0 else 1.0
			frames.append(f)
		var dur: = 150.0 + span * 85.0
		Juice.play(v, Vector2.ZERO, frames, dur, [0.45, 0.0, 0.9, 0.55], t0 * 72.0, v.squish)
		total = maxf(total, t0 * 72.0 + dur)
		ends.append([v, _pos(Vector2i(path[-1].x, path[-1].y))])
	if not paths.is_empty():
		_after(320, _sfx.bind("swap", 0.5))
	await _wait(total / 1000.0)
	for e in ends:
		if is_instance_valid(e[0]):
			e[0].position = e[1]
			e[0].modulate.a = 1.0





func _times(res: Dictionary, from: Dictionary) -> Dictionary:
	var b: Board = game.board
	var T: = {}
	for ef in res.effects:
		var base: float = T.get(b.key(ef.pos), 0.0)
		var chained: bool = ef.get("depth", 0) > 0 or base > 0.0
		if chained:
			base += CHAIN_BEAT
		var fuse: float = FUSE[ef.kind] * (CHAIN_FUSE if chained else 1.0)
		var o: Vector2i = ef.pos
		var order: Array = ef.cells.duplicate()
		if ef.kind == Board.CRAYON:
			order.sort_custom( func(a, c): return _dist(a, o) < _dist(c, o))
		ef.base = base
		ef.fuse = fuse
		ef.fire = base + fuse
		ef.times = {}
		for idx in order.size():
			var q: Vector2i = order[idx]
			var d: = 60.0
			match ef.kind:
				Board.ERASER_H:
					d = fuse + absi(q.x - o.x) * 32.0
				Board.ERASER_V:
					d = fuse + absi(q.y - o.y) * 32.0
				Board.PUSHPIN:
					d = fuse + _dist(q, o) * 45.0
				Board.CRAYON:
					d = fuse + (order.size() if q == o else idx) * 38.0
					if q == o:
						ef.fire = base + d
				Board.PAPER_PLANE:
					d = fuse + 600.0 if q == ef.target else fuse
			var kk: = b.key(q)
			ef.times[kk] = d
			if not T.has(kk) or base + d < T[kk]:
				T[kk] = base + d
	if not from.is_empty():
		for c in res.cleared + res.hits:
			var kk: = b.key(c.pos)
			if not T.has(kk):
				T[kk] = 60.0 + _dist(c.pos, from.at) * 34.0
	return T


func _dist(a: Vector2i, c: Vector2i) -> int:
	return absi(a.x - c.x) + absi(a.y - c.y)


func _show_step(res: Dictionary, combo: int, points: int) -> void :
	var b: Board = game.board
	var from: = _from
	_from = {}
	var T: = _times(res, from)
	var S: = cell_size
	_dying = {}
	for c in res.cleared:
		var v: = _view(c.tile)
		if v:
			_dying[c.tile.id] = v

	var zoned: = {}
	for ef in res.effects:
		for kk in ef.times:
			if not zoned.has(kk):
				zoned[kk] = true
				_zone(b.unkey(kk), ef.base, T.get(kk, ef.base + ef.times[kk]), ef.kind)
	if not from.is_empty():
		for c in res.cleared:
			var kk: = b.key(c.pos)
			if not zoned.has(kk):
				zoned[kk] = true
				_zone(c.pos, 0.0, T.get(kk, 60.0), &"combo")
	if fx:
		for ef in res.effects:
			var tail: float = ef.times.values().max() if not ef.times.is_empty() else 0.0
			_after(ef.base, _effect_fx.bind(ef))
			_after(ef.base + tail + 60.0, _after_fx.bind(ef))

	var push: = {}
	for ef in res.effects:
		var o: = _pos(ef.pos) + Vector2.ONE * S / 2
		for kk in ef.times:
			if not push.has(kk):
				push[kk] = {at = o, power = POWER.get(ef.kind, 1.0)}
	if not from.is_empty():
		for c in res.cleared:
			var kk: = b.key(c.pos)
			if not push.has(kk):
				push[kk] = {at = _pos(from.at) + Vector2.ONE * S / 2, power = 1.5}

	var gather: = {}
	for cr in res.created:
		for kk in cr.keys:
			gather[kk] = cr.pos

	var origin: = {}
	for ef in res.effects:
		if ef.get("tile"):
			origin[ef.tile.id] = ef
	var n: int = res.cleared.size()
	var i: = 0
	var last: = 0.0
	var sum: = Vector2.ZERO
	for c in res.cleared:
		var kk: = b.key(c.pos)
		var delay: float
		if T.has(kk):
			delay = T[kk]
		else:
			delay = minf(i * 10.0, 150.0)
			i += 1
		var ef0: Dictionary = origin.get(c.tile.id, {})
		if not ef0.is_empty() and ef0.fire > delay:
			var v0: = _view(c.tile)
			if v0 and T.has(kk):
				_after(delay, _chain_kick.bind(v0, ef0.depth))
			delay = ef0.fire
		last = maxf(last, delay)
		var p: = cell_center(c.pos)
		sum += p
		var v: = _view(c.tile)
		if v == null:
			continue
		_views.erase(c.tile.id)
		if gather.has(kk):
			v.gather(_pos(gather[kk]) - _pos(c.pos), delay)
			continue
		var color: = _color(c.tile)
		if fx:
			_after(delay + 50.0, _pop_extras.bind(p, color, n))
		_pop_tile(v, c.tile, delay, push.get(kk, {}), p, color)
	if n >= 4:
		_after(60, _bump.bind(n))
	if fx and combo >= 3:
		_after(60, fx.shake.bind(2.0 + combo, 160.0))
	_hit_fx(res, T)
	for h in res.hits:
		last = maxf(last, T.get(b.key(h.pos), 60.0))
	if fx and not from.is_empty() and String(from.kind).begins_with("crayon"):
		var o: = cell_center(from.at)
		for j in mini(res.cleared.size(), 40):
			var c: Dictionary = res.cleared[j]
			fx.crayon_line(o, cell_center(c.pos), RAINBOW[j % 5], maxf(0.0, T.get(b.key(c.pos), 0.0) - 120.0))
	if fx and n > 0:
		for j in mini(3, ceili(n / 3.0)):
			_after(j * 70.0, fx.pop_sound.bind(combo - 1 + j))
		if n >= 6:
			_after(60, _sfx.bind("star", 1.0 + combo * 0.05))
		fx.combo_show(combo, get_global_transform() * Vector2(size.x / 2, size.y * 0.28))
		if res.effects.is_empty():
			_after(90, fx.word.bind("w_seuk", sum / n + Vector2( - S * 1.3, - S * 0.2), S * 1.6, -10.0))
		if points > 0:
			_after(160, fx.float_num.bind(sum / n, "+%d" % points, Color("ff5d9e") if combo > 1 else Color("ffb020"), combo > 2))
	await _wait((maxf(minf(n * 10.0, 150.0), last) + 220.0) / 1000.0)

	if fx and not res.created.is_empty():
		fx.stop(55)
		fx.shake(3, 140)
	for cr in res.created:
		var nv: = _add_view(cr.tile, cr.pos)
		nv.appear_item(180.0)
		if fx:
			_after(180, _created_fx.bind(cell_center(cr.pos)))



func _pop_tile(v: TileView, t: BoardTile, delay: float, push: Dictionary, p: Vector2, color: Color) -> void :
	if t.type < 0:
		_after(delay, v.pop_item.bind(0.0))
		return
	var to: Dictionary = fly_to.call(t) if fly_to.is_valid() else {}
	if not push.is_empty() and to.is_empty():
		v.knock(push.at, push.power, delay)
		return
	var fly: bool = fx != null and not to.is_empty() and fx.flying() < FxLayer.FLY_MAX
	v.pop(delay, fly)
	if fx:
		_after(delay + (140.0 if fly else 150.0), _pop_after.bind(t, p, color, to if fly else {}))



func _pop_after(t: BoardTile, p: Vector2, color: Color, to: Dictionary) -> void :
	var S: = cell_size
	fx.doodle_ring(p, S * 1.6, color, 300.0)
	fx.crumbs(p, 3)
	if not to.is_empty():
		fx.fly_tile(art.texture_for(t), p + Vector2(0, - S * 0.16), to.at, color, to.get("hit", Callable()))
	else:
		fx.kp("d_star", p + Vector2(0, - S * 0.2), S * 0.42, color, [{s = 0.4, a = 1.0}, {y = - S * 0.9, s = 1.0, r = 40.0, a = 0.0}], 520.0, "ease-out")



func _chain_kick(v: TileView, depth: int) -> void :
	if not is_instance_valid(v):
		return
	v.kick(KICK_MS)
	_sfx("item_make", minf(2.0, 1.0 + 0.09 * depth))



func _chain_pitch(ef: Dictionary) -> float:
	return minf(1.6, 1.0 + 0.07 * ef.get("depth", 0))



func _pop_extras(p: Vector2, color: Color, n: int) -> void :
	if n < 16 or randf() < 0.5:
		fx.doodle_ring(p, cell_size * 1.4, color, 300.0)
	fx.scribbles(p, color, 3 if n > 15 else 5)
	fx.shards(p, [color, Color.WHITE], 2 if n > 12 else 4, 9.0, true)



func _bump(n: int) -> void :
	Juice.play(self, position, [{s = 1.0}, {s = 1.0 + minf(0.03, n * 0.002)}, {s = 1.0}], 160.0, "ease-out")



func _created_fx(p: Vector2) -> void :
	fx.doodle_ring(p, cell_size * 1.8, Color("ffe680"), 320.0)
	fx.scribbles(p, Color("ffe680"), 10)
	fx.kp("d_stars", p, cell_size * 1.6, Color.WHITE, [{s = 0.2, a = 1.0}, {t = 0.5, s = 1.0, r = 45.0, a = 1.0}, {s = 1.1, r = 90.0, a = 0.0}], 520.0, "ease-out")
	_sfx("item_make", 1.1)



func _zone(q: Vector2i, on: float, pop: float, kind: StringName) -> void :
	var b: Board = game.board
	if not b.inside(q) or b.hole(q):
		return
	var z: Panel = null
	for c in _zones:
		if not c.visible:
			z = c
			break
	if z == null:
		if _zones.size() >= 64:
			return
		z = ZONE_SCENE.instantiate()
		_zone_layer.add_child(z)
		_zones.append(z)
	z.size = Vector2.ONE * cell_size
	z.pivot_offset = z.size / 2
	z.self_modulate = ZONE_TINT.get(kind, Color.WHITE)
	z.show()
	var wait: = maxf(60.0, pop - on)
	var dur: = wait + 260.0
	var f: = func(x: float) -> float: return minf(0.98, x / dur)
	Juice.play(z, _pos(q), [
		{a = 0.0, s = 0.6}, 
		{t = f.call(minf(70.0, wait * 0.5)), a = 0.85, s = 1.0}, 
		{t = f.call(wait * 0.75), a = 0.55, s = 0.94}, 
		{t = f.call(wait), a = 1.0, s = 1.08}, 
		{a = 0.0, s = 1.2}, 
	], dur, "ease-out", on, z.hide)




func _effect_fx(ef: Dictionary) -> void :
	var S: = cell_size
	var o: = cell_center(ef.pos)
	var v: TileView = _dying.get(ef.tile.id) if ef.get("tile") else null
	var fuse: float = ef.get("fuse", FUSE[ef.kind])
	var pitch: = _chain_pitch(ef)
	match ef.kind:
		Board.ERASER_H, Board.ERASER_V:
			if v:
				v.wiggle(fuse)
			_after(fuse, _eraser_go.bind(ef, o))
		Board.PUSHPIN:
			_sfx("pin", 0.6 * pitch)
			if v:
				v.inflate(fuse)
			for j in 4:
				fx.kp("d_spark", o + Vector2(S * 0.2, - S * 0.45), S * 0.7, Color("ffcf3f"), [{s = 0.3, r = 20.0, a = 1.0}, {s = 1.0, r = 20.0, a = 0.0}], 120.0, "ease", j * 70.0 * fuse / FUSE[ef.kind])
			_after(fuse, _pushpin_boom.bind(o, ef.get("depth", 0)))
		Board.CRAYON:
			_sfx("crayon", pitch)
			if v:
				v.spin_up(fuse)
			fx.kp("d_ring", o, S * 2.4, Color("ffb3d1"), [{s = 1.2, a = 0.0}, {s = 0.4, r = -240.0, a = 1.0}], fuse, "ease-in")
			var j: = 0
			var b: Board = game.board
			for kk in ef.times:
				var q: = b.unkey(kk)
				if q == ef.pos:
					continue
				fx.crayon_line(o, cell_center(q), RAINBOW[j % 5], maxf(0.0, ef.times[kk] - 150.0))
				j += 1
			_after(fuse, _crayon_flash.bind(ef.get("depth", 0), o))
		Board.PAPER_PLANE:
			if v:
				v.lift(fuse)
			_after(fuse, _plane_go.bind(ef, o))


func _crayon_flash(depth: int, o: Vector2) -> void :
	fx.word("w_pung", o + Vector2(0, - cell_size * 0.6), cell_size * 1.8, 6.0)
	fx.flash(Color.WHITE, 0.4)
	fx.shake(6 + mini(depth, 4), 300)



func _eraser_go(ef: Dictionary, o: Vector2) -> void :
	var S: = cell_size
	var b: Board = game.board
	var horiz: bool = ef.kind == Board.ERASER_H
	_sfx("eraser", 1.1 * _chain_pitch(ef))
	fx.doodle_ring(o, S * 2.2, Color("c4bec8"), 260.0)
	fx.crumbs(o, 5)
	fx.word("w_seuk", o + Vector2(S * 1.5, - S * 0.75), S * 1.9, -10.0 if horiz else 8.0)
	fx.stop(40)
	var cells: = b.cols if horiz else b.rows
	var start: int = ef.pos.x if horiz else ef.pos.y
	for dir in [-1, 1]:
		var steps: float = (cells - start - 0.5) if dir > 0 else (start + 1.5)
		var dist: float = steps * S * dir
		var to: = o + (Vector2(dist, 0) if horiz else Vector2(0, dist))
		var rot: = (0.0 if dir > 0 else 180.0) if horiz else (90.0 if dir > 0 else -90.0)
		fx.kp(art.eraser_h, o, S * 0.95, Color.WHITE, [{s = 0.7, r = rot}, {x = to.x - o.x, y = to.y - o.y, s = 1.1, r = rot}], steps * 32.0, "linear")
		fx.smudge(o, to, steps * 32.0 / 0.55)
		for kk in range(1, int(steps) + 1):
			var q: = o + (Vector2(dir * kk * S, 0) if horiz else Vector2(0, dir * kk * S))
			fx.crumbs(q, 2, kk * 32.0)
	fx.shake(4 + mini(ef.get("depth", 0), 4), 200)



func _pushpin_boom(o: Vector2, depth: = 0) -> void :
	var S: = cell_size
	_sfx("pin", 0.9 * minf(1.6, 1.0 + 0.07 * depth))
	fx.boom_doodle(o, S * 3.6, 1.0, 520.0)
	fx.ink_splat(o, S * 2.2, 900.0, 220.0)
	fx.doodle_ring(o, S * 5.2, Color("4a4262"), 420.0)
	fx.paper_bits(o, 10, 1.6)
	fx.crumbs(o, 4)
	fx.word("w_kwang", o + Vector2(S * 0.3, - S * 1.3), S * 2.2, -8.0, 760.0)
	fx.zoom(o, 1.06, 300.0)
	fx.stop(70)
	fx.shake(7 + mini(depth, 4), 320)
	fx.flash(Color("fff6a8"), 0.35)



func _plane_go(ef: Dictionary, o: Vector2) -> void :
	var S: = cell_size
	var b: Board = game.board
	for d in Board.NEAR4:
		var q: Vector2i = ef.pos + d
		if b.inside(q):
			fx.scribbles(o + Vector2(d) * S, Color("bff3ff"), 3)
	if ef.get("target", NO_CELL) == NO_CELL:
		return
	var to: = cell_center(ef.target)
	await fx.plane_fly(art.paper_plane, o, to, 600.0)
	fx.boom_doodle(to, S * 1.8, 0.7, 300.0)
	fx.doodle_ring(to, S * 2.4, Color("7cc4ec"), 320.0)
	fx.scribbles(to, Color("bff3ff"), 8)
	_sfx("plane", 1.1 * _chain_pitch(ef))
	fx.shake(4 + mini(ef.get("depth", 0), 4), 160)



func _after_fx(ef: Dictionary) -> void :
	var S: = cell_size
	var b: Board = game.board
	var o: = cell_center(ef.pos)
	match ef.kind:
		Board.PUSHPIN:
			fx.paper_bits(o - Vector2(0, S * 0.3), 4, 0.6)
		Board.ERASER_H, Board.ERASER_V:
			var horiz: bool = ef.kind == Board.ERASER_H
			for j in range(0, b.cols if horiz else b.rows, 2):
				fx.crumbs(cell_center(Vector2i(j, ef.pos.y) if horiz else Vector2i(ef.pos.x, j)), 1)
		Board.CRAYON:
			var r: = get_global_rect()
			for j in 14:
				fx.scribbles(r.position + Vector2(randf() * r.size.x, randf() * r.size.y), RAINBOW[j % 5], 1)
		Board.PAPER_PLANE:
			if ef.get("target", NO_CELL) != NO_CELL:
				fx.paper_bits(cell_center(ef.target), 3, 0.6)



func _show_combo(c: Dictionary) -> void :
	_from = c
	if fx == null:
		return
	var S: = cell_size
	var p: = cell_center(c.at)
	var ta: TileView = _view(_last_swap.get("ta"))
	var tb: TileView = _view(_last_swap.get("tb"))
	_sfx("item_make", 0.8)
	if tb:
		Juice.play(tb, Vector2.ZERO, [{x = tb.position.x, y = tb.position.y}, {x = _pos(c.at).x, y = _pos(c.at).y}], 220.0, [0.5, 0.0, 0.4, 1.0])
	for v in [ta, tb]:
		if v:
			v.merge_spin()
	fx.kp("d_ring", p, S * 2.2, Color("ffe680"), [{s = 1.3, a = 0.0}, {s = 0.5, r = -300.0, a = 1.0}], 380.0, "ease-in")
	await _wait(0.38)
	fx.boom_doodle(p, S * 3.4, 1.0, 320.0)
	var big: bool = String(c.kind).begins_with("crayon") or c.kind == "pushpin+pushpin"
	fx.zoom(p, 1.12 if big else 1.07)
	_sfx("crayon" if String(c.kind).begins_with("crayon") else "item_make", 1.0)
	fx.flash(Color("fff6a8"), 0.5)
	fx.shake(8, 350)
	fx.doodle_ring(p, S * 7, Color("ffe680"), 500.0)
	if art.combo:
		fx.kp(art.combo, p, S * 2.6, Color.WHITE, [
			{s = 0.2, r = -25.0, a = 0.0}, {t = 0.25, s = 1.25, r = 6.0, a = 1.0}, {t = 0.4, s = 1.0, a = 1.0}, 
			{t = 0.75, s = 1.04, a = 1.0}, {s = 1.5, a = 0.0}, 
		], 900.0, "ease-out")
	await _wait(0.25)
	var planes: Array = c.get("planes", [])
	if planes.is_empty():
		return
	for tg in planes:
		fx.plane_fly(art.paper_plane, p, cell_center(tg), 620.0)
	await _wait(0.62)
	for tg in planes:
		if c.get("carry", &"") != &"":
			_effect_fx({kind = c.carry, pos = tg, times = {}, target = NO_CELL})
		else:
			fx.scribbles(cell_center(tg), Color("bff3ff"), 8)




func _hit_fx(res: Dictionary, T: Dictionary) -> void :
	var b: Board = game.board
	for u in res.unlocked:
		_after(T.get(b.key(u.pos), 60.0), _tape_off.bind(u))
	for h in res.hits:
		_after(T.get(b.key(h.pos), 60.0), _hit_one.bind(h))
	for j in res.highlight.size():
		_after(80.0 + minf(j * 30.0, 300.0), _paint.bind(res.highlight[j].pos))
	if not res.highlight.is_empty():
		_after(80, _sfx.bind("highlighter", 1.0))



func _tape_off(u: Dictionary) -> void :
	var v: = _view(u.tile)
	if v:
		v.hide_tape()
		v.squish()
	_sfx("tape", 1.0)
	if fx == null:
		return
	var S: = cell_size
	var p: = cell_center(u.pos)
	fx.fly_off(art.tape, p, S * 0.9)
	fx.toss_piece(art.tape, p, S * 0.8, -1.0 if randf() < 0.5 else 1.0, 60.0)
	fx.shards(p, [Color("c9d6e6"), Color("eef4fa"), Color("9fb3c8")], 8, 9.0)
	fx.doodle_ring(p, S * 1.6, Color("b9c8d8"))
	_fly_goal("tape", art.tape, p)


func _hit_one(h: Dictionary) -> void :
	var v: = _view(h.tile)
	var t: BoardTile = h.tile
	var S: = cell_size
	var p: = cell_center(h.pos)
	var kind: = String(t.block)
	match t.block:
		Board.CRUMBS:
			_sfx("crumbs")
			if fx:
				var tex: Texture2D = art.crumbs[0]
				if h.gone:
					if v:
						v.hide_art()
					fx.pull_out(art.texture_for(t) if t.hp > 0 else tex, p, S)
				else:
					fx.toss_piece(tex, p - Vector2(0, S * 0.1), S * 0.4, -1.0)
					fx.toss_piece(tex, p - Vector2(0, S * 0.1), S * 0.36, 1.0, 50.0)
					if v:
						v.jolt()
				fx.toss_piece(tex, p + Vector2(0, S * 0.25), S * 0.3, -1.0 if randf() < 0.5 else 1.0, 220.0)
				fx.shards(p + Vector2(0, S * 0.2), [Color("c9c4bd"), Color("f0a8b0"), Color("9c968e"), Color.WHITE], 8, 7.0, true)
				fx.doodle_ring(p, S * 1.6, Color("8f8a94"), 300.0)
		Board.INK:
			_sfx("ink")
			if fx:
				if h.gone:
					if v:
						v.hide_art()
					fx.kp(art.ink, p, S * 0.86, Color.WHITE, [{a = 1.0}, {t = 0.7, s = 1.25, a = 1.0}, {s = 1.35, a = 0.0}], 140.0, "ease-in")
				fx.kp(art.ink, p, S * 1.1, Color.WHITE, [{s = 0.5, a = 1.0}, {s = 1.3, r = 20.0, a = 0.0}], 420.0, "ease-out", 120.0)
				fx.doodle_ring(p, S * 2, Color("5f70b8"), 320.0)
				fx.shards(p, [Color("2c3a7a"), Color("5f70b8"), Color("1a2350")], 10, 8.0, true)
		Board.STICKY:
			_sfx("postit", 1.0 if h.gone else 1.2)
			if fx and h.gone:
				if v:
					v.hide_art()
				var dir: = -1.0 if randf() < 0.5 else 1.0
				var k: = S / 56.0
				fx.kp(art.sticky[0], p, S * 0.95, Color.WHITE, [
					{s = 0.9, a = 1.0}, {t = 0.3, y = - S * 0.25, s = 1.22, r = dir * -6.0}, 
					{t = 0.65, x = dir * 30 * k, y = - S * 1.1, s = 1.0, r = dir * 40.0, a = 1.0}, {x = dir * 60 * k, y = - S * 0.6, s = 0.7, r = dir * 110.0, a = 0.0}, 
				], 620.0, "ease-out")
				fx.toss_piece(art.sticky[0], p + Vector2( - S * 0.2, - S * 0.2), S * 0.5, -1.0, 90.0)
				fx.toss_piece(art.sticky[0], p + Vector2(S * 0.2, - S * 0.2), S * 0.5, 1.0, 120.0)
				fx.shards(p, [Color("ffe14d"), Color("fff3a8"), Color("e8c43a"), Color.WHITE], 8, 11.0)
				fx.doodle_ring(p, S * 1.8, Color("ffe680"), 300.0)
				fx.shake(4, 160)
			elif fx:
				fx.kp(art.sticky[mini(t.hp, art.sticky.size() - 1)], p, S * 0.86, Color.WHITE, [
					{a = 1.0}, {t = 0.25, s = 1.05, r = -8.0}, {t = 0.5, s = 1.05, r = 8.0}, 
					{t = 0.7, y = - S * 0.1, s = 1.1, a = 1.0}, {y = - S * 0.2, s = 1.15, a = 0.0}, 
				], 320.0, "ease-in-out")
				fx.fly_off(art.sticky[0], p - Vector2(0, S * 0.25), S * 0.6)
				fx.toss_piece(art.sticky[0], p, S * 0.5, -1.0, 200.0)
				fx.toss_piece(art.sticky[0], p, S * 0.5, 1.0, 230.0)
				fx.shards(p, [Color("ff9fc0"), Color("ffe14d"), Color.WHITE], 10, 10.0)
	if fx and (h.gone or t.block != Board.STICKY):
		_fly_goal(kind, art.texture_for(t) if t.hp > 0 else _first_layer(t), p)
	if v == null:
		return
	if h.gone:
		_views.erase(t.id)
		get_tree().create_timer(0.75).timeout.connect(v.queue_free)
	else:
		v.show_tile(t, art)
		v.squish()


func _first_layer(t: BoardTile) -> Texture2D:
	if t.block == Board.STICKY:
		return art.sticky[0]
	if t.block == Board.CRUMBS:
		return art.crumbs[0]
	return art.ink



func _paint(q: Vector2i) -> void :
	var c: CellView = _cells.get(q)
	if c == null:
		return
	c.set_painted(true)
	c.splash()
	if fx:
		fx.shards(cell_center(q), [Color("d6ff3d"), Color("eaff8a"), Color("b5e01f")], 4, 8.0, true)



func _fly_goal(kind: String, tex: Texture2D, p: Vector2) -> void :
	if not goal_at.is_valid():
		return
	var to: Vector2 = goal_at.call(kind)
	if to == Vector2.INF:
		return
	fx.fly_tile(tex, p, to, Color("ffd84d"), goal_bump.bind(kind) if goal_bump.is_valid() else Callable())



func _show_collect(got: Array) -> void :
	for g in got:
		var v: = _view(g.tile)
		var p: = cell_center(g.pos)
		if v:
			_views.erase(g.tile.id)
			v.queue_free()
		if fx:
			fx.scribbles(p, Color("ffd84d"), 10)
			_fly_goal("deliver", art.deliver, p)
	_sfx("star", 1.2)



func _show_convert(e: Dictionary) -> void :
	var v: = _view(e.tile)
	if v == null:
		return
	var land: = func() -> void :
		if not is_instance_valid(v):
			return
		v.show_tile(e.tile, art)
		v.squish()
		if fx:
			var p: = cell_center(e.pos)
			fx.scribbles(p, Color.WHITE, 6)
			if _bonus:
				fx.float_num(p, "+150", Color("e07b39"))
			fx.pop_sound(mini(_bonus_i, 11))
			_bonus_i += 1
	if fx and _bonus:
		var from: Vector2 = bonus_from.call() if bonus_from.is_valid() else get_global_rect().get_center() - Vector2(0, size.y * 0.6)
		if fx.fly_tile(art.eraser_h, from, cell_center(e.pos), Color("bfe9ff"), land):
			_land_wait = true
			return
	land.call()



func _show_replace(e: Dictionary) -> void :
	var old: = _view(e.old)
	if old:
		_views.erase(e.old.id)
		old.pop(0.0)
	var nv: = _add_view(e.tile, e.pos)
	if e.tile.block == Board.INK:
		nv.ink_in()
		_sfx("ink", 0.7)
		if fx:
			fx.scribbles(cell_center(e.pos), Color("5f70b8"), 6)
	else:
		nv.squish()
		if fx:
			fx.scribbles(cell_center(e.pos), Color("e8c43a"), 6)
		_sfx("postit", 0.9)
	await _wait(0.38)
