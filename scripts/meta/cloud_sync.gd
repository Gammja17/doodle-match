extends RefCounted
## 클라우드 저장 맞추기 (로그인한 계정으로 기기를 바꿔도 이어하기). Meta 하나와 클라우드 창구 하나를 이어 줌.
##   var sync := CloudSyncScript.new(meta, backend)  → backend.sign_in("google") → 상태가 바뀌면 state_changed
##   "choose"면 choice로 고르는 화면을 그리고 choose("local" | "cloud")
##   앱은 1분에 한 번, 그리고 앱이 뒤로 갈 때·닫힐 때 flush()를 부름 (바뀐 게 있을 때만 올림)
##
## 웹게임 구글 연동 버그(켜자마자 저장된 새 기기의 빈 기록이 "더 최근"이라 계정 기록을 덮어씀)를 거울삼은 규칙:
##  1. 계정과 맞추기 전(state != "synced")에는 절대 올리지 않음.
##  2. "더 최근 저장"으로 고르지 않고(기기 시계는 서로 어긋남), 이 기기가 마지막으로 계정과 맞춘 내용(data.sync 해시)을 기준으로 고름:
##     계정 기록이 그 뒤로 안 바뀜 → 이 기기 것을 올림 / 이 기기가 그 뒤로 안 바뀜(내용 해시가 같음) → 계정 것을 받음
##     이 기기에 진행이 없음(새 기기: 깬 판·결제 없음) → 묻지 않고 계정 것을 받음 / 둘 다 바뀜 → "choose" (사람이 고름)
##  3. 계정 기록을 못 읽으면 아무것도 안 올림 (계정 기록을 지킴).
##  4. 계정 것을 받기 전에 이 기기 기록을 save.json.before_cloud로 남김 (잘못 골라도 되살릴 수 있게).
##  5. 다른 계정으로 로그인하면 맞춘 적 없는 것으로 봄. 앱보다 새 버전 기록은 받지도 덮지도 않음("update_app").

signal state_changed(state: String)  # off | checking | choose | synced | error
signal took_cloud  # 이 기기 기록이 계정 기록으로 바뀜 (화면을 다시 그려야 함)

var meta: Meta
var backend
var state := "off"
var error := ""  # state가 error일 때: fetch(못 읽음) | update_app(앱보다 새 기록) | broken(계정 기록이 깨짐)
## 고르는 화면용 { local, cloud = 진행 요약, recommend = "local" | "cloud", cloud_only_purchases, local_only_purchases }
var choice := {}
var dirty := false  # 맞춘 뒤 이 기기에서 저장한 게 있음

var _pending := {}  # choose일 때 받아 둔 계정 기록
var _inflight_hash := ""
var _uploaded_hash := ""
var _quiet := false  # 스스로 저장할 때 dirty를 안 켬


func _init(m: Meta, b) -> void:
	meta = m
	backend = b
	b.signed_in.connect(_on_signed_in)
	b.signed_out.connect(_on_signed_out)
	b.fetched.connect(_on_fetched)
	b.uploaded.connect(_on_uploaded)
	m.saved.connect(_on_saved)


## 진행 요약 (고르는 화면에 나란히 보여 줌)
static func progress(d: Dictionary) -> Dictionary:
	var lv := 0
	for id in d.get("own", {}):
		lv += int(d.own[id])
	return {
		cleared = d.get("stars", {}).size(),
		friends = d.get("own", {}).size(),
		level_sum = lv,
		coins = int(d.get("coins", 0)),
		dust = int(d.get("dust", {}).get("paid", 0)) + int(d.get("dust", {}).get("free", 0)),
		paid_dust = int(d.get("dust", {}).get("paid", 0)),
		purchases = d.get("purchases", {}).size(),
		saved_at = int(d.get("saved_at", 0)),
		device = String(d.get("device_id", "")),
	}


## 새 기기처럼 아무 진행도 없는 기록인지 (깬 판도 결제도 없음)
static func is_blank(d: Dictionary) -> bool:
	return d.get("stars", {}).is_empty() and d.get("purchases", {}).is_empty()


func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)


func _on_signed_in(_account: String) -> void:
	_pending = {}
	choice = {}
	_set_state("checking")
	backend.fetch()


func _on_signed_out() -> void:
	_set_state("off")


func _on_fetched(ok: bool, rec: Dictionary) -> void:
	if state != "checking":
		return
	if not ok:
		error = "fetch"
		_set_state("error")
		return
	if rec.is_empty():
		_keep_local(true)  # 계정이 비어 있으면 이 기기 것을 올림
		return
	var cloud := _decode(rec)
	if cloud.is_empty():
		error = "broken"
		_set_state("error")
		return
	if int(cloud.data.get("version", 0)) > SaveStore.VERSION:
		error = "update_app"
		_set_state("error")
		return
	var s: Dictionary = meta.data.sync
	var same: bool = s.account == backend.account()
	if same:
		_uploaded_hash = s.hash  # 마지막으로 맞춘 내용 (그대로면 다시 안 올림)
	if same and String(s.get("cloud", "")) != "" and rec.get("hash", "") == s.cloud:  # 계정 기록이 그 뒤로 그대로
		_keep_local()
	elif (same and SaveStore.content_hash(meta.data) == s.hash) or is_blank(meta.data):
		_take(rec, cloud)
	else:
		_pending = rec
		var mine := progress(meta.data)
		var theirs := progress(cloud.data)
		var cloud_more: bool = theirs.cleared > mine.cleared or (theirs.cleared == mine.cleared and theirs.level_sum >= mine.level_sum)
		choice = {
			local = mine,
			cloud = theirs,
			recommend = "cloud" if cloud_more else "local",  # 진행 많은 쪽 (같으면 계정 쪽)
			cloud_only_purchases = _only(cloud.data, meta.data),
			local_only_purchases = _only(meta.data, cloud.data),
		}
		_set_state("choose")


## 고르는 화면에서: "local" 이 기기 기록으로 계속(계정 기록을 덮음) | "cloud" 계정 기록을 받음
func choose(side: String) -> bool:
	if state != "choose":
		return false
	if side == "local":
		_keep_local(true)
	else:
		_take(_pending, _decode(_pending))
	return true


## 맞춘 뒤 바뀐 게 있으면 올림. 올렸으면 true
func flush() -> bool:
	if state != "synced" or not dirty or meta.read_only:
		return false
	return _upload()


## 이 기기 것으로 계속: 계정 기록과 다르면 올림 (force: 고르는 화면에서 이 기기를 골랐을 때 늘 올림)
func _keep_local(force := false) -> void:
	_set_state("synced")
	if not meta.read_only:
		_upload(force)


func _take(rec: Dictionary, cloud: Dictionary) -> void:
	if meta.save_path != "":
		var f := FileAccess.open(meta.save_path + ".before_cloud", FileAccess.WRITE)
		if f:
			f.store_string(SaveStore.encode(meta.data))
			f.close()
	var d: Dictionary = SaveStore.upgrade(meta.cfg, cloud.data)
	d.device_id = meta.data.device_id  # 기기 표시는 이 기기 것
	if cloud.tampered:
		d.tampered = true
	d.sync = {account = backend.account(), at = int(rec.at), hash = SaveStore.content_hash(d), cloud = String(rec.get("hash", ""))}
	meta.data = d
	_uploaded_hash = d.sync.hash
	_save_quiet()
	dirty = false
	_set_state("synced")
	took_cloud.emit()


func _upload(force := false) -> bool:
	var h := SaveStore.content_hash(meta.data)
	if not force and h == _uploaded_hash:
		dirty = false
		return false
	_inflight_hash = h
	backend.upload({text = SaveStore.encode(meta.data), hash = h, at = meta.now(), device = meta.data.device_id, progress = progress(meta.data)})
	return true


func _on_uploaded(ok: bool, at: int) -> void:
	if not ok:
		dirty = true  # 다음 flush에서 다시
		return
	_uploaded_hash = _inflight_hash
	meta.data.sync = {account = backend.account(), at = at, hash = _inflight_hash, cloud = _inflight_hash}
	_save_quiet()
	dirty = SaveStore.content_hash(meta.data) != _uploaded_hash  # 올리는 사이에 또 바뀌었으면 다음에


func _on_saved() -> void:
	if not _quiet:
		dirty = true


func _save_quiet() -> void:
	_quiet = true
	meta.save()
	_quiet = false


## 계정 기록 → { data, tampered }. 깨졌으면 빈 Dictionary
func _decode(rec: Dictionary) -> Dictionary:
	var r := SaveStore.decode(String(rec.get("text", "")))
	return r if r.ok else {}


## a에만 있는 결제 수 (계정 기록을 고르면 사라질 결제를 화면에 경고)
static func _only(a: Dictionary, b: Dictionary) -> int:
	return a.get("purchases", {}).keys().filter(func(k): return not b.get("purchases", {}).has(k)).size()
