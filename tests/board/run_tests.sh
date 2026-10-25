#!/usr/bin/env bash
# 보드 테스트를 헤드리스로 돌림. GDScript 실행 오류는 종료 코드에 안 잡혀서 SCRIPT ERROR·ERROR 줄도 실패로 침
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-C:/Users/Dev/tools/Godot4.7.2/Godot_v4.7.2-stable_win64_console.exe}"
failed=0
for t in tests/board/test_board.gd tests/board/test_board_scene.gd; do
	out=$("$GODOT" --headless --path . -s "$t" 2>&1)
	code=$?
	echo "$out" | grep -v '^\s*$' | grep -v '^Godot Engine'
	if [ $code -ne 0 ] || echo "$out" | grep -qE 'SCRIPT ERROR|^ERROR:'; then
		echo "실패: $t"
		failed=1
	fi
done
exit $failed
