extends RefCounted
## 클라우드 저장 창구 (계정 하나에 저장 한 벌). 게임은 cloud_sync.gd를 거쳐서만 부른다.
## 이 클래스 자체는 "클라우드 없음" 구현이다 (로그인하면 unavailable). 진짜(Play 게임즈 저장·Firebase 등)는
## 이걸 상속해서 _sign_in/_link/_fetch/_upload만 채운다. 테스트·디버그용은 fake_cloud.gd.
## 신호는 진짜 서버처럼 나중에(다음 프레임) 온다고 생각하고 짠다 (deferred = false면 바로, 테스트).
##
## 계정 기록 rec = { text(SaveStore.encode 글자), hash(내용 해시: 바뀌었나 볼 때), at(올린 시각 ms, 보여 주기만), device(올린 기기), progress(진행 요약) }

signal signed_in(account: String)  # 로그인·계정 연결이 됐음 (게스트 → 구글 연결도. 이미 쓰던 계정이면 그 계정으로 바뀜)
signal signed_out
signal fetched(ok: bool, rec: Dictionary)  # ok = false: 못 읽음(네트워크). rec = {}: 계정에 기록 없음
signal uploaded(ok: bool, at: int)
signal failed(what: String, reason: String)  # what: sign_in | link. reason: cancelled | unavailable | error

var deferred := true
var _account := ""


func account() -> String:
	return _account


## kind: guest | google (진짜 구현이 받는 종류에 맞춤)
func sign_in(kind := "guest") -> void:
	_sign_in(kind)


## 지금 계정(게스트)에 다른 로그인을 붙임. 그 로그인이 이미 다른 계정에 붙어 있으면 그 계정으로 바뀜 (signed_in이 새 계정으로 옴)
func link(kind: String) -> void:
	if _account == "":
		_emit(failed, ["link", "error"])
	else:
		_link(kind)


func sign_out() -> void:
	_account = ""
	_emit(signed_out, [])


func fetch() -> void:
	if _account == "":
		_emit(fetched, [false, {}])
	else:
		_fetch()


func upload(rec: Dictionary) -> void:
	if _account == "":
		_emit(uploaded, [false, 0])
	else:
		_upload(rec)


# ---------- 상속해서 채우는 곳 ----------

func _sign_in(_kind: String) -> void:
	_emit(failed, ["sign_in", "unavailable"])


func _link(_kind: String) -> void:
	_emit(failed, ["link", "unavailable"])


func _fetch() -> void:
	_emit(fetched, [false, {}])


func _upload(_rec: Dictionary) -> void:
	_emit(uploaded, [false, 0])


# ---------- 상속한 쪽이 쓰는 도우미 ----------

func _emit(sig: Signal, args: Array) -> void:
	if deferred:
		(func(): sig.emit.callv(args)).call_deferred()
	else:
		sig.emit.callv(args)
