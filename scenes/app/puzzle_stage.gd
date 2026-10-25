extends Control







const GOAL_CHIP: = preload("res://scenes/board/goal_chip.tscn")
const IDLE_HINT_SEC: = 6.0
const STAR_ON: = preload("res://ui/screens/art/star_on.png")
const STAR_OFF: = preload("res://ui/screens/art/star_off.png")
const DANGER: = Color("ff6b6b")
const DIORAMA_MIN: = 110.0

var n: = 1
var stage: Dictionary
var game: BoardGame
var party: Array = []
var _done: = false
var _tutoring: = false
var _lit: = 0
var _danger: Tween
var _seen_events: Array = []

@onready var _board: BoardView = %BoardView
@onready var _area: Control = %BoardArea
@onready var _tutor: Tutor = %Tutor


func _ready() -> void :
	SafeArea.apply( %Screen)
	n = int(AppState.args().get("n", 1))
	party = AppState.party()
	stage = RouteInfo.puzzle(n)
	stage.fixed_board = Tutorial.board(RouteInfo.ref(n))
	var buddy: String = stage.get("buddy", "")
	if buddy in party:
		stage.moves += RouteInfo.puzzle_rule("buddy_moves")
	%StageName.text = "%d판" % n
	%BuddyNote.text = "단짝 %s +%d" % [FriendLook.shared().name_of(buddy), RouteInfo.puzzle_rule("buddy_moves")] if buddy in party else ""
	var helper: String = buddy if buddy in party else party[0] if not party.is_empty() else ""
	%Helper.texture = FriendLook.shared().face(helper) if helper != "" else null
	%ScoreBar.resized.connect(_place_marks)
	_board.fx = %Fx
	_board.changed.connect(_refresh)
	_board.changed.connect(_on_moved)
	_board.message.connect(_banner)
	_board.finished.connect(_on_finished)
	%PauseOverlay.give_up.connect(_give_up)
	%Idle.timeout.connect(_hint)
	%AdContinue.pressed.connect(_continue.bind(true))
	%CoinContinue.pressed.connect(_continue.bind(false))
	%Stop.pressed.connect( func():
		%Continue.hide()
		_finish(false))
	%Continue.hide()
	game = BoardGame.new()
	game.start(stage)
	_put_start_items(AppState.meta().take_start_items())
	for g in stage.goals:
		var chip: GoalChip = GOAL_CHIP.instantiate()
		%Goals.add_child(chip)
		chip.get_node("Icon").custom_minimum_size = Vector2(86, 86)
		chip.get_node("Count").add_theme_font_size_override("font_size", 36)
	AppState.begin_stage(RouteInfo.ref(n))
	AppSound.bgm("puzzle_%d" % (RouteInfo.chapter_of(n) % 3 + 1))
	await get_tree().process_frame
	_board.setup(game, _area.size)
	_board.position = Vector2(floorf((_area.size.x - _board.size.x) / 2), _area.size.y - _board.size.y - 12)
	var gap: = _board.position.y - 24.0
	%Diorama.visible = gap >= DIORAMA_MIN
	if %Diorama.visible:
		%Diorama.position = Vector2.ZERO
		%Diorama.size = Vector2(_area.size.x, gap)
		%Diorama.setup(RouteInfo.chapter_of(n), party)
	else:
		_board.position = ((_area.size - _board.size) / 2).floor()
	%BoardBack.position = _board.position - Vector2(12, 12)
	%BoardBack.size = _board.size + Vector2(24, 24)
	_place_marks()
	_refresh()
	if Tutorial.has(RouteInfo.ref(n)):
		_tutoring = true
		await Tutorial.run(_tutor, RouteInfo.ref(n), {board = _board, goals = %GoalsCard, moves = %LimitCard}, _board.changed)
		_tutoring = false
	%Idle.start(IDLE_HINT_SEC)



func _put_start_items(kinds: Array) -> void :
	if kinds.is_empty():
		return
	var b: = game.board
	var spots: = b.cells().filter( func(q):
		var t: = b.at(q)
		return t.type >= 0 and t.special == &"" and Board.movable(t))
	for k in kinds:
		if spots.is_empty():
			break
		var t: = b.at(spots.pop_at(b.rng.randi_range(0, spots.size() - 1)))
		t.special = StringName(k)
		t.type = BoardTile.ITEM
	AppState.toast("포장해 둔 아이템을 깔고 시작!")


func _refresh() -> void :
	%Moves.text = str(game.moves)
	%Score.text = str(game.score)
	_set_danger(game.moves <= 3 and not game.over)
	var top: = _bar_top()
	%ScoreBar.value = minf(1.0, game.score / top)
	var lit: int = stage.stars.filter( func(t): return game.score >= int(t)).size()
	while _lit < lit:
		var star: TextureRect = %Marks.get_child(_lit)
		star.texture = STAR_ON
		star.pivot_offset = star.size / 2
		star.create_tween().tween_property(star, "scale", Vector2.ONE * 1.15, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_lit += 1
	var chips: = %Goals.get_children()
	for i in stage.goals.size():
		var g: Dictionary = stage.goals[i]
		chips[i].set_goal(_board.art.goal_icon(g), game.remain(g), "점수 " if g.k == "score" else "")



func _bar_top() -> float:
	return maxf(1.0, float(stage.stars[2]) * 1.12)



func _place_marks() -> void :
	var w: float = %ScoreBar.size.x
	var marks: = %Marks.get_children()
	for k in marks.size():
		marks[k].position.x = w * float(stage.stars[k]) / _bar_top() - marks[k].size.x / 2



func _set_danger(on: bool) -> void :
	if on == (_danger != null):
		return
	var card: Control = %LimitCard
	card.self_modulate = DANGER if on else Color.WHITE
	for l: Label in [ %Moves, %MovesTitle]:
		if on:
			l.add_theme_color_override("font_color", Color.WHITE)
		else:
			l.remove_theme_color_override("font_color")
	%Diorama.worry(on)
	if on:
		_danger = AppFx.pulse(card, 600.0)
	else:
		_danger.kill()
		_danger = null
		card.scale = Vector2.ONE



func _react() -> void :
	var ev: Array = game._events
	if not %Diorama.visible or ev.is_empty() or is_same(ev, _seen_events):
		return
	_seen_events = ev
	var combo: = 0
	var burst: = false
	for e: Dictionary in ev:
		if e.kind == "step":
			combo = maxi(combo, int(e.combo))
			burst = burst or not e.res.get("effects", []).is_empty()
		elif e.kind in ["activate", "combo"]:
			burst = true
	if burst:
		%Diorama.surprised()
	elif combo >= 3:
		%Diorama.combo()



func _a_move() -> Array:
	for m in BattleBot.moves(game.board):
		if m.size() == 2:
			return m
	return []


func _on_moved() -> void :
	_react()
	if not _tutoring:
		_tutor.clear()
		%Idle.start(IDLE_HINT_SEC)


func _hint() -> void :
	if _tutoring or _board.busy or game.over:
		return
	var m: = _a_move()
	if m.is_empty():
		return
	_tutor.point_move(_board.cell_center(m[0]), _board.cell_center(m[1]))
	for p: Vector2i in m:
		var v: TileView = _board._view(game.board.at(p))
		if v:
			v.anim([{}, {t = 0.25, s = 1.08, r = -6.0}, {t = 0.5, s = 1.08, r = 6.0}, {t = 0.75, s = 1.08, r = -6.0}, {}], 800.0, "ease")



func _banner(text: String) -> void :
	var pic: = WordArt.of(text)
	if pic:
		var r: TextureRect = %BannerPic
		r.texture = pic
		r.show()
		AppFx.play(r, [{s = 0.0, r = -8.0}, {t = 0.12, s = 1.2, r = 3.0}, {t = 0.22, s = 1.0}, {t = 0.8, s = 1.0}, {y = -50.0, s = 1.1, a = 0.0}], 1050, "ease-out").tween_callback(r.hide)
		return
	var b: Label = %Banner
	b.text = text
	b.show()
	b.modulate.a = 1.0
	var tw: = b.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.tween_callback(b.hide)



func result(won: bool) -> Dictionary:
	var buddy: String = stage.get("buddy", "")
	var pop: = 0
	for k in game.tile_counts:
		pop += int(game.tile_counts[k])
	return {kind = "route", ref = RouteInfo.ref(n), won = won, stars = game.stars() if won else 0, team = party, 
		mvp = buddy if buddy in party else party[0] if not party.is_empty() else "", score = game.score, counts = {pop = pop}}


func _on_finished(won: bool, _stars: int) -> void :
	_refresh()
	_tutor.clear()
	%Idle.stop()
	if not won:
		_offer_continue()
		return
	AppSound.vibrate(60)
	await get_tree().create_timer(0.3).timeout
	%Diorama.cheer()
	await %ClearShow.play("다 지웠다!", FriendLook.shared().sticker(result(true).mvp), %Fx)
	_finish(true)



func _offer_continue() -> void :
	var m: = AppState.meta()
	var price: = _continue_price()
	%AdContinue.text = "광고 보고 +%d수 (오늘 %d번)" % [RouteInfo.puzzle_rule("continue_moves"), AppAds.left("continue")]
	%AdContinue.disabled = not AppAds.can("continue")
	%CoinContinue.text = "코인 %d으로 +%d수" % [price, RouteInfo.puzzle_rule("continue_moves")]
	%CoinContinue.disabled = m.data.coins < price and m.item_n("continue") <= 0
	%Continue.show()
	var p: Control = %Panel
	p.modulate.a = 0.0
	await get_tree().process_frame
	AppFx.pop_small(p)


func _continue_price() -> int:
	for s in AppState.meta().cfg.economy.shop:
		if s.id == "continue":
			return int(s.price)
	return 0


func _continue(by_ad: bool) -> void :
	var m: = AppState.meta()
	if by_ad:
		if not await AppAds.watch("continue"):
			AppState.toast("광고를 끝까지 못 봤어")
			return
	elif not ((m.item_n("continue") > 0 or m.buy_item("continue")) and m.use_item("continue")):
		return
	%Continue.hide()
	game.over = false
	game.moves += RouteInfo.puzzle_rule("continue_moves")
	_refresh()
	%Idle.start(IDLE_HINT_SEC)


func _give_up() -> void :
	if _board.busy:
		return
	_finish(false)


func _finish(won: bool) -> void :
	if _done:
		return
	_done = true
	var r: = result(won)
	AppState.end_stage()
	var out: = AppState.meta().finish_stage(r)
	AppState.go("result", {n = n, won = won, stars = r.stars, score = game.score, out = out, mvp = r.mvp})



func back() -> void :
	if %Continue.visible:
		%Stop.pressed.emit()
	elif not _done:
		%PauseOverlay.toggle()



func pause() -> void :
	if not _done and not %Continue.visible and not %PauseOverlay.is_open():
		%PauseOverlay.open()
