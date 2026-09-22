extends "res://tests/test_case.gd"
## Balance 공식과 Num.format 검사


func run() -> void:
	_test_balance(Balance)
	_test_companions(Balance)
	_test_num(Num)


func _test_balance(balance: Node) -> void:
	_equal(balance.milestones(1), 0, "1레벨 마일스톤")
	_equal(balance.milestones(9), 0, "9레벨 마일스톤")
	_equal(balance.milestones(10), 1, "10레벨 마일스톤")
	_equal(balance.milestones(24), 1, "24레벨 마일스톤")
	_equal(balance.milestones(25), 2, "25레벨 마일스톤")
	_equal(balance.milestones(50), 3, "50레벨 마일스톤")
	_equal(balance.milestones(100), 5, "100레벨 마일스톤")

	_close(balance.attack(1.0, 1), 1.0, "1레벨 공격력")
	_close(balance.attack(1.0, 10), 20.0, "10레벨 공격력 (×2)")
	_close(balance.attack(1.0, 25), 100.0, "25레벨 공격력 (×4)")
	_close(balance.attack(3.0, 0), 0.0, "0레벨(미고용) 공격력")

	_close(balance.level_cost(5.0, 0), 5.0, "0레벨 비용")
	_close(balance.level_cost(5.0, 1), 5.35, "1레벨 비용")
	_close(balance.hero_level_cost(1), 5.35, "용사 1레벨 비용")
	_close(balance.hero_click_damage(10), 20.0, "용사 10레벨 클릭 피해")

	var summed := 0.0
	for i in 10:
		summed += balance.level_cost(5.0, 1 + i)
	_close(balance.bulk_cost(5.0, 1, 10), summed, "10레벨 일괄 비용 = 낱개 비용의 합")
	_close(balance.bulk_cost(5.0, 1, 1), balance.level_cost(5.0, 1), "1레벨 일괄 비용 = 낱개 비용")
	_equal(balance.max_affordable(5.0, 1, 0.0), 0, "골드 0이면 못 산다")
	_equal(balance.max_affordable(5.0, 1, 5.0), 0, "5.35 미만이면 0")
	_equal(balance.max_affordable(5.0, 1, 6.0), 1, "6골드면 1레벨")
	_equal(balance.max_affordable(5.0, 1, summed + 0.01), 10, "합계만큼 있으면 10레벨")
	_equal(balance.max_affordable(5.0, 1, summed - 1.0), 9, "조금 모자라면 9레벨")

	_close(balance.monster_hp(1), 10.0, "1스테이지 체력")
	_close(balance.monster_hp(2), 11.5, "2스테이지 체력")
	_close(balance.monster_hp(100), 10.0 * pow(1.15, 99), "100스테이지 체력")
	_close(balance.kill_gold(15.0), 1.0, "처치 골드")


func _test_companions(balance: Node) -> void:
	var W: int = Balance.Companion.WARRIOR
	var A: int = Balance.Companion.ARCHER
	var M: int = Balance.Companion.MAGE
	var C: int = Balance.Companion.CLERIC
	_close(balance.companion_dps(W, 1, false), 3.0, "전사 1레벨 DPS")
	_close(balance.companion_dps(W, 0, false), 0.0, "미고용 DPS")
	_close(balance.companion_dps(A, 1, false), 16.0 * 1.4, "궁수 치명타 기대값 ×1.4")
	_close(balance.companion_dps(M, 1, false), 110.0, "마법사 일반")
	_close(balance.companion_dps(M, 1, true), 330.0, "마법사 보스 ×3")
	_close(balance.cleric_multiplier(0), 1.0, "성직자 없음")
	_close(balance.cleric_multiplier(5), 1.1, "성직자 5레벨 +10%")
	var levels: Array[int] = [1, 1, 1, 1]
	var expected := (3.0 + 16.0 * 1.4 + 110.0 + 200.0) * 1.02
	_close(balance.party_dps(levels, false), expected, "동료 DPS 합계 × 성직자 버프")
	_close(balance.companion_cost(W, 0), 10.0, "전사 고용 비용")
	_close(balance.companion_cost(C, 1), 10700.0, "성직자 1레벨 비용")
	_equal(balance.companion_unlock_stage(A), 10, "궁수 합류 스테이지")


func _test_num(num: Node) -> void:
	_equal(num.format(0.0), "0", "0")
	_equal(num.format(0.67), "0", "1 미만은 0")
	_equal(num.format(9999.0), "9999", "1만 미만 정수")
	_equal(num.format(9999.9), "9999", "1만 미만은 버림")
	_equal(num.format(10000.0), "1.00만", "1만")
	_equal(num.format(12345.0), "1.23만", "1.23만")
	_equal(num.format(12399.0), "1.23만", "소수 둘째 자리 버림")
	_equal(num.format(456000.0), "45.6만", "45.6만")
	_equal(num.format(4560000000.0), "45.6억", "45.6억")
	_equal(num.format(99999999.0), "9999만", "9999만")
	_equal(num.format(100000000.0), "1.00억", "1억")
	_equal(num.format(7.89e14), "789조", "789조")
	_equal(num.format(1.234e19), "1234경", "1234경")
	_equal(num.format(1e20), "1.00해", "1해")
	_equal(num.format(1e68), "1.00무량대수", "1무량대수")
	_equal(num.format(9.99e71), "9990무량대수", "9990무량대수")
	_equal(num.format(99999.0), "9.99만", "9.99만 (10만 바로 아래)")
	_equal(num.format(999999.0), "99.9만", "99.9만 (100만 바로 아래)")
	_equal(num.format(9999999.0), "999만", "999만")
	_equal(num.format(1e72), "1.00e72", "10^72는 과학적 표기")
	_equal(num.format(1.23456e80), "1.23e80", "과학적 표기 버림")
	_equal(num.format(-12345.0), "-1.23만", "음수")
