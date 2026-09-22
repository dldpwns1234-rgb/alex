extends "res://tests/test_case.gd"
## 단련: 표, 비용, 해금, 구매 배수, 효과 합산, 저장, 회귀 초기화


func run() -> void:
	_test_table()
	_test_cost()
	_test_buy()
	_test_values()
	_test_save()


func _test_table() -> void:
	_equal(Balance.TRAININGS.size(), 25, "단련 25종")
	for owner in range(-1, 4):
		var unlocks: Array[int] = []
		for i in Balance.TRAININGS.size():
			if Balance.training_owner(i) == owner:
				unlocks.append(Balance.training_unlock_level(i))
		_equal(unlocks, [10, 25, 50, 75, 100], "%s의 해금 레벨" % Balance.owner_name(owner))
	for i in Balance.TRAININGS.size():
		_equal(Balance.training_max_level(i) in [4, 5, 10], true, "%s 최대 레벨" % Balance.training_name(i))
		_equal(Balance.training_note(i).is_empty(), false, "%s 설명" % Balance.training_name(i))
	_equal(Balance.training_note(0), "클릭 피해 +10%", "연격 설명")
	_equal(Balance.training_note(5), "전사 DPS +20%", "굳건함 설명")
	_equal(Balance.training_note(6), "재등장 대기 -0.02초", "도발 설명")
	_equal(Balance.training_note(20), "성직자 버프 +0.2%p/레벨", "축복 설명")


func _test_cost() -> void:
	_close(Balance.training_base_cost(0), Balance.level_cost(5.0, 10) * 5.0, "연격 첫 비용 = 용사 10레벨 비용 × 5")
	_close(Balance.training_cost(0, 3), Balance.training_base_cost(0) * pow(1.3, 3), "3레벨이면 ×1.3³")
	_close(Balance.training_base_cost(5), Balance.level_cost(10.0, 10) * 5.0, "굳건함 첫 비용 = 전사 10레벨 비용 × 5")
	var summed := 0.0
	for n in 4:
		summed += Balance.training_cost(0, n)
	_close(Balance.bulk_cost(Balance.training_base_cost(0), 0, 4, 1.3), summed, "4레벨 일괄 = 낱개 합")
	_equal(Balance.max_affordable(Balance.training_base_cost(0), 0, summed + 0.01, 1.3), 4, "합계만큼 있으면 4레벨")
	_equal(Balance.max_affordable(Balance.training_base_cost(0), 0, summed - 1.0, 1.3), 3, "조금 모자라면 3레벨")


func _test_buy() -> void:
	_fresh_run()
	_equal(Training.is_unlocked(0), false, "용사 1레벨이면 연격 잠김")
	Game.gold = 1e9
	_equal(Training.buy(0), false, "잠긴 단련은 못 산다")
	Party.hero_level = 10
	_equal(Training.is_unlocked(0), true, "용사 10레벨에 연격 해금")
	_equal(Training.is_unlocked(1), false, "급소 찌르기는 아직")
	Game.gold = 0.0
	_equal(Training.can_buy(0), false, "골드가 없으면 못 산다")
	Game.gold = Balance.training_cost(0, 0) + 1.0
	_equal(Training.buy(0), true, "연격 구매")
	_equal(Training.levels[0], 1, "연격 1레벨")
	_close(Game.gold, 1.0, "비용을 뺀다")

	Party.set_buy_mode(Party.BuyMode.TEN)
	Game.gold = 1e9
	var ten := Training.purchase(0)
	_equal(ten.count, 9, "×10이지만 남은 9레벨만")
	_equal(Training.buy(0), true, "남은 만큼 구매")
	_equal(Training.levels[0], 10, "연격 최대")
	_equal(Training.is_maxed(0), true, "최대 레벨")
	_equal(Training.buy(0), false, "최대면 못 산다")

	Party.set_buy_mode(Party.BuyMode.MAX)
	Party.companion_levels[Balance.Companion.WARRIOR] = 10
	Game.gold = Balance.bulk_cost(Balance.training_base_cost(5), 0, 3, 1.3) + 0.5
	var most := Training.purchase(5)
	_equal(most.count, 3, "최대 모드: 살 수 있는 만큼")
	_equal(Training.buy(5), true, "굳건함 3레벨 구매")
	_close(Game.gold, 0.5, "남는 골드")
	_equal(Training.any_affordable(), false, "더 살 수 있는 게 없다")
	Party.set_buy_mode(Party.BuyMode.ONE)


func _test_values() -> void:
	_fresh_run()
	Training.levels[0] = 3   # 연격
	Training.levels[5] = 2   # 굳건함 (전사)
	Training.levels[10] = 5  # 정밀 사격
	Training.levels[20] = 5  # 축복
	_close(Training.value(Balance.Effect.CLICK_DAMAGE), 0.3, "연격 3레벨 = +30%")
	_close(Training.value(Balance.Effect.KILL_GOLD), 0.0, "안 산 효과는 0")
	_close(Training.companion_damage_multiplier(Balance.Companion.WARRIOR), 1.4, "굳건함 2레벨 = ×1.4")
	_close(Training.companion_damage_multiplier(Balance.Companion.ARCHER), 1.0, "궁수는 그대로")
	var mods := Training.mods()
	_close(mods["archer_crit_chance"], 0.2, "정밀 사격 5레벨: 치명타 20%")
	_close(mods["archer_crit_mult"], 5.0, "치명타 배율 그대로")
	_close(mods["cleric_buff"], 0.03, "축복 5레벨: 버프 3%/레벨")
	_close(mods["companion_damage"][0], 1.4, "보정값에도 전사 ×1.4")


func _test_save() -> void:
	_fresh_run()
	Training.levels[0] = 4
	Training.levels[24] = 2
	var data := Save.to_dict()
	_equal(data.has("training"), true, "저장 데이터에 단련이 들어간다")
	Training.reset()
	_equal(Training.levels[0], 0, "초기화")
	Save.from_dict(data)
	_equal(Training.levels[0], 4, "연격 복원")
	_equal(Training.levels[24], 2, "기적 복원")
	Training.from_dict({"levels": [99]})
	_equal(Training.levels[0], 10, "상한을 넘는 저장값은 잘라낸다")
	_equal(Training.levels[24], 0, "모자란 항목은 0")

	Training.levels[0] = 4
	Game.highest_stage = 100
	Prestige.perform()
	_equal(Training.levels[0], 0, "회귀하면 단련도 초기화")
	_fresh_run()
