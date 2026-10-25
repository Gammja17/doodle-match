class_name BoardGame
extends RefCounted

















const BONUS_BATCH: = 3

const BLOCK_CHARS: = {"c": [Board.CRUMBS, 1], "C": [Board.CRUMBS, 2], "p": [Board.STICKY, 1], "P": [Board.STICKY, 2], "k": [Board.INK, 1]}

var board: = Board.new()
var stage: Dictionary = {}
var moves: = 0
var score: = 0
var delivered: = 0
var tile_counts: = {}
var over: = false
var won: = false

var _delivers_spawned: = 0
var _ink_hit: = false
var _events: Array = []


func start(st: Dictionary) -> void :
	stage = st
	moves = st.moves
	score = 0
	delivered = 0
	tile_counts = {}
	over = false
	won = false
	_ink_hit = false
	var map: Array = st.map
	board.set_size(map.size(), map[0].length())
	board.ntypes = st.tiles
	var uses_hl: bool = st.goals.any( func(g): return g.k == "highlighter")
	var spec: = {blocks = [], delivers = [], tapes = [], fixed = st.get("fixed_board", [])}
	board.mask = []
	board.highlight = []
	var kinds: Array = st.get("deliver", {}).get("kinds", [])
	for y in map.size():
		var mrow: = []
		var hrow: = []
		for x in map[y].length():
			var ch: String = map[y][x]
			var p: = Vector2i(x, y)
			mrow.append(ch != "#")
			hrow.append(ch == "h")
			if BLOCK_CHARS.has(ch):
				spec.blocks.append([p, BLOCK_CHARS[ch][0], BLOCK_CHARS[ch][1]])
			elif ch == "d":
				spec.delivers.append([p, kinds[spec.delivers.size() % kinds.size()]])
			elif ch == "t":
				spec.tapes.append(p)
		board.mask.append(mrow)
		if uses_hl:
			board.highlight.append(hrow)
	_delivers_spawned = spec.delivers.size()
	board.spawn_deliver = _spawn_deliver if st.has("deliver") else Callable()
	board.create(spec)



func _spawn_deliver() -> String:
	var d: Dictionary = stage.deliver
	var on: = 0
	for p in board.cells():
		if board.at(p).type == BoardTile.DELIVER:
			on += 1
	if _delivers_spawned >= d.total or on >= d.max_on_board:
		return ""
	if on > 0 and board.rng.randf() > 0.15:
		return ""
	_delivers_spawned += 1
	return d.kinds[(_delivers_spawned - 1) % d.kinds.size()]


func count(k: String) -> int:
	var n: = 0
	if k == "highlighter":
		for y in board.highlight.size():
			for x in board.cols:
				if not board.highlight[y][x] and not board.hole(Vector2i(x, y)):
					n += 1
		return n
	for p in board.cells():
		var t: = board.at(p)
		if (k == "tape" and t.taped) or t.block == k:
			n += 1
	return n


func remain(g: Dictionary) -> int:
	match g.k:
		"deliver":
			return maxi(0, int(stage.deliver.total) - delivered)
		"tile":
			return maxi(0, int(g.n) - tile_counts.get(int(g.tile), 0))
		"score":
			return maxi(0, int(g.n) - score)
	return count(g.k)


func is_done() -> bool:
	return stage.goals.all( func(g): return remain(g) == 0)


func stars() -> int:
	var s: Array = stage.stars
	return 3 if score >= s[2] else 2 if score >= s[1] else 1



func try_swap(a: Vector2i, b: Vector2i) -> Array:
	_events = []
	if over or absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return _events
	var ta: = board.at(a)
	var tb: = board.at(b)
	if not Board.movable(ta) or not Board.movable(tb):
		return _events
	board.swap(a, b)
	_events.append({kind = "swap", a = a, b = b, ta = ta, tb = tb})
	var combo: = board.swap_combo(a, b)

	var items: = []
	if combo.is_empty():
		if ta.special != &"":
			items.append(b)
		if tb.special != &"":
			items.append(a)
	if combo.is_empty() and items.is_empty() and board.find_runs().is_empty():
		board.swap(a, b)
		_events.append({kind = "swap_back", a = a, b = b, ta = ta, tb = tb})
		return _events
	if not combo.is_empty():
		_events.append({kind = "combo", combo = combo})
	_cascade([a, b], combo.cells if not combo.is_empty() else items)
	_end_turn()
	return _events



func activate(p: Vector2i) -> Array:
	_events = []
	var t: = board.at(p)
	if over or t == null or t.special == &"":
		return _events
	_events.append({kind = "activate", pos = p, tile = t})
	_cascade([], [p])
	_end_turn()
	return _events


func _cascade(swapped: Array, forced: Array, depth: = 0) -> void :
	var combo: = 0
	while true:
		var res: = board.resolve(swapped if combo == 0 else [], forced if combo == 0 else [])
		if res.is_empty():
			break
		combo += 1
		_on_step(res, combo)
		_events.append({kind = "fall", paths = board.gravity()})
		_collect()
	if board.has_move():
		return
	board.shuffle()
	var tiles: = []
	for q in board.cells():
		tiles.append({pos = q, tile = board.at(q)})
	_events.append({kind = "shuffle", tiles = tiles})

	if not board.find_runs().is_empty() and depth < 4:
		_cascade([], [], depth + 1)
	elif not board.has_move():

		var spots: = board.cells().filter( func(q):
			var t: = board.at(q)
			return t.type >= 0 and t.special == &"" and Board.movable(t))
		if not spots.is_empty():
			var q: Vector2i = spots[board.rng.randi_range(0, spots.size() - 1)]
			var t: = board.at(q)
			t.special = Board.CRAYON
			t.type = BoardTile.ITEM
			_events.append({kind = "gift", pos = q, tile = t})


func _on_step(res: Dictionary, combo: int) -> void :
	var pts: int = res.cleared.size() * 20 * combo + res.created.size() * 100 + res.hits.size() * 50\
	+ res.unlocked.size() * 60 + res.highlight.size() * 40
	for c in res.cleared:
		var ty: int = c.tile.type
		if ty >= 0:
			tile_counts[ty] = tile_counts.get(ty, 0) + 1
	if res.hits.any( func(h): return h.tile.block == Board.INK):
		_ink_hit = true
	score += pts
	_events.append({kind = "step", res = res, combo = combo, points = pts})



func _collect() -> void :
	while true:
		var got: = board.collect_delivers()
		if got.is_empty():
			return
		delivered += got.size()
		score += got.size() * 500
		_events.append({kind = "collect", got = got})
		_events.append({kind = "fall", paths = board.gravity()})


func _end_turn() -> void :
	moves -= 1

	if not _ink_hit and count("ink") > 0 and not is_done():
		var s: = board.spread_ink()
		if not s.is_empty():
			_events.append({kind = "ink_spread", pos = s.pos, old = s.old, tile = s.tile})
			_cascade([], [])
	_ink_hit = false
	if is_done():
		won = true
		_bonus()
		over = true
		_events.append({kind = "win", stars = stars()})
	elif moves <= 0:
		over = true
		_events.append({kind = "fail"})




func _bonus() -> void :
	if moves <= 0:
		return
	_events.append({kind = "bonus_start"})
	var spots: = board.cells().filter( func(q):
		var t: = board.at(q)
		return t.type >= 0 and t.special == &"" and not t.taped)
	var picked: = []
	for i in mini(moves, 10):
		if spots.is_empty():
			break
		picked.append(spots.pop_at(board.rng.randi_range(0, spots.size() - 1)))
	var items: = []
	for q in picked:
		var t: = board.at(q)
		var x: = board.rng.randf()
		if x < 0.5:
			t.special = Board.ERASER_H if board.rng.randf() < 0.5 else Board.ERASER_V
		else:
			t.special = Board.PUSHPIN if x < 0.8 else Board.PAPER_PLANE
		t.type = BoardTile.ITEM
		score += 150
		moves -= 1
		items.append(t)
		_events.append({kind = "convert", pos = q, tile = t})
	while not items.is_empty():
		var batch: = []
		for t in items.slice(0, BONUS_BATCH):
			if t.special == &"":
				continue

			for q in board.cells():
				if board.at(q) == t:
					batch.append(q)
		items = items.slice(BONUS_BATCH)
		if not batch.is_empty():
			_cascade([], batch)
	var rest: = moves
	if rest > 0:
		score += rest * 500
		moves = 0
	_events.append({kind = "bonus_end", rest = rest})
