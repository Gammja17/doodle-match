class_name AudioManager
extends Node
## 배경음악(크로스페이드)·징글·효과음(풀)·볼륨 설정 저장.
## project.godot 자동 로드에 이름 "Audio"로 등록해서 씀:
##   Audio.play_bgm("map") · Audio.play_jingle("win") · Audio.sfx("button") · Audio.pop(combo)
## 파일 → 쓰는 곳 목록은 audio/MANIFEST.md.

signal jingle_finished(key: String)

const BGM_DIR := "res://audio/bgm/"
const SFX_DIR := "res://audio/sfx/"

## 화면 → 곡 파일. 후보는 <화면>_a / <화면>_b. 고른 쪽 글자로 바꾸면 됨.
const BGM := {
	title = "title_a",
	map = "map_a",
	puzzle_1 = "puzzle_1_a",
	puzzle_2 = "puzzle_2_a",
	puzzle_3 = "puzzle_3_a",
	raid_1 = "raid_1_a",
	raid_2 = "raid_2_a",
	boss = "boss_a",
	guild = "guild_a",
	shop = "shop_a",
	story = "story_a",
}
## 한 번만 나오는 짧은 곡 (끝나면 jingle_finished)
const JINGLES := {
	win = "win_a",
	lose = "lose_a",
}
## 효과음 이름 → 파일들 (여러 개면 하나를 골라 틀어서 덜 반복적으로 들림)
const SFX := {
	pop = ["pop"],
	swap = ["swap"],
	swap_back = ["swap_back"],
	shuffle = ["shuffle"],
	item_make = ["item_make"],
	eraser = ["eraser"],
	pin = ["pin"],
	crayon = ["crayon"],
	plane = ["plane"],
	postit = ["postit_1", "postit_2"],
	tape = ["tape_1", "tape_2"],
	ink = ["ink"],
	crumbs = ["crumbs"],
	highlighter = ["highlighter"],
	attack = ["attack_1", "attack_2"],
	hit = ["hit_1", "hit_2"],
	enemy_attack = ["enemy_attack"],
	enemy_defeat = ["enemy_defeat"],
	heal = ["heal"],
	skill = ["skill"],
	button = ["button"],
	back = ["back"],
	toggle = ["toggle"],
	popup = ["popup"],
	error = ["error"],
	page = ["page_1", "page_2"],
	coin = ["coin"],
	star = ["star"],
	reward = ["reward"],
	level_up = ["level_up"],
	gacha_roll = ["gacha_roll"],
	gacha_reveal = ["gacha_reveal"],
	gacha_rare = ["gacha_rare"],
}
## 콤보마다 오르는 음 (반음, 장음계). 콤보 1 = 원래 음
const POP_STEPS := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]
const POOL_SIZE := 12
const SILENT_DB := -60.0

static var settings_path := "user://audio.cfg"

var music_volume := 0.8:
	set(v):
		music_volume = clampf(v, 0.0, 1.0)
		_apply_bus("Music", music_volume)
var sfx_volume := 0.8:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_bus("SFX", sfx_volume)

var bgm_key := ""  # 지금 틀고 있는 배경음악 이름 ("" = 없음)
var _music: Array[AudioStreamPlayer] = []  # 크로스페이드용 둘
var _cur := 0
var _jingle: AudioStreamPlayer
var _jingle_key := ""
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _fade: Tween
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 화면에서도 소리 남
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 2:
		_music.append(_player("Music"))
	_jingle = _player("Music")
	_jingle.finished.connect(func(): jingle_finished.emit(_jingle_key))
	for i in POOL_SIZE:
		_pool.append(_player("SFX"))
	load_settings()


## 배경음악을 바꿈. 같은 곡이면 그대로 둠. key "" = 끄기
func play_bgm(key: String, fade := 1.0) -> void:
	if key == bgm_key and _music[_cur].playing:
		return
	if key == "":
		stop_bgm(fade)
		return
	var stream := _load(BGM_DIR + BGM[key] + ".ogg", true)
	_jingle.stop()
	bgm_key = key
	var old := _music[_cur]
	_cur = 1 - _cur
	var now := _music[_cur]
	now.stream = stream
	now.play()
	_crossfade(now, old, fade)


func stop_bgm(fade := 1.0) -> void:
	bgm_key = ""
	_crossfade(null, _music[_cur], fade)


## 결과 징글: 배경음악을 끄고 한 번 틈. 다음 화면에서 play_bgm 부르면 됨
func play_jingle(key: String) -> void:
	stop_bgm(0.3)
	_jingle_key = key
	_jingle.stream = _load(BGM_DIR + JINGLES[key] + ".ogg", false)
	_jingle.play()


## 효과음 하나. pitch 1 = 원래 음
func sfx(key: String, pitch := 1.0, volume_db := 0.0) -> AudioStreamPlayer:
	var names: Array = SFX[key]
	var p := _free_player()
	p.stream = _load(SFX_DIR + names[randi() % names.size()] + ".ogg", false)
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
	return p


## 매칭 팝. 콤보가 이어질수록 음이 올라감
func pop(combo: int) -> AudioStreamPlayer:
	return sfx("pop", pop_pitch(combo))


static func pop_pitch(combo: int) -> float:
	var step: int = POP_STEPS[clampi(combo - 1, 0, POP_STEPS.size() - 1)]
	return pow(2.0, step / 12.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(settings_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)  # 없으면 기본값
	music_volume = cfg.get_value("audio", "music", 0.8)
	sfx_volume = cfg.get_value("audio", "sfx", 0.8)


func _crossfade(now: AudioStreamPlayer, old: AudioStreamPlayer, fade: float) -> void:
	if _fade:
		_fade.kill()
	if fade <= 0.0 or (now == null and not old.playing):
		if now:
			now.volume_db = 0.0
		old.stop()
		return
	_fade = create_tween().set_parallel()
	if now:
		now.volume_db = SILENT_DB
		_fade.tween_property(now, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old.playing:
		_fade.tween_property(old, "volume_db", SILENT_DB, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fade.chain().tween_callback(old.stop)


## 비어 있는 플레이어. 다 바쁘면 가장 먼저 튼 것을 끊고 씀
func _free_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var p := _pool[(_next + i) % POOL_SIZE]
		if not p.playing:
			_next = (_next + i + 1) % POOL_SIZE
			return p
	var oldest := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	return oldest


func _load(path: String, loop: bool) -> AudioStream:
	if not _cache.has(path):
		var s: AudioStream = load(path)
		if s is AudioStreamOggVorbis:
			s.loop = loop  # 배경음악 파일은 처음으로 이어지게 다듬어 둠 (loop_offset 0)
		_cache[path] = s
	return _cache[path]


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, "Master")


func _apply_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.0)
