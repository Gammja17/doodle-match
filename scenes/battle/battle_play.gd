extends Control




const MON_CARD: = preload("res://scenes/battle/mon_card.tscn")
const PARTY_SLOT: = preload("res://scenes/battle/party_slot.tscn")
const DEBUFF_TEXT: = {"sleep": "쿨쿨… 친구 하나가 잠듦", "poison": "독! 3턴 동안 조금씩", "weak": "어둠! 2턴 동안 공격 약해짐", 
	"drain": "게이지를 뺏겼어", "ink_spit": "잉크를 뱉었다!", "stomp": "쿵쿵! 판이 뒤섞임"}

@export var battle_id: = "b008"
@export var team_ids: PackedStringArray = ["f06", "f05", "f01", "f10", "f03"]
@export var level: = 4.0
@export var art: BattleArt

var opts: = {}

var game: BattleGame

var _cards: Array = []
var _slots: Array = []
var _tiles: TileArt
var _tiles_base: TileArt
var _peck_t: = 0
var _peck_n: = 0

@onready var _board: BattleBoardView = %BoardView
@onready var _area: Control = %BoardArea
@onready var _fx: FxLayer = %Fx


func _ready() -> void :
	_fx.screen = self
	_board.fx = _fx
	_board.fly_to = _fly_to
	_board.throw_from = _throw_from
	_tiles_base = _board.art
	_board.battle_event.connect(_on_event)
	_board.changed.connect(_on_changed)
	_board.message.connect(_fx.banner)
	_board.finished.connect(_on_finished)
	%Retry.pressed.connect(start)
	%Auto.set_pressed_no_signal(AppState.meta().data.get("auto_skill", false))
	%Auto.toggled.connect(_on_auto)
	start()


func start() -> void :
	game = BattleGame.new()
	game.start(battle_id, Array(team_ids), opts.merged({lv = level}))
	%Result.hide()
	_tiles = _tiles_base.duplicate()
	_tiles.tiles = art.team_faces(game.team.map( func(f): return f.id))
	var cols: Array[Color] = []
	for f in game.team:
		cols.append(FriendLook.shared().color(f.id))
	_tiles.colors = cols
	_board.art = _tiles
	for n in %Party.get_children():
		n.queue_free()
	_slots = []
	for j in game.real:
		var s: PartySlot = PARTY_SLOT.instantiate()
		%Party.add_child(s)
		s.setup(j, game.team[j], game.need[j], _tiles.tiles[j], art.attr_icons.get(game.team[j].attr), cols[j])
		s.pressed.connect(_on_skill)
		_slots.append(s)
	_build_mons()
	%Pic.texture = _scenery()
	await get_tree().process_frame
	_board.setup(game, _area.size)
	_board.position = ((_area.size - _board.size) / 2).floor()
	%BoardBack.position = _board.position - Vector2(12, 12)
	%BoardBack.size = _board.size + Vector2(24, 24)
	_refresh()
	_board.busy = true
	_appear_cards()
	await _board.drop_in("토벌 시작!")
	_board.busy = false




func _scenery() -> Texture2D:
	var p: = StoryDB.bg_path(StoryDB.default_bg("before:" + battle_id))
	if not ResourceLoader.exists(p):
		var strip: = "res://art/puzzle_strips/%s.jpg" % StoryDB.chapter_of("before:" + battle_id)
		if ResourceLoader.exists(strip):
			return load(strip)
		p = StoryDB.bg_path(StoryDB.default_bg("prologue"))
	var t: Texture2D = load(p)
	var band: = AtlasTexture.new()
	band.atlas = t
	band.region = Rect2(0, t.get_height() * 0.18, t.get_width(), t.get_height() * 0.32)
	return band


func _build_mons() -> void :
	for n in %Monsters.get_children():
		n.queue_free()
	_cards = []
	for m in game.mons:
		var c: MonCard = MON_CARD.instantiate()
		%Monsters.add_child(c)
		c.setup(m, art)
		c.picked.connect(_on_pick)
		_cards.append(c)



func _appear_cards() -> void :
	await get_tree().process_frame
	for i in _cards.size():
		if is_instance_valid(_cards[i]):
			_cards[i].appear(i * 120.0)
	_fx.sfx("popup")


func _target_card() -> MonCard:
	var t: = game.target()
	return null if t.is_empty() or t.index >= _cards.size() else _cards[t.index]


func _throw_from() -> Vector2:
	var c: = _target_card()
	return c.art_center() if c else get_global_rect().get_center()



func _fly_to(t: BoardTile) -> Dictionary:
	if t.type < 0 or t.type >= game.team.size():
		return {}
	if game.team[t.type].has("heal"):
		return {at = _team_center(), hit = _bar_bump}
	var c: = _target_card()
	return {} if c == null else {at = c.art_center(), hit = _peck.bind(c)}



func _peck(c) -> void :
	var now: = Time.get_ticks_msec()
	if now - _peck_t < 45 or not is_instance_valid(c):
		return
	_peck_n = 0 if now - _peck_t > 600 else _peck_n + 1
	_peck_t = now
	c.peck()
	_fx.sfx("hit", 1.15 + mini(_peck_n, 8) * 0.05)


func _bar_bump() -> void :
	var bar: Control = %TeamHp
	Juice.play(bar, bar.position, [{s = 1.0}, {s = 1.05}, {s = 1.0}], 140.0)



func _on_changed() -> void :
	if not _board.busy:
		_refresh()
		if not game.over:
			get_tree().create_timer(0.3).timeout.connect(_auto_skill)


func _on_skill(slot: int) -> void :
	if _board.busy or game.over or not game.can_skill(slot):
		_slots[slot].shake()
		_fx.sfx("error", 1.2)
		return
	await _board.play(game.use_skill(slot))



func _on_auto(on: bool) -> void :
	AppState.meta().data.auto_skill = on
	AppState.save()
	_fx.sfx("button")
	_auto_skill()


func _auto_skill() -> void :
	if _board.busy or game.over or not AppState.meta().data.get("auto_skill", false):
		return
	for j in game.real:
		if game.can_skill(j):
			_on_skill(j)
			return


func _on_pick(i: int) -> void :
	if _board.busy:
		return
	game.set_target(i)
	_fx.sfx("pop", 1.3)
	_refresh()



func _on_event(e: Dictionary) -> void :
	match e.kind:
		"hit":
			_hit(e)
		"mon_dead":
			_dead(e.mon)
		"mon_heal":
			_cards[e.mon].set_hp(e.left)
			_fx.float_num(_cards[e.mon].art_center(), "+%d" % e.amt, Color("3fae4f"))
			_fx.burst(_cards[e.mon].art_center(), Color("8fe0a0"), 10)
			_fx.sfx("heal")
		"mon_attack":
			_attack(e)
		"heal", "team_heal":
			_set_team_hp(e.hp)
			_fx.float_num(_team_center() - Vector2(0, 10), "+%d" % e.amt, Color("3fae4f"), e.kind == "team_heal")
			_fx.sfx("heal", 1.2)
		"poison":
			_set_team_hp(e.hp)
			_fx.float_num(_team_center() - Vector2(0, 10), "-%d" % e.dmg, Color("9b5bd6"))
			_fx.sfx("error", 1.3)
		"gauge":
			for j in game.real:
				_slots[j].set_gauge(e.gauge[j], game.need[j])
		"skill":
			_skill(e.slot)
		"fever":
			_fx.fever_show("공격 ×1.5")
		"delay":
			_fx.banner("공격 %d턴 늦춤" % e.n, 450)
		"debuff":
			if DEBUFF_TEXT.has(e.debuff):
				_fx.banner(DEBUFF_TEXT[e.debuff], 650)
			_fx.burst(_team_center(), Color("9b5bd6"), 8)
			_fx.sfx("error")
		"wave":
			_build_mons()
			_fx.banner("웨이브 %d" % (e.index + 1), 400)
			_appear_cards()



func _hit(e: Dictionary) -> void :
	var card: MonCard = _cards[e.mon]
	card.set_hp(e.left)
	card.hurt()
	var S: = _fx.S
	var k: = _fx.k
	var c: = card.art_center()
	var w: = card.size.x
	var at: = c + Vector2((randf() - 0.5) * w * 0.6, - S * 0.1 + (randf() - 0.5) * 30.0 * k)
	var color: Color = BattleArt.ATTR_COLOR.get(game.team[e.slot].attr, Color.WHITE)
	var ang: = -35.0 + (randf() - 0.5) * 50.0
	_fx.kp("slash_03", at, S * 1.8, color, [{r = ang, sx = 0.0, a = 1.0}, {t = 0.4, r = ang, sx = 1.0, a = 1.0}, {r = ang, sx = 1.1, sy = 0.2, a = 0.0}], 260.0, "ease-out")
	_fx.ring(at, (150.0 if e.crit else 90.0) * k, Color("ffd84d") if e.crit else Color.WHITE, 300.0)
	_fx.burst(at, color, 5)


	_fx.float_num(Vector2(at.x, c.y + 54.0 * k), str(e.dmg) + ("!" if e.eff > 1.0 else ""), color, e.crit or e.eff > 1.0)
	_fx.sfx("hit", 1.0 + randf() * 0.15)
	if e.crit or e.eff > 1.0:
		_fx.stop(90 if e.crit else 50)
		_fx.zoom(c, 1.025, 160.0)
		_fx.flash(Color.WHITE, 0.25)
	if e.crit:
		_fx.shake(5, 200)



func _dead(i: int) -> void :
	var card: MonCard = _cards[i]
	var c: = card.art_center()
	var last: = true
	for j in _cards.size():
		if j != i and _cards[j].shown_hp() > 0:
			last = false
	_fx.sfx("enemy_defeat", 1.0 if last else 1.25)
	if last:
		_fx.stop(120)
		_fx.zoom(c, 1.14, 900.0)
		_fx.slow(500, 0.35)
		_fx.shake(10, 320)
		_fx.burst(c, Color("ffcf3f"), 16)
		_fx.burst(c, Color.WHITE, 12)
		card.die_big()
	else:
		_fx.burst(c, Color("ffcf3f"), 10)
		_fx.shake(5, 200)
		card.die_small()



func _attack(e: Dictionary) -> void :
	_cards[e.mon].lunge()
	_fx.sfx("enemy_attack", 0.85)
	await get_tree().create_timer(0.33).timeout
	_fx.sfx("enemy_attack")
	_fx.flash()
	_fx.shake(12, 380)
	_set_team_hp(e.hp)
	_fx.float_num(_team_center() - Vector2(0, 10), "-%d" % e.dmg, Color("e2543f"), true)
	var party: Control = %Party
	var k: = _fx.k
	Juice.play(party, party.position, [{x = -6 * k}, {x = 6 * k}, {}], 240.0)



func _skill(slot: int) -> void :
	_slots[slot].set_gauge(0, game.need[slot])
	_slots[slot].punch()
	var color: Color = _tiles.colors[slot]
	if AppPrefs.get_value("skill_cutin"):
		await %CutIn.play(art.cutins.get(game.team[slot].id, _tiles.tiles[slot]), color, _fx, _skill_name(slot), _skill_pic(slot))
	_board.start_aura(color)



func _skill_name(slot: int) -> String:
	var sid: String = game.skills[slot].get("id", "")
	var rid: = FriendLook.shared().rid(game.team[slot].id)
	return JoinCard._s("char.%s.skill%s.name" % [rid, sid.get_slice("_s", 1)])



func _skill_pic(slot: int) -> Texture2D:
	var sid: String = game.skills[slot].get("id", "")
	return WordArt.skill(FriendLook.shared().rid(game.team[slot].id), sid.get_slice("_s", 1))


func _set_team_hp(v: int) -> void :
	%TeamHp.value = v


func _team_center() -> Vector2:
	return %TeamHp.get_global_rect().get_center()



func _refresh() -> void :
	if _cards.size() != game.mons.size() or ( not _cards.is_empty() and _cards[0].index != game.mons[0].index):
		_build_mons()
	var t: = game.target()
	for i in game.mons.size():
		var m: Dictionary = game.mons[i]
		_cards[i].set_hp(m.hp)
		_cards[i].set_cd(m.cd)
		_cards[i].set_picked(game.mons.size() > 1 and not t.is_empty() and t.index == i)
	%TeamHp.max_value = game.hp_max
	_set_team_hp(game.hp)
	for j in game.real:
		_slots[j].set_gauge(game.gauge[j], game.need[j])
		_slots[j].set_asleep(game.asleep(j))
	var tags: = []
	if game.fever > 0:
		tags.append("피버 %d" % game.fever)
	if game.rally > 0:
		tags.append("응원 %d" % game.rally)
	if game.poison > 0:
		tags.append("독 %d" % game.poison)
	if game.weak > 0:
		tags.append("어둠 %d" % game.weak)
	if not game.sleep.is_empty():
		tags.append("잠 %d" % game.sleep.values().max())
	%Status.text = "  ".join(PackedStringArray(tags))
	%Wave.text = "웨이브 %d / %d" % [mini(game.wave + 1, game.stage.waves.size()), game.stage.waves.size()]


func _on_finished(won: bool, stars: int) -> void :
	_refresh()
	var r: = game.result()
	if won:
		await %ClearShow.play("토벌 성공!", _mvp_face(r.mvp), _fx)
	else:
		_fx.banner("후퇴…", 600)
		_fx.jingle("lose")
		await get_tree().create_timer(1.0).timeout
	%ResultTitle.text = "토벌 성공!" if won else "후퇴…"
	%ResultStars.text = ("★".repeat(stars) + "☆".repeat(3 - stars)) if won else "상성 좋은 친구랑 다시 가 보자"
	%ResultHp.text = "남은 체력 %d%%  ·  %d턴" % [roundi(r.hp_ratio * 100), r.turns]
	%Result.show()



func _mvp_face(id: String) -> Texture2D:
	for j in game.real:
		if game.team[j].id == id:
			return _tiles.tiles[j]
	return _tiles.tiles[0]
