class_name RoomView
extends Control
## 방 한 칸 그림: 벽·바닥 색, 휘갈김 자국, 가구, 친구, 의뢰판, 가구 도구(돌리기·넣기).
## Guild는 읽기만 하고, 바꾸는 일은 신호로 GuildHouse에 넘김. 자리는 Guild 천분율 ↔ 이 방 px.

signal furniture_tapped(index: int)
signal furniture_dropped(index: int, at: Vector2i)
signal friend_tapped(id: String)
signal friend_dropped(id: String, at: Vector2i)
signal flip_pressed(index: int)
signal store_pressed(index: int)
signal background_pressed

const FURN_SCENE := preload("res://scenes/guild/furniture_sticker.tscn")
const RESIDENT_SCENE := preload("res://scenes/guild/resident.tscn")
const MARK_SCENE := preload("res://scenes/guild/scribble_mark.tscn")
## 휘갈김 자국 자리 (천분율, 가운데). 자국 수만큼 앞에서부터 씀
const MARK_SPOTS := [[300, 300], [720, 200], [500, 720], [180, 840], [820, 800], [520, 440], [140, 160], [860, 480]]
const MARK_SIZE := Vector2(150, 90)  # 680px 방 기준

var tools_index := -1  # 도구가 붙은 가구 자리 (-1 = 없음)
var _furn := {}  # 가구 자리 -> FurnitureSticker
var _res := {}  # 친구 id -> Resident
var _guild: Guild
var _room_id := ""

@onready var _wall: ColorRect = $Wall
@onready var _floor: ColorRect = $Floor
@onready var _board: PanelContainer = $Board
@onready var _board_text: Label = $Board/Text
@onready var _marks: Control = $Marks
@onready var _things: Control = $Things
@onready var _tools: PanelContainer = $Tools
@onready var _hint: Label = $Hint
@onready var _life: Timer = $Life


func _ready() -> void:
	%Flip.pressed.connect(func(): flip_pressed.emit(tools_index))
	%Store.pressed.connect(func(): store_pressed.emit(tools_index))
	_life.timeout.connect(life_beat)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		background_pressed.emit()


func to_px(v: Vector2i) -> Vector2:
	return Vector2(v.x * size.x / 1000.0, v.y * size.y / 1000.0)


func to_permille(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 1000.0 / size.x), roundi(p.y * 1000.0 / size.y))


func build(guild: Guild, room_id: String, editing: bool) -> void:
	_guild = guild
	_room_id = room_id
	var cfg := guild.cfg
	var r: Dictionary = cfg.room_by_id[room_id]
	var rm := guild.room(room_id)
	_wall.color = Color(cfg.walls[rm.wall].color if rm.wall != "" else r.wall_color)
	_floor.color = Color(cfg.floors[rm.floor].color if rm.floor != "" else r.floor_color)
	_hint.visible = editing
	_board.visible = r.get("board", false)
	if _board.visible:
		var m := guild.meta
		_board_text.text = "의뢰판\n오늘 의뢰 %d/%d" % [m.missions().done.size(), m.missions().ids.size()] \
			if m.missions_on() else "의뢰판\n준비 중"

	_clear(_marks)
	for k in guild.marks_left(room_id):
		_add_mark(k)

	_clear(_things)
	_furn.clear()
	_res.clear()
	for i in rm.items.size():
		var it: Dictionary = rm.items[i]
		var f: Dictionary = cfg.furn.get(it.k, {})
		if f.is_empty():
			continue
		var s: FurnitureSticker = FURN_SCENE.instantiate()
		_things.add_child(s)
		s.setup(i, f, size.x / 1000.0, it.f, editing)
		s.set_foot(to_px(Vector2i(it.x, it.y)))
		var kind: String = f.kind
		var top := roundi(s.size.y * 1000.0 / size.y) + 10  # 그림 윗부분이 방 위로 잘리지 않게
		s.clamp_foot = func(p: Vector2) -> Vector2:
			var v := _clamp_furn(kind, to_permille(p))
			return to_px(Vector2i(v.x, maxi(v.y, mini(top, Guild.Y_RANGE[kind].y))))
		s.tapped.connect(func(idx): furniture_tapped.emit(idx))
		s.dropped.connect(func(idx, p): furniture_dropped.emit(idx, to_permille(p)), CONNECT_DEFERRED)  # 다시 그려도 되게
		_furn[i] = s
		s.set_meta("order", {wall = 0, flat = 1000}.get(kind, 2000 + it.y) + i * 0.001)
	for id in rm.friends:
		var n: Resident = RESIDENT_SCENE.instantiate()
		_things.add_child(n)
		n.setup(id, cfg.friends.get(id, {}), id == guild.leader(room_id), not editing)
		var p := guild.friend_pos(room_id, id)
		n.set_foot(to_px(p))
		n.clamp_foot = func(q: Vector2) -> Vector2: return to_px(_clamp_friend(to_permille(q)))
		n.tapped.connect(func(fid): friend_tapped.emit(fid))
		n.dropped.connect(func(fid, q): friend_dropped.emit(fid, to_permille(q)), CONNECT_DEFERRED)
		_res[id] = n
	_resort()
	show_tools(tools_index if editing else -1)
	# 생활 연출: 구경 모드에서만 친구들이 돌아다니고 혼잣말
	_life.stop()
	if not editing and not rm.friends.is_empty():
		_life.start(guild.idle_wait())


## 그리는 순서: 벽 → 러그 → 바닥 가구·친구는 발밑이 아래일수록 앞 (친구가 걸으면 다시 맞춤)
func _resort() -> void:
	var order := []
	for c in _things.get_children():
		var key: float = c.get_meta("order") if c.has_meta("order") else 2000.0 + to_permille((c as Control).position + Vector2(c.size.x / 2.0, c.size.y)).y + 0.5
		order.append([key, c])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for k in order.size():
		_things.move_child(order[k][1], k)


## 생활 연출 한 번: 친구 한 명이 걷거나 말함 (Life 타이머가 부름, 테스트에서 바로 불러도 됨) → 한 일
func life_beat() -> Dictionary:
	if _guild == null or _res.is_empty():
		return {}
	var b := _guild.idle_beat(_room_id)
	var n: Resident = _res.get(b.get("id", ""))
	if n == null or n.is_dragging():
		b = {}
	elif b.walk != null:
		n.walk_to(to_px(b.walk), float(_guild.cfg.rules.life.walk_speed) * size.x / 1000.0, _resort)
	else:
		for k in b.talk.size():
			say(b.talk[k][0], b.talk[k][1], k * 1.2)
	_life.start(_guild.idle_wait())
	return b


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _clamp_furn(kind: String, v: Vector2i) -> Vector2i:
	var yr: Vector2i = Guild.Y_RANGE[kind]
	return Vector2i(clampi(v.x, Guild.X_RANGE.x, Guild.X_RANGE.y), clampi(v.y, yr.x, yr.y))


func _clamp_friend(v: Vector2i) -> Vector2i:
	return Vector2i(clampi(v.x, Guild.FRIEND_X.x, Guild.FRIEND_X.y), clampi(v.y, Guild.FRIEND_Y.x, Guild.FRIEND_Y.y))


func furniture_count() -> int:
	return _furn.size()


func furniture_node(i: int) -> FurnitureSticker:
	return _furn.get(i)


func resident(id: String) -> Resident:
	return _res.get(id)


func mark_count() -> int:
	return _marks.get_children().filter(func(m): return not m.has_meta("erasing")).size()


# ---------- 가구 도구 ----------

## i번 가구 위에 돌리기·넣기 (i < 0이면 닫음)
func show_tools(i: int) -> void:
	tools_index = i if _furn.has(i) else -1
	_tools.visible = tools_index >= 0
	if not _tools.visible:
		return
	var s: FurnitureSticker = _furn[tools_index]
	var ts := _tools.get_combined_minimum_size()
	var p := s.position + Vector2((s.size.x - ts.x) / 2.0, -ts.y - 8.0)
	if p.y < 4.0:
		p.y = s.position.y + s.size.y + 8.0  # 위에 자리가 없으면 아래에
	_tools.position = p.clamp(Vector2(4, 4), size - ts - Vector2(4, 4))


# ---------- 말풍선·연출 ----------

func say(id: String, line: String, delay := 0.0) -> void:
	if _res.has(id):
		_res[id].say(line, delay)


func jelly(id: String) -> void:
	if _res.has(id):
		_res[id].jelly()


func _add_mark(k: int) -> TextureRect:
	var m: TextureRect = MARK_SCENE.instantiate()
	_marks.add_child(m)
	m.size = MARK_SIZE * size.x / 680.0
	m.pivot_offset = m.size / 2.0
	var spot: Array = MARK_SPOTS[k % MARK_SPOTS.size()]
	m.position = to_px(Vector2i(spot[0], spot[1])) - m.size / 2.0
	m.rotation = (k % 3 - 1) * 0.18
	return m


## 휘갈김 자국이 left_before개에서 left_now개로 줄었을 때, 줄어든 자국을 지우개로 지우는 연출
func erase_marks(left_before: int, left_now: int) -> void:
	for k in range(left_now, left_before):
		var m := _add_mark(k)
		m.set_meta("erasing", true)
		m.material.set_shader_parameter("progress", 0.0)
		var tw := m.create_tween()
		tw.tween_property(m, "material:shader_parameter/progress", 1.0, 0.7)
		tw.tween_callback(m.queue_free)
