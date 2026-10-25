extends Control
## 타이틀 = 공책 표지: 이름표 스티커에 제목, 표지에 붙은 친구 스티커들. "공책 펼치기"로 지도 (처음이면 프롤로그 대화 먼저).
## 표지 그림은 720x1280 틀 안에 놓고 화면 가운데에 둠 (긴 폰·태블릿에서도 안 흐트러지게)
## 표지 친구들은 웹 타이틀 파티처럼 통통 (hop 1.3s, 0.12s씩 엇갈림)


func _ready() -> void:
	SafeArea.apply(%Screen)
	AppSound.bgm("title")
	%Open.pressed.connect(_open)
	%Settings.pressed.connect(AppState.go.bind("settings", {from = "title"}))
	AppFx.hop(%StickerGrenn)
	AppFx.hop(%StickerYuja, 1300.0, 120.0)
	var m := AppState.meta()
	%Progress.text = "%d판 깼어 · 별 %d개" % [m.cleared_count(), m.data.stars.values().reduce(func(s, v): return s + int(v), 0)] 		if m.cleared_count() > 0 else "처음 펼치는 공책"


func _open() -> void:
	%Open.disabled = true
	await AppState.story_once("prologue")
	AppState.go("map")


func back() -> void:
	AppState.runner().ask_quit()
