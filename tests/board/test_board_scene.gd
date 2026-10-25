extends SceneTree
## 시험 판 씬을 헤드리스로 띄우고 스와이프로 끝까지 둬 봄.
## 턴마다 화면 타일이 판 로직과 하나하나 맞는지(빠진 타일, 남은 타일, 자리) 봄.
## 실행: Godot --headless --path . -s tests/board/test_board_scene.gd

const Util := preload("res://tests/board/board_test_util.gd")

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("    " + msg)


func _run() -> void:
	Engine.time_scale = 8.0  # 연출 기다림을 빨리
	var play: Control = load("res://scenes/board/board_play.tscn").instantiate()
	root.add_child(play)
	await process_frame
	await process_frame
	var view: BoardView = play.get_node("%BoardView")
	check(view.size.x > 0 and view.cell_size >= 40, "판 크기가 안 잡힘: %s" % view.size)
	_check_sync(view, "시작")
	var turns := 0
	while not play.game.over and turns < 60:
		var opts := Util.moves_on(play.game.board)
		check(not opts.is_empty(), "턴 %d: 둘 곳이 없음" % turns)
		if opts.is_empty():
			break
		var m: Array = opts[turns % opts.size()]
		if m.size() == 2:
			await view.swipe(m[0], m[1] - m[0])
		else:
			await view.play(play.game.activate(m[0]))
		turns += 1
		_check_sync(view, "턴 %d" % turns)
	check(play.game.over, "판이 안 끝남")
	await create_timer(0.5).timeout
	check(play.get_node("%Result").visible, "결과 창이 안 뜸")
	print("scene: %d턴, %s, 점수 %d, %d failed" % [turns, "깸" if play.game.won else "못 깸", play.game.score, _fails])
	quit(_fails)


func _check_sync(view: BoardView, when: String) -> void:
	var b := view.game.board
	var views := view._views
	check(views.size() == b.cells().size(), "%s: 화면 타일 %d개, 판 %d개" % [when, views.size(), b.cells().size()])
	for p in b.cells():
		var v: TileView = views.get(b.at(p).id)
		check(v != null, "%s: %s 타일이 화면에 없음" % [when, p])
		if v:
			check(v.position.is_equal_approx(Vector2(p) * view.cell_size), "%s: %s 타일 자리가 %s" % [when, p, v.position])
			check(v.tile == b.at(p), "%s: %s 그림이 다른 타일" % [when, p])
