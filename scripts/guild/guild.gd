class_name Guild
extends RefCounted
## 길드 하우스 꾸미기 순수 로직 (그림 없음). 웹 집 꾸미기(친구마다 집 한 채)를 "집 하나 + 방(구역)"으로 바꾼 것.
## 방은 이야기 진행으로 열리고, 방마다 가구·벽지·바닥·친구(최대 6)를 놓는다. 숫자는 GuildConfig.
## 저장은 메타 저장 안 meta.data.guild (모양은 fresh()). 바꾸는 함수는 끝에 바로 저장함 (meta.save_path를 비우면 안 함).
## 자리는 방 너비·높이 천분율 정수 (가구는 아래쪽 가운데, 친구는 발밑).
##
## 꾸미기 보상은 코인·호감·꾸미기 것뿐, 능력치는 없음 (bm.md §0):
##   하루 선물(방장이 코인), 방 완성(휘갈김 자국을 다 지우면 별가루 + 테마 가구), 길드 등급(의뢰판 칸·프로필 테두리),
##   소속 방 보너스(그 소속 친구 3명 이상이면 호감 ×1.5)

signal room_completed(room_id: String, reward: Dictionary)  # 휘갈김 자국을 다 지웠음 (보상은 이미 들어감)

const X_RANGE := Vector2i(40, 960)
const Y_RANGE := {wall = Vector2i(140, 580), flat = Vector2i(660, 1000), floor = Vector2i(600, 990)}
const FRIEND_X := Vector2i(100, 900)
const FRIEND_Y := Vector2i(640, 970)
const FRIEND_SLOTS := [[500, 820], [260, 760], [740, 760], [380, 940], [620, 940], [150, 920]]
const SAME_STEP := 80  # 같은 가구를 또 놓으면 이만큼 비켜서

var meta: Meta
var cfg: GuildConfig
var rng := RandomNumberGenerator.new()
var _undo := []  # 꾸미기 중 되돌리기: [{ room, items, wall, floor }] (저장 안 함)


func _init(p_meta: Meta, config: GuildConfig = null) -> void:
	meta = p_meta
	cfg = config if config else GuildConfig.new()
	rng.randomize()
	var g := data()
	var base := fresh()
	for k in base:
		if not g.has(k):
			g[k] = base[k]
	sync()


## 처음 길드 저장
static func fresh() -> Dictionary:
	return {
		rooms = {},     # 방 id -> fresh_room()
		inv = {},       # 가구 id -> 산(받은) 개수. 보관함에 남은 수 = 이것 - 모든 방에 놓인 수
		walls = [],     # 가진 벽지 id (모든 방에서 씀)
		floors = [],    # 가진 바닥 id
		stardust = 0,   # 방 완성으로 받은 별가루 (메타에 별가루 칸이 생기면 옮김, docs/app-notes.md)
	}


static func fresh_room() -> Dictionary:
	return {
		items = [],     # [{ k: 가구 id, x, y, f: 좌우 뒤집음 }] 뒤에 있을수록 위에 그림
		wall = "",      # "" = 기본 벽
		floor = "",
		friends = [],   # 놓인 친구 id. 맨 앞이 방장 (하루 선물)
		pos = {},       # 친구 id -> [x, y]
		gift = "",      # 방장 선물을 받은 날
		fixed = [],     # 이 방에 한 번이라도 놓은 가구 종류 (휘갈김 자국 지운 수)
		done = false,   # 방 완성 보상 받음
	}


func data() -> Dictionary:
	if not meta.data.has("guild"):
		meta.data.guild = fresh()
	return meta.data.guild


func _save() -> void:
	if meta.save_path != "":
		meta.save()


# ---------- 방 열기 ----------

## 길드 하우스 자체가 열렸는지 (웹 집과 같은 판: meta_extra unlocks.house)
func is_open() -> bool:
	return meta.is_open("house")


func _unlocked(r: Dictionary) -> bool:
	var u: Dictionary = r.unlock
	if u.has("clears"):
		return meta.cleared_count() >= int(u.clears)
	var ch: Dictionary = meta.cfg.route.chapters[int(u.chapter) - 1]
	return meta.data.stars.has(meta.cfg.route_ref[int(ch.first) + int(ch.count) - 1])


## 들어갈 수 있는 방인지 (옮겨 간 방은 닫힘)
func room_open(id: String) -> bool:
	var r: Dictionary = cfg.room_by_id.get(id, {})
	if r.is_empty() or not is_open() or not _unlocked(r):
		return false
	return not (r.has("moves_to") and _unlocked(cfg.room_by_id[r.moves_to]))


func open_rooms() -> Array:
	sync()
	return cfg.rooms.filter(func(r): return room_open(r.id)).map(func(r): return r.id)


## 아직 안 열린 방 (옮겨 가서 닫힌 방은 빼고)
func locked_rooms() -> Array:
	return cfg.rooms.filter(func(r): return not _unlocked(r)).map(func(r): return r.id)


## 잠긴 방에 붙일 말: "6판을 깨면", "7장을 깨면"
func unlock_hint(id: String) -> String:
	var u: Dictionary = cfg.room_by_id[id].unlock
	return "%d판을 깨면" % int(u.clears) if u.has("clears") else "%d장을 깨면" % int(u.chapter)


## 옮겨 갈 방이 열렸으면 살림을 통째로 옮김 (그렌의 오두막 → 요새 큰방). 여러 번 불러도 됨
func sync() -> void:
	var g := data()
	for r in cfg.rooms:
		if not r.has("moves_to") or not g.rooms.has(r.id) or not _unlocked(cfg.room_by_id[r.moves_to]):
			continue
		var src: Dictionary = g.rooms[r.id]
		var dst := room(r.moves_to)
		dst.items.append_array(src.items)
		for key in ["wall", "floor", "gift"]:
			if dst[key] == "":
				dst[key] = src[key]
		for id in src.friends:
			if dst.friends.size() < int(cfg.rules.room_max_friends) and not id in dst.friends:
				dst.friends.append(id)
				dst.pos[id] = src.pos.get(id, _slot(dst.friends.size() - 1))
		for k in src.items.map(func(it): return it.k):
			_fix(r.moves_to, k)
		g.rooms.erase(r.id)
		_save()


## 방 저장 (처음 부르면 만듦)
func room(id: String) -> Dictionary:
	var rooms: Dictionary = data().rooms
	if not rooms.has(id):
		rooms[id] = fresh_room()
	return rooms[id]


# ---------- 가구 사기 ----------

func bought(k: String) -> int:
	return int(data().inv.get(k, 0))


func placed(k: String) -> int:
	var n := 0
	for rm in data().rooms.values():
		n += rm.items.filter(func(it): return it.k == k).size()
	return n


## 보관함에 남은 개수 (산 것 - 놓인 것)
func left(k: String) -> int:
	return bought(k) - placed(k)


## 가게에 보일 가구: 기본 26종 + 열린 방 테마 가구 (보상 전용은 받은 뒤에만). 어느 방에나 놓을 수 있음
func shop_list() -> Array:
	return cfg.furn_order.filter(_in_shop)


func _in_shop(k: String) -> bool:
	var f: Dictionary = cfg.furn[k]
	if f.has("room") and not (is_open() and _unlocked(cfg.room_by_id[f.room])):
		return false
	return not f.get("reward", false) or bought(k) > 0


func can_buy(k: String) -> bool:
	var f: Dictionary = cfg.furn.get(k, {})
	return not f.is_empty() and not f.get("reward", false) and k in shop_list() and meta.data.coins >= int(f.price)


func buy(k: String) -> bool:
	if not can_buy(k):
		return false
	meta.data.coins -= int(cfg.furn[k].price)
	data().inv[k] = bought(k) + 1
	_save()
	return true


# ---------- 놓기·옮기기·뒤집기·넣기·되돌리기 ----------

## 보관함에 있는 가구를 방에 놓음 (처음 자리, 같은 가구는 조금씩 비켜서). 놓은 자리 번호, 못 놓으면 -1
func place(room_id: String, k: String) -> int:
	if not room_open(room_id) or left(k) <= 0:
		return -1
	var rm := room(room_id)
	var f: Dictionary = cfg.furn[k]
	_push_undo(room_id)
	var same: int = rm.items.filter(func(it): return it.k == k).size()
	rm.items.append({k = k, x = clampi(f.x + same * SAME_STEP, X_RANGE.x, X_RANGE.y), y = _clamp_y(f.kind, f.y), f = false})
	meta.mission_add("furnish")
	_fix(room_id, k)
	_save()
	return rm.items.size() - 1


## 웹 가게 단추처럼: 보관함에 없으면 사서 놓음
func buy_and_place(room_id: String, k: String) -> int:
	if not room_open(room_id):
		return -1
	if left(k) <= 0 and not buy(k):
		return -1
	return place(room_id, k)


## 끌어서 놓은 자리 (손을 뗄 때 한 번 부름). 가구 종류에 맞는 높이로 맞춤
func move(room_id: String, i: int, x: int, y: int) -> bool:
	var rm := room(room_id)
	if i < 0 or i >= rm.items.size():
		return false
	_push_undo(room_id)
	var it: Dictionary = rm.items[i]
	it.x = clampi(x, X_RANGE.x, X_RANGE.y)
	it.y = _clamp_y(cfg.furn[it.k].kind, y)
	_save()
	return true


## 돌리기: 좌우 뒤집기 (옆에서 보는 스티커 방이라 웹처럼 뒤집기만)
func flip(room_id: String, i: int) -> bool:
	var rm := room(room_id)
	if i < 0 or i >= rm.items.size():
		return false
	_push_undo(room_id)
	rm.items[i].f = not rm.items[i].f
	_save()
	return true


## 보관함에 넣기
func store(room_id: String, i: int) -> bool:
	var rm := room(room_id)
	if i < 0 or i >= rm.items.size():
		return false
	_push_undo(room_id)
	rm.items.remove_at(i)
	_save()
	return true


func _clamp_y(kind: String, y: int) -> int:
	var r: Vector2i = Y_RANGE[kind]
	return clampi(y, r.x, r.y)


## 꾸미기를 시작할 때 (되돌리기 기록을 비움)
func begin_edit() -> void:
	_undo.clear()


## 다 했어
func end_edit() -> void:
	_undo.clear()
	_save()


func can_undo() -> bool:
	return not _undo.is_empty()


## 마지막으로 바꾼 것 하나를 되돌림: 놓기·옮기기·뒤집기·넣기·벽지·바닥.
## 산 가구는 보관함에 남고 코인은 안 돌려줌. 지운 휘갈김 자국도 그대로 (한 번 고친 건 고친 것)
func undo() -> String:
	if _undo.is_empty():
		return ""
	var s: Dictionary = _undo.pop_back()
	var rm := room(s.room)
	rm.items = s.items
	rm.wall = s.wall
	rm.floor = s.floor
	_save()
	return s.room


## 되돌리기 기록은 한 방 것만 (다른 방을 꾸미기 시작하면 비움 → 보관함 수가 어긋나지 않음)
func _push_undo(room_id: String) -> void:
	if not _undo.is_empty() and _undo[-1].room != room_id:
		_undo.clear()
	var rm := room(room_id)
	_undo.append({room = room_id, items = rm.items.duplicate(true), wall = rm.wall, floor = rm.floor})
	if _undo.size() > int(cfg.rules.undo_max):
		_undo.pop_front()


# ---------- 벽지·바닥 ----------

func has_deco(kind: String, id: String) -> bool:
	return id == "" or id in data()[kind + "s"]


## 벽지(kind "wall")나 바닥("floor")을 바꿈. 안 가졌으면 사서 바꿈 (가진 건 모든 방에서 씀). "" = 기본
func set_deco(room_id: String, kind: String, id: String) -> bool:
	var list: Dictionary = cfg.walls if kind == "wall" else cfg.floors
	if not room_open(room_id) or (id != "" and not list.has(id)):
		return false
	if not has_deco(kind, id):
		if meta.data.coins < int(list[id].price):
			return false
		meta.data.coins -= int(list[id].price)
		data()[kind + "s"].append(id)
	_push_undo(room_id)
	room(room_id)[kind] = id
	_save()
	return true


# ---------- 아늑함·길드 등급 ----------

## 웹 식 그대로: 가구 종류마다 값/10, 같은 가구 더 놓으면 +2, 벽지·바닥을 바꾸면 +15씩. 보상 가구는 value로 셈
func cozy(room_id: String) -> int:
	var rm := room(room_id)
	var h: Dictionary = cfg.house
	var n := (int(h.cozy_wall_or_floor) if rm.wall != "" else 0) + (int(h.cozy_wall_or_floor) if rm.floor != "" else 0)
	var seen := {}
	for it in rm.items:
		var f: Dictionary = cfg.furn.get(it.k, {})
		if f.is_empty():
			continue
		n += int(h.cozy_dup_item) if seen.has(it.k) else roundi(float(f.get("value", f.price)) / float(h.cozy_price_div))
		seen[it.k] = true
	return n


## 길드 전체 아늑함 = 열린 방 아늑함 합
func guild_cozy() -> int:
	var n := 0
	for id in open_rooms():
		n += cozy(id)
	return n


## 길드 등급 1부터
func rank() -> int:
	var c := guild_cozy()
	return cfg.rules.rank.filter(func(r): return c >= int(r.cozy)).size()


## 다음 등급까지 필요한 길드 아늑함 (마지막 등급이면 -1)
func next_rank_cozy() -> int:
	var r := rank()
	return int(cfg.rules.rank[r].cozy) if r < cfg.rules.rank.size() else -1


## 의뢰판(하루 미션) 칸이 늘어난 수. 메타가 missions.per_day에 더해 씀 (docs/app-notes.md)
func board_bonus() -> int:
	var n := 0
	for r in cfg.rules.rank.slice(0, rank()):
		n += int(r.get("board", 0))
	return n


## 받은 프로필 테두리
func frames() -> Array:
	return cfg.rules.rank.slice(0, rank()).filter(func(r): return r.has("frame")).map(func(r): return r.frame)


# ---------- 휘갈김 자국·방 완성 ----------

func marks_total(room_id: String) -> int:
	return int(cfg.room_by_id[room_id].marks)


func marks_left(room_id: String) -> int:
	return maxi(0, marks_total(room_id) - room(room_id).fixed.size())


## 이 방에 처음 놓는 가구 종류면 자국 하나를 지우고, 다 지웠으면 방 완성 보상
func _fix(room_id: String, k: String) -> void:
	var rm := room(room_id)
	if not k in rm.fixed:
		rm.fixed.append(k)
	if rm.done or rm.fixed.size() < marks_total(room_id):
		return
	rm.done = true
	var reward := {stardust = int(cfg.rules.room_complete.stardust)}
	data().stardust += reward.stardust
	for id in cfg.furn_order:
		var f: Dictionary = cfg.furn[id]
		if f.get("room") == room_id and f.get("reward", false):
			data().inv[id] = bought(id) + 1
			reward.furniture = id
	room_completed.emit(room_id, reward)


# ---------- 친구 ----------

## 친구가 놓인 방 ("" = 없음)
func where(id: String) -> String:
	for rid in data().rooms:
		if id in data().rooms[rid].friends:
			return rid
	return ""


func is_full(room_id: String) -> bool:
	return room(room_id).friends.size() >= int(cfg.rules.room_max_friends)


## 방에 친구를 놓음 (다른 방에 있었으면 옮김)
func put_friend(room_id: String, id: String) -> bool:
	if not room_open(room_id) or not meta.owned(id) or not cfg.friends.has(id):
		return false
	var rm := room(room_id)
	if id in rm.friends:
		return true
	if is_full(room_id):
		return false
	var was := where(id)
	if was != "":
		take_friend(was, id)
	rm.friends.append(id)
	rm.pos[id] = _free_slot(rm)
	_save()
	return true


func take_friend(room_id: String, id: String) -> bool:
	var rm := room(room_id)
	if not id in rm.friends:
		return false
	rm.friends.erase(id)
	rm.pos.erase(id)
	_save()
	return true


## 친구를 끌어다 놓은 자리
func move_friend(room_id: String, id: String, x: int, y: int) -> bool:
	var rm := room(room_id)
	if not id in rm.friends:
		return false
	rm.pos[id] = [clampi(x, FRIEND_X.x, FRIEND_X.y), clampi(y, FRIEND_Y.x, FRIEND_Y.y)]
	_save()
	return true


func friend_pos(room_id: String, id: String) -> Vector2i:
	var p: Array = room(room_id).pos.get(id, [500, 820])
	return Vector2i(int(p[0]), int(p[1]))


func _slot(k: int) -> Array:
	return FRIEND_SLOTS[k % FRIEND_SLOTS.size()].duplicate()


func _free_slot(rm: Dictionary) -> Array:
	var used: Array = rm.pos.values()
	for s in FRIEND_SLOTS:
		if not s in used:
			return s.duplicate()
	return _slot(rm.friends.size())


## 방장 = 맨 앞 친구
func leader(room_id: String) -> String:
	var f: Array = room(room_id).friends
	return f[0] if not f.is_empty() else ""


func set_leader(room_id: String, id: String) -> bool:
	var rm := room(room_id)
	if not id in rm.friends:
		return false
	rm.friends.erase(id)
	rm.friends.push_front(id)
	_save()
	return true


# ---------- 하루 선물 ----------

func gift_coins(room_id: String) -> int:
	var h: Dictionary = cfg.house
	return mini(int(h.gift_max), int(h.gift_base) + cozy(room_id) / int(h.gift_cozy_per_coin))


func can_gift(room_id: String) -> bool:
	return room_open(room_id) and leader(room_id) != "" and cozy(room_id) >= int(cfg.house.gift_min_cozy) \
		and room(room_id).gift != meta.today()


## 방장 선물 받기 → 코인 수 (못 받으면 0)
func take_gift(room_id: String) -> int:
	if not can_gift(room_id):
		return 0
	var n := gift_coins(room_id)
	room(room_id).gift = meta.today()
	meta.add_coins(n)
	return n


# ---------- 소속 방 보너스·탭 ----------

## 소속 방에 그 소속 친구가 min_friends명 이상
func group_bonus(room_id: String) -> bool:
	var g: String = cfg.room_by_id[room_id].group
	if g == "":
		return false
	var n: int = room(room_id).friends.filter(func(id): return cfg.friends.get(id, {}).get("group") == g).size()
	return n >= int(cfg.rules.group_bonus.min_friends)


## 이 친구 호감 오르는 배율 (소속 방 보너스를 받는 자리에 있으면 1.5). 메타가 호감을 더할 때 곱해 씀 (docs/app-notes.md)
func aff_mult(id: String) -> float:
	var rid := where(id)
	if rid == "" or not group_bonus(rid) or cfg.friends[id].group != cfg.room_by_id[rid].group:
		return 1.0
	return float(cfg.rules.group_bonus.aff_mult)


## 친구를 톡: 하루 한 번 쓰다듬기(호감, 미션 pat) + 한마디. 관계 있는 친구가 같은 방에 있으면 가끔 둘이 주고받음
## → { talk: [[말한 친구 id, 대사]], pat: 쓰다듬기가 들어갔는지 }
func tap(room_id: String, id: String) -> Dictionary:
	var out := {talk = [], pat = false}
	if not id in room(room_id).friends:
		return out
	if meta.can_pat(id):
		var before := meta.aff_pts(id)
		meta.pat(id)
		out.pat = true
		var extra := roundi((meta.aff_pts(id) - before) * (aff_mult(id) - 1.0))
		if extra > 0:
			meta.aff_add(id, extra)
	out.talk = _talk(room_id, id, "tap", float(cfg.rules.pair_talk_chance))
	return out


## 한마디 또는 (관계 있는 친구가 같은 방이면 chance로) 둘이 주고받는 대화
func _talk(room_id: String, id: String, kind: String, chance: float) -> Array:
	var pairs := pair_talks(room_id, id)
	if not pairs.is_empty() and rng.randf() < chance:
		return pairs[rng.randi() % pairs.size()]
	var lines := cfg.friend_lines(id, kind)
	return [[id, lines[rng.randi() % lines.size()]]] if not lines.is_empty() else []


## 이 친구와 관계 있는 친구가 같은 방에 있을 때 나올 대화들
func pair_talks(room_id: String, id: String) -> Array:
	var here: Array = room(room_id).friends
	return cfg.pairs.filter(func(p): return (p.a == id and p.b in here) or (p.b == id and p.a in here)) \
		.map(func(p): return cfg.pair_talk(p))


## 선물 줄 때 방장 한마디
func gift_line(room_id: String) -> String:
	return cfg.friend_lines(leader(room_id), "gift")[0] if leader(room_id) != "" else ""


# ---------- 생활 연출 (구경 모드, 저장 안 함) ----------

## 다음 생활 연출까지 기다릴 초
func idle_wait() -> float:
	var r: Array = cfg.rules.life.every_sec
	return rng.randf_range(float(r[0]), float(r[1]))


## 방 친구 한 명이 할 일 하나: { id, walk: 걸어갈 자리 Vector2i 또는 null, talk: [[id, 대사]] } (친구가 없으면 {})
## 걷기 아니면 혼잣말, 관계 있는 친구가 같은 방이면 가끔 둘이 대화
func idle_beat(room_id: String) -> Dictionary:
	var here: Array = room(room_id).friends
	if here.is_empty():
		return {}
	var life: Dictionary = cfg.rules.life
	var id: String = here[rng.randi() % here.size()]
	if rng.randf() < float(life.walk):
		return {id = id, walk = wander_spot(room_id, id), talk = []}
	return {id = id, walk = null, talk = _talk(room_id, id, "idle", float(life.pair))}


## 자기 자리(끌어다 놓은 곳) 둘레 wander 안에서 아무 데나 (바닥 안)
func wander_spot(room_id: String, id: String) -> Vector2i:
	var home := friend_pos(room_id, id)
	var w: Array = cfg.rules.life.wander
	var x := home.x + rng.randi_range(-int(w[0]), int(w[0]))
	var y := home.y + rng.randi_range(-int(w[1]), int(w[1]))
	return Vector2i(clampi(x, FRIEND_X.x, FRIEND_X.y), clampi(y, FRIEND_Y.x, FRIEND_Y.y))
