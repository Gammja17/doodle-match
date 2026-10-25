extends Control






const GOAL_CHIP: = preload("res://scenes/board/goal_chip.tscn")
const TILE_ART: = preload("res://scenes/board/tile_art.tres")
const FRIEND_TILE: = preload("res://scenes/app/parts/friend_tile.tscn")
const RAMEN: = preload("res://scenes/app/ramen.gd")

var n: = 1
var party: Array = []
var _enemy_attrs: Array = []
var _buddy: = ""
var _new: Array = []

@onready var _slots: Array = %Party.get_children()


func _ready() -> void :
	SafeArea.apply( %Screen)
	n = int(AppState.args().get("n", 1))
	party = AppState.party()
	%Back.pressed.connect(AppState.go.bind("map"))
	%ToMap.pressed.connect(AppState.go.bind("map"))
	%Go.pressed.connect(_start)
	%Refill.pressed.connect(_refill)
	%AdHeart.pressed.connect(_ad_heart)
	for s in _slots:
		s.get_node("FriendIcon").picked.connect(_remove)
		s.get_node("FriendIcon").compact()
	_show_stage()
	_new = AppState.app().get("new", []).duplicate()
	if not _new.is_empty():
		AppState.app().new = []
		AppState.save()
	var m: = AppState.meta()
	for id in m.cfg.friends.friends.map( func(f): return f.id):
		if m.owned(id):
			var tile: FriendTile = FRIEND_TILE.instantiate()
			%Roster.add_child(tile)
			tile.show_friend(id, m.lv(id))
			tile.tilt(tile.get_index())
			tile.picked.connect(_add.bind(tile))
	_refresh()


func _show_stage() -> void :
	var st: = RouteInfo.stage(n)
	var battle: = RouteInfo.is_battle(n)
	%Title.text = "%d판 · %s%s" % [n, "토벌" if battle else "퍼즐", "" if st.level == "normal" else (" · 도전" if st.level == "challenge" else " · 어려움")]
	%PuzzleInfo.visible = not battle
	%BattleInfo.visible = battle
	if battle:
		var b: = BattleData.battle(RouteInfo.ref(n))
		%Waves.text = "웨이브 %d" % b.waves.size()
		_enemy_attrs = RouteInfo.enemy_attrs(n)
		var labels: = %EnemyAttrs.get_children()
		for i in labels.size():
			labels[i].visible = i < _enemy_attrs.size()
			if labels[i].visible:
				labels[i].text = FriendLook.attr_name(_enemy_attrs[i])
				labels[i].add_theme_color_override("font_color", FriendLook.attr_color(_enemy_attrs[i]))
		_show_boosts(true)
		return
	_show_boosts(false)
	var p: = RouteInfo.puzzle(n)
	var g: = BoardGame.new()
	g.start(p)
	%Moves.text = "이동 %d%s" % [p.moves, " (시간 판: 임시로 이동 수)" if p.has("timed_as_moves") else ""]
	for goal in p.goals:
		var chip: GoalChip = GOAL_CHIP.instantiate()
		%Goals.add_child(chip)
		chip.set_goal(TILE_ART.goal_icon(goal), g.remain(goal), "점수 " if goal.k == "score" else "")
	_buddy = p.get("buddy", "")
	%Buddy.visible = _buddy != ""
	if _buddy != "":
		%Buddy.text = "단짝 %s(을)를 데려가면 이동 +%d" % [FriendLook.shared().name_of(_buddy), RouteInfo.puzzle_rule("buddy_moves")]



func _show_boosts(battle: bool) -> void :
	var m: = AppState.meta()
	var bowl: String = m.data.buff if battle else ""
	%BowlIcon.visible = bowl != ""
	%Bowl.visible = bowl != ""
	if bowl != "":
		%BowlIcon.texture = load(RAMEN.BOWL_ICON[bowl]) if RAMEN.BOWL_ICON.has(bowl) else null
		%Bowl.text = "%s: %s" % [RAMEN.BOWL_NAME.get(bowl, ""), RAMEN.BOWL_DESC.get(bowl, "")]
	for c in %PackIcons.get_children():
		c.queue_free()
	var packed: = [] if battle else m.start_items().filter( func(s): return m.item_n(s.id) > 0)
	for s in packed:
		var icon: = TextureRect.new()
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = TILE_ART.get(String(s.put[0]))
		%PackIcons.add_child(icon)
	%Pack.visible = not packed.is_empty()
	%Pack.text = "포장해 둔 아이템을 깔고 시작"
	%Boosts.visible = bowl != "" or not packed.is_empty()


func _refresh() -> void :
	var m: = AppState.meta()
	for i in _slots.size():
		var icon: FriendIcon = _slots[i].get_node("FriendIcon")
		icon.visible = i < party.size()
		if icon.visible:
			_show_icon(icon, party[i])
	for tile: FriendTile in %Roster.get_children():
		_show_icon(tile, tile.id)
		tile.set_on(tile.id in party)
	%PartyTitle.text = "출격 %d/%d" % [party.size(), AppState.TEAM_SIZE]
	var can: = m.can_enter()
	%Go.disabled = not can or party.is_empty()
	%NoHeart.visible = not can
	if not can:
		var wait: = m.heart_wait_ms() / 1000
		%HeartText.text = "하트가 없어 · 다음 하트까지 %d:%02d" % [wait / 60, wait % 60]
		%Refill.text = "코인 %d으로 하트 채우기" % int(m.cfg.economy.hearts.refill_all_coins)
		%Refill.disabled = m.data.coins < int(m.cfg.economy.hearts.refill_all_coins)
		%AdHeart.text = "광고 보고 하트 +1 (오늘 %d번)" % AppAds.left("heart")
		%AdHeart.disabled = not AppAds.can("heart")
	%TopBar.refresh()



func _show_icon(icon: Control, id: String) -> void :
	icon.show_friend(id, AppState.meta().lv(id))
	var badge: = ""
	if id in _new:
		badge = "NEW"
	elif id == _buddy:
		badge = "단짝"
	elif _enemy_attrs.any( func(e): return BattleData.attr_mult(MetaConfig.shared().friend_by_id[id].attr, e) > 1.0):
		badge = "유리!"
	icon.set_badge(badge)


func _add(id: String, tile: FriendTile = null) -> void :
	if id in party:
		_remove(id)
		return
	if party.size() >= AppState.TEAM_SIZE:
		AppSound.sfx("error")
		if tile:
			AppFx.no(tile, 4.0, 180.0)
		return
	party.append(id)
	_refresh()


func _remove(id: String) -> void :
	party.erase(id)
	_refresh()


func _refill() -> void :
	AppState.meta().refill_hearts()
	_refresh()


func _ad_heart() -> void :
	await AppAds.watch("heart")
	_refresh()


func _start() -> void :
	if not AppState.meta().can_enter() or party.is_empty():
		return
	%Go.disabled = true
	AppState.set_party(party)
	await AppState.story_once("before:" + RouteInfo.ref(n))
	AppState.go("battle" if RouteInfo.is_battle(n) else "puzzle", {n = n})


func back() -> void :
	AppState.go("map")
