class_name BattleBot
extends RefCounted
## 토벌 자동 플레이 봇 (웹판 tools/sim.js 토벌 봇을 옮김). 밸런스 맞출 때와 테스트에 씀.
## 게이지가 찬 스킬부터 바로 쓰고, 둘 수 있는 수를 하나씩 복사본에서 미리 터뜨려 보고 값이 제일 좋은 수를 둠
## 값 = 깎은 체력 + 판에 남은 아이템 힘 × 6 + 채운 체력(많이 다쳤을수록 크게) + 게이지 오른 만큼 × 1.5 (+ 쓰러뜨리면 30)

const ITEM_VALUE := {&"crayon": 7, &"pushpin": 4, &"paper_plane": 3, &"eraser_h": 3, &"eraser_v": 3}


## 한 판을 끝까지 둠. 결과는 g.result()
static func run(g: BattleGame, rng: RandomNumberGenerator, cap := 400) -> Dictionary:
	for turn in cap:
		if g.over:
			break
		for k in g.real:
			if g.can_skill(k) and not g.alive().is_empty():
				g.use_skill(k)
		if g.over:
			break
		var ms := moves(g.board)
		if ms.is_empty():
			g.board.shuffle()
			continue
		var g0 := _gauge_value(g)
		var best: Array = ms[0]
		var bv := -INF
		for m in ms:
			var c := g.clone()
			var d0 := c.dealt
			var h0 := c.healed
			_play(c, m, false)
			var v: float = (c.dealt - d0) + potential(c.board) * 6.0 \
				+ (c.healed - h0) * (0.4 + float(c.hp_max - c.hp) / c.hp_max * 3.0) \
				+ _gauge_value(c) - g0 + rng.randf() * 0.5
			if c.alive().is_empty():
				v += 30.0
			if v > bv:
				bv = v
				best = m
		_play(g, best, true)
	return g.result()


static func _play(g: BattleGame, m: Array, finish: bool) -> void:
	if m.size() == 1:
		g.activate(m[0], finish)
	else:
		g.try_swap(m[0], m[1], finish)


static func _gauge_value(g: BattleGame) -> float:
	var v := 0.0
	for j in g.real:
		v += mini(g.gauge[j], g.need[j]) * 1.5
	return v


## 판에 있는 아이템 값 (나중에 쓸 수 있는 힘)
static func potential(b: Board) -> int:
	var v := 0
	for q in b.cells():
		v += ITEM_VALUE.get(b.at(q).special, 0)
	return v


## 둘 수 있는 수: [p] 아이템 톡, [a, b] 옆 칸 바꾸기 (매치가 되거나 아이템을 밀면)
static func moves(b: Board) -> Array:
	var out := []
	for p in b.cells():
		var t := b.at(p)
		if not Board.movable(t):
			continue
		if t.special != &"":
			out.append([p])
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = p + d
			var u := b.at(q)
			if not Board.movable(u):
				continue
			if t.special != &"" or u.special != &"":
				out.append([p, q])
				continue
			b.swap(p, q)
			var ok := not b.find_runs().is_empty()
			b.swap(p, q)
			if ok:
				out.append([p, q])
	return out
