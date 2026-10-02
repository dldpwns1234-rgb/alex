extends "res://tests/test_case.gd"
## 초월 (GDD 7.12절): 파편 공식, 조건(이번 삶의 최후의 마왕), 내려놓음과 유지, 별의 상점 6종의 효과, 저장과 옛 저장


func run() -> void:
	_fresh_run()
	Transcend.reset()
	_test_formula()
	_test_condition()
	_test_perform()
	_test_shop_effects()
	_test_save()
	_fresh_run()
	Transcend.reset()


func _test_formula() -> void:
	_close(Balance.star_reward(21600.0), 3.0, "6시간이면 파편 3개 (기준 6시간 30분)")
	_close(Balance.star_reward(5400.0), 6.0, "1시간 30분이면 6개")
	_close(Balance.star_reward(86400.0), 1.0, "24시간이면 1개 (최소)")
	_close(Balance.star_reward(0.0), floor(3.0 * sqrt(23400.0 / 60.0)), "0초는 60초로 본다")
	_close(Balance.star_cost(0), 1.0, "첫 레벨 1파편")
	_close(Balance.star_cost(4), 5.0, "다섯째 레벨 5파편")


func _test_condition() -> void:
	_equal(Transcend.can_transcend(), false, "처음에는 초월할 수 없다")
	Game.stage = 1000
	Game.demon_king_defeated.emit()
	_equal(Transcend.can_transcend(), false, "1000의 마왕으로는 안 된다")
	Game.stage = Balance.FINAL_STAGE
	Game.demon_king_defeated.emit()
	_equal(Transcend.can_transcend(), true, "최후의 마왕을 잡으면 초월할 수 있다")
	_fresh_run()


func _test_perform() -> void:
	Transcend.final_cleared = true
	Transcend.cycle_seconds = 21600.0
	Rebirth.add_threads(50.0)
	Rebirth.fate_levels[Balance.Fate.DESTINY] = 3
	Rebirth.rebirth_count = 7
	Prestige.crystals = 1000.0
	Prestige.prestige_count = 20
	Equipment.add_stones(30.0)
	Tower.best_floor = 40
	Achievements.add(Balance.Stat.KILLS, 500.0)
	_equal(Transcend.perform(), true, "초월")
	_close(Transcend.stars, 3.0, "파편 +3")
	_equal(Transcend.count, 1, "초월 1회")
	_close(Transcend.cycle_seconds, 0.0, "이번 삶 시간이 0부터")
	_equal(Transcend.can_transcend(), false, "다시 최후의 마왕을 잡아야 한다")
	_close(Rebirth.threads, 0.0, "운명의 실을 내려놓는다")
	_equal(Rebirth.level(Balance.Fate.DESTINY), 0, "운명의 상점을 내려놓는다")
	_equal(Rebirth.rebirth_count, 0, "환생 횟수를 내려놓는다")
	_close(Prestige.crystals, 0.0, "결정을 내려놓는다")
	_equal(Prestige.prestige_count, 0, "회귀 기록을 내려놓는다")
	_equal(Tower.best_floor, 0, "탑 최고층을 내려놓는다")
	_close(Equipment.stones, 30.0, "강화석은 남는다")
	_close(Achievements.value(Balance.Stat.KILLS), 500.0, "통계는 남는다")
	_equal(Game.stage, 1, "판이 처음부터")
	_equal(Automation.is_unlocked(Balance.Auto.PRESTIGE), true, "초월 1회부터 자동화 해금이 남는다")
	_fresh_run()


func _test_shop_effects() -> void:
	Transcend.stars = 100.0
	for i in 2:
		Transcend.buy(Balance.Star.WINGS)
	Transcend.buy(Balance.Star.ECHO)
	_equal(Transcend.level(Balance.Star.WINGS), 2, "별빛 날개 2레벨")
	Transcend.final_cleared = true
	Transcend.perform()
	_close(Rebirth.threads, 10.0, "별빛 날개: 초월 직후 실 +10")
	_equal(Prestige.level(Balance.Memory.SWORD), 2, "기억의 잔향: 검술 2레벨")
	_equal(Prestige.level(Balance.Memory.GOLD), 2, "기억의 잔향: 황금 2레벨")
	Transcend.buy(Balance.Star.SHORTCUT)
	Transcend.buy(Balance.Star.SHORTCUT)
	_equal(Balance.can_rebirth(400, Transcend.shortcut()), true, "지름길 2레벨: 400에서 환생")
	_close(Balance.thread_reward(400, Transcend.shortcut()), 5.0, "실 공식 기준도 350으로")
	_equal(Promotions.max_rank(), Balance.PROMOTION_MAX_RANK, "각성 전 승급 상한 5")
	Transcend.buy(Balance.Star.AWAKEN)
	_equal(Promotions.max_rank(), Balance.PROMOTION_MAX_RANK + 1, "동료 각성 1레벨: 상한 6")
	var before := Rebirth.damage_multiplier()
	Transcend.buy(Balance.Star.BLESSING)
	_close(Rebirth.damage_multiplier(), before * 10.0, "별의 축복: 모든 피해 ×10")
	_equal(Transcend.buy(Balance.Star.AUTO_REBIRTH), true, "자동 환생 해금")
	_equal(Transcend.buy(Balance.Star.AUTO_REBIRTH), false, "자동 환생은 1레벨이 최대")
	_equal(Automation.is_unlocked(Balance.Auto.REBIRTH), true, "자동 환생 토글이 열린다")
	Prestige.best_stage = 600
	var reborn := Rebirth.rebirth_count
	Automation._stall = Balance.AUTO_PRESTIGE_STALL + 1.0
	Automation._process(0.01)
	_equal(Rebirth.rebirth_count, reborn + 1, "정체하면 회귀 대신 환생한다")
	_fresh_run()


func _test_save() -> void:
	var data := Save.to_dict()
	_equal(data.has("transcend"), true, "저장 데이터에 초월이 들어간다")
	var levels := Transcend.star_levels.duplicate()
	var stars := Transcend.stars
	Transcend.reset()
	Save.from_dict(data)
	_equal(Transcend.star_levels, levels, "별의 상점 복원")
	_close(Transcend.stars, stars, "파편 복원")
	_equal(Transcend.count, 2, "초월 횟수 복원")
	var old := data.duplicate(true)
	old.erase("transcend")
	Save.from_dict(old)
	_equal(Transcend.count, 0, "초월이 없던 옛 저장은 0회")
	_equal(Promotions.max_rank(), Balance.PROMOTION_MAX_RANK, "옛 저장은 승급 상한 5")
	Transcend.reset()
