extends VBoxContainer
## 소리 크기 두 줄(배경음악·효과음)과 진동 켜기. 설정 화면과 일시정지 창에서 같이 씀.
## 소리는 AudioManager(/root/Audio)에 바로 넣고, 손을 떼면 저장


func _ready() -> void:
	var a := AppSound._audio()
	%Music.value = a.music_volume if a else 0.8
	%Sfx.value = a.sfx_volume if a else 0.8
	%Music.value_changed.connect(func(v):
		if a:
			a.music_volume = v)
	%Sfx.value_changed.connect(func(v):
		if a:
			a.sfx_volume = v)
	for s: HSlider in [%Music, %Sfx]:
		s.drag_ended.connect(func(_changed):
			if a:
				a.save_settings()
			AppSound.sfx("button"))
	%Vibration.button_pressed = AppPrefs.get_value("vibration")
	%Vibration.toggled.connect(func(on):
		AppPrefs.set_value("vibration", on)
		AppSound.vibrate())
