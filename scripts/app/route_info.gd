class_name RouteInfo
extends RefCounted
## 지도 판 정보 (route.json + puzzles.json + battles.json). 판 번호 n은 1부터.
## 열림 규칙: 1판은 처음부터, 그다음은 앞 판을 깨면 (웹과 같음)

const PUZZLES := "res://data/puzzles.json"
## 시간 판을 이동 수로 바꿀 때 한 수 = 몇 초 (rules: 스킬 puzzle_moves n수 = 시간 판 n×3초)
const SEC_PER_MOVE := 3

const RULES := "res://data/rules.json"

static var _puzzles := {}
static var _rules := {}


static func cfg() -> MetaConfig:
	return MetaConfig.shared()


static func count() -> int:
	return cfg().route.stages.size()


static func stage(n: int) -> Dictionary:
	return cfg().route.stages[n - 1]


static func ref(n: int) -> String:
	return cfg().route_ref.get(n, "")


static func is_battle(n: int) -> bool:
	return ref(n).begins_with("b")


static func chapters() -> Array:
	return cfg().route.chapters


## n판이 있는 장 (0부터)
static func chapter_of(n: int) -> int:
	var cs := chapters()
	for i in cs.size():
		if n < int(cs[i].first) + int(cs[i].count):
			return i
	return cs.size() - 1


static func stars(m: Meta, n: int) -> int:
	return int(m.data.stars.get(ref(n), 0))


static func is_open(m: Meta, n: int) -> bool:
	return n == 1 or (n <= count() and stars(m, n - 1) > 0)


## 지금 갈 수 있는 가장 먼 판
static func frontier(m: Meta) -> int:
	var n := 1
	while n < count() and stars(m, n) > 0:
		n += 1
	return n


## 퍼즐 판 객체 (BoardGame.start에 넣을 복사본). 시간 판은 아직 엔진이 못 받아서 임시로 이동 수로 바꿈
static func puzzle(n: int) -> Dictionary:
	if _puzzles.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PUZZLES))
		for p in data.puzzles:
			_puzzles[p.id] = p
	var p: Dictionary = _puzzles[ref(n)].duplicate(true)
	for g in p.goals:  # JSON 숫자는 실수라서 TileArt.goal_icon의 tile % n이 터짐 → 정수로
		for k in ["tile", "n"]:
			if g.has(k):
				g[k] = int(g[k])
	if not p.has("moves"):
		p.moves = ceili(float(p.time) / SEC_PER_MOVE)
		p.timed_as_moves = true
	return p


## rules.json puzzle 숫자 (buddy_moves 단짝 이동 +, continue_moves 이어하기 이동 +)
static func puzzle_rule(key: String) -> int:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	return int(_rules.puzzle[key])


## 이 판에 나오는 괴물 속성들 (웨이브 순서, 겹치는 건 한 번)
static func enemy_attrs(n: int) -> Array:
	var out := []
	for w in BattleData.battle(ref(n)).waves:
		if not w.attr in out:
			out.append(w.attr)
	return out
