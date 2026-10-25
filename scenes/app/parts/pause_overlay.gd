class_name PauseOverlay
extends Control
## 판 위에 덮는 "멈춤" 단추(왼쪽 위 동그란 그림) + 일시정지 창 (소리·진동, 계속하기, 나가기).
## 창은 웹 .pause-card처럼 0.6배 → 1 (220ms 튕김)으로 열리고 닫힐 땐 바로 사라짐.
## 창이 열리면 트리를 멈춤(이 창만 돌아감). 그만하기는 한 번 더 묻고(하트 -1) give_up

signal give_up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Pause.pressed.connect(open)
	%Resume.pressed.connect(close)
	%GiveUp.pressed.connect(func(): %Sure.visible = true)
	%SureNo.pressed.connect(func(): %Sure.visible = false)
	%SureYes.pressed.connect(func():
		close()
		give_up.emit())
	%Dialog.hide()


func open() -> void:
	%Sure.visible = false
	%Dialog.show()
	get_tree().paused = true
	var p: Control = %Panel
	p.modulate.a = 0.0
	await get_tree().process_frame  # 가운데 정렬이 끝난 크기로
	AppFx.pop_small(p)


func close() -> void:
	%Dialog.hide()
	get_tree().paused = false


func is_open() -> bool:
	return %Dialog.visible


## 뒤로 단추: 열려 있으면 닫고, 아니면 엶
func toggle() -> void:
	if is_open():
		close()
	else:
		open()
