extends SceneTree
## 반짝 뽑기 확률 공개 데이터를 JSON으로 내보냄 (홈페이지·docs/release/probability.md 맞추기용).
## 실행: Godot --headless --path . -s scripts/meta/export_rates.gd -- [날짜 2026-11-01] [저장할 파일]
##   날짜를 안 주면 오늘 배너, 파일을 안 주면 화면에 찍음. 실제 뽑기와 같은 표(sparkle_gacha.gd)에서 만듦


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var m := Meta.new()
	m.save_path = ""
	if args.size() > 0:
		var t := Time.get_unix_time_from_datetime_string(args[0]) * 1000
		m.clock = func() -> int: return t
	var text := JSON.stringify(m.sparkle_rates(), " ")
	if args.size() > 1:
		var f := FileAccess.open(args[1], FileAccess.WRITE)
		f.store_string(text + "\n")
		f.close()
	else:
		print(text)
	quit()
