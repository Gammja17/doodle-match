class_name Ads
extends RefCounted
## 보상형 광고 창구. 게임 코드는 Platform.ads()로 이것만 부른다.
## 이 클래스 자체는 "광고 없음" 구현이다 (웹·PC, 플러그인이 아직 없는 릴리스 빌드). 진짜(AdMob)는 상속해서 _start/_load/_show만 채운다.
##
## 흐름: configure() → start() → can_show(slot)이면 광고 단추를 켬 → show(slot)
##   → 끝까지 봤으면 rewarded(slot) 다음 closed(slot, true), 중간에 닫았으면 closed(slot, false)만
##   보상은 rewarded에서만 준다. 하루 횟수 제한(bm.md §4)은 게임(메타) 쪽이 센다.
## skip = true면 광고를 안 띄우고 바로 rewarded·closed (광고 없이 받기를 샀거나, 13세 미만에게 광고를 안 보일 때).

signal rewarded(slot: String)
signal closed(slot: String, got_reward: bool)
## reason: not_ready(아직 못 받음) no_fill(보여 줄 광고 없음) unavailable(광고 없음) error
signal failed(slot: String, reason: String)

var skip := false
var deferred := true  # false면 신호를 바로 보냄 (테스트)
## configure()로 받은 값: child_directed(어린이 대상 처리), under_age(동의 나이 미만), max_rating("G")
var options := {child_directed = false, under_age = false, max_rating = "G"}


## start() 전에 부른다. 전체 이용가라 max_rating은 늘 G
func configure(opts: Dictionary) -> void:
	options.merge(opts, true)


func start() -> void:
	_start()


func can_show(slot: String) -> bool:
	return skip or (StoreIds.AD_SLOTS.has(slot) and _can_show(slot))


func show(slot: String) -> void:
	if not StoreIds.AD_SLOTS.has(slot):
		_emit(failed, [slot, "error"])
	elif skip:
		_emit(rewarded, [slot])
		_emit(closed, [slot, true])
	elif not _can_show(slot):
		_emit(failed, [slot, "not_ready"])
	else:
		_show(slot)


## 설정 화면에 "광고 개인정보 설정" 단추가 있어야 하는지 (유럽 등 동의가 필요한 곳, UMP)
func needs_privacy_button() -> bool:
	return false


func open_privacy_options() -> void:
	pass


# ---------- 상속해서 채우는 곳 ----------

func _start() -> void:
	pass


func _can_show(_slot: String) -> bool:
	return false


func _show(slot: String) -> void:
	_emit(failed, [slot, "unavailable"])


## 신호를 다음 프레임에 보냄 (deferred = false면 바로)
func _emit(sig: Signal, args: Array) -> void:
	if deferred:
		(func(): sig.emit.callv(args)).call_deferred()
	else:
		sig.emit.callv(args)
