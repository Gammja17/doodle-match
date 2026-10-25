extends HBoxContainer
## 아래 메뉴 = 공책 인덱스 탭 (웹게임 dock: 그림 위·글자 아래): 지도 / 친구 / 길드 / 가게.
## 지금 화면 탭은 눌린 채, 아직 안 열린 탭은 그림이 흐리고 글자 대신 "n판"(열리는 판) 표시, 못 누름
## (열림 판 수 = meta_extra unlocks: friends, gacha)

## 탭 이름 -> [화면, 열림 기능 id(없으면 늘 열림), 글자]
const TABS := {
	"Map": ["map", "", "지도"],
	"Friends": ["friends", "friends", "친구"],
	"Guild": ["guild", "house", "길드"],
	"Shop": ["shop", "gacha", "가게"],
}

@export var current := "map"


func _ready() -> void:
	var m := AppState.meta()
	for node_name in TABS:
		var t: Array = TABS[node_name]
		var b: Button = get_node(node_name)
		b.button_pressed = t[0] == current
		var open: bool = t[1] == "" or m.is_open(t[1])
		b.disabled = not open
		b.text = t[2] if open else "%d판" % int(m.cfg.extra.unlocks[t[1]])
		b.pressed.connect(_go.bind(t[0], b))


func _go(screen: String, b: Button) -> void:
	if screen == current:
		b.button_pressed = true  # 지금 탭은 눌린 채로
		return
	AppState.go(screen)
