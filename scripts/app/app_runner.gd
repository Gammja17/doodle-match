class_name AppRunner
extends Node
## 앱 전체에 하나 (AppState가 처음 불릴 때 root에 붙임). 화면이 바뀌어도 남아서:
## - 화면 넘김: 종이로 덮고(app_layer, 로딩 글자) 씬을 읽어 바꾸고 걷음.
##   스레드 읽기(load_threaded_request)는 preload가 많은 씬(battle_play)에서 가끔 "Could not preload"로 깨져서 덮은 뒤 그냥 읽음
## - 뒤로가기(안드로이드 뒤로 단추·Esc): 대화 건너뛰기 → 화면의 back() → 없으면 지도로. 타이틀에선 끝낼지 물음
## - 앱이 뒤로 갈 때(전화·홈 단추) 저장, 판 화면이면 일시정지 창
## - 판 도중 앱이 꺼졌으면 다음 실행 때 그 판을 그만둔 걸로 침 (하트 -1, 알림)
## - 소리: 사운드 세션 AudioManager가 자동 로드로 안 붙어 있으면 /root/Audio로 붙임, 모든 단추에 딸깍 + 눌림 크기
## - 글꼴: 테마 세션 game_font(Poor Story = 웹게임과 같은 글꼴, 기호는 Noto 대체)를 고도 기본 글꼴로
##   (웹엔 시스템 글꼴이 없어 한글이 네모로 나와서). 그래도 없는 기호는 원래 기본 글꼴(Open Sans)이 받침
## - 글 세션 data/strings/<언어>.json을 고도 번역(TranslationServer)에 등록 → 어디서든 tr(key). 언어는 설정(AppPrefs language)
## - 결제·광고 시작 (Platform). 결제가 오면 메타가 지급(grant_product, 같은 주문은 한 번)한 뒤 finish
##   (Meta.attach_billing은 Meta 객체에 묶여서, 백업 불러오기로 Meta가 바뀌면 옛 Meta에 지급될 수 있어 여기서 지금 Meta로 넘김)

const LAYER := preload("res://scenes/app/parts/app_layer.tscn")

var layer: AppLayer
var busy := false
var _next := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false  # project.godot 기본은 뒤로 단추 = 바로 꺼짐
	layer = LAYER.instantiate()
	add_child(layer)
	if get_tree().root.get_node_or_null("Audio") == null:
		var audio := AudioManager.new()
		audio.name = "Audio"
		get_tree().root.add_child.call_deferred(audio)
	get_tree().node_added.connect(_on_node_added)
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(b)
	_use_font()
	_load_strings()
	var ads := Platform.ads()
	ads.configure({})
	ads.start()
	var billing := Platform.billing()
	billing.purchased.connect(_on_purchased)
	billing.start()
	_check_interrupted.call_deferred()
	for t in AppState._s().get("toasts", []):
		toast(t)
	AppState._s().toasts = []


func _on_purchased(p: Dictionary) -> void:
	var m := AppState.meta()
	if not m.already_granted(p.order_id):
		var got := m.grant_product(p.key, p.order_id)
		if not got.is_empty():
			toast("받았어! " + Shop.describe_got(got))
			AppSound.sfx("reward")
	Platform.billing().finish(p)


## 지난번에 판 도중 꺼졌으면: 그만둔 판과 똑같이 메타에 넘김 (하트 -1)
func _check_interrupted() -> void:
	var a := AppState.app()
	var ref: String = a.playing
	var scene := get_tree().current_scene
	if ref == "" or (scene and scene.name in ["PuzzleStage", "BattleStage"]):
		return
	AppState.end_stage()
	var out := AppState.meta().finish_stage({kind = "route", ref = ref, won = false})
	toast("지난번에 판 도중 꺼져서 그 판은 그만둔 걸로 쳤어" + (" (하트 -1)" if out.get("heart_lost", false) else ""))


const FONT := preload("res://ui/theme/fonts/game_font.tres")
const FONT_BOLD := preload("res://ui/theme/fonts/game_font_bold.tres")


func _use_font() -> void:
	if ThemeDB.fallback_font == FONT:
		return
	var base := ThemeDB.fallback_font
	for f: Font in [FONT, FONT_BOLD]:
		if not base in f.fallbacks:
			f.fallbacks = f.fallbacks + [base]  # 기호 대체(Noto 13자) 뒤에 원래 기본 글꼴
	ThemeDB.fallback_font = FONT
	ThemeDB.get_default_theme().default_font = FONT  # 테마에 글꼴이 없는 다른 세션 화면(토벌·길드·대화)도


func _load_strings() -> void:
	for lang in ["ko", "en"]:
		var path := "res://data/strings/%s.json" % lang
		if not FileAccess.file_exists(path):
			continue
		var t := Translation.new()
		t.locale = lang
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for k in d:
			if not k.begins_with("_"):
				t.add_message(k, str(d[k]))
		TranslationServer.add_translation(t)
	TranslationServer.set_locale(AppPrefs.get_value("language"))


func change(path: String) -> void:
	if busy:
		_next = path  # 덮는 중에 또 부르면 마지막 것으로
		return
	busy = true
	await layer.cover()
	if not ResourceLoader.has_cached(path):
		layer.show_loading(true)  # 처음 여는 화면: 읽는 동안 "연필 깎는 중…"이 보이게 한 프레임 그림
		await get_tree().process_frame
	var scene := load(path) as PackedScene
	get_tree().paused = false
	get_tree().change_scene_to_packed(scene)
	await get_tree().scene_changed
	layer.show_loading(false)
	await layer.uncover()
	busy = false
	if _next != "":
		var p := _next
		_next = ""
		change(p)


func toast(text: String) -> void:
	layer.toast(text)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			AppState.save()
			var scene := get_tree().current_scene
			if what == NOTIFICATION_APPLICATION_PAUSED and scene and scene.has_method("pause"):
				scene.pause()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## 뒤로: 열린 것부터 닫음
func back() -> void:
	var story := get_tree().root.get_node_or_null("Story/StoryScene")
	if story:
		story.skip()
		return
	if busy:
		return
	if layer.close_dialog():
		return
	AppSound.sfx("back")
	var scene := get_tree().current_scene
	if scene and scene.has_method("back"):
		scene.back()
	else:
		AppState.go("map")


## 타이틀에서 뒤로: 끝낼까?
func ask_quit() -> void:
	layer.ask("공책을 덮을까?\n(게임 끄기)", "덮기", func():
		AppState.save()
		get_tree().quit())


## 단추마다 딸깍 + 눌린 동안 살짝 작아짐 (씬에 코드를 안 넣으려고 여기서 한꺼번에)
## 웹게임처럼 눌림은 바로 (애니메이션 없음): 동그란 그림 단추 .92, 아래 탭 .94, 큰 단추 .96
func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(AppSound.sfx.bind("toggle" if n.toggle_mode else "button"))
		var k := 0.92 if n is TextureButton else 0.94 if n.theme_type_variation == &"TabButton" else 0.96
		n.button_down.connect(_press.bind(n, k))
		n.button_up.connect(_press.bind(n, 1.0))


func _press(b: Control, k: float) -> void:
	b.pivot_offset = b.size / 2
	b.scale = Vector2(k, k)
