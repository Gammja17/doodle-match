extends SceneTree
## 퍼즐 보드 헤드리스 테스트.
## 실행: Godot --headless --path . -s tests/board/test_board.gd  (실패 수가 종료 코드)
##
## 판 그림 글자: . 매치 없는 채움 색(0~4)  0~6 그 색  _ 빈칸  # 구멍
##   H 가로 지우개  V 세로 지우개  P 압정  C 크레용  A 종이비행기
##   b 포스트잇  g 두 겹 포스트잇  o 잉크  w 지우개 가루  W 두 겹 가루  i 떨구기 조각

const Util := preload("res://tests/board/board_test_util.gd")

var _fails := 0
var _checks := 0
var _current := ""


func _init() -> void:
	for m in get_method_list():
		if not m.name.begins_with("test_"):
			continue
		_current = m.name
		var before := _fails
		call(m.name)
		print(("  ok    " if _fails == before else "  FAIL  ") + m.name)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(_fails)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		printerr("    %s: %s" % [_current, msg])


# ---------- 판 만들기 ----------

func fill(b: Board, pattern: Array, tapes := []) -> void:
	b.set_size(pattern.size(), pattern[0].length())
	b.grid = []
	var mask := []
	var has_hole := false
	for y in pattern.size():
		var row := []
		var mrow := []
		for x in pattern[y].length():
			var ch: String = pattern[y][x]
			if ch == ".":
				ch = str((x + 2 * y) % 5)
			has_hole = has_hole or ch == "#"
			mrow.append(ch != "#")
			row.append(_tile_for(b, ch))
		b.grid.append(row)
		mask.append(mrow)
	b.mask = mask if has_hole else []
	for p in tapes:
		b.at(p).taped = true


func _tile_for(b: Board, ch: String) -> BoardTile:
	match ch:
		"_", "#": return null
		"H": return b.new_tile(BoardTile.ITEM, Board.ERASER_H)
		"V": return b.new_tile(BoardTile.ITEM, Board.ERASER_V)
		"P": return b.new_tile(BoardTile.ITEM, Board.PUSHPIN)
		"C": return b.new_tile(BoardTile.ITEM, Board.CRAYON)
		"A": return b.new_tile(BoardTile.ITEM, Board.PAPER_PLANE)
		"b": return b.new_block(Board.STICKY, 1)
		"g": return b.new_block(Board.STICKY, 2)
		"o": return b.new_block(Board.INK, 1)
		"w": return b.new_block(Board.CRUMBS, 1)
		"W": return b.new_block(Board.CRUMBS, 2)
		"i": return b.new_deliver("star")
	return b.new_tile(int(ch))


func board_of(pattern: Array, tapes := [], seed := 7) -> Board:
	var b := Board.new()
	b.rng.seed = seed
	b.ntypes = 7
	fill(b, pattern, tapes)
	return b


func game_of(pattern: Array, goals: Array, moves := 20, seed := 7, tapes := []) -> BoardGame:
	var g := BoardGame.new()
	g.board.rng.seed = seed
	var map := []
	for row in pattern:
		map.append("".join(PackedStringArray(Array(row.split("")).map(func(c): return "#" if c == "#" else "."))))
	g.start({tiles = 7, moves = moves, goals = goals, stars = [100, 200, 300], map = map})
	fill(g.board, pattern, tapes)
	return g


func kinds(events: Array) -> Array:
	return events.map(func(e): return e.kind)


func keys_of(b: Board, cells: Array) -> Dictionary:
	var out := {}
	for p in cells:
		out[b.key(p)] = true
	return out


func full_7x7() -> Array:
	return [".......", ".......", ".......", ".......", ".......", ".......", "......."]


# ---------- 매칭 ----------

func test_filler_has_no_match() -> void:
	var b := board_of(full_7x7())
	check(b.find_runs().is_empty(), "채움 판에 매치가 있음")


func test_find_runs_line_and_square() -> void:
	var b := board_of([
		".......",
		"..555..",
		".......",
		"......6",
		"55....6",
		"55....6",
		"......6",
	])
	var runs := b.find_runs()
	var dirs := runs.map(func(r): return [String(r.dir), r.cells.size()])
	check(dirs.has(["h", 3]), "가로 3개를 못 찾음 %s" % [dirs])
	check(dirs.has(["v", 4]), "세로 4개를 못 찾음 %s" % [dirs])
	check(dirs.has(["sq", 4]), "2x2 네모를 못 찾음 %s" % [dirs])
	check(runs.size() == 3, "매치 수가 3이 아님 %s" % [dirs])


func test_makes_match_on_create() -> void:
	for s in 20:
		var b := Board.new()
		b.rng.seed = s
		b.ntypes = 5
		b.create({blocks = [[Vector2i(3, 3), Board.STICKY, 2], [Vector2i(0, 6), Board.INK, 1]], tapes = [Vector2i(1, 1)]})
		check(b.find_runs().is_empty(), "seed %d: 새 판에 매치가 있음" % s)
		check(b.has_move(), "seed %d: 새 판에 둘 곳이 없음" % s)
		check(b.at(Vector2i(3, 3)).block == Board.STICKY and b.at(Vector2i(3, 3)).hp == 2, "포스트잇이 제자리에 없음")
		check(b.at(Vector2i(1, 1)).taped, "테이프가 안 붙음")


# ---------- 아이템 생성 ----------

func test_four_makes_eraser_at_swapped_cell() -> void:
	var b := board_of([".......", "5555...", "......."])
	var res := b.resolve([Vector2i(1, 1), Vector2i(1, 0)])
	check(res.created.size() == 1, "아이템이 하나 안 생김")
	check(res.created[0].pos == Vector2i(1, 1), "바꾼 칸에 안 생김: %s" % res.created[0].pos)
	check(res.created[0].tile.special == Board.ERASER_V, "가로 4개 -> 세로 지우개가 아님")
	check(res.cleared.size() == 4, "4칸이 지워지고 그 자리에 생겨야 함: %d" % res.cleared.size())
	check(b.at(Vector2i(1, 1)).special == Board.ERASER_V, "판에 지우개가 없음")
	check(res.effects.is_empty(), "방금 생긴 아이템이 같은 단계에 터짐")


func test_vertical_four_makes_horizontal_eraser() -> void:
	var b := board_of(["..5....", "..5....", "..5....", "..5....", "......."])
	var res := b.resolve()
	check(res.created.size() == 1 and res.created[0].tile.special == Board.ERASER_H, "세로 4개 -> 가로 지우개가 아님")


func test_five_makes_crayon_in_middle() -> void:
	var b := board_of([".......", ".55555.", "......."])
	var res := b.resolve()
	check(res.created.size() == 1 and res.created[0].tile.special == Board.CRAYON, "5개 -> 크레용이 아님")
	check(res.created[0].pos == Vector2i(3, 1), "가운데에 안 생김: %s" % res.created[0].pos)


func test_l_shape_makes_pushpin_at_corner() -> void:
	var b := board_of([".......", ".5.....", ".5.....", ".555...", "......."])
	var res := b.resolve()
	check(res.created.size() == 1 and res.created[0].tile.special == Board.PUSHPIN, "L -> 압정이 아님")
	check(res.created[0].pos == Vector2i(1, 3), "모서리에 안 생김: %s" % res.created[0].pos)
	check(res.cleared.size() == 5, "L 5칸이 안 지워짐: %d" % res.cleared.size())


func test_t_shape_makes_pushpin() -> void:
	var b := board_of([".......", ".555...", "..5....", "..5....", "......."])
	var res := b.resolve()
	check(res.created.size() == 1 and res.created[0].tile.special == Board.PUSHPIN, "T -> 압정이 아님")
	check(res.created[0].pos == Vector2i(2, 1), "가로세로 만나는 칸이 아님: %s" % res.created[0].pos)


func test_square_makes_paper_plane() -> void:
	var b := board_of([".......", "..55...", "..55...", "......."])
	var res := b.resolve()
	check(res.created.size() == 1 and res.created[0].tile.special == Board.PAPER_PLANE, "네모 -> 종이비행기가 아님")


func test_three_makes_nothing() -> void:
	var b := board_of([".......", "..555..", "......."])
	var res := b.resolve()
	check(res.created.is_empty(), "3개에서 아이템이 생김")
	check(res.cleared.size() == 3, "3칸이 안 지워짐")


## 아이템 생성이 블럭 파괴보다 먼저: 밀어 쓴 아이템은 다음 단계에 터지고, 방금 생긴 아이템은 그때 지켜짐
func test_new_item_created_before_moved_item_fires() -> void:
	var b := board_of([
		".......",
		"..5....",
		"55V5...",
		".......",
		".......",
	])
	var a := Vector2i(2, 1)
	var c := Vector2i(2, 2)
	b.swap(a, c)  # 5가 내려와 5555, 세로 지우개는 위로
	var r1 := b.resolve([a, c], [a])
	check(r1.created.size() == 1 and r1.created[0].pos == c, "첫 단계에 새 아이템이 안 생김")
	check(r1.effects.is_empty(), "첫 단계에 밀어 쓴 아이템이 먼저 터짐")
	check(b.at(a) != null and b.at(a).special == Board.ERASER_V, "밀어 쓴 지우개가 사라짐")
	var r2 := b.resolve()
	check(r2.effects.size() == 1 and r2.effects[0].kind == Board.ERASER_V, "둘째 단계에 미룬 지우개가 안 터짐")
	check(b.at(c) != null and b.at(c).special == Board.ERASER_V, "방금 생긴 아이템이 지켜지지 않음")
	check(b.at(Vector2i(2, 0)) == null and b.at(Vector2i(2, 4)) == null, "세로 줄이 안 지워짐")


# ---------- 아이템 효과, 합치기 ----------

func test_eraser_and_pushpin_effects() -> void:
	var b := board_of(full_7x7())
	var e := b.effect_cells(b.new_tile(BoardTile.ITEM, Board.ERASER_H), Vector2i(3, 2))
	check(e.size() == 7 and e.all(func(p): return p.y == 2), "가로 지우개가 한 줄이 아님")
	var p := b.effect_cells(b.new_tile(BoardTile.ITEM, Board.PUSHPIN), Vector2i(3, 3))
	check(p.size() == 13, "압정 마름모가 13칸이 아님: %d" % p.size())
	var corner := b.effect_cells(b.new_tile(BoardTile.ITEM, Board.PUSHPIN), Vector2i(0, 0))
	check(corner.size() == 6, "모서리 압정이 판 밖을 셈: %d" % corner.size())


func test_paper_plane_flies_to_block() -> void:
	var b := board_of([".......", ".A.....", ".......", ".......", ".......", ".......", "......b"])
	var cells := b.effect_cells(b.at(Vector2i(1, 1)), Vector2i(1, 1))
	check(cells.size() == 6, "십자 5칸 + 목표 1칸이 아님: %d" % cells.size())
	check(b.at(Vector2i(1, 1)).target == Vector2i(6, 6), "장애물로 안 날아감: %s" % b.at(Vector2i(1, 1)).target)


func test_combo_eraser_eraser_cross() -> void:
	var b := board_of([".......", ".......", ".......", "...HV..", ".......", ".......", "......."])
	var combo := b.swap_combo(Vector2i(3, 3), Vector2i(4, 3))
	check(combo.kind == "eraser_h+eraser_v", "합치기 이름: %s" % combo.kind)
	var k := keys_of(b, combo.cells)
	for i in 7:
		check(k.has(b.key(Vector2i(i, 3))) and k.has(b.key(Vector2i(4, i))), "십자에 빠진 칸: %d" % i)
	check(k.size() == 13, "십자가 13칸이 아님: %d" % k.size())
	check(b.at(Vector2i(3, 3)).special == &"" and b.at(Vector2i(4, 3)).special == &"", "합친 뒤 아이템이 남음")


func test_combo_pushpin_pushpin_big_square() -> void:
	var p := []
	for y in 9:
		p.append(".........")
	p[4] = "...PP...."
	var b := board_of(p)
	var combo := b.swap_combo(Vector2i(3, 4), Vector2i(4, 4))
	check(keys_of(b, combo.cells).size() == 49, "압정+압정 7x7이 아님: %d" % keys_of(b, combo.cells).size())


func test_combo_pushpin_eraser_wide_cross() -> void:
	var p := []
	for y in 9:
		p.append(".........")
	p[4] = "...PH...."
	var b := board_of(p)
	var combo := b.swap_combo(Vector2i(3, 4), Vector2i(4, 4))
	check(keys_of(b, combo.cells).size() == 9 * 3 * 2 - 9, "압정+지우개 3줄 십자가 아님: %d" % keys_of(b, combo.cells).size())


func test_combo_crayon_with_color() -> void:
	var b := board_of([".......", "C5.....", "...5...", ".....5.", "......."])
	var combo := b.swap_combo(Vector2i(0, 1), Vector2i(1, 1))
	check(combo.kind == Board.CRAYON and combo.type == 5, "크레용이 그 색을 안 고름")
	check(combo.cells.size() == 4, "크레용 + 5색 3개 = 4칸이 아님: %d" % combo.cells.size())


func test_combo_crayon_crayon_clears_all() -> void:
	var b := board_of([".......", ".CC....", "......."])
	var combo := b.swap_combo(Vector2i(1, 1), Vector2i(2, 1))
	check(combo.cells.size() == 21, "크레용 두 개가 판 전체가 아님: %d" % combo.cells.size())


func test_combo_crayon_eraser_converts() -> void:
	var b := board_of(full_7x7())
	b.put(Vector2i(0, 0), b.new_tile(BoardTile.ITEM, Board.CRAYON))
	b.put(Vector2i(1, 0), b.new_tile(BoardTile.ITEM, Board.ERASER_H))
	var combo := b.swap_combo(Vector2i(0, 0), Vector2i(1, 0))
	check(combo.converted, "바뀌었다고 안 함")
	var all_items := true
	for q in b.cells():
		var t := b.at(q)
		if t.type == combo.type and t.special != Board.ERASER_H and t.special != Board.ERASER_V:
			all_items = false
	check(all_items, "그 색이 다 지우개로 안 바뀜")


func test_combo_plane_carries_eraser() -> void:
	var b := board_of([".......", ".AH....", ".......", ".......", ".......", "....g..", "......."])
	var combo := b.swap_combo(Vector2i(1, 1), Vector2i(2, 1))
	check(combo.planes == [Vector2i(4, 5)], "비행기가 포스트잇으로 안 감: %s" % [combo.planes])
	check(combo.carry == Board.ERASER_H, "지우개를 안 싣고 감")
	var k := keys_of(b, combo.cells)
	for x in 7:
		check(k.has(b.key(Vector2i(x, 5))), "도착한 줄이 안 지워짐: %d" % x)


func test_combo_plane_plane_three_planes() -> void:
	var b := board_of([".......", ".AA....", ".......", ".......", ".......", ".......", "......."])
	var combo := b.swap_combo(Vector2i(1, 1), Vector2i(2, 1))
	check(combo.planes.size() == 3, "비행기 셋이 안 날아감: %d" % combo.planes.size())


# ---------- 장애물 ----------

func test_sticky_two_layers() -> void:
	var b := board_of([".......", ".......", "..g....", ".555...", "......."])
	var r1 := b.resolve()
	check(r1.hits.size() == 1 and not r1.hits[0].gone, "두 겹 포스트잇이 한 번에 떨어짐")
	check(b.at(Vector2i(2, 2)).hp == 1, "포스트잇 한 겹이 안 벗겨짐")
	for x in [1, 2, 3]:
		b.put(Vector2i(x, 3), b.new_tile(6))
	var r2 := b.resolve()
	check(r2.hits.size() == 1 and r2.hits[0].gone, "두 번째에 안 떨어짐")
	check(b.at(Vector2i(2, 2)) == null, "떨어진 자리가 안 비워짐")


func test_block_not_hit_by_far_match() -> void:
	var b := board_of([".......", "b......", ".......", "...555.", "......."])
	var res := b.resolve()
	check(res.hits.is_empty(), "멀리 있는 포스트잇이 맞음")


func test_crumbs_hit_by_eraser() -> void:
	var b := board_of([".......", "...H..W", "......."])
	var res := b.resolve([], [Vector2i(3, 1)])
	check(res.hits.size() == 1 and res.hits[0].tile.block == Board.CRUMBS and not res.hits[0].gone, "지우개 줄 끝 가루가 안 맞음")
	check(b.at(Vector2i(6, 1)).hp == 1, "가루 한 겹이 안 줄어듦")


func test_tape_comes_off_tile_stays() -> void:
	var b := board_of([".......", ".555...", "......."], [Vector2i(2, 1)])
	check(not Board.movable(b.at(Vector2i(2, 1))), "테이프 칸이 움직임")
	var res := b.resolve()
	check(res.unlocked.size() == 1 and res.cleared.size() == 2, "테이프만 떨어져야 함")
	var t := b.at(Vector2i(2, 1))
	check(t != null and not t.taped and t.type == 5, "테이프 친구가 사라지거나 테이프가 남음")


func test_no_item_on_taped_cell() -> void:
	var b := board_of([".......", "5555...", "......."], [Vector2i(1, 1)])
	var res := b.resolve([Vector2i(1, 1), Vector2i(1, 0)])
	check(res.created.size() == 1 and res.created[0].pos != Vector2i(1, 1), "테이프 칸에 아이템이 생김")
	check(b.at(Vector2i(1, 1)).type == 5 and not b.at(Vector2i(1, 1)).taped, "테이프 친구가 그대로 안 남음")


func test_ink_spreads_when_not_hit() -> void:
	var g := game_of([".......", "...5...", "55.5...", ".......", ".......", ".......", "......o"], [{k = "ink"}])
	var ev := g.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	check(kinds(ev).has("ink_spread"), "잉크를 안 맞혔는데 안 번짐: %s" % [kinds(ev)])
	check(g.count("ink") == 2, "잉크가 2칸이 아님: %d" % g.count("ink"))


func test_ink_hit_stops_spread() -> void:
	var g := game_of([".......", "...5...", "55.5...", "..o....", ".......", ".......", "......o"], [{k = "ink"}])
	var ev := g.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	check(not kinds(ev).has("ink_spread"), "잉크를 맞혔는데 번짐")
	check(g.board.at(Vector2i(2, 3)) == null or g.board.at(Vector2i(2, 3)).block != Board.INK, "매치 옆 잉크가 안 지워짐")


func test_highlighter_spreads_from_painted_cell() -> void:
	var b := board_of([".......", ".555...", ".......", "....666", "......."])
	b.highlight = []
	for y in 5:
		b.highlight.append([false, false, false, false, false, false, false])
	b.highlight[1][1] = true
	var res := b.resolve()
	check(res.highlight.size() == 2, "칠한 칸이 낀 매치에서 2칸 번져야 함: %d" % res.highlight.size())
	check(b.highlight[1][2] and b.highlight[1][3], "매치 칸이 안 칠해짐")
	check(not b.highlight[3][4], "형광펜 없는 매치가 칠해짐")


func test_drop_collected_at_bottom() -> void:
	var b := board_of([".......", ".......", "..i....", ".......", "i......", "b......"])
	check(b.collect_delivers().size() == 1, "포스트잇 위 바닥 조각만 모여야 함")
	check(b.at(Vector2i(0, 4)) == null and b.at(Vector2i(2, 2)) != null, "엉뚱한 조각이 모임")
	b.put(Vector2i(2, 5), b.new_deliver("star"))
	check(b.collect_delivers().size() == 1, "맨 밑 조각이 안 모임")


func test_drop_not_cleared_by_match() -> void:
	var b := board_of([".......", ".......", "..H.i..", "......."])
	b.resolve([], [Vector2i(2, 2)])
	check(b.at(Vector2i(4, 2)) != null and b.at(Vector2i(4, 2)).type == BoardTile.DELIVER, "떨구기 조각이 터짐")


# ---------- 떨어뜨리기, 섞기, 막힘 ----------

func test_gravity_fills_under_blocks() -> void:
	var b := board_of([".......", "...b...", "..._...", "..___..", "...____", "......."])
	b.gravity()
	var empty := 0
	for y in b.rows:
		for x in b.cols:
			if b.at(Vector2i(x, y)) == null:
				empty += 1
	check(empty == 0, "빈칸이 %d개 남음" % empty)
	check(b.at(Vector2i(3, 1)).block == Board.STICKY, "포스트잇이 떨어짐")


func test_gravity_respects_holes() -> void:
	var b := board_of(["#.....#", "#_____#", "..._...", "###.###"])
	var paths := b.gravity()
	check(b.at(Vector2i(0, 0)) == null and b.at(Vector2i(3, 3)) != null, "구멍이 채워지거나 아래가 안 채워짐")
	check(paths.any(func(p): return p.fresh), "새 친구가 안 나옴")
	for p in paths:
		for step in p.path:
			if step.y >= 0:
				check(not b.hole(Vector2i(step.x, step.y)), "구멍을 지나감 %s" % step)


func test_shuffle_keeps_blocks_and_finds_move() -> void:
	for s in 10:
		var b := board_of(["0123i", "1b30g", "2301o", "30_23", "01230"], [Vector2i(0, 4)], s)
		b.ntypes = 4
		var before := {}
		for q in b.cells():
			if not Board.movable(b.at(q)) or b.at(q).type == BoardTile.DELIVER:
				before[q] = b.at(q)
		var types := b.cells().map(func(q): return b.at(q).type)
		types.sort()
		b.shuffle()
		for q in before:
			check(b.at(q) == before[q], "seed %d: 섞기로 %s가 움직임" % [s, q])
		check(b.find_runs().is_empty(), "seed %d: 섞은 뒤 매치가 있음" % s)
		check(b.has_move(), "seed %d: 섞은 뒤 둘 곳이 없음" % s)
		var after := b.cells().map(func(q): return b.at(q).type)
		after.sort()
		check(after == types, "seed %d: 섞기가 색을 바꿈" % s)


func test_has_move_counts_items() -> void:
	var b := board_of(["0101", "2323", "0101", "232H"])
	check(b.has_move(), "아이템이 있으면 둘 곳이 있음")
	b.put(Vector2i(3, 3), b.new_tile(3))
	check(not b.has_move(), "막힌 판인데 둘 곳이 있다고 함")


func test_random_play_never_stuck() -> void:
	var stage_map := ["...p...", ".t...t.", "..C.C..", ".......", "k.....k", ".d.P.d.", "......."]
	var wins := 0
	for s in 12:
		var g := BoardGame.new()
		g.board.rng.seed = s
		# 짝수 판은 못 깨는 목표(이동을 다 씀), 홀수 판은 장애물 목표(깨면 보너스 타임)
		var goals := [{k = "tile", tile = 0, n = 999}] if s % 2 == 0 else [{k = "sticky"}, {k = "crumbs"}, {k = "deliver"}]
		g.start({tiles = 5, moves = 40, goals = goals, stars = [1, 2, 3], map = stage_map,
			deliver = {total = 4, max_on_board = 2, kinds = ["ing_a", "ing_b"]}})
		var pick := RandomNumberGenerator.new()
		pick.seed = s
		var turns := 0
		while not g.over and turns < 60:
			var options := Util.moves_on(g.board)
			check(not options.is_empty(), "seed %d 턴 %d: 둘 곳이 없음" % [s, turns])
			if options.is_empty():
				break
			var m: Array = options[pick.randi_range(0, options.size() - 1)]
			var ev := g.try_swap(m[0], m[1]) if m.size() == 2 else g.activate(m[0])
			check(not ev.is_empty() and not kinds(ev).has("swap_back"), "seed %d: 고른 수가 안 먹힘" % s)
			turns += 1
			check(g.board.find_runs().is_empty(), "seed %d 턴 %d: 턴이 끝났는데 매치가 남음" % [s, turns])
			check(g.board.has_move(), "seed %d 턴 %d: 턴이 끝났는데 둘 곳이 없음" % [s, turns])
			# 빈칸은 잉크·장애물에 위와 옆이 다 막혀 못 채우는 칸뿐 (웹판과 같음): 다시 떨어뜨려도 움직이는 게 없어야 함
			check(g.board.gravity().is_empty(), "seed %d 턴 %d: 판이 덜 떨어짐" % [s, turns])
		check(g.over and g.moves == 0, "seed %d: 판이 안 끝남" % s)
		if s % 2 == 0:
			check(not g.won, "seed %d: 못 깨는 판을 깸" % s)
		elif g.won:
			wins += 1
	check(wins > 0, "장애물 판을 한 번도 못 깸 (보너스 타임을 못 거침)")


# ---------- 판 진행 ----------

func test_bad_swap_goes_back() -> void:
	var g := game_of(full_7x7(), [{k = "score", n = 99999}], 5)
	var before := g.board.at(Vector2i(0, 0))
	var ev := g.try_swap(Vector2i(0, 0), Vector2i(1, 0))
	check(kinds(ev) == ["swap", "swap_back"], "매치 없는 바꾸기가 안 돌아감: %s" % [kinds(ev)])
	check(g.board.at(Vector2i(0, 0)) == before and g.moves == 5, "판이나 이동 수가 바뀜")


func test_swap_match_uses_move_and_scores() -> void:
	var g := game_of([".......", "...5...", "55.5...", ".......", ".......", ".......", "......."], [{k = "score", n = 99999}], 5)
	var ev := g.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	check(kinds(ev).slice(0, 3) == ["swap", "step", "fall"], "사건 순서: %s" % [kinds(ev)])
	check(g.moves == 4, "이동 수가 안 줄어듦: %d" % g.moves)
	check(g.score > 0, "점수가 안 오름")
	check(g.tile_counts.get(5, 0) >= 3, "터뜨린 색을 안 셈")


func test_moved_item_fires_without_match() -> void:
	var g := game_of([".......", ".......", "...H...", ".......", "......."], [{k = "score", n = 99999}], 5)
	var ev := g.try_swap(Vector2i(3, 2), Vector2i(3, 3))
	var steps := ev.filter(func(e): return e.kind == "step")
	check(not steps.is_empty() and steps[0].res.effects.size() == 1, "밀어 옮긴 지우개가 안 터짐")
	check(steps[0].res.effects[0].pos == Vector2i(3, 3), "옮긴 자리에서 안 터짐")


func test_swap_two_items_combines() -> void:
	var g := game_of([".......", ".......", "...PH..", ".......", "......."], [{k = "score", n = 99999}], 5)
	var ev := g.try_swap(Vector2i(3, 2), Vector2i(4, 2))
	check(kinds(ev).slice(0, 2) == ["swap", "combo"], "합치기 사건이 없음: %s" % [kinds(ev)])
	check(ev[1].combo.kind == "eraser_h+pushpin", "합치기 이름: %s" % ev[1].combo.kind)


func test_activate_item_costs_a_move() -> void:
	var g := game_of([".......", ".......", "...P...", ".......", "......."], [{k = "score", n = 99999}], 5)
	check(g.activate(Vector2i(0, 0)).is_empty(), "아이템 아닌 칸이 발동됨")
	var ev := g.activate(Vector2i(3, 2))
	check(kinds(ev).slice(0, 2) == ["activate", "step"], "누른 아이템이 안 터짐: %s" % [kinds(ev)])
	check(g.moves == 4, "아이템 누르기가 한 턴을 안 씀")


func test_goal_counts() -> void:
	var g := game_of(["b.g....", ".o.....", "..w....", "......."], [{k = "sticky"}, {k = "ink"}, {k = "crumbs"}, {k = "tape"}], 5, 7, [Vector2i(3, 3)])
	check(g.remain({k = "sticky"}) == 2 and g.remain({k = "ink"}) == 1 and g.remain({k = "crumbs"}) == 1 and g.remain({k = "tape"}) == 1, "목표 개수가 틀림")
	check(not g.is_done(), "남은 목표가 있는데 끝남")


func test_win_runs_bonus_time() -> void:
	var g := game_of([".......", "...5...", "55.5...", ".......", ".......", ".......", "......."], [{k = "score", n = 1}], 6)
	var ev := g.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	var k := kinds(ev)
	check(k.has("bonus_start") and k.has("bonus_end") and k[-1] == "win", "보너스 타임 뒤 승리가 아님: %s" % [k])
	check(k.count("convert") == 5, "남은 이동 5개가 아이템 5개로 안 바뀜: %d" % k.count("convert"))
	check(g.over and g.won and g.moves == 0, "끝난 상태가 아님")
	check(g.score >= 5 * 150, "보너스 점수가 안 들어옴")


func test_fail_when_moves_run_out() -> void:
	var g := game_of([".......", "...5...", "55.5...", ".......", ".......", ".......", "......."], [{k = "tile", tile = 0, n = 999}], 1)
	var ev := g.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	check(kinds(ev)[-1] == "fail" and g.over and not g.won, "이동을 다 썼는데 실패가 아님: %s" % [kinds(ev)])
	check(g.try_swap(Vector2i(0, 0), Vector2i(1, 0)).is_empty(), "끝난 판에서 또 둘 수 있음")


func test_deliver_goal_collects() -> void:
	var g := BoardGame.new()
	g.board.rng.seed = 3
	g.start({tiles = 5, moves = 30, goals = [{k = "deliver"}], stars = [1, 2, 3], map = [".....", ".....", ".....", ".....", "....."],
		deliver = {total = 2, max_on_board = 2, kinds = ["ing_a"]}})
	fill(g.board, ["0123i", "12301", "23012", "30120", "01i01"])
	g._collect()
	check(g.delivered == 1 and g.score == 500, "바닥 조각 하나만 모여야 함: %d" % g.delivered)
	check(g.board.at(Vector2i(4, 0)).type == BoardTile.DELIVER, "위쪽 조각이 모임")
	check(g.remain({k = "deliver"}) == 1, "남은 조각 수가 틀림")


func test_tile_goal_with_json_numbers() -> void:
	# JSON 숫자는 float로 들어옴: 구슬 번호 1.0도 1로 세야 함
	var g := game_of([".......", "...5...", "55.5...", ".......", ".......", ".......", "......."], [{k = "tile", tile = 5.0, n = 3.0}], 5)
	g.try_swap(Vector2i(2, 2), Vector2i(3, 2))
	check(g.remain(g.stage.goals[0]) == 0, "float 구슬 번호 목표를 못 셈")


# ---------- 내보낸 데이터 (data/puzzles.json) ----------

func test_exported_puzzles_start() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var n := 0
	for st in data.puzzles:
		if not st.has("moves"):
			continue  # 시간 판은 아직 안 받음
		var g := BoardGame.new()
		g.board.rng.seed = n
		g.start(st)
		n += 1
		var b := g.board
		var want := {}
		var map := "".join(PackedStringArray(st.map))
		for ch in "cCpPktd":
			want[ch] = map.count(ch)
		var got := {c = 0, C = 0, p = 0, P = 0, k = 0, t = 0, d = 0}
		for q in b.cells():
			var t := b.at(q)
			if t.block == Board.CRUMBS:
				got["c" if t.hp == 1 else "C"] += 1
			elif t.block == Board.STICKY:
				got["p" if t.hp == 1 else "P"] += 1
			elif t.block == Board.INK:
				got.k += 1
			elif t.type == BoardTile.DELIVER:
				got.d += 1
			if t.taped:
				got.t += 1
		for ch in want:
			check(want[ch] == got[ch], "%s: %s 글자 %d개인데 판에 %d개" % [st.id, ch, want[ch], got[ch]])
		check(b.find_runs().is_empty() and b.has_move(), "%s: 시작 판이 이상함" % st.id)
		check(st.goals.all(func(x): return x.k in ["crumbs", "sticky", "ink", "tape", "highlighter", "deliver", "tile", "score"]), "%s: 모르는 목표 %s" % [st.id, st.goals])
	check(n == 194, "이동 수 판이 194개가 아님: %d" % n)


func test_exported_puzzles_play_through() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var pick := RandomNumberGenerator.new()
	pick.seed = 11
	var played := 0
	for i in range(0, data.puzzles.size(), 7):  # 30개쯤 골라서
		var st: Dictionary = data.puzzles[i]
		if not st.has("moves"):
			continue
		var g := BoardGame.new()
		g.board.rng.seed = i
		g.start(st)
		var turns := 0
		while not g.over and turns < 200:
			var options := Util.moves_on(g.board)
			if options.is_empty():
				check(false, "%s 턴 %d: 둘 곳이 없음" % [st.id, turns])
				break
			var m: Array = options[pick.randi_range(0, options.size() - 1)]
			var ev := g.try_swap(m[0], m[1]) if m.size() == 2 else g.activate(m[0])
			check(not kinds(ev).has("swap_back"), "%s: 고른 수가 안 먹힘" % st.id)
			turns += 1
			check(g.board.find_runs().is_empty() and g.board.has_move(), "%s 턴 %d: 판이 덜 끝남" % [st.id, turns])
		check(g.over, "%s: 안 끝남" % st.id)
		played += 1
	check(played > 20, "판을 너무 적게 둠: %d" % played)
