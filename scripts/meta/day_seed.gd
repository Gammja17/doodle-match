class_name DaySeed
extends RefCounted
## 날짜 글자로 정하는 난수 (그날은 누구나 같은 판·같은 미션). 원본 seeded()를 그대로 따라 함:
## 원본은 JS 실수로 곱해서 2^53을 넘는 곱이 반올림됨 → 같은 수가 나오게 여기서도 float로 곱함.

const U32 := 4294967296.0

var _s: float


func _init(text: String) -> void:
	var a := 7.0
	for i in text.length():
		a = a * 31.0 + text.unicode_at(i)
	_s = fmod(a, U32)


## 0 이상 1 미만 (1/10000 단위)
func next() -> float:
	_s = fmod(_s * 1103515245.0 + 12345.0, U32)
	return fmod(_s, 10000.0) / 10000.0


## 오늘의 도전 판: 비틀기는 날마다 rotation_step칸씩 건너뛰며 돌고, 장애물 자리는 날짜로 흩뿌림.
## 돌려주는 판은 data/SCHEMA.md 판 객체 (BoardGame.start에 그대로) + twist(몇 번째 비틀기)
static func daily_stage(dc: Dictionary, day: String, day_no: int) -> Dictionary:
	var k := posmod(day_no * int(dc.rotation_step), dc.twists.size())
	var st: Dictionary = dc.twists[k].duplicate(true)
	var base: Array = st.base
	var put: Array = st.scatter
	st.erase("base")
	st.erase("scatter")
	st.map = scatter(DaySeed.new(day), base, put)
	st.twist = k
	return st


## 빈 판(구멍 모양)에 글자를 좌우 대칭으로 흩뿌림. put: [{ cell, count, rows: [위 줄, 아래 줄] }]
static func scatter(rnd: DaySeed, hole: Array, put: Array) -> Array:
	var g := []
	for row in hole:
		var line := []
		for ch in row:
			line.append(ch)
		g.append(line)
	var cols: int = g[0].size()
	for p in put:
		var free := []
		for r in range(int(p.rows[0]), int(p.rows[1]) + 1):
			for c in ceili(cols / 2.0):
				if g[r][c] == "." and g[r][cols - 1 - c] == ".":
					free.append(Vector2i(c, r))
		var k := 0
		while k < int(p.count) and not free.is_empty():
			var at: Vector2i = free.pop_at(floori(rnd.next() * free.size()))
			g[at.y][at.x] = p.cell
			g[at.y][cols - 1 - at.x] = p.cell
			k += 1 if at.x == cols - 1 - at.x else 2
	var out := []
	for line in g:
		out.append("".join(PackedStringArray(line)))
	return out
