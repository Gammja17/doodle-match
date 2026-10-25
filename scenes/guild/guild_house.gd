class_name GuildHouse
extends Control
## 길드 하우스 꾸미기 화면. 위: 방 탭, 가운데: 방(RoomView), 아래: 아늑함·등급·자국, 꾸미기/친구/선물, 가게.
## 구경 모드: 친구를 톡(쓰다듬기 + 한마디)·끌기, 방장 선물 받기, 친구 놓기.
## 꾸미기 모드: 가게에서 사서 놓기, 가구 끌기·돌리기·넣기, 벽지·바닥, 되돌리기. 친구는 그대로.
## 앱 흐름은 setup(meta)로 같은 Meta를 넘기고 closed를 받으면 됨. 혼자 띄우면 저장 파일을 읽음.

signal closed

const ROOM_TAB := preload("res://scenes/guild/room_tab.tscn")
const SHOP_CARD := preload("res://scenes/guild/shop_card.tscn")
const FRIEND_CHIP := preload("res://scenes/guild/friend_chip.tscn")
const TOAST_TIME := 1.6
const GUILD_ART := preload("res://scenes/guild/guild_art.gd")

var meta: Meta
var guild: Guild
var room_id := ""
var editing := false
var shop_tab := "furn"  # furn | wall | floor
var _toast_tw: Tween

@onready var _room: RoomView = %RoomView


func setup(p_meta: Meta, p_guild: Guild = null) -> void:
	meta = p_meta
	guild = p_guild if p_guild else Guild.new(meta)
	guild.room_completed.connect(_on_room_completed)


func _ready() -> void:
	if meta == null:
		setup(Meta.load_game())
	%Back.pressed.connect(func(): closed.emit())
	%Deco.pressed.connect(_toggle_edit)
	%Undo.pressed.connect(_on_undo)
	%Friends.pressed.connect(_open_picker)
	%Gift.pressed.connect(_on_gift)
	%PickerClose.pressed.connect(func(): %Picker.visible = false)
	%TabFurn.pressed.connect(_set_shop_tab.bind("furn"))
	%TabWall.pressed.connect(_set_shop_tab.bind("wall"))
	%TabFloor.pressed.connect(_set_shop_tab.bind("floor"))
	_room.furniture_tapped.connect(func(i): _room.show_tools(i))
	_room.furniture_dropped.connect(_on_furniture_dropped)
	_room.flip_pressed.connect(func(i): _edit(func(): return guild.flip(room_id, i), i))
	_room.store_pressed.connect(func(i): _edit(func(): return guild.store(room_id, i), -1))
	_room.background_pressed.connect(func(): _room.show_tools(-1))
	_room.friend_tapped.connect(_on_friend_tapped)
	_room.friend_dropped.connect(func(id, at): guild.move_friend(room_id, id, at.x, at.y); refresh())
	_room.resized.connect(refresh)
	var rooms := guild.open_rooms()
	open_room(rooms[-1] if not rooms.is_empty() else "")


## 방 열기 (꾸미던 중이면 그대로 꾸미기, 되돌리기 기록은 방마다 따로)
func open_room(id: String) -> void:
	room_id = id
	_room.tools_index = -1
	if editing:
		guild.begin_edit()
	refresh()


func refresh() -> void:
	if guild == null:
		return
	var open := room_id != "" and guild.room_open(room_id)
	%Locked.visible = not open
	_room.visible = open
	%Coins.text = "코인 %d" % meta.data.coins
	_fill_tabs()
	if not open:
		%Title.text = "길드 하우스"
		for n in [%InfoBar, %ModeBar, %Shop]:
			n.visible = false
		return
	%InfoBar.visible = true
	%ModeBar.visible = true
	%Title.text = guild.cfg.room_by_id[room_id].name
	%Cozy.text = "아늑함 %d" % guild.cozy(room_id)
	var nxt := guild.next_rank_cozy()
	%Rank.text = "길드 %d등급" % guild.rank() + (" (다음 %d / %d)" % [guild.guild_cozy(), nxt] if nxt >= 0 else "")
	var left := guild.marks_left(room_id)
	%Marks.text = "휘갈김 %d" % left if left > 0 else "다 고침!"
	%Deco.text = "다 했어" if editing else "꾸미기"
	%Undo.visible = editing
	%Undo.disabled = not guild.can_undo()
	%Friends.visible = not editing
	%Gift.visible = not editing and guild.can_gift(room_id)
	%Gift.text = "선물 +%d" % guild.gift_coins(room_id)
	%Shop.visible = editing
	_room.build(guild, room_id, editing)
	if editing:
		_fill_shop()


func _fill_tabs() -> void:
	var tabs: HBoxContainer = %Tabs
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	var open := guild.open_rooms()
	for r in guild.cfg.rooms:
		var on: bool = r.id in open
		if not on and not r.id in guild.locked_rooms():
			continue  # 옮겨 가서 닫힌 방 (그렌의 오두막)
		var b: Button = ROOM_TAB.instantiate()
		tabs.add_child(b)
		b.text = r.name if on else "%s · %s" % [r.name, guild.unlock_hint(r.id)]
		b.disabled = not on
		b.set_pressed_no_signal(r.id == room_id)
		b.pressed.connect(open_room.bind(r.id), CONNECT_DEFERRED)  # 탭을 다시 만들므로 신호가 끝난 뒤에


# ---------- 가게 ----------

func _set_shop_tab(tab: String) -> void:
	shop_tab = tab
	_fill_shop()


## 가게 칸: 목록이 그대로면 칸을 다시 만들지 않고 글자만 바꿈 (가구를 옮길 때마다 가게 스크롤이 처음으로 안 튀게)
func _fill_shop() -> void:
	var cfg := guild.cfg
	var cards := []  # [id, 이름, 색, 값 글자, 쓰는 중]
	if shop_tab == "furn":
		for k in guild.shop_list():
			var f: Dictionary = cfg.furn[k]
			var n := guild.left(k)
			cards.append([k, f.name, f.color, "보관 %d" % n if n > 0 else "%d코인" % f.price, false, GUILD_ART.texture(f.get("art", ""))])
	else:
		var items: Dictionary = cfg.walls if shop_tab == "wall" else cfg.floors
		var now: String = guild.room(room_id)[shop_tab]
		var base: String = cfg.room_by_id[room_id][shop_tab + "_color"]
		cards.append(["", "기본", base, "쓰는 중" if now == "" else "바꾸기", now == ""])
		for id in items:
			var d: Dictionary = items[id]
			var price := "쓰는 중" if now == id else "바꾸기" if guild.has_deco(shop_tab, id) else "%d코인" % d.price
			cards.append([id, d.name, d.color, price, now == id])
	var list: HBoxContainer = %ShopList
	var same: bool = list.get_child_count() == cards.size()
	if same:
		for k in cards.size():
			if list.get_child(k).id != cards[k][0] or not list.get_child(k).has_meta(shop_tab):
				same = false
	if not same:
		for c in list.get_children():
			list.remove_child(c)
			c.queue_free()
		for e in cards:
			var c: ShopCard = SHOP_CARD.instantiate()
			list.add_child(c)
			c.set_meta(shop_tab, true)
			c.picked.connect(_on_shop_picked)
	for k in cards.size():
		var e: Array = cards[k]
		list.get_child(k).setup(e[0], e[1], e[2], e[3], e[4], e[5] if e.size() > 5 else null)


func _on_shop_picked(id: String) -> void:
	if shop_tab == "furn":
		var before := guild.marks_left(room_id)
		var i := guild.buy_and_place(room_id, id)
		if i < 0:
			toast("코인이 모자라")
		else:
			_room.tools_index = i
			refresh()
			_room.erase_marks(before, guild.marks_left(room_id))
	elif not _edit(func(): return guild.set_deco(room_id, shop_tab, id), _room.tools_index):
		toast("코인이 모자라")
	_fill_shop()


## 꾸미기 한 동작을 하고 다시 그림. 도구는 keep_tools번 가구에 붙여 둠
func _edit(action: Callable, keep_tools: int) -> bool:
	var ok: bool = action.call()
	_room.tools_index = keep_tools
	refresh()
	return ok


func _on_furniture_dropped(i: int, at: Vector2i) -> void:
	_edit(func(): return guild.move(room_id, i, at.x, at.y), i)


func _toggle_edit() -> void:
	editing = not editing
	if editing:
		guild.begin_edit()
	else:
		guild.end_edit()
	_room.tools_index = -1
	refresh()


func _on_undo() -> void:
	if guild.undo() != "":
		_room.tools_index = -1
		refresh()


# ---------- 친구 ----------

func _on_friend_tapped(id: String) -> void:
	var r := guild.tap(room_id, id)
	_room.jelly(id)
	for k in r.talk.size():
		_room.say(r.talk[k][0], r.talk[k][1], k * 1.2)
	if r.pat:
		toast("%s 호감 올랐어" % guild.cfg.friend_name(id))


func _on_gift() -> void:
	var who := guild.leader(room_id)
	var line := guild.gift_line(room_id)
	var n := guild.take_gift(room_id)
	if n <= 0:
		return
	refresh()
	_room.say(who, line)
	toast("코인 +%d" % n)


func _open_picker() -> void:
	%Picker.visible = true
	_fill_picker()


func _fill_picker() -> void:
	var grid: GridContainer = %PickerGrid
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var rm := guild.room(room_id)
	%PickerTitle.text = "이 방에 놓을 친구 %d/%d" % [rm.friends.size(), int(guild.cfg.rules.room_max_friends)]
	for id in guild.cfg.friends:
		if not meta.owned(id):
			continue
		var chip: VBoxContainer = FRIEND_CHIP.instantiate()
		grid.add_child(chip)
		var here: bool = id in rm.friends
		var elsewhere := guild.where(id)
		var pick: Button = chip.get_node("Pick")
		pick.text = guild.cfg.friend_name(id) + ("" if here or elsewhere == "" else " (%s)" % guild.cfg.room_by_id[elsewhere].name)
		pick.set_pressed_no_signal(here)
		pick.toggled.connect(_on_pick.bind(id), CONNECT_DEFERRED)
		var lead: Button = chip.get_node("Lead")
		lead.visible = here
		lead.disabled = guild.leader(room_id) == id
		lead.text = "방장" if lead.disabled else "방장으로"
		lead.pressed.connect(_on_lead.bind(id), CONNECT_DEFERRED)


func _on_lead(id: String) -> void:
	guild.set_leader(room_id, id)
	_fill_picker()
	refresh()


func _on_pick(on: bool, id: String) -> void:
	if on and not guild.put_friend(room_id, id):
		toast("방이 꽉 찼어 (%d명)" % int(guild.cfg.rules.room_max_friends))
	elif not on:
		guild.take_friend(room_id, id)
	_fill_picker()
	refresh()


# ---------- 알림 ----------

func toast(text: String) -> void:
	var t: PanelContainer = %Toast
	t.get_node("Text").text = text
	t.visible = true
	t.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(TOAST_TIME)
	_toast_tw.tween_property(t, "modulate:a", 0.0, 0.25)
	_toast_tw.tween_callback(func(): t.visible = false)


func toast_text() -> String:
	return %Toast.get_node("Text").text if %Toast.visible else ""


func _on_room_completed(id: String, reward: Dictionary) -> void:
	var what := "별가루 +%d" % reward.stardust
	if reward.has("furniture"):
		what += ", '%s' 받음" % guild.cfg.furn[reward.furniture].name
	toast("%s 다 고쳤어! %s" % [guild.cfg.room_by_id[id].name, what])
