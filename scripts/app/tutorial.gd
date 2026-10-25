class_name Tutorial
extends RefCounted










const ITEM_KIND: = {
	"eraser": [&"eraser_h", &"eraser_v"], "pushpin": [&"pushpin"], "plane": [&"paper_plane"], "crayon": [&"crayon"], 
}

const LESSONS: = {
	"p001": {
		board = [".......", ".......", "1020312", "2301231"], 
		steps = [
			{do = "move", a = Vector2i(2, 3), b = Vector2i(2, 2), say = "쓱 밀어서 3개 맞춰 봐"}, 
			{do = "spot", target = "goals", say = "이걸 다 지우면 이겨"}, 
			{do = "spot", target = "moves", say = "이건 남은 이동 수야"}, 
		], 
	}, 
	"p002": {
		board = [".......", "..121..", "3120132", "2001032", "1230213", "3102321"], 
		steps = [
			{do = "make:eraser", a = Vector2i(3, 4), b = Vector2i(3, 3), say = "4개를 맞춰 봐"}, 
			{do = "item", kind = "eraser", say = "지우개가 생겼어!"}, 
			{do = "use", kind = "eraser", say = "지우개를 밀어 봐"}, 
		], 
	}, 
	"p003": {
		board = [".......", "1230412", "3410234", "2101043", ".34023.", "..243.."], 
		steps = [
			{do = "make:pushpin", a = Vector2i(3, 4), b = Vector2i(3, 3), say = "ㄱ자로 맞춰 봐"}, 
			{do = "item", kind = "pushpin", say = "압정이 생겼어!"}, 
			{do = "use", kind = "pushpin", say = "압정을 밀어 봐"}, 
		], 
	}, 
	"p004": {
		board = [".......", "3200142", "..010..", "..234.."], 
		steps = [
			{do = "make:plane", a = Vector2i(4, 2), b = Vector2i(3, 2), say = "네모로 4개 맞춰 봐"}, 
			{do = "item", kind = "plane", say = "종이비행기야!"}, 
			{do = "use", kind = "plane", say = "비행기를 밀어 봐"}, 
		], 
	}, 
	"p005": {
		board = [".......", ".......", "1342134", "0010043", "230.142"], 
		steps = [
			{do = "make:crayon", a = Vector2i(2, 4), b = Vector2i(2, 3), say = "5개를 맞춰 봐"}, 
			{do = "item", kind = "crayon", say = "크레용이 생겼어!"}, 
			{do = "use", kind = "crayon", say = "크레용을 밀어 봐"}, 
		], 
	}, 
	"p006": {
		board = [".......", ".......", "12EP340"], 
		steps = [
			{do = "spot_cells", a = Vector2i(2, 2), b = Vector2i(3, 2), say = "아이템끼리 합치면 세져"}, 
			{do = "move", a = Vector2i(2, 2), b = Vector2i(3, 2), say = "둘을 쓱 바꿔 봐"}, 
		], 
	}, 
	"b001": {
		steps = [
			{do = "spot", target = "party", say = "구슬을 터뜨리면 친구가 때려"}, 
			{do = "spot", target = "monsters", say = "숫자가 0이면 괴물이 때려"}, 
			{do = "spot", target = "party", say = "게이지가 차면 친구를 톡!"}, 
		], 
	}, 
}


static func has(ref: String) -> bool:
	return LESSONS.has(ref) and not AppState.seen("tips", ref)



static func board(ref: String) -> Array:
	return LESSONS.get(ref, {}).get("board", []) if has(ref) else []



static func run(tutor: Tutor, ref: String, ctx: Dictionary, moved: Signal) -> void :
	if not has(ref):
		return
	var view: BoardView = ctx.get("board")
	for st: Dictionary in LESSONS[ref].steps:
		var doing: String = st.do.get_slice(":", 0)
		match doing:
			"spot":
				var c: Control = ctx.get(st.target)
				if c == null:
					continue
				tutor.spot(c.get_global_rect(), st.say)
				tutor.point_at(c)
				await tutor.wait_tap()
			"spot_cells":
				tutor.spot(_cells_rect(view, [st.a, st.b]), st.say)
				await tutor.wait_tap()
			"move", "make":
				await _guide_move(tutor, view, st.a, st.b, st.say, moved)
			"item", "use":
				var p: = _find(view, st.kind)
				if p == Board.NO_CELL:
					continue
				if doing == "item":
					tutor.spot(_cells_rect(view, [p]), st.say)
					await tutor.wait_tap()
				else:
					var q: = _neighbor(view, p)
					if q != Board.NO_CELL:
						await _guide_move(tutor, view, p, q, st.say, moved)
		tutor.clear()
	tutor.clear()
	AppState.mark_seen("tips", ref)



static func _guide_move(tutor: Tutor, view: BoardView, a: Vector2i, b: Vector2i, say: String, moved: Signal) -> void :
	tutor.spot(_cells_rect(view, [a, b]), say)
	tutor.point_move(view.cell_center(a), view.cell_center(b))
	if view.has_method("allow_only"):
		view.allow_only(a, b)
	await moved
	if view.has_method("allow_only"):
		view.allow_only(Board.NO_CELL, Board.NO_CELL)


static func _cells_rect(view: BoardView, cells: Array) -> Rect2:
	var r: = Rect2()
	for i in cells.size():
		var c: = Rect2(view.cell_center(cells[i]) - Vector2.ONE * view.cell_size / 2, Vector2.ONE * view.cell_size)
		r = c if i == 0 else r.merge(c)
	return r



static func _find(view: BoardView, kind: String) -> Vector2i:
	var b: Board = view.game.board
	for p in b.cells():
		if b.at(p).special in ITEM_KIND.get(kind, []):
			return p
	return Board.NO_CELL



static func _neighbor(view: BoardView, p: Vector2i) -> Vector2i:
	var b: Board = view.game.board
	for d: Vector2i in Board.NEAR4:
		if Board.movable(b.at(p + d)):
			return p + d
	return Board.NO_CELL
