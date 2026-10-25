class_name BattleBoardView
extends BoardView
## 토벌 판 화면: 판 사건은 BoardView가 보여 주고, 전투 사건은 battle_event로 넘긴 뒤 잠깐 기다림.
## 웹처럼 터진 얼굴이 괴물에게 날아가 박힌 뒤에 데미지 숫자가 뜸. 스킬 동안 판 테두리가 친구 색으로 빛남

signal battle_event(e: Dictionary)

const GLOW := preload("res://scenes/board/board_glow.tscn")
## 전투 사건마다 다음 사건까지 쉬는 시간 (초). 웹 game.js의 sleep 값
const PAUSE := {
	"hit": 0.11, "heal": 0.11, "team_heal": 0.3, "gauge": 0.0, "fever": 1.5, "skill": 1.25, "delay": 0.4,
	"mon_attack": 0.8, "debuff": 0.5, "poison": 0.3, "mon_heal": 0.4, "mon_dead": 0.3, "wave": 0.9,
}

## 괴물이 던지는 포스트잇이 날아오는 곳 (화면 좌표)
var throw_from: Callable

var _aura: Panel
var _aura_color := Color.WHITE
var _finish_pending := false
var _throw_i := 0


func play(events: Array) -> void:
	_throw_i = 0
	await super(events)
	stop_aura()


func _show(e: Dictionary) -> void:
	match e.kind:
		"replace":
			if fx and throw_from.is_valid() and e.tile.block == Board.STICKY:
				_throw(e)
			else:
				await super(e)
		"step":
			if _finish_pending and fx:
				_finish_pending = false
				var r: Array = e.res.cleared
				var c := get_global_rect().get_center()
				if not r.is_empty():
					c = Vector2.ZERO
					for x in r:
						c += cell_center(x.pos)
					c /= r.size()
				fx.skill_finish(c, _aura_color)
			await super(e)
		_:
			if not PAUSE.has(e.kind):
				await super(e)
				return
			if e.kind == "hit" and fx:  # 얼굴이 괴물에게 다 박힌 뒤에 숫자
				var t := 0.0
				while fx.flying() > 0 and t < 0.7:
					await get_tree().process_frame
					t += get_process_delta_time()
			battle_event.emit(e)
			if PAUSE[e.kind] > 0:
				await _wait(PAUSE[e.kind])


## 스킬 동안 판 테두리가 친구 색으로 은은히 (웹 skillAura: 620ms 반복 + 테두리 반짝이 8)
func start_aura(color: Color) -> void:
	_aura_color = color
	_finish_pending = true
	if _aura == null:
		_aura = GLOW.instantiate()
		add_child(_aura)
	var m := 6.0 * cell_size / 56.0
	_aura.position = -Vector2.ONE * m
	_aura.size = size + Vector2.ONE * m * 2
	_aura.self_modulate = color
	_aura.modulate.a = 0.0
	_aura.show()
	var tw := _aura.create_tween()
	tw.tween_property(_aura, "modulate:a", 1.0, 0.22)
	tw.tween_property(_aura, "modulate:a", 0.45, 0.31)
	tw.tween_property(_aura, "modulate:a", 1.0, 0.31)
	if fx == null:
		return
	var r := get_global_rect()
	for i in 8:
		var side := i % 4
		var u := randf()
		var p: Vector2 = r.position + [Vector2(u * r.size.x, 0), Vector2(r.size.x, u * r.size.y), Vector2(u * r.size.x, r.size.y), Vector2(0, u * r.size.y)][side]
		fx.kp("star_04", p, cell_size * 0.55, color if i % 2 else Color.WHITE, [{s = 0.0, a = 1.0}, {t = 0.4, s = 1.1, r = 60.0, a = 1.0}, {s = 0.0, r = 120.0, a = 0.0}], 520.0, "ease", i * 70.0)


func stop_aura() -> void:
	_finish_pending = false
	if _aura and _aura.visible:
		var tw := _aura.create_tween()
		tw.tween_property(_aura, "modulate:a", 0.0, 0.26)
		tw.tween_callback(_aura.hide)


## 괴물이 포스트잇을 던짐: 포물선으로 날아와 꽂히면 칸이 바뀜 (웹 throwBoxes 120ms 간격)
func _throw(e: Dictionary) -> void:
	var land := func() -> void:
		var old := _view(e.old)
		if old:
			_views.erase(e.old.id)
			old.pop(0.0)
		var nv := _add_view(e.tile, e.pos)
		nv.squish()
		fx.burst(cell_center(e.pos), Color("e8c43a"), 6)
		_sfx("postit", 0.8)
	if fx.fly_tile(art.sticky[0], throw_from.call(), cell_center(e.pos), Color("e8c43a"), land, _throw_i * 120.0):
		_throw_i += 1
		_land_wait = true
	else:
		land.call()
