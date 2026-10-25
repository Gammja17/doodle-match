extends Control






const STAR_ON: = preload("res://ui/screens/art/star_on.png")
const STAR_OFF: = preload("res://ui/screens/art/star_off.png")

var n: = 1


func _ready() -> void :
	SafeArea.apply( %Screen)
	var a: = AppState.args()
	n = int(a.get("n", 1))
	var won: bool = a.get("won", false)
	var out: Dictionary = a.get("out", {})
	var stars: = int(a.get("stars", 0)) if won else 0
	var battle: = RouteInfo.is_battle(n)
	var word: = ("토벌 성공!" if battle else "다 지웠다!") if won else "아쉬워…"
	%Title.text = "%d판 %s" % [n, word] if won else word
	_title_art(word, won)
	var grade: = ("처음 깼다!" if out.get("first", false) else "참 잘했어요") if won else "다시 해 보자"
	var detail: = _detail(a)
	%Grade.text = grade + ("  ·  " + detail if detail != "" else "")
	var party: = AppState.party()
	var hero: String = a.get("mvp", party[0] if not party.is_empty() else "")
	%Hero.texture = FriendLook.shared().sticker(hero) if hero != "" else null
	%Hero.rotation_degrees = 0.0 if won else -2.0
	for s: TextureRect in %Stars.get_children():
		s.texture = STAR_OFF
	%Coins.text = "+%d" % int(out.get("coins", 0))
	%AdDouble.visible = won and int(out.get("coins", 0)) > 0 and AppAds.can("coins_x2")
	%AdDouble.text = "광고 보고 코인 2배 (오늘 %d번)" % AppAds.left("coins_x2")
	%AdDouble.pressed.connect(_double.bind(int(out.get("coins", 0))))
	%CoinRow.visible = int(out.get("coins", 0)) > 0
	%TreatRow.visible = out.has("treat")
	if out.has("treat"):
		%TreatIcon.texture = load("res://ui/screens/art/%s.png" % out.treat.id) if ResourceLoader.exists("res://ui/screens/art/%s.png" % out.treat.id) else %TreatIcon.texture
		%Treat.text = "+%d" % int(out.treat.n)
	%ShardRow.visible = out.has("shards")
	if out.has("shards"):
		%Shard.text = "조각+%d" % int(out.shards.n)
	%HeartRow.visible = out.get("heart_lost", false)
	_dashes()
	%JoinedRow.hide()
	%Next.visible = won and n < RouteInfo.count()
	%Retry.visible = not %Next.visible
	%Next.pressed.connect(AppState.go.bind("prep", {n = n + 1}))
	%Retry.pressed.connect(AppState.go.bind("prep", {n = n}))
	%Map.pressed.connect(back)
	AppSound.jingle("win" if won else "lose")
	get_tree().create_timer(0.5).timeout.connect( %Blocker.hide)
	await get_tree().process_frame
	AppFx.pop_modal( %Card)
	if won:
		await _reveal(stars)
		if out.get("first", false):
			await AppState.story_once("after:" + RouteInfo.ref(n))
		await _late_joins()



func _late_joins() -> void :
	var m: = AppState.meta()
	var ids: = []
	for id in m.due_joins():
		if m.recruit(id):
			ids.append(id)
	await AppState.join_cards(ids)



func _title_art(word: String, won: bool) -> void :
	var pic: = WordArt.of(word)
	if pic == null:
		return
	%Title.hide()
	%TitleRow.show()
	%Word.texture = pic
	%Word.custom_minimum_size = Vector2(96.0 * pic.get_width() / pic.get_height(), 96)
	var digits: = WordArt.glyphs(str(n))
	%Num.visible = won and not digits.is_empty()
	%Pan.visible = won
	%Pan.text = "판" if %Num.visible else "%d판" % n
	if %Num.visible:
		%Num.show_glyphs(digits, 66.0)



func _reveal(stars: int) -> void :
	var row: = %Stars.get_children()
	for i in stars:
		await get_tree().create_timer((450.0 if i == 0 else 330.0) / 1000.0).timeout
		if not is_inside_tree():
			return
		row[i].texture = STAR_ON
		AppFx.star_pop(row[i])
		AppSound.sfx("star")
		AppSound.vibrate(20)



func _dashes() -> void :
	var first: = true
	for row: Control in %Cells.get_children():
		row.get_node("Dash").visible = row.visible and not first
		if row.visible:
			first = false
	%Cells.get_parent().visible = not first


func _double(coins: int) -> void :
	%AdDouble.disabled = true
	if await AppAds.watch("coins_x2", coins):
		%Coins.text = "+%d" % (coins * 2)
		AppSound.sfx("coin")
		%AdDouble.hide()
	else:
		%AdDouble.disabled = false


func back() -> void :
	var won: bool = AppState.args().get("won", false)
	AppState.set_chapter(RouteInfo.chapter_of(n + 1 if won else n))
	AppState.go("map")


func _detail(a: Dictionary) -> String:
	if a.has("hp_ratio"):
		return "남은 체력 %d%% · %d턴" % [roundi(a.hp_ratio * 100), int(a.turns)]
	if a.has("score"):
		return "점수 %d" % int(a.score)
	return ""
