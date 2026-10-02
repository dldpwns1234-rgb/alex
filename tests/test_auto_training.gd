extends "res://tests/test_case.gd"
## 단련 자동 구매 (운명의 상점 '자동 강화'가 동료 자동 강화와 함께 연다): 비용이 가진 골드의 일정 몫 이하인 단련을 싼 것부터 한 레벨씩.
## 잠김·끔에는 안 사고, 구매 배수와 상관없이 한 레벨씩, 한 프레임에 상한까지, 최대 레벨이면 멈춘다

const FRAME: float = 1.0 / 60.0


func run() -> void:
	_test_auto_training()
	_fresh_run()


func _test_auto_training() -> void:
	_fresh_run()
	var T: int = Balance.Auto.TRAINING
	var first := _hero_training(Balance.training_unlock_level(0))
	Party.hero_level = 100  # 용사 단련 다섯이 모두 열린다 (동료는 0이라 동료 단련은 잠김)
	var cost := Training.purchase(first, Party.BuyMode.ONE).cost
	Game.gold = cost / Balance.AUTO_TRAINING_GOLD_SHARE
	Automation._process(FRAME)
	_equal(Training.levels[first], 0, "운명을 사기 전엔 안 산다")
	Rebirth.threads = 1.0
	_equal(Rebirth.buy(Balance.Fate.AUTO_UPGRADE), true, "자동 강화 해금")
	_equal(Automation.is_unlocked(T), true, "단련 자동 구매도 같은 운명이 연다")
	_equal(Automation.is_enabled(T), true, "기본은 켬")
	Automation.set_enabled(Balance.Auto.UPGRADE, false)  # 동료는 따로 본다 (test_auto_upgrade.gd)
	Automation.set_enabled(T, false)
	Automation._process(FRAME)
	_equal(Training.levels[first], 0, "끄면 안 산다")
	Automation.set_enabled(T, true)

	Party.set_buy_mode(Party.BuyMode.MAX)
	Game.gold = cost / Balance.AUTO_TRAINING_GOLD_SHARE * 0.99
	Automation._process(FRAME)
	_equal(_total(), 0, "가장 싼 단련도 골드의 몫을 넘으면 안 산다")
	Game.gold = cost / Balance.AUTO_TRAINING_GOLD_SHARE
	Automation._process(FRAME)
	_equal(Training.levels[first], 1, "가장 싼 단련을 한 레벨 (구매 배수가 최대여도)")
	_equal(_total(), 1, "다음 단련은 남은 골드의 몫을 넘어 하나만")
	_close(Game.gold, cost / Balance.AUTO_TRAINING_GOLD_SHARE - cost, "비용만큼 썼다")
	Party.set_buy_mode(Party.BuyMode.ONE)

	Game.gold = 1e30
	Automation._process(FRAME)
	_equal(_total(), 1 + Balance.AUTO_UPGRADE_BUYS_PER_FRAME, "한 프레임에 %d번까지" % Balance.AUTO_UPGRADE_BUYS_PER_FRAME)
	for _i in 100:
		Automation._process(FRAME)
	var all_maxed := true
	for i in Training.levels.size():
		if Training.is_unlocked(i) and not Training.is_maxed(i):
			all_maxed = false
	_equal(all_maxed, true, "열린 단련은 끝까지 채운다")
	_equal(Training.levels[_hero_training(Balance.training_unlock_level(0))] > 0, true, "용사 단련을 샀다")
	var companion_bought := 0
	for i in Training.levels.size():
		if Balance.training_owner(i) != Balance.OWNER_HERO:
			companion_bought += Training.levels[i]
	_equal(companion_bought, 0, "잠긴 동료 단련은 안 산다")

	# 저장: 토글이 다섯뿐이던 저장은 여섯째가 켬
	Automation.from_dict({"enabled": [true, true, true, false, true]})
	_equal(Automation.is_enabled(T), true, "옛 저장은 단련 자동 구매가 켬")
	_equal(Automation.is_enabled(Balance.Auto.UPGRADE), false, "있는 값은 그대로")
	Automation.reset()


## 용사 단련 중 해금 레벨이 unlock인 것
func _hero_training(unlock: int) -> int:
	for i in Training.levels.size():
		if Balance.training_owner(i) == Balance.OWNER_HERO and Balance.training_unlock_level(i) == unlock:
			return i
	return -1


func _total() -> int:
	var total := 0
	for level in Training.levels:
		total += level
	return total
