extends Control
## 퍼즐 한 판: 위에 이동 수·목표·점수, 가운데 판, 끝나면 도장 쾅 → 결과 창.
## 판은 data/puzzles.json에서 puzzle_id로 골라 옴 (이동 수 판만. 시간 판은 아직 안 됨)

const GOAL_CHIP := preload("res://scenes/board/goal_chip.tscn")
const PUZZLES := "res://data/puzzles.json"
const HERO := preload("res://art/characters/grenn_wolf.png")  # 깼을 때 올라오는 친구 (주인공)

@export var puzzle_id := "p019"

var stage: Dictionary
var game: BoardGame

@onready var _board: BoardView = %BoardView
@onready var _area: Control = %BoardArea
@onready var _fx: FxLayer = %Fx


func _ready() -> void:
	_fx.screen = self
	_board.fx = _fx
	_board.goal_at = _goal_at
	_board.goal_bump = _goal_bump
	_board.fly_to = _fly_to
	_board.bonus_from = func(): return %Moves.get_global_rect().get_center()
	_board.changed.connect(_refresh)
	_board.message.connect(_fx.banner)
	_board.finished.connect(_on_finished)
	%Retry.pressed.connect(start)
	stage = load_puzzle(puzzle_id)
	start()


static func load_puzzle(id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PUZZLES))
	for p in data.puzzles:
		if p.id == id:
			return p
	push_error("퍼즐 %s이 %s에 없음" % [id, PUZZLES])
	return {}


func start() -> void:
	game = BoardGame.new()
	game.start(stage)
	%Result.hide()
	for n in %Goals.get_children():
		n.queue_free()
	for g in stage.goals:
		%Goals.add_child(GOAL_CHIP.instantiate())
	await get_tree().process_frame  # 판 자리 크기가 정해진 뒤에 깖
	_board.setup(game, _area.size)
	_board.position = ((_area.size - _board.size) / 2).floor()
	_refresh()
	_board.busy = true
	await _board.drop_in("시작!")
	_board.busy = false


func _refresh() -> void:
	%Moves.text = str(game.moves)
	%Score.text = str(game.score)
	var chips := %Goals.get_children()
	for i in stage.goals.size():
		var g: Dictionary = stage.goals[i]
		chips[i].set_goal(_board.art.goal_icon(g), game.remain(g), "점수 " if g.k == "score" else "")


## 목표 칩 화면 좌표 (k: 목표 이름, tile이면 "tile:번호"). 없으면 Vector2.INF
func _goal_at(k: String) -> Vector2:
	var c := _chip(k)
	return c.center() if c else Vector2.INF


func _goal_bump(k: String) -> void:
	var c := _chip(k)
	if c:
		c.bump()
		_fx.sfx("pop", 1.8)


func _chip(k: String) -> GoalChip:
	var chips := %Goals.get_children()
	for i in mini(stage.goals.size(), chips.size()):
		var g: Dictionary = stage.goals[i]
		if g.k == k or (g.k == "tile" and k == "tile:%d" % int(g.tile)):
			return chips[i]
	return null


## 그 색이 목표면 터진 얼굴이 목표 칩으로 날아감
func _fly_to(t: BoardTile) -> Dictionary:
	var at := _goal_at("tile:%d" % t.type)
	return {} if at == Vector2.INF else {at = at, hit = _goal_bump.bind("tile:%d" % t.type)}


func _on_finished(won: bool, stars: int) -> void:
	_refresh()
	if won:
		await %ClearShow.play("다 지웠다!", HERO, _fx)
	else:
		_fx.banner("이동 끝…", 600)
		_fx.jingle("lose")
		await get_tree().create_timer(1.0).timeout
	%ResultTitle.text = "다 지웠다!" if won else "이동 끝…"
	%ResultStars.text = ("★".repeat(stars) + "☆".repeat(3 - stars)) if won else "다시 해 볼까?"
	%Result.show()
