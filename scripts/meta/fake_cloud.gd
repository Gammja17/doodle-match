extends "res://scripts/meta/cloud_backend.gd"
## 가짜 클라우드: 서버 대신 static 사전 하나 (FakeCloud를 여러 개 만들면 기기 여러 대가 같은 서버를 쓰는 셈).
## 앱을 끄면 사라짐. 에디터·디버그·테스트용. fail_next로 네트워크 실패를 흉내 낸다.

static var server := {}  # 계정 -> 계정 기록 rec
static var emails := {}  # 구글 이메일 -> 계정
static var _n := 0

var email := "player@example.com"  # link("google")·sign_in("google")에 쓸 구글 계정 (테스트가 바꿈)
var fail_next := ""  # 다음 한 번 실패: fetch | upload | sign_in | link


static func reset_server() -> void:
	server = {}
	emails = {}


func _fail(what: String) -> bool:
	if fail_next != what:
		return false
	fail_next = ""
	return true


func _sign_in(kind: String) -> void:
	if _fail("sign_in"):
		_emit(failed, ["sign_in", "error"])
		return
	if kind == "google":
		if not emails.has(email):
			emails[email] = _new_account("acc")
		_account = emails[email]
	else:
		_account = _new_account("guest")
	_emit(signed_in, [_account])


## 구글 연결: 그 구글 계정을 처음 붙이면 지금 계정(게스트)을 그대로 쓰고, 이미 다른 계정에 붙어 있으면 그 계정으로 바뀜
func _link(kind: String) -> void:
	if _fail("link") or kind != "google":
		_emit(failed, ["link", "error"])
		return
	if emails.has(email):
		_account = emails[email]
	else:
		emails[email] = _account
	_emit(signed_in, [_account])


func _fetch() -> void:
	if _fail("fetch"):
		_emit(fetched, [false, {}])
	else:
		_emit(fetched, [true, server.get(_account, {}).duplicate(true)])


func _upload(rec: Dictionary) -> void:
	if _fail("upload"):
		_emit(uploaded, [false, 0])
		return
	server[_account] = rec.duplicate(true)
	_emit(uploaded, [true, int(rec.at)])


static func _new_account(prefix: String) -> String:
	_n += 1
	return "%s-%d" % [prefix, _n]
