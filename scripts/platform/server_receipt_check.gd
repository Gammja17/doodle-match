class_name ServerReceiptCheck
extends ReceiptCheck
## 진짜 영수증 확인: server/ 영수증 서버에 HTTPS로 묻는다 (API: docs/release/paid-spec.md §5).
## 서버에 못 닿거나 답이 이상하면 reason "error" → 게임은 보상도 finish도 안 함 → 다음 실행 때 다시.
## 지금은 안드로이드만 (서버가 iOS를 아직 못 봄). Platform.receipts()가 VERIFY_URL이 있을 때 고른다.

const TIMEOUT_S := 15.0
const MAX_REVOKED := 500  # 서버가 한 번에 받는 주문 번호 수

var url: String
var install_id: String
## (url, body) -> { code, body }. code 0 = 네트워크 실패. 테스트는 가짜를 끼움
var post: Callable


func _init(base_url: String, p_install_id: String) -> void:
	url = base_url.trim_suffix("/")
	install_id = p_install_id
	post = _http_post


func _check(p: Dictionary) -> void:
	var body := {
		platform = "android",
		key = p.key,
		kind = p.kind,
		store_id = StoreIds.store_id(p.key, "Android"),
		order_id = String(p.get("order_id", "")),
		token = String(p.get("token", "")),
		install_id = install_id,
		app_version = String(ProjectSettings.get_setting("application/config/version", "")),
	}
	var res: Dictionary = await post.call(url + "/v1/verify", body)
	_done(p, parse_verify(res))


func _check_revoked(order_ids: Array) -> void:
	if order_ids.is_empty():
		_emit(revoked_found, [[]])
		return
	var res: Dictionary = await post.call(url + "/v1/revoked", {install_id = install_id, order_ids = order_ids.slice(-MAX_REVOKED)})
	var j = _json(res.body) if res.code == 200 else null
	if j is Dictionary and j.get("revoked") is Array:
		_emit(revoked_found, [j.revoked])


## 서버 답 → r. 200(결과) 400(bad_request)만 믿고, 나머지는 error
static func parse_verify(res: Dictionary) -> Dictionary:
	var j = _json(res.body) if res.code == 200 or res.code == 400 else null
	if not (j is Dictionary and j.has("ok")):
		return {ok = false, reason = "error", expires_ms = 0, test = false}
	return {ok = bool(j.ok), reason = String(j.get("reason", "")), expires_ms = int(j.get("expires_ms", 0)), test = bool(j.get("test", false))}


## 깨진 JSON이면 null (JSON.parse_string과 달리 오류 로그를 안 남김)
static func _json(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null


## HTTPRequest 하나를 잠깐 트리에 붙여 POST하고 뗀다
func _http_post(to: String, body: Dictionary) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_S
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(req)
	await req.ready
	var err := req.request(to, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {code = 0, body = ""}
	var r: Array = await req.request_completed  # [result, code, headers, body]
	req.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return {code = 0, body = ""}
	return {code = r[1], body = (r[3] as PackedByteArray).get_string_from_utf8()}
