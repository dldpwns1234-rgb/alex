extends "res://tests/test_case.gd"
## 판 기록 (GDD 7절): 이번 판 시간(게임 시간)과 지난 판 최고. 회귀·환생·도전 시작에서 새로 세고, 저장된다


func run() -> void:
	_fresh_run()
	_equal(Prestige.last_run_best, 0, "처음 판은 지난 판이 없다")
	_close(Prestige.run_seconds, 0.0, "처음 판 시간 0")
	Prestige.tick(90.0)
	_close(Prestige.run_seconds, 90.0, "게임 시간이 쌓인다")

	# 회귀: 지난 판 최고를 남기고 시간을 0으로
	Game.stage = 130
	Game.highest_stage = 130
	_equal(Prestige.perform(), true, "회귀")
	_equal(Prestige.last_run_best, 130, "지난 판 최고 130")
	_close(Prestige.run_seconds, 0.0, "새 판 시간 0")
	Game.highest_stage = 143
	_equal(Prestige.run_gain(), 13, "지난 판 대비 +13")
	Game.highest_stage = 120
	_equal(Prestige.run_gain(), -10, "낮으면 음수")

	# 저장과 불러오기
	Prestige.tick(42.0)
	var data := Save.to_dict()
	Prestige.reset()
	_equal(Prestige.last_run_best, 0, "초기화하면 기록도 지운다")
	Save.from_dict(data)
	_close(Prestige.run_seconds, 42.0, "판 시간을 불러온다")
	_equal(Prestige.last_run_best, 130, "지난 판 최고를 불러온다")
	var old: Dictionary = data["prestige"].duplicate()
	old.erase("run_seconds")
	old.erase("last_run_best")
	Prestige.from_dict(old)
	_equal(Prestige.last_run_best, 0, "옛 저장은 지난 판 없음")

	# 도전 시작(회귀 없이 새 판)도 새 판이다
	Prestige.prestige_count = 1
	Game.highest_stage = 80
	Prestige.tick(10.0)
	Challenges._reset_run()
	_equal(Prestige.last_run_best, 80, "도전 시작도 새 판: 지난 판 최고 80")
	_close(Prestige.run_seconds, 0.0, "도전 시작에 시간 0")

	# 데이터 초기화는 처음 판으로
	Save.blocked = true
	Save.reset_data()
	Save.blocked = false
	_equal(Prestige.last_run_best, 0, "데이터 초기화 뒤에는 지난 판이 없다")
	_fresh_run()
