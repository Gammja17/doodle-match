extends Control




const LINKS: = {
	"Privacy": "", 
	"Terms": "", 
	"Probability": "", 
	"Contact": "", 
}


const TOGGLES: = {"FastPlay": "fast_play", "SkillCutin": "skill_cutin"}

var _from: = "map"


func _ready() -> void :
	SafeArea.apply( %Screen)
	_from = AppState.args().get("from", "map")
	%Close.pressed.connect(back)
	%Back.pressed.connect(back)
	%Export.pressed.connect(_export)
	%Import.pressed.connect(_ask_import)
	%Reset.pressed.connect(_ask_reset)
	%Restore.pressed.connect(_restore)
	%AdPrivacy.visible = Platform.ads().needs_privacy_button()
	%AdPrivacy.pressed.connect(Platform.ads().open_privacy_options)
	for node_name in TOGGLES:
		var pref: String = TOGGLES[node_name]
		var b: CheckButton = get_node("%" + node_name)
		b.button_pressed = AppPrefs.get_value(pref)
		b.toggled.connect( func(on): AppPrefs.set_value(pref, on))
	%Language.item_selected.connect( func(i):
		AppPrefs.set_value("language", ["ko", "en"][i])
		TranslationServer.set_locale(["ko", "en"][i]))
	%Credits.pressed.connect(_credits)
	%CreditsClose.pressed.connect( %CreditsPanel.hide)
	%CreditsPanel.hide()
	for key in LINKS:
		var b: Button = get_node("%" + key)
		b.disabled = LINKS[key] == ""
		if b.disabled:
			b.text += " (주소 미정)"
		b.pressed.connect(OS.shell_open.bind(LINKS[key]))
	%Version.text = "버전 %s" % ProjectSettings.get_setting("application/config/version", "0.1")



func backup_code() -> String:
	return Marshalls.utf8_to_base64(SaveStore.encode(AppState.meta().data))


func _export() -> void :
	var code: = backup_code()
	%Code.text = code
	DisplayServer.clipboard_set(code)
	AppState.toast("백업 코드를 복사했어. 메모장 같은 데 꼭 적어 둬")


func _ask_import() -> void :
	if %Code.text.strip_edges() == "":
		AppState.toast("위 칸에 백업 코드를 붙여 넣어 줘")
		return
	AppState.runner().layer.ask("이 백업으로 바꿀까?\n지금 진행은 사라져", "바꾸기", func(): import_code( %Code.text))




func import_code(code: String) -> bool:
	code = code.strip_edges()
	var ok: = RegEx.create_from_string("^[A-Za-z0-9+/=\\s]+$").search(code) != null
	var r: = SaveStore.decode(Marshalls.base64_to_utf8(code)) if ok else {ok = false}
	var d: Dictionary = r.get("data", {})
	if not (r.ok and d.has("version") and d.has("stars") and d.has("own")):
		AppState.toast("백업 코드가 깨졌어. 다시 확인해 줘")
		return false
	var m: = AppState.meta()
	m.data = SaveStore.upgrade(m.cfg, d)
	if r.get("tampered", false):
		m.data.tampered = true
	AppState.save()
	AppState.set_chapter(-1)
	AppState.toast("백업을 불러왔어")
	return true



func _ask_reset() -> void :
	var layer: = AppState.runner().layer
	layer.ask("""처음부터 다시 할까?
친구·코인·진행·본 이야기가 다 지워져.
(남기고 싶으면 먼저 백업 코드를 만들어 둬)""", "지우기", func():

		await get_tree().process_frame
		layer.ask("""정말 지울까?
되돌릴 수 없어""", "처음부터", reset_progress))



func reset_progress() -> void :
	AppState.meta().reset()
	AppState.set_chapter(-1)
	AppState.toast("처음부터 다시 시작해")
	AppState.go("title")


func _restore() -> void :
	var b: = Platform.billing()
	if not b.is_ready():
		AppState.toast("지금은 스토어에 연결할 수 없어")
		return
	b.restore()
	AppState.toast("산 것을 다시 확인하는 중…")


func _credits() -> void :
	%CreditsText.text = "\n".join(PackedStringArray([
		"Doodle Match (가제)", 
		"", 
		"만든 사람: (출시 전에 채움)", 
		"그림·소리: (작가 크레딧 자리 — bm.md 원칙 7)", 
		"", 
		"이 게임은 Godot Engine으로 만들었어.", 
		"", 
		Engine.get_license_text(), 
	]))
	%CreditsPanel.show()
	var p: Control = %Panel
	p.modulate.a = 0.0
	await get_tree().process_frame
	AppFx.pop_small(p)


func back() -> void :
	if %CreditsPanel.visible:
		%CreditsPanel.hide()
	else:
		AppState.go(_from)
