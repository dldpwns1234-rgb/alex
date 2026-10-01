extends "res://tests/test_case.gd"
## 도약 (운명의 상점): 회귀·환생 뒤 지난 판 최고 − 간격에서 시작한다. 예지보다 높을 때만, 유산도 받는다. 도전 판을 시작할 때는 쉰다


func run() -> void:
	_test_balance()
	_test_start()
	_fresh_run()


func _test_balance() -> void:
	var L: int = Balance.Fate.LEAP
	_equal(Balance.fate_max_level(L), 8, "최대 8레벨")
	_equal(Balance.leap_gap(1), 500, "1레벨: 지난 판 최고 − 500")
	_equal(Balance.leap_gap(8), 150, "8레벨: − 150")
	_equal(Balance.leap_start(0, 3000), 1, "레벨이 없으면 1")
	_equal(Balance.leap_start(8, 3000), 2850, "8레벨, 지난 판 3000 → 2850")
	_equal(Balance.leap_start(1, 300), 1, "지난 판이 간격보다 낮으면 1")
	_equal(Balance.fate_note(L).begins_with("회귀 후 지난 판 최고 − 500"), true, "상점 설명")


func _test_start() -> void:
	_fresh_run()
	var L: int = Balance.Fate.LEAP
	var F: int = Balance.Fate.FORESIGHT
	_equal(Rebirth.start_stage(3000), 1, "도약도 예지도 없으면 1")
	Rebirth.fate_levels[F] = 4
	Rebirth.fate_levels[L] = 8
	_equal(Rebirth.start_stage(200), 101, "지난 판 200: 예지(101)가 도약(50)보다 높다")
	_equal(Rebirth.start_stage(1000), 850, "지난 판 1000: 도약 850")
	Rebirth.fate_levels[L] = 1
	_equal(Rebirth.start_stage(1000), 500, "1레벨이면 500")
	Rebirth.fate_levels[L] = 8

	Game.highest_stage = 1000
	Game.stage = 990
	var expected_gold := Balance.inheritance_gold(850, Game.gold_multiplier())
	_equal(Prestige.perform(), true, "회귀")
	_equal(Game.stage, 850, "도약으로 850에서 시작")
	_equal(Game.highest_stage, 850, "이번 판 최고도 850")
	_close(Game.gold, expected_gold, "건너뛴 849스테이지의 유산")
	_equal(Party.is_companion_unlocked(Balance.Companion.CLERIC), true, "그 스테이지까지의 동료 합류가 열린다")

	Game.highest_stage = 1200
	_equal(Rebirth.perform(), true, "환생")
	_equal(Game.stage, 1050, "환생 뒤에도 지난 판 최고 − 150 (운명은 남는다)")

	Game.highest_stage = 1500
	_equal(Challenges.start(0), true, "도전 시작")
	_equal(Game.stage, 101, "도전 판은 목표를 건너뛰지 않게 예지만 (101)")
	_equal(Challenges.active, 0, "도전 중")
	Challenges.give_up()
	Game.highest_stage = 1500
	_equal(Prestige.perform(), true, "도전을 포기하고 회귀")
	_equal(Game.stage, 1350, "도전이 아니면 다시 도약")
	Game.highest_stage = 200
	_equal(Prestige.perform(), true, "짧게 끝난 판")
	_equal(Game.stage, 101, "지난 판이 낮으면 예지 시작")
