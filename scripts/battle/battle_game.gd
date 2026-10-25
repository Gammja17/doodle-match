class_name BattleGame
extends RefCounted












const ITEMS_ANY: = [Board.ERASER_H, Board.ERASER_V, Board.PUSHPIN, Board.PAPER_PLANE]

const THROWS_STICKY: = ["e03"]

var board: = Board.new()
var ref: = ""
var stage: Dictionary = {}
var team: Array = []
var real: = 0
var lvm: Array = []
var skills: Array = []
var need: Array = []
var gauge: Array = []
var hp: = 120
var hp_max: = 120
var mons: Array = []
var wave: = 0
var pick: = -1
var fever: = 0
var rally: = 0
var sleep: = {}
var poison: = 0
var poison_dmg: = 0
var weak: = 0
var turns: = 0
var dealt: = 0
var healed: = 0
var dealt_by: = {}
var counts: = {}
var over: = false
var won: = false

var simple_monsters: = false

var _route_n: = 0
var _in_skill: = false
var _events: Array = []







func start(battle_id: String, team_ids: Array, opts: = {}) -> void :
	ref = battle_id
	stage = BattleData.battle(battle_id)
	_route_n = opts.get("route_n", BattleData.route_n(battle_id))
	simple_monsters = opts.get("simple_monsters", false)
	if opts.has("seed"):
		board.rng.seed = opts.seed
	var fr: = BattleData.friends()
	team = team_ids.map( func(id): return BattleData.friend(id))
	real = team.size()
	var cheer: = []
	for id in fr.tile_friends + fr.friends.map( func(f): return f.id):
		if id not in team_ids and id not in cheer:
			cheer.append(id)
	for i in maxi(0, int(fr.team_size) - real):
		team.append(BattleData.friend(cheer[i]))
	lvm = []
	skills = []
	need = []
	gauge = []
	for f in team:
		var lv: = _lv_of(opts, f.id)
		lvm.append(opts.get("mult", {}).get(f.id, BattleData.level_mult(f.id, lv)))
		var sk: Dictionary = f.skills[opts.get("skill", {}).get(f.id, 0)]
		skills.append(sk)
		need.append(roundi(sk.need * (1.0 - 0.04 * maxf(0.0, lv - 1.0))))
		gauge.append(floori(need.back() * float(opts.get("gauge_fill", 0.0))) if gauge.size() < real else 0)
	hp_max = int(opts.get("team_hp", BattleData.rules().team_hp))
	hp = hp_max
	fever = 0
	rally = 0
	sleep = {}
	poison = 0
	weak = 0
	turns = 0
	dealt = 0
	healed = 0
	dealt_by = {}
	counts = {}
	over = false
	won = false
	board.set_size(7, 7)
	board.ntypes = team.size()
	board.mask = []
	board.highlight = []
	board.spawn_deliver = Callable()
	board.create()
	wave = 0
	_spawn_wave()


func _lv_of(opts: Dictionary, id: String) -> float:
	var lv = opts.get("lv", 1)
	return float(lv.get(id, 1) if lv is Dictionary else lv)




func wave_members(wv: int) -> Array:
	var waves: Array = stage.waves
	var w: Dictionary = waves[wv]
	var r: = BattleData.rules()
	var n: = int(w.get("group", 0))
	if n == 0 and not simple_monsters and not w.get("boss", false) and wv == 0 and _route_n - 1 >= r.group_from_route:
		n = 3 if _route_n - 1 >= r.trio_from_route and (int(ref.substr(1)) - 1) % 2 == 0 else 2
	if n < 2:
		return [w]
	var others: = []
	for i in waves.size():
		if i != wv and not waves[i].get("boss", false):
			others.append(waves[i])
	var g: Dictionary = r.group2 if n == 2 else r.group3
	var out: = []
	for j in n:
		var base: Dictionary = w if j == 0 else (others[j - 1] if j - 1 < others.size() else w.merged({hue = (int(w.get("hue", 0)) + 50 * j) % 360}, true))
		out.append(base.merged({hp = roundi(w.hp * g.hp_share), atk = roundi(w.atk * g.atk_mult), cd = int(w.cd) + j, boss = false}, true))
	return out


func _spawn_wave() -> void :
	mons = []
	for w in wave_members(wave):
		mons.append({index = mons.size(), w = w, hp = int(w.hp), max = int(w.hp), cd = int(w.cd), atk_n = 0, used = false})
	pick = -1


func alive() -> Array:
	return mons.filter( func(m): return m.hp > 0)



func target() -> Dictionary:
	if pick >= 0 and pick < mons.size() and mons[pick].hp > 0:
		return mons[pick]
	var al: = alive()
	return al[0] if not al.is_empty() else {}



func set_target(i: int) -> void :
	if i >= 0 and i < mons.size() and mons[i].hp > 0:
		pick = -1 if pick == i else i


func asleep(slot: int) -> bool:
	return sleep.get(slot, 0) > 0


func can_skill(slot: int) -> bool:
	return not over and slot < real and gauge[slot] >= need[slot]





func try_swap(a: Vector2i, b: Vector2i, finish: = true) -> Array:
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
	if finish:
		_end_turn()
	return _events



func activate(p: Vector2i, finish: = true) -> Array:
	_events = []
	var t: = board.at(p)
	if over or t == null or t.special == &"":
		return _events
	_events.append({kind = "activate", pos = p, tile = t})
	_cascade([], [p])
	if finish:
		_end_turn()
	return _events


func _cascade(swapped: Array, forced: Array, depth: = 0) -> void :
	var combo: = 0
	while true:
		var res: = board.resolve(swapped if combo == 0 else [], forced if combo == 0 else [])
		if res.is_empty():
			break
		combo += 1
		if combo == 5:
			_count("combo5")
		if combo == 5 and fever == 0:
			fever = BattleData.fever_turns()
			_events.append({kind = "fever"})
		_events.append({kind = "step", res = res, combo = combo})
		_on_step(res, combo)
		_events.append({kind = "fall", paths = board.gravity()})
	if board.has_move():
		return
	board.shuffle()
	_events.append({kind = "shuffle", tiles = _positions()})
	if not board.find_runs().is_empty() and depth < 4:
		_cascade([], [], depth + 1)
	elif not board.has_move():
		var spots: = _pick_tiles(1, func(t): return t.type >= 0 and t.special == &"" and Board.movable(t))
		for q in spots:
			var t: = board.at(q)
			t.special = Board.CRAYON
			t.type = BoardTile.ITEM
			_events.append({kind = "gift", pos = q, tile = t})


func _positions() -> Array:
	var out: = []
	for q in board.cells():
		out.append({pos = q, tile = board.at(q)})
	return out



func _on_step(res: Dictionary, combo: int) -> void :
	var r: = BattleData.rules()
	var tally: = {}
	for c in res.cleared:
		var ty: int = c.tile.type
		if ty >= 0:
			tally[ty] = tally.get(ty, 0) + 1
			_count("pop")
	_count("item", res.effects.size())
	for h in res.hits:
		if h.gone:
			_count(String(h.tile.block))
	var mult: float = (1.0 + r.combo_step * (combo - 1)) * (r.fever_mult if fever > 0 else 1.0) * (r.rally_mult if rally > 0 else 1.0)
	for ty in tally:
		var n: int = tally[ty]
		var ch: Dictionary = team[ty]
		var cheer: bool = ty >= real
		var zz: = asleep(ty)
		if not cheer and not _in_skill and not zz:
			gauge[ty] += n
		var power: float = r.helper_tile_mult if cheer else lvm[ty]
		var zzm: = 0.5 if zz else 1.0
		if ch.has("heal"):
			var amt: = roundi(n * ch.heal * mult * power * zzm)
			_heal(amt, ty)
		elif not target().is_empty():
			var crit: bool = ch.has("crit") and board.rng.randf() < ch.crit
			var eff: = 1.0 if cheer else BattleData.attr_mult(ch.attr, target().w.attr)
			_hit_monster(roundi(n * ch.dmg * mult * eff * power * (r.crit_mult if crit else 1.0) * zzm), ty, eff, crit)
	_events.append({kind = "gauge", gauge = gauge.duplicate()})


func _count(id: String, n: = 1) -> void :
	if n > 0:
		counts[id] = counts.get(id, 0) + n


func _heal(amt: int, slot: = -1) -> void :
	var got: = mini(amt, hp_max - hp)
	healed += got
	if slot >= 0:
		dealt_by[team[slot].id] = dealt_by.get(team[slot].id, 0) + got
	hp = mini(hp_max, hp + amt)
	_events.append({kind = "heal" if slot >= 0 else "team_heal", slot = slot, amt = amt, hp = hp})



func _hit_monster(dmg: int, slot: int, eff: float, crit: bool, carried: = false) -> void :
	var m: = target()
	if m.is_empty():
		return
	if not carried and weak > 0:
		dmg = maxi(1, roundi(dmg * BattleData.enemy_skills().weak.dmg_mult))
	var got: = mini(dmg, m.hp)
	dealt += got
	var id: String = team[slot].id
	dealt_by[id] = dealt_by.get(id, 0) + got
	m.hp = maxi(0, m.hp - dmg)
	_events.append({kind = "hit", mon = m.index, slot = slot, dmg = dmg, crit = crit, eff = eff, left = m.hp})
	if m.hp > 0:
		return
	_events.append({kind = "mon_dead", mon = m.index})
	var nx: = target()
	var rest: = dmg - got
	if not nx.is_empty() and rest > 0:
		var e2: = BattleData.attr_mult(team[slot].attr, nx.w.attr)
		_hit_monster(maxi(1, roundi(rest / eff * e2)), slot, e2, crit, true)





func use_skill(slot: int) -> Array:
	_events = []
	if not can_skill(slot):
		return _events
	gauge[slot] = 0
	_count("skill")
	_in_skill = true
	var sk: Dictionary = skills[slot]
	_events.append({kind = "skill", slot = slot, skill = sk.id})
	var cells: = _skill_effect(slot, sk)
	_cascade([], cells)
	_in_skill = false
	_events.append({kind = "gauge", gauge = gauge.duplicate()})
	if alive().is_empty():
		_wave_cleared()
	return _events



func _skill_effect(k: int, sk: Dictionary) -> Array:
	var ch: Dictionary = team[k]
	var fr: = BattleData.friends()
	var eff: = 1.0 if target().is_empty() else BattleData.attr_mult(ch.get("attr", ""), target().w.attr)
	var cells: = []
	if sk.has("effect"):
		var e: Dictionary = fr.base_effects[sk.effect]
		match sk.effect:
			"scribble8":
				cells = _pick_tiles(e.clear_random, func(_t): return true)
			"rows2":
				cells = _lines(e.clear_rows, 0)
			"cols2":
				cells = _lines(0, e.clear_cols)
			"cross3":
				var c0: = Vector2i(board.rng.randi_range(1, board.cols - 2), board.rng.randi_range(1, board.rows - 2))
				var half: = floori(e.clear_cross_width / 2.0)
				for d in range( - half, half + 1):
					for x in board.cols:
						cells.append(Vector2i(x, c0.y + d))
					for y in board.rows:
						cells.append(Vector2i(c0.x + d, y))
				cells = cells.filter( func(q): return board.inside(q))
				_skill_hit(k, roundi(ch.dmg * e.hit_mult * eff * lvm[k]), eff)
				_delay(e.delay)
			"big_hit":
				_skill_hit(k, roundi(ch.dmg * e.hit_mult * eff), eff)
			"heal25":
				_heal(roundi(hp_max * e.heal))
			"heal20_gauge3":
				_heal(roundi(hp_max * e.heal))
				for j in gauge.size():
					gauge[j] += e.gauge_all
			"convert6":
				_convert(k, e.convert)
			"drop_crayon":
				_put(e.put, false)
			"stall3":
				_delay(e.delay)
				_skill_hit(k, roundi(ch.dmg * e.hit_mult * eff), eff)
			"drop_pushpin3":
				cells = _put(e.put, true)
			"shuffle_cheer":
				_shuffle()
				for j in gauge.size():
					if j != k:
						gauge[j] += e.gauge_others
		return cells
	match sk.fx:
		"drop":
			if sk.get("shuffle", false):
				_shuffle()
			cells = _put(sk.items, sk.get("fire", false))
		"blocks":

			for q in board.cells():
				if board.at(q).block != &"" or board.at(q).taped:
					cells.append(q)
			if cells.is_empty():
				cells = _pick_tiles(fr.fx_rules.blocks.fallback_tiles)
		"lines":
			cells = _lines(sk.rows, sk.cols)
		"convert":
			_convert(k, sk.n)
			if sk.has("heal"):
				_heal(roundi(hp_max * sk.heal))
		"bighit":
			_skill_hit(k, roundi(ch.dmg * sk.mult * eff * lvm[k]), eff)
		"delay":
			_delay(sk.n)
			if sk.has("hit"):
				_skill_hit(k, roundi(ch.dmg * sk.hit * eff), eff)
		"gauge", "half", "rally", "heal":
			if sk.get("shuffle", false):
				_shuffle()
			if sk.has("heal"):
				_heal(roundi(hp_max * sk.heal))
			var plus: int = sk.n if sk.fx == "gauge" else (fr.fx_rules.rally.gauge_all if sk.fx == "rally" else sk.get("gauge", 0))
			for j in real:
				if j == k:
					continue
				gauge[j] += plus
				if sk.fx == "half":
					gauge[j] = maxi(gauge[j], ceili(need[j] / 2.0))
			if sk.fx == "rally":
				rally = fr.fx_rules.rally.turns
	return cells


func _skill_hit(k: int, dmg: int, eff: float) -> void :
	if not target().is_empty():
		_hit_monster(dmg, k, eff, true)


func _delay(n: int) -> void :
	for m in alive():
		m.cd += n
	_events.append({kind = "delay", n = n})



func _pick_tiles(n: int, ok: Callable = Callable()) -> Array:
	var all: = []
	for q in board.cells():
		var t: = board.at(q)
		if (ok.call(t) if ok.is_valid() else (t.special == &"" and t.type >= 0)):
			all.append(q)
	for i in range(all.size() - 1, 0, -1):
		var j: = board.rng.randi_range(0, i)
		var tmp = all[i]
		all[i] = all[j]
		all[j] = tmp
	return all.slice(0, n)



func _lines(nr: int, nc: int) -> Array:
	var cells: = []
	var ys: = range(board.rows)
	var xs: = range(board.cols)
	_shuffle_array(ys)
	_shuffle_array(xs)
	for y in ys.slice(0, nr):
		for x in board.cols:
			cells.append(Vector2i(x, y))
	for x in xs.slice(0, nc):
		for y in board.rows:
			cells.append(Vector2i(x, y))
	return cells


func _shuffle_array(a: Array) -> void :
	for i in range(a.size() - 1, 0, -1):
		var j: = board.rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp



func _put(kinds: Array, fire: bool) -> Array:
	var spots: = _pick_tiles(kinds.size())
	for i in spots.size():
		var t: = board.at(spots[i])
		var kind: String = kinds[i]
		t.special = ITEMS_ANY[board.rng.randi_range(0, 3)] if kind == "any" else StringName(kind)
		t.type = BoardTile.ITEM
		_events.append({kind = "convert", pos = spots[i], tile = t})
	return spots if fire else []



func _convert(k: int, n: int) -> void :
	for q in _pick_tiles(n, func(t): return t.special == &"" and t.type >= 0 and t.type != k):
		board.at(q).type = k
		_events.append({kind = "convert", pos = q, tile = board.at(q)})


func _shuffle() -> void :
	board.shuffle()
	_events.append({kind = "shuffle", tiles = _positions()})




func _end_turn() -> void :
	turns += 1
	if alive().is_empty():
		_wave_cleared()
		return
	if fever > 0:
		fever -= 1
	if rally > 0:
		rally -= 1
	_tick_debuffs()
	var al: = alive()
	for m in al:
		m.cd -= 1
	for m in al:
		if m.cd > 0:
			continue
		_mon_attack(m)
		m.cd = int(m.w.cd)
		if hp <= 0:
			over = true
			_events.append({kind = "fail"})
			return


func _mon_attack(m: Dictionary) -> void :
	var atk: = int(m.w.atk)
	hp = maxi(0, hp - atk)
	_events.append({kind = "mon_attack", mon = m.index, dmg = atk, hp = hp})
	if m.w.enemy in THROWS_STICKY:
		for d in board.drop_blocks(3 if m.w.get("boss", false) else 2, Board.STICKY, 1):
			_events.append({kind = "replace", pos = d.pos, old = d.old, tile = d.tile})
		if not board.has_move():
			_cascade([], [])
	_special(m)



func _special(m: Dictionary) -> void :
	if simple_monsters:
		return
	var kind: = BattleData.enemy_skill(m.w.enemy)
	m.atk_n += 1
	if kind == "" or hp <= 0:
		return
	if m.w.get("boss", false):
		if m.atk_n % 2 == 0:
			return
	elif m.used or mons.any( func(o): return o.index != m.index and o.used) or (kind != "heal" and _any_debuff()):
		return
	m.used = true
	var s: Dictionary = BattleData.enemy_skills()[kind]
	match kind:
		"sleep":
			var ks: = range(real).filter( func(j): return not asleep(j) and not team[j].has("heal"))
			if ks.is_empty():
				return
			var k: int = ks[board.rng.randi_range(0, ks.size() - 1)]
			sleep[k] = int(s.turns)
			_events.append({kind = "debuff", debuff = kind, mon = m.index, slot = k})
		"poison":
			poison = int(s.turns)
			poison_dmg = maxi(int(s.dmg_min), roundi(m.w.atk * s.dmg_atk_ratio))
			_events.append({kind = "debuff", debuff = kind, mon = m.index})
		"weak":
			weak = int(s.turns)
			_events.append({kind = "debuff", debuff = kind, mon = m.index})
		"drain":
			var k: = 0
			for j in real:
				if gauge[j] > gauge[k]:
					k = j
			if gauge[k] == 0:
				return
			gauge[k] = floori(gauge[k] * s.gauge_mult)
			_events.append({kind = "debuff", debuff = kind, mon = m.index, slot = k})
		"ink_spit":
			for q in _pick_tiles(s.tiles, func(t): return t.type >= 0 and t.special == &"" and not t.taped and t.block == &""):
				var old: = board.at(q)
				board.put(q, board.new_block(Board.INK, 1))
				_events.append({kind = "replace", pos = q, old = old, tile = board.at(q)})
			_events.append({kind = "debuff", debuff = kind, mon = m.index})
			if not board.has_move():
				_cascade([], [])
		"stomp":
			_shuffle()
			_events.append({kind = "debuff", debuff = kind, mon = m.index})
		"heal":
			var amt: = roundi(m.max * s.hp_ratio)
			m.hp = mini(m.max, m.hp + amt)
			_events.append({kind = "mon_heal", mon = m.index, amt = amt, left = m.hp})


func _any_debuff() -> bool:
	return poison > 0 or weak > 0 or not sleep.is_empty()



func _tick_debuffs() -> void :
	if poison > 0:
		var d: = mini(poison_dmg, hp - 1)
		if d > 0:
			hp -= d
			_events.append({kind = "poison", dmg = d, hp = hp})
		poison -= 1
	if weak > 0:
		weak -= 1
	for k in sleep.keys():
		sleep[k] -= 1
		if sleep[k] <= 0:
			sleep.erase(k)


func _wave_cleared() -> void :
	wave += 1
	if wave < stage.waves.size():
		_spawn_wave()
		_events.append({kind = "wave", index = wave})
		return
	over = true
	won = true
	_events.append({kind = "win", stars = stars()})



func stars() -> int:
	var ratio: = float(hp) / hp_max
	return 3 if ratio >= 0.7 else 2 if ratio >= 0.35 else 1




func result() -> Dictionary:
	var mvp: = ""
	for j in real:
		var id: String = team[j].id
		if mvp == "" or dealt_by.get(id, 0) > dealt_by.get(mvp, 0):
			mvp = id
	return {kind = "route", ref = ref, won = won, stars = stars() if won else 0, team = team.slice(0, real).map( func(f): return f.id), 
		mvp = mvp, counts = counts.duplicate(), hp_ratio = float(hp) / hp_max, turns = turns, wave = wave, 
		waves = stage.waves.size(), dealt_by = dealt_by.duplicate()}



func clone() -> BattleGame:
	var g: = BattleGame.new()
	for p in ["ref", "stage", "team", "real", "lvm", "skills", "need", "hp", "hp_max", "wave", "pick", "fever", "rally", 
			"poison", "poison_dmg", "weak", "turns", "dealt", "healed", "over", "won", "simple_monsters", "_route_n"]:
		g.set(p, get(p))
	g.gauge = gauge.duplicate()
	g.sleep = sleep.duplicate()
	g.dealt_by = dealt_by.duplicate()
	g.counts = counts.duplicate()
	g.mons = mons.duplicate(true)
	var b: = g.board
	b.rows = board.rows
	b.cols = board.cols
	b.ntypes = board.ntypes
	b._next_id = board._next_id
	b.rng.seed = board.rng.randi()
	b.grid = []
	for row in board.grid:
		b.grid.append(row.map( func(t): return _copy_tile(t) if t != null else null))
	return g


static func _copy_tile(t: BoardTile) -> BoardTile:
	var c: = BoardTile.new(t.id, t.type, t.special)
	c.block = t.block
	c.hp = t.hp
	c.taped = t.taped
	c.deliver_kind = t.deliver_kind
	return c
