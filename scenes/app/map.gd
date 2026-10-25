extends Control







const UNLOCK_TIPS: = {
	"friends": ["Friends", "친구 앨범이 열렸어!"], 
	"house": ["Guild", "길드가 열렸어!"], 
	"gacha": ["Shop", "문구점이 열렸어!"], 
	"ramen": ["RamenShop", "국숫집이 열렸어! 토벌 전에 한 그릇"], 
}


const NOTEBOOKS: = ["줄공책", "모눈 수학노트", "스케치북", "일기장", "찢어진 공책"]

var _chapter: = 0

@onready var _nodes: Array = %Page.get_children().filter( func(c): return c is StageNode)


func _ready() -> void :
	SafeArea.apply( %Screen)
	AppSound.bgm("map")
	var m: = AppState.meta()
	if AppState.chapter() < 0:
		AppState.set_chapter(RouteInfo.chapter_of(RouteInfo.frontier(m)))
	for node: StageNode in _nodes:
		node.chosen.connect(_on_chosen)
	%Prev.pressed.connect(_turn.bind(-1))
	%Next.pressed.connect(_turn.bind(1))
	%Settings.pressed.connect(AppState.go.bind("settings", {from = "map"}))
	%Home.pressed.connect(back)
	var ramen_open: = m.is_open("ramen")
	%RamenShop.disabled = not ramen_open
	%RamenShop.text = "국숫집" if ramen_open else "국숫집\n%d판 깨면" % int(m.cfg.extra.unlocks.ramen)
	%RamenShop.pressed.connect(AppState.go.bind("ramen"))
	_show(AppState.chapter())
	for f in UNLOCK_TIPS:
		if m.is_open(f) and not AppState.seen("tips", "open_" + f):
			AppState.mark_seen("tips", "open_" + f)
			_spot_unlock.call_deferred(UNLOCK_TIPS[f])
			break



func _spot_unlock(tip: Array) -> void :
	await get_tree().create_timer(0.6).timeout
	var tab: Control = %RamenShop if tip[0] == "RamenShop" else %Screen.get_node("VBox/NavTabs/" + tip[0])
	%Tutor.spot(tab.get_global_rect(), tip[1])
	%Tutor.point_at(tab)
	await %Tutor.wait_tap()
	%Tutor.clear()


func _show(ch: int) -> void :
	var m: = AppState.meta()
	_chapter = ch
	AppState.set_chapter(ch)
	var c: Dictionary = RouteInfo.chapters()[ch]
	var first: = int(c.first)
	var got: = 0
	for i in _nodes.size():
		var node: StageNode = _nodes[i]
		node.visible = i < int(c.count)
		if node.visible:
			node.setup(first + i, m)
			got += RouteInfo.stars(m, first + i)
	var book: = clampi(int(ch / 6.0), 0, 4)
	%Chapter.text = "%d장" % (ch + 1)
	%Sub.text = NOTEBOOKS[book]
	%Bg.texture = load("res://ui/screens/art/bg_map_%d.jpg" % (book + 1))
	%Stars.text = "%d/%d" % [got, int(c.count) * 3]
	%Range.text = "%d~%d판" % [first, first + int(c.count) - 1]
	%Prev.disabled = ch == 0
	%Next.disabled = ch >= RouteInfo.chapter_of(RouteInfo.frontier(m))
	for b: TextureButton in [ %Prev, %Next]:
		b.modulate.a = 0.3 if b.disabled else 1.0



func _turn(dir: int) -> void :
	var page: Control = %Page
	AppSound.sfx("page")
	page.pivot_offset = Vector2(0 if dir > 0 else page.size.x, page.size.y / 2)
	var tw: = create_tween()
	tw.tween_property(page, "scale:x", 0.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(_show.bind(_chapter + dir))
	tw.tween_property(page, "scale:x", 1.0, 0.18).set_ease(Tween.EASE_OUT)


func _on_chosen(n: int) -> void :
	AppState.go("prep", {n = n})


func back() -> void :
	AppState.go("title")
