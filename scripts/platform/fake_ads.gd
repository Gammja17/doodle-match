class_name FakeAds
extends Ads
## 가짜 광고: 화면 없이 바로 다 본 셈. 에디터·디버그 빌드에서만 쓴다.

## 다음 show() 결과 하나: watched(끝까지 봄) | closed_early(중간에 닫음) | no_fill | error. 한 번 쓰면 watched로
var next := "watched"
var shown := []  # 보여 준 자리 (테스트 확인용)


func _can_show(_slot: String) -> bool:
	return true


func _show(slot: String) -> void:
	var r := next
	next = "watched"
	if r == "no_fill" or r == "error":
		_emit(failed, [slot, r])
		return
	shown.append(slot)
	if r == "watched":
		_emit(rewarded, [slot])
	_emit(closed, [slot, r == "watched"])
