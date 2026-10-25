extends Control







const ROW: = preload("res://scenes/app/parts/ramen_row.tscn")
const TILE_ART: = preload("res://scenes/board/tile_art.tres")
const BG: = "res://ui/screens/art/bg_ramen.jpg"
const MASTER: = "res://ui/screens/art/ramen_master.png"
const RESIDENTS: = "res://data/guild/residents.json"

const BOWL_NAME: = {hp150 = "곱빼기", gauge_half = "진한 국물", hp150_gauge_half = "모둠 한 상"}
const BOWL_DESC: = {hp150 = "토벌 체력 150", gauge_half = "토벌 스킬 게이지 반", hp150_gauge_half = "토벌 체력 150 + 게이지 반"}
const BOWL_SAY: = {hp150 = "곱빼기다. 남기지 마라.", gauge_half = "진한 국물이다. 힘이 날 거다.", hp150_gauge_half = "모둠이다. 천천히 먹어라."}
const BOWL_ICON: = {hp150 = "res://ui/screens/art/heart.png", gauge_half = "res://ui/screens/art/bar_fill_skill.png", hp150_gauge_half = "res://ui/screens/art/chest.png"}

const ITEM_NAME: = {start_erasers = "지우개 세트", start_pushpin = "압정", start_crayon = "크레용"}
const ITEM_DESC: = {start_erasers = "퍼즐: 가로·세로 지우개 깔고 시작", start_pushpin = "퍼즐: 압정 깔고 시작", start_crayon = "퍼즐: 크레용 깔고 시작"}
const TRAIN: = {
	hp = {name = "체력 수련", icon = "res://ui/screens/art/heart.png", say = "곱빼기를 매일 먹어라. 몸이 버틴다."}, 
	atk = {name = "공격 수련", icon = "res://ui/screens/art/role_attack.png", say = "국물이 진할수록 주먹도 세진다."}, 
}

const MASTER_LINES: = [
	"왔군. 주문은 순서대로.", 
	"국물은 새벽부터 끓인다. 휘갈김은 이 냄새를 싫어하지.", 
	"부리로 뜨는 게 국자보다 빠르다.", 
	"토벌 하나 끝냈으면 한 그릇 먹고 가라.", 
	"면 굵기, 기름 양, 국물 진하기. 정하고 말해라.", 
	"가게 규칙은 지켜라. 줄 서고, 남기지 말고.", 
	"늑대 녀석, 오늘도 왔군.", 
	"그릇은 깨끗이 비우고 가라.", 
]
const SAY_SEC: = 2.6

var tab: = "ramen"
var _mi: = 0
var _say_tw: Tween
var _lines: = {}


func _ready() -> void :
	SafeArea.apply( %Screen)
	AppSound.bgm("shop")
	if ResourceLoader.exists(BG):
		%Bg.texture = load(BG)
	%Master.texture_normal = load(MASTER) if ResourceLoader.exists(MASTER) else null
	%Back.pressed.connect(back)
	for t in ["Ramen", "Train", "Pack"]:
		get_node("%Tab" + t).pressed.connect(set_tab.bind(t.to_lower()))
	%Master.pressed.connect(_master_talk)
	%GuestArt.pressed.connect(_guest_tap)
	_lines = JSON.parse_string(FileAccess.get_file_as_string(RESIDENTS)).get("friends", {})
	_seat_friends()
	_show_guest()
	set_tab(AppState.args().get("tab", "ramen"))
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	var m: = AppState.meta()
	say( %Master, "먹던 거부터 다 먹고 와라." if m.data.buff != "" else "왔군. 한 그릇은 서비스다." if int(m.data.free_bowl) > 0 else "왔군. 한 그릇 먹고 가라.")
	_intro()


func set_tab(t: String) -> void :
	tab = t
	for name in ["Ramen", "Train", "Pack"]:
		get_node("%Tab" + name).set_pressed_no_signal(name.to_lower() == t)
	for c in %Rows.get_children():
		c.queue_free()
	match t:
		"train":
			_render_train()
		"pack":
			_render_pack()
		_:
			_render_ramen()
	%TopBar.refresh()


func _row() -> Node:
	var r: = ROW.instantiate()
	%Rows.add_child(r)
	return r




func _render_ramen() -> void :
	var m: = AppState.meta()
	%MenuTitle.text = "차림표"
	for b in m.ramen_menu():
		var r: = _row()
		var kind: = "buy"
		var ticket: = "사기\n코인 %d" % int(b.price)
		var desc: String = BOWL_DESC.get(b.id, "")
		if not m.ramen_open(b):
			kind = "lock"
			ticket = "%d판\n깨면" % int(b.unlock_clears)
			desc = "%d판까지 깨면 메뉴에 나와" % int(b.unlock_clears)
		elif m.data.buff == b.id:
			kind = "use"
			ticket = "먹었다\n다음 토벌"
		elif int(m.data.free_bowl) > 0:
			kind = "free"
			ticket = "한 그릇\n서비스"
		r.setup(b.id, _tex(BOWL_ICON.get(b.id, "")), BOWL_NAME.get(b.id, b.id), desc, ticket, kind)
		r.pressed.connect(_order)
	var every: = int(m.cfg.economy.buffs.stamp_every)
	var st: = int(m.data.bowls) % every
	if m.data.buff != "":
		%Note.text = "먹은 효과: %s · 다음 토벌에서 써" % BOWL_NAME.get(m.data.buff, "")
	else:
		%Note.text = "%s도장 %s%s (%d그릇마다 간식)" % ["공짜 %d그릇 · " % int(m.data.free_bowl) if int(m.data.free_bowl) > 0 else "", "●".repeat(st), "○".repeat(every - st), every]


func _order(id: String) -> void :
	var m: = AppState.meta()
	var r: = m.eat(id)
	if not r.ok:
		AppSound.sfx("error")
		say( %Master, {locked = "그건 아직 안 판다.", has_buff = "먹던 거부터 다 먹고 와라.", coins = "코인이 모자라다. 토벌하고 와라."}[r.reason])
		return
	AppSound.sfx("coin")
	say( %Master, ("서비스다. " if r.free else "") + BOWL_SAY.get(id, ""))
	set_tab("ramen")
	if r.treat != "":
		await get_tree().create_timer(2.2).timeout
		if not is_inside_tree():
			return
		say( %Master, "도장 다섯 개다. 간식, 덤이다.")
		AppSound.sfx("star")
		_show_guest()




func _render_train() -> void :
	var m: = AppState.meta()
	var tr: Dictionary = m.cfg.economy.training
	var cap: = m.train_cap()
	%MenuTitle.text = "수련 장부"
	for id in ["hp", "atk"]:
		var lv: = int(m.data.train[id])
		var maxed: = lv >= int(tr.max_lv)
		var capped: = not maxed and lv >= cap
		var now_val: = "토벌 체력 %d" % (int(m.cfg.rules.battle.team_hp) + lv * int(tr.hp_per_lv)) if id == "hp" else "공격·회복 %s%%" % ("%.1f" % (100.0 + lv * float(tr.atk_pct_per_lv))).trim_suffix(".0")
		var desc: = "Lv%d · %s" % [lv, now_val]
		var ticket: = "수련\n코인 %d" % m.train_cost(id)
		var kind: = "buy"
		if maxed:
			ticket = "수련\n끝"
			kind = "lock"
		elif capped:
			ticket = "%d판\n깨면" % (lv * int(tr.cap_per_clears))
			kind = "lock"
		var r: = _row()
		r.setup(id, _tex(TRAIN[id].icon), TRAIN[id].name, desc, ticket, kind, "●".repeat(lv) + "○".repeat(maxi(0, cap - lv)))
		r.pressed.connect(_train)
	%Note.text = "수련은 영원히 남아 · 지금은 Lv%d까지 (%d판마다 +1)" % [cap, int(tr.cap_per_clears)]


func _train(id: String) -> void :
	var m: = AppState.meta()
	if not m.train_up(id):
		AppSound.sfx("error")
		say( %Master, "코인이 모자라다. 토벌하고 와라." if m.data.coins < m.train_cost(id) else "아직 이르다. 토벌하고 와라.")
		return
	AppSound.sfx("star")
	say( %Master, TRAIN[id].say)
	set_tab("train")




func _render_pack() -> void :
	var m: = AppState.meta()
	%MenuTitle.text = "포장 메뉴"
	for s in m.start_items():
		var r: = _row()
		var n: = m.item_n(s.id)
		r.setup(s.id, TILE_ART.get(String(s.put[0])), ITEM_NAME.get(s.id, s.id) + ("  ×%d" % n if n > 0 else ""), ITEM_DESC.get(s.id, ""), "사기\n코인 %d" % int(s.price))
		r.pressed.connect(_buy)
	%Note.text = "사 두면 다음 퍼즐 판에 깔고 시작해 (종류마다 판에 하나)"


func _buy(id: String) -> void :
	var m: = AppState.meta()
	if not m.buy_item(id):
		AppSound.sfx("error")
		say( %Master, "코인이 모자라다. 토벌하고 와라.")
		return
	AppSound.sfx("coin")
	say( %Master, "포장이다. 다음 판에 들고 가라.")
	set_tab("pack")




func _master_talk() -> void :
	say( %Master, MASTER_LINES[_mi % MASTER_LINES.size()])
	_mi += 1



func _seat_friends() -> void :
	var m: = AppState.meta()
	var own: Array = m.data.own.keys().filter( func(id): return m.owned(id) and FriendLook.shared().sticker(id) != null)
	own.shuffle()
	var seats: = %Seats.get_children()
	for i in seats.size():
		var seat: TextureButton = seats[i]
		seat.visible = i < own.size()
		if seat.visible:
			var id: String = own[i]
			seat.texture_normal = FriendLook.shared().sticker(id)
			seat.pressed.connect( func(): say(seat, _line_of(id)))


func _line_of(id: String) -> String:
	var lines: Array = _lines.get(id, {}).get("lines", [])
	return lines[randi() % lines.size()] if not lines.is_empty() else "…맛있다!"



func _show_guest() -> void :
	var g: = AppState.meta().ramen_guest()
	%Guest.visible = not g.is_empty()
	if g.is_empty():
		return
	%GuestArt.texture_normal = FriendLook.shared().sticker(g.id)
	%GuestBadge.text = "간식 %d/%d" % [mini(g.have, g.count), g.count]
	%GuestBadge.modulate = Color(1, 1, 1) if g.have >= g.count else Color(1, 1, 1, 0.85)


func _guest_tap() -> void :
	var m: = AppState.meta()
	var g: = m.ramen_guest()
	if g.is_empty():
		return
	if m.recruit(g.id):
		AppSound.sfx("star")
		AppState.toast("%s(이)가 친구가 됐어!" % FriendLook.shared().name_of(g.id))
		AppState.set_party(AppState.party() + [g.id])
		_seat_friends()
		_show_guest()
		return
	say( %GuestArt, "간식 %d개만 모아 오면… 같이 다녀 줄게!" % g.count)



func say(who: Control, text: String) -> void :
	var bubble: Control = %Say
	%SayText.text = text
	bubble.reset_size()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var shop: Control = %Shop
	var r: = who.get_global_rect()
	var at: = Vector2(r.get_center().x - bubble.size.x / 2, r.position.y - bubble.size.y - 6) - shop.global_position
	bubble.position = Vector2(clampf(at.x, 0, shop.size.x - bubble.size.x), maxf(at.y, 0))
	bubble.show()
	bubble.modulate.a = 1.0
	if _say_tw:
		_say_tw.kill()
	_say_tw = create_tween()
	_say_tw.tween_interval(SAY_SEC - 0.3)
	_say_tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	AppSound.sfx("pop")



func _intro() -> void :
	if AppState.seen("tips", "ramen_intro"):
		return
	await _guide( %TabRamen, "토벌 전에 한 그릇!\n토벌을 새로 깨면 공짜야")
	if %Guest.visible:
		await _guide( %GuestArt, "문가 손님에게\n간식을 모아 주면 친구가 돼")
	%Tutor.clear()
	AppState.mark_seen("tips", "ramen_intro")


func _guide(target: Control, text: String) -> void :
	var t = %Tutor
	if t.has_method("spot"):
		t.spot(target.get_global_rect(), text)
	else:
		t.show_tip(text)
		t.point_at(target)
	await t.wait_tap()


func _tex(path: String) -> Texture2D:
	return load(path) if path != "" and ResourceLoader.exists(path) else null


func back() -> void :
	AppState.go("map")
