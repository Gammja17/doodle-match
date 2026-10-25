class_name AppSound
extends RefCounted
## 앱 화면에서 소리 내는 창구. 사운드 세션의 AudioManager(/root/Audio)에 넘기되, 그 소리 파일이 아직 없으면 조용히 넘어감
## (audio/ 폴더가 생기기 전에도 앱이 오류 없이 돌게). 진동도 여기 (설정에서 끌 수 있음)


static func _audio() -> AudioManager:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Audio") as AudioManager


static func _has(path: String) -> bool:
	return ResourceLoader.exists(path)


## 화면 배경음악 (AudioManager.BGM 키)
static func bgm(key: String) -> void:
	var a := _audio()
	if a and AudioManager.BGM.has(key) and _has(AudioManager.BGM_DIR + AudioManager.BGM[key] + ".ogg"):
		a.play_bgm(key)


static func jingle(key: String) -> void:
	var a := _audio()
	if a and AudioManager.JINGLES.has(key) and _has(AudioManager.BGM_DIR + AudioManager.JINGLES[key] + ".ogg"):
		a.play_jingle(key)


static func sfx(key: String) -> void:
	var a := _audio()
	if a and AudioManager.SFX.has(key) and AudioManager.SFX[key].all(func(f): return _has(AudioManager.SFX_DIR + f + ".ogg")):
		a.sfx(key)


static func vibrate(ms := 40) -> void:
	if AppPrefs.get_value("vibration", true):
		Input.vibrate_handheld(ms)
