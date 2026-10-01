extends "res://tests/test_case.gd"
## 화면 설정(Prefs): 하단 메뉴 시트 높이의 기본값, 바꾸기와 시그널, 저장과 복원, 옛 저장, 새 판과 데이터 초기화


func run() -> void:
	_fresh_run()
	_close(Prefs.sheet_height, 0.0, "기본은 접힘(0)")
	var seen: Array[float] = []
	var handler := func(height: float) -> void: seen.append(height)
	Prefs.sheet_height_changed.connect(handler)
	Prefs.set_sheet_height(900.0)
	_close(Prefs.sheet_height, 900.0, "높이 900")
	Prefs.set_sheet_height(900.0)
	_equal(seen.size(), 1, "바꿀 때만 시그널 (같은 값은 조용하다)")
	_close(seen[0], 900.0, "시그널에 새 높이")
	Prefs.set_sheet_height(-5.0)
	_close(Prefs.sheet_height, 0.0, "음수는 0(접힘)으로")
	Prefs.sheet_height_changed.disconnect(handler)

	Prefs.set_sheet_height(900.0)
	var data := Save.to_dict()
	_equal(data.has("prefs"), true, "저장 데이터에 prefs 절이 들어간다")
	_close(float(data["prefs"]["sheet_height"]), 900.0, "높이 저장")
	Prefs.reset()
	_close(Prefs.sheet_height, 0.0, "초기화는 접힘")
	Save.from_dict(data)
	_close(Prefs.sheet_height, 900.0, "높이 복원")
	Save.from_dict({"save_version": 1})
	_close(Prefs.sheet_height, 0.0, "prefs가 없던 옛 저장은 접힘")

	Prefs.set_sheet_height(700.0)
	Game.reset()
	Party.reset()
	_close(Prefs.sheet_height, 700.0, "새 판(회귀)을 시작해도 남는다")
	Save.reset_data()
	_close(Prefs.sheet_height, 0.0, "데이터 초기화는 기본값으로")
	_fresh_run()
