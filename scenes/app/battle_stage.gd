extends Control





const BATTLE_PLAY: = preload("res://scenes/battle/battle_play.tscn")
const RAMEN: = preload("res://scenes/app/ramen.gd")

var n: = 1
var play: Control
var _done: = false


func _ready() -> void :
	SafeArea.apply( %Screen)
	SafeArea.apply( %Holder)
	n = int(AppState.args().get("n", 1))
	var m: = AppState.meta()
	var party: = AppState.party()
	play = BATTLE_PLAY.instantiate()
	play.battle_id = RouteInfo.ref(n)
	play.team_ids = PackedStringArray(party)
	play.level = party.reduce( func(s, id): return s + m.lv(id), 0) / float(maxi(1, party.size()))
	var buff: = m.take_battle_buff()
	var mult: = {}
	for id in party:
		mult[id] = m.mult(id)
	play.opts = {team_hp = buff.team_hp, gauge_fill = buff.gauge_fill, mult = mult}
	if buff.bowl != "":
		AppState.toast("%s 먹고 왔다! %s" % [RAMEN.BOWL_NAME.get(buff.bowl, ""), RAMEN.BOWL_DESC.get(buff.bowl, "")])
	play.art = _with_cutins(play.art, party)
	%Holder.add_child(play)
	var view: BattleBoardView = play.get_node("%BoardView")
	view.finished.connect(_on_finished)
	view.battle_event.connect(_on_event)
	%StageName.text = "%d판 토벌" % n
	%PauseOverlay.give_up.connect(_give_up)
	AppState.begin_stage(RouteInfo.ref(n))
	var boss: bool = BattleData.battle(RouteInfo.ref(n)).waves.any( func(w): return w.get("boss", false))
	AppSound.bgm("boss" if boss else "raid_%d" % (RouteInfo.chapter_of(n) % 2 + 1))
	if Tutorial.has(RouteInfo.ref(n)):
		await get_tree().process_frame
		await get_tree().process_frame
		await Tutorial.run( %Tutor, RouteInfo.ref(n), {party = play.get_node("%Party"), monsters = play.get_node("%Monsters")}, view.changed)


func _on_event(e: Dictionary) -> void :
	match e.kind:
		"mon_attack":
			AppSound.vibrate(50)



func _with_cutins(art: BattleArt, party: Array) -> BattleArt:
	var a: BattleArt = art.duplicate()
	a.cutins = art.cutins.duplicate()
	for id in party:
		var t: = FriendLook.shared().cutin(id)
		if t:
			a.cutins[id] = t
	return a


func _on_finished(won: bool, _stars: int) -> void :
	play.get_node("%Result").hide()
	%Tutor.clear()
	if won:
		AppSound.vibrate(60)
	await get_tree().create_timer(0.6).timeout
	_finish(won)


func _give_up() -> void :
	if play.get_node("%BoardView").busy:
		return
	_finish(false)


func _finish(won: bool) -> void :
	if _done:
		return
	_done = true
	var r: Dictionary = play.game.result()
	r.won = won and play.game.won
	if not r.won:
		r.stars = 0
	AppState.end_stage()
	var out: = AppState.meta().finish_stage(r)
	AppState.go("result", {n = n, won = r.won, stars = r.stars, out = out, hp_ratio = r.hp_ratio, turns = r.turns})


func back() -> void :
	if not _done:
		%PauseOverlay.toggle()


func pause() -> void :
	if not _done and not %PauseOverlay.is_open():
		%PauseOverlay.open()
