extends RefCounted
## 테스트 공용 도우미


## 둘 수 있는 수: [a, b] 바꾸기 또는 [p] 아이템 누르기
static func moves_on(b: Board) -> Array:
	var out := []
	for p in b.cells():
		if not Board.movable(b.at(p)):
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = p + d
			if not Board.movable(b.at(q)):
				continue
			b.swap(p, q)
			var ok := not b.find_runs().is_empty()
			b.swap(p, q)
			if ok or b.at(p).special != &"" or b.at(q).special != &"":
				out.append([p, q])
	if out.is_empty():
		for p in b.cells():
			if b.at(p).special != &"":
				out.append([p])
	return out
