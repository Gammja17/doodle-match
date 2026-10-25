class_name Board
extends RefCounted



const ERASER_H: = &"eraser_h"
const ERASER_V: = &"eraser_v"
const PUSHPIN: = &"pushpin"
const CRAYON: = &"crayon"
const PAPER_PLANE: = &"paper_plane"

const STICKY: = &"sticky"
const INK: = &"ink"
const CRUMBS: = &"crumbs"

const NO_CELL: = Vector2i(-1, -1)
const NEAR4: = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

var rows: = 7
var cols: = 7
var ntypes: = 7
var grid: Array = []
var mask: Array = []
var highlight: Array = []
var spawn_deliver: Callable
var rng: = RandomNumberGenerator.new()

var _next_id: = 1
var _protect: = {}
var _deferred: Array = []


func set_size(r: int, c: int) -> void :
	rows = r
	cols = c


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows


func hole(p: Vector2i) -> bool:
	return not mask.is_empty() and not mask[p.y][p.x]


func at(p: Vector2i) -> BoardTile:
	return grid[p.y][p.x] if inside(p) else null


func put(p: Vector2i, t: BoardTile) -> void :
	grid[p.y][p.x] = t


func key(p: Vector2i) -> int:
	return p.y * cols + p.x


@warning_ignore("integer_division")
func unkey(k: int) -> Vector2i:
	return Vector2i(k % cols, k / cols)


static func movable(t: BoardTile) -> bool:
	return t != null and t.block == &"" and not t.taped


func painted(p: Vector2i) -> bool:
	return not highlight.is_empty() and highlight[p.y][p.x]


func new_tile(type: int, special: StringName = &"") -> BoardTile:
	_next_id += 1
	return BoardTile.new(_next_id, type, special)


func new_deliver(kind: String) -> BoardTile:
	var t: = new_tile(BoardTile.DELIVER)
	t.deliver_kind = kind
	return t


func new_block(kind: StringName, hp: = 1) -> BoardTile:
	var t: = new_tile(BoardTile.BLOCK)
	t.block = kind
	t.hp = hp
	return t


func rand_type() -> int:
	return rng.randi_range(0, ntypes - 1)



func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			if grid[y][x] != null:
				out.append(Vector2i(x, y))
	return out



const FIXED_ITEMS: = {"E": ERASER_H, "V": ERASER_V, "P": PUSHPIN, "A": PAPER_PLANE, "C": CRAYON}





func create(spec: Dictionary = {}) -> void :
	while true:
		grid = []
		for y in rows:
			var row: = []
			row.resize(cols)
			grid.append(row)
		for b in spec.get("blocks", []):
			put(b[0], new_block(b[1], b[2]))
		for d in spec.get("delivers", []):
			put(d[0], new_deliver(d[1]))
		var fixed: Array = spec.get("fixed", [])
		for y in mini(fixed.size(), rows):
			var row: String = fixed[y]
			for x in mini(row.length(), cols):
				var p: = Vector2i(x, y)
				if at(p) != null or hole(p):
					continue
				if row[x].is_valid_int():
					put(p, new_tile(int(row[x])))
				elif FIXED_ITEMS.has(row[x]):
					put(p, new_tile((x + y) % ntypes, FIXED_ITEMS[row[x]]))
		for y in rows:
			for x in cols:
				var p: = Vector2i(x, y)
				if at(p) != null or hole(p):
					continue
				var t: = rand_type()
				var tries: = 1
				while makes_match(p, t) and tries < 40:
					t = rand_type()
					tries += 1
				put(p, new_tile(t))
		for p in spec.get("tapes", []):
			if at(p) != null and at(p).type >= 0:
				at(p).taped = true
		if has_move() and find_runs().is_empty():
			return



func makes_match(p: Vector2i, t: int) -> bool:
	var ty: = func(dx: int, dy: int) -> int:
		var q: BoardTile = at(p + Vector2i(dx, dy))
		return q.type if q != null else -999
	return (ty.call(-1, 0) == t and ty.call(-2, 0) == t)\
	or (ty.call(0, -1) == t and ty.call(0, -2) == t)\
	or (ty.call(-1, 0) == t and ty.call(0, -1) == t and ty.call(-1, -1) == t)


func _type_at(p: Vector2i) -> int:
	var t: = at(p)
	return t.type if t != null else -999



func find_runs() -> Array:
	var runs: = []
	for a in rows:
		_scan_line(runs, true, a)
	for a in cols:
		_scan_line(runs, false, a)
	for y in rows - 1:
		for x in cols - 1:
			var t: = _type_at(Vector2i(x, y))
			if t >= 0 and _type_at(Vector2i(x + 1, y)) == t and _type_at(Vector2i(x, y + 1)) == t and _type_at(Vector2i(x + 1, y + 1)) == t:
				runs.append({dir = &"sq", type = t, cells = [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]})
	return runs


func _scan_line(runs: Array, horizontal: bool, a: int) -> void :
	var inner: = cols if horizontal else rows
	var cell: = func(i: int) -> Vector2i: return Vector2i(i, a) if horizontal else Vector2i(a, i)
	var s: = 0
	while s < inner:
		var t: = _type_at(cell.call(s))
		var e: = s + 1
		while t >= 0 and e < inner and _type_at(cell.call(e)) == t:
			e += 1
		if t >= 0 and e - s >= 3:
			var out: = []
			for i in range(s, e):
				out.append(cell.call(i))
			runs.append({dir = &"h" if horizontal else &"v", type = t, cells = out})
		s = e



func group_runs(runs: Array) -> Array:
	var parent: = range(runs.size())
	var owner: = {}
	for i in runs.size():
		for p in runs[i].cells:
			var k: = key(p)
			if owner.has(k):
				parent[_find(parent, i)] = _find(parent, owner[k])
			else:
				owner[k] = i
	var groups: = {}
	for i in runs.size():
		var root: = _find(parent, i)
		if not groups.has(root):
			groups[root] = {type = runs[i].type, runs = [], keys = {}}
		var grp: Dictionary = groups[root]
		grp.runs.append(runs[i])
		for p in runs[i].cells:
			grp.keys[key(p)] = true
	return groups.values()


func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i




@warning_ignore("integer_division")
func special_for(grp: Dictionary, swapped: Array) -> Dictionary:
	var lines: Array = grp.runs.filter( func(r): return r.dir != &"sq")
	var max_len: = 0
	var has_h: = false
	var has_v: = false
	for r in lines:
		max_len = maxi(max_len, r.cells.size())
		if r.dir == &"h":
			has_h = true
		else:
			has_v = true
	var kind: = &""
	if max_len >= 5:
		kind = CRAYON
	elif has_h and has_v:
		kind = PUSHPIN
	elif max_len == 4:
		for r in lines:
			if r.cells.size() == 4:
				kind = ERASER_V if r.dir == &"h" else ERASER_H
				break
	elif grp.runs.any( func(r): return r.dir == &"sq"):
		kind = PAPER_PLANE
	if kind == &"":
		return {}
	var pos: = NO_CELL
	for p in swapped:
		if grp.keys.has(key(p)):
			pos = p
			break
	if pos == NO_CELL and kind == PUSHPIN:
		var hk: = {}
		for r in lines:
			if r.dir == &"h":
				for p in r.cells:
					hk[key(p)] = true
		for r in lines:
			if r.dir == &"v":
				for p in r.cells:
					if pos == NO_CELL and hk.has(key(p)):
						pos = p
	if pos == NO_CELL:
		var pool: Array = lines if not lines.is_empty() else grp.runs
		var longest: Dictionary = pool[0]
		for r in pool:
			if r.cells.size() > longest.cells.size():
				longest = r
		pos = longest.cells[longest.cells.size() / 2]
	var locked: Dictionary = grp.get("locked", {})
	if locked.has(key(pos)):
		pos = NO_CELL
		for k in grp.keys:
			if not locked.has(k):
				pos = unkey(k)
				break
		if pos == NO_CELL:
			return {}
	return {pos = pos, kind = kind}



func effect_cells(t: BoardTile, p: Vector2i, avoid: = {}) -> Array:
	var out: = []
	if t.special == ERASER_H:
		for x in cols:
			out.append(Vector2i(x, p.y))
	elif t.special == ERASER_V:
		for y in rows:
			out.append(Vector2i(p.x, y))
	elif t.special == PUSHPIN:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var q: = p + Vector2i(dx, dy)
				if absi(dx) + absi(dy) <= 2 and inside(q):
					out.append(q)
	elif t.special == CRAYON:
		var ty: = common_type()
		for q in cells():
			if at(q).type == ty:
				out.append(q)
	elif t.special == PAPER_PLANE:
		out.append(p)
		for d in NEAR4:
			if inside(p + d):
				out.append(p + d)
		var skip: = avoid.duplicate()
		for q in out:
			skip[key(q)] = true
		t.target = pick_target(skip)
		if t.target != NO_CELL:
			out.append(t.target)
	return out



func pick_target(avoid: = {}) -> Vector2i:
	var tiers: = [[], [], [], []]
	for q in cells():
		if avoid.has(key(q)):
			continue
		var t: = at(q)
		var above: = at(q + Vector2i(0, -1))
		if t.block != &"" or t.taped:
			tiers[0].append(q)
		elif not highlight.is_empty() and not highlight[q.y][q.x] and t.type != BoardTile.DELIVER:
			tiers[1].append(q)
		elif t.type >= 0 and above != null and above.type == BoardTile.DELIVER:
			tiers[2].append(q)
		elif t.type >= 0:
			tiers[3].append(q)
	for tier in tiers:
		if not tier.is_empty():
			return tier[rng.randi_range(0, tier.size() - 1)]
	return NO_CELL


func common_type() -> int:
	var n: = []
	n.resize(ntypes)
	n.fill(0)
	for q in cells():
		var ty: = at(q).type
		if ty >= 0 and ty < ntypes:
			n[ty] += 1
	return n.find(n.max())




func swap_combo(a: Vector2i, b: Vector2i) -> Dictionary:
	var ta: = at(a)
	var tb: = at(b)
	var out: = []
	if ta.special == CRAYON and tb.special == CRAYON:
		ta.special = &""
		tb.special = &""
		out.assign(cells())
		return {cells = out, kind = &"crayon+crayon", at = b}
	if ta.special == CRAYON or tb.special == CRAYON:
		var rb: = ta if ta.special == CRAYON else tb
		var other: = tb if ta.special == CRAYON else ta
		var rpos: = a if ta.special == CRAYON else b
		rb.special = &""
		out.append(rpos)

		var ty: = other.type if other.type >= 0 else common_type()
		var conv: = other.special
		for q in cells():
			var t: = at(q)
			if t.type != ty:
				continue
			if conv != &"" and t != other and not t.taped:
				if conv == ERASER_H or conv == ERASER_V:
					t.special = ERASER_H if rng.randf() < 0.5 else ERASER_V
				else:
					t.special = conv
			out.append(q)
		return {cells = out, kind = &"crayon", at = rpos, type = ty, converted = conv != &""}
	if ta.special != &"" and tb.special != &"":
		var sa: = ta.special
		var sb: = tb.special
		var names: = [String(sa), String(sb)]
		names.sort()
		var kinds: = "+".join(PackedStringArray(names))
		ta.special = &""
		tb.special = &""
		var p0: = b
		var add: = func(q: Vector2i) -> void :
			if inside(q):
				out.append(q)
		if sa == PAPER_PLANE or sb == PAPER_PLANE:

			add.call(p0)
			for d in NEAR4:
				add.call(p0 + d)
			out.append(a)
			var carry: = &"" if sa == sb else (sb if sa == PAPER_PLANE else sa)
			var avoid: = {}
			for q in out:
				avoid[key(q)] = true
			var planes: = []
			for i in (1 if carry != &"" else 3):
				var tg: = pick_target(avoid)
				if tg == NO_CELL:
					break
				avoid[key(tg)] = true
				planes.append(tg)
				if carry != &"":
					out.append_array(effect_cells(BoardTile.new(0, BoardTile.ITEM, carry), tg))
				else:
					out.append(tg)
			return {cells = out, kind = kinds, at = b, planes = planes, carry = carry}
		if sa == PUSHPIN and sb == PUSHPIN:
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					add.call(p0 + Vector2i(dx, dy))
		elif sa == PUSHPIN or sb == PUSHPIN:
			for d in range(-1, 2):
				for x in cols:
					add.call(Vector2i(x, p0.y + d))
				for y in rows:
					add.call(Vector2i(p0.x + d, y))
		else:
			for x in cols:
				add.call(Vector2i(x, p0.y))
			for y in rows:
				add.call(Vector2i(p0.x, y))
		out.append(a)
		return {cells = out, kind = kinds, at = b}
	return {}






func resolve(swapped: Array = [], forced: Array = []) -> Dictionary:
	var protect: = _protect
	var deferred: = _deferred
	_protect = {}
	_deferred = []
	if forced.is_empty() and not deferred.is_empty():
		forced = []
		for q in cells():
			if deferred.has(at(q)) and at(q).special != &"":
				forced.append(q)
	var groups: = group_runs(find_runs())
	var clear: = {}
	var matched: = {}
	var creates: = []
	var hl_keys: = {}

	var carried: = {}
	if not highlight.is_empty() and swapped.size() == 2:
		if painted(swapped[0]):
			carried[key(swapped[1])] = true
		if painted(swapped[1]):
			carried[key(swapped[0])] = true
	var inked: = func(q: Vector2i) -> bool: return painted(q) or carried.has(key(q))
	var any_inked: = func(ks: Array) -> bool:
		if highlight.is_empty():
			return false
		return ks.any( func(k): return inked.call(unkey(k)))
	for grp in groups:
		var locked: = {}
		for k in grp.keys:
			clear[k] = true
			matched[k] = true
			if at(unkey(k)).taped:
				locked[k] = true
		grp.locked = locked
		if any_inked.call(grp.keys.keys()):
			for k in grp.keys:
				hl_keys[k] = true
		var sp: = special_for(grp, swapped)
		if not sp.is_empty():
			sp.keys = grp.keys
			creates.append(sp)
	var forced_keys: = []
	for q in forced:
		if inside(q):
			forced_keys.append(key(q))
	if not creates.is_empty() and not forced_keys.is_empty()\
	and forced_keys.all( func(k): return at(unkey(k)) != null and at(unkey(k)).special != &""):
		_deferred = forced_keys.map( func(k): return at(unkey(k)))
		forced_keys = []
	for k in forced_keys:
		clear[k] = true
	if any_inked.call(forced_keys):
		for k in forced_keys:
			hl_keys[k] = true
	if clear.is_empty():
		return {}


	var effects: = []
	var fired: = {}
	var origins: = []
	var queue: = clear.keys()
	var depth_of: = {}
	var parent_of: = {}
	while not queue.is_empty():
		var k: int = queue.pop_front()
		var p: = unkey(k)
		var t: = at(p)
		if t == null or t.special == &"" or fired.has(t.id) or protect.has(t.id):
			continue
		fired[t.id] = true
		origins.append(p)
		var depth: int = depth_of.get(k, 0)
		var hit: = effect_cells(t, p, clear)
		effects.append({kind = t.special, pos = p, target = t.target, cells = hit, tile = t, depth = depth, parent = parent_of.get(k, -1)})
		if inked.call(p) or hl_keys.has(k):
			for q in hit:
				hl_keys[key(q)] = true
		for q in hit:
			var kq: = key(q)
			if not clear.has(kq):
				clear[kq] = true
				depth_of[kq] = depth + 1
				parent_of[kq] = effects.size() - 1
				queue.append(kq)

	var hit_keys: = {}
	var hit_near: = func(p: Vector2i) -> void :
		for d in NEAR4:
			var n: = at(p + d)
			if n != null and n.block != &"":
				hit_keys[key(p + d)] = true
	for k in matched:
		hit_near.call(unkey(k))
	for k in clear:
		var t: = at(unkey(k))
		if t != null and t.block != &"":
			hit_keys[k] = true
	for p in origins:
		hit_near.call(p)

	var cleared: = []
	var hits: = []
	var unlocked: = []
	var painted_now: = []
	for k in clear:
		var p: = unkey(k)
		var t: = at(p)
		if t == null or t.block != &"" or t.type == BoardTile.DELIVER or protect.has(t.id):
			continue
		if t.taped:
			t.taped = false
			unlocked.append({pos = p, tile = t})
			continue
		cleared.append({pos = p, tile = t})
		put(p, null)
	for k in hit_keys:
		var p: = unkey(k)
		var t: = at(p)
		t.hp -= 1
		var gone: = t.hp <= 0
		hits.append({pos = p, tile = t, gone = gone})
		if gone:
			put(p, null)
	var created: = []
	for sp in creates:
		var t: = new_tile(BoardTile.ITEM, sp.kind)
		put(sp.pos, t)
		created.append({pos = sp.pos, tile = t, keys = sp.keys})
	if not _deferred.is_empty():
		_protect = protect.duplicate()
		for c in created:
			_protect[c.tile.id] = true
	for k in hl_keys:
		var p: = unkey(k)
		if not highlight.is_empty() and not hole(p) and not highlight[p.y][p.x]:
			highlight[p.y][p.x] = true
			painted_now.append({pos = p})
	return {cleared = cleared, created = created, effects = effects, hits = hits, unlocked = unlocked, highlight = painted_now}




func gravity() -> Array:
	var paths: = {}
	var rec: = func(t: BoardTile, from: Vector2i, to: Vector2i, tick: int) -> void :
		if not paths.has(t.id):
			paths[t.id] = {tile = t, fresh = false, path = [Vector3i(from.x, from.y, tick)]}
		else:
			var path: Array = paths[t.id].path
			if path[-1].z < tick:
				path.append(Vector3i(from.x, from.y, tick))
		paths[t.id].path.append(Vector3i(to.x, to.y, tick + 1))

	var top: = []
	for x in cols:
		var y: = 0
		while y < rows and hole(Vector2i(x, y)):
			y += 1
		top.append(y)
	var open_above: = func(p: Vector2i) -> bool:
		for y in range(p.y - 1, top[p.x] - 1, -1):
			var q: = Vector2i(p.x, y)
			if (at(q) != null and not movable(at(q))) or hole(q):
				return false
		return true
	for tick in 80:
		var moved: = false
		for y in range(rows - 2, -1, -1):
			for x in cols:
				var p: = Vector2i(x, y)
				var below: = Vector2i(x, y + 1)
				var t: = at(p)
				if movable(t) and at(below) == null and not hole(below):
					put(below, t)
					put(p, null)
					rec.call(t, p, below, tick)
					moved = true
		for x in cols:
			var y0: int = top[x]
			if y0 >= rows or grid[y0][x] != null:
				continue
			var t: = _spawn()
			grid[y0][x] = t
			paths[t.id] = {tile = t, fresh = true, path = [Vector3i(x, y0 - 1, tick), Vector3i(x, y0, tick + 1)]}
			moved = true
		if moved:
			continue
		var y: = rows - 1
		while y >= 1 and not moved:
			for x in cols:
				var p: = Vector2i(x, y)
				if at(p) != null or hole(p) or open_above.call(p):
					continue
				for dx in ([-1, 1] if rng.randf() < 0.5 else [1, -1]):
					var from: = Vector2i(x + dx, y - 1)
					var t: = at(from)
					if not movable(t):
						continue
					put(p, t)
					put(from, null)
					rec.call(t, from, p, tick)
					moved = true
					break
			y -= 1
		if moved:
			continue

		var fed: = func(p: Vector2i) -> bool:
			if open_above.call(p):
				return true
			for dx in [-1, 1]:
				if movable(at(p + Vector2i(dx, -1))):
					return true
			return false
		y = rows - 1
		while y >= 0 and not moved:
			for x in cols:
				var p: = Vector2i(x, y)
				if at(p) != null or hole(p) or fed.call(p):
					continue
				for dx in [-1, 1]:
					var from: = Vector2i(x + dx, y)
					var t: = at(from)
					if not movable(t) or not fed.call(from):
						continue
					put(p, t)
					put(from, null)
					rec.call(t, from, p, tick)
					moved = true
					break
			y -= 1
		if not moved:
			break
	return paths.values()


func _spawn() -> BoardTile:
	var kind: String = spawn_deliver.call() if spawn_deliver.is_valid() else ""
	return new_deliver(kind) if kind != "" else new_tile(rand_type())



func collect_delivers() -> Array:
	var got: = []
	for p in cells():
		if at(p).type != BoardTile.DELIVER:
			continue
		var bottom: = true
		for y in range(p.y + 1, rows):
			var q: = Vector2i(p.x, y)
			if not (at(q) != null and at(q).block != &"") and not hole(q):
				bottom = false
				break
		if bottom:
			got.append({pos = p, tile = at(p)})
	for g in got:
		put(g.pos, null)
	return got



func spread_ink() -> Dictionary:
	var cand: = []
	for p in cells():
		if at(p).block != INK:
			continue
		for d in NEAR4:
			var n: = at(p + d)
			if n != null and n.type >= 0 and n.special == &"" and not n.taped:
				cand.append(p + d)
	if cand.is_empty():
		return {}
	var p: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
	var old: = at(p)
	put(p, new_block(INK, 1))
	return {pos = p, old = old, tile = at(p)}


func swap(a: Vector2i, b: Vector2i) -> void :
	var t: = at(a)
	put(a, at(b))
	put(b, t)



func has_move() -> bool:
	for p in cells():
		if at(p).special != &"":
			return true
	for p in cells():
		if not movable(at(p)):
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = p + d
			if not movable(at(q)):
				continue
			swap(p, q)
			var ok: = not find_runs().is_empty()
			swap(p, q)
			if ok:
				return true
	return false



func drop_blocks(n: int, kind: = STICKY, hp: = 1) -> Array:
	var cand: = []
	for p in cells():
		var t: = at(p)
		if t.type >= 0 and t.special == &"" and not t.taped:
			cand.append(p)
	var out: = []
	for i in n:
		if cand.is_empty():
			break
		var p: Vector2i = cand.pop_at(rng.randi_range(0, cand.size() - 1))
		var old: = at(p)
		put(p, new_block(kind, hp))
		out.append({pos = p, old = old, tile = at(p)})
	return out



func shuffle() -> void :
	var spots: = []
	for p in cells():
		if movable(at(p)) and at(p).type != BoardTile.DELIVER:
			spots.append(p)
	var tiles: = spots.map( func(p): return at(p))
	for tries in 200:
		for i in range(tiles.size() - 1, 0, -1):
			var j: = rng.randi_range(0, i)
			var tmp = tiles[i]
			tiles[i] = tiles[j]
			tiles[j] = tmp
		for i in spots.size():
			put(spots[i], tiles[i])
		if find_runs().is_empty() and has_move():
			return
	for t in tiles:
		if t.special == &"":
			t.type = rand_type()
