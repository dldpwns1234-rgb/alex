extends "res://tests/test_case.gd"
## 동료 승급: 공식, 해금과 구매, DPS 배율, 저장, 회귀 초기화


func run() -> void:
	_test_balance()
	_test_promote()
	_test_effects()
	_test_save()
	_fresh_run()


func _test_balance() -> void:
	var W: int = Balance.Companion.WARRIOR
	_equal(Balance.promotion_level(1), 50, "1단계는 레벨 50")
	_equal(Balance.promotion_level(3), 150, "3단계는 레벨 150")
	_equal(Balance.promotion_level(Balance.PROMOTION_MAX_RANK), 250, "최고 단계는 레벨 250")
	_close(Balance.promotion_cost(W, 1), Balance.companion_cost(W, 50) * 50.0, "1단계 비용 = 50레벨 비용 × 50")
	_close(Balance.promotion_multiplier(0), 1.0, "0단계 배율 1")
	_close(Balance.promotion_multiplier(2), 2.25, "2단계 배율 1.5² = 2.25")
	_equal(Balance.promotion_stars(3), "★★★", "별 3개")
	_equal(Balance.promotion_stars(0), "", "0단계는 별 없음")


func _test_promote() -> void:
	_fresh_run()
	var W: int = Balance.Companion.WARRIOR
	_equal(Promotions.rank(W), 0, "시작 0단계")
	_equal(Promotions.is_unlocked(W), false, "미고용이면 승급 불가")
	_equal(Promotions.any_affordable(), false, "승급할 동료 없음")
	Party.companion_levels[W] = 49
	_equal(Promotions.is_unlocked(W), false, "49레벨은 아직")
	Party.companion_levels[W] = 50
	_equal(Promotions.is_unlocked(W), true, "50레벨이면 1단계 열림")
	_equal(Promotions.next_level(W), 50, "다음 승급 레벨 50")
	var cost := Promotions.cost(W)
	_close(cost, Balance.promotion_cost(W, 1), "1단계 비용")
	_equal(Promotions.can_promote(W), false, "골드가 없으면 못 산다")
	_equal(Promotions.promote(W), false, "그래서 승급 실패")
	Game.gold = cost + 1.0
	_equal(Promotions.any_affordable(), true, "살 수 있는 승급이 있다")
	_equal(Promotions.promote(W), true, "승급")
	_equal(Promotions.rank(W), 1, "1단계")
	_close(Game.gold, 1.0, "비용을 뺀다")
	_equal(Promotions.next_level(W), 100, "다음은 레벨 100")
	_equal(Promotions.is_unlocked(W), false, "레벨 50으로는 2단계 불가")
	Party.companion_levels[W] = 250
	Game.gold = 1e15
	for i in 4:
		_equal(Promotions.promote(W), true, "%d단계 승급" % (i + 2))
	_equal(Promotions.rank(W), 5, "최고 5단계")
	_equal(Promotions.is_maxed(W), true, "최고 단계")
	_equal(Promotions.is_unlocked(W), false, "최고 단계면 더 못 연다")
	_equal(Promotions.promote(W), false, "최고 단계는 못 산다")
	_close(Promotions.multiplier(W), pow(1.5, 5), "5단계 배율 1.5⁵ ≈ 7.6")


func _test_effects() -> void:
	_fresh_run()
	var W: int = Balance.Companion.WARRIOR
	var A: int = Balance.Companion.ARCHER
	Party.companion_levels[W] = 50
	Party.companion_levels[A] = 1
	_close(Party.companion_dps(W, false), 1200.0, "50레벨 전사 DPS 1200 (3 × 50 × 2^3)")
	Promotions.ranks[W] = 1
	_close(Party.companion_dps(W, false), 1800.0, "1단계 승급: 전사 ×1.5")
	_close(Party.companion_dps(A, false), 22.4, "다른 동료는 그대로")
	_close(Party.party_dps(false), 1822.4, "합계에도 반영")
	Promotions.ranks[W] = 3
	_close(Party.party_dps(false), 4050.0 + 22.4, "3단계 ×3.375")
	_close(Party.click_damage(), 1.0 + 0.0, "각성이 없으면 클릭 피해는 그대로")

	var before := Game.gold
	Save.grant_offline(100.0)
	var per_second := Balance.offline_gold_per_second(1, 4072.4)
	_close(Game.gold, before + per_second * 100.0 * 0.5, "오프라인 보상의 동료 DPS에도 승급")

	Game.highest_stage = 120
	_equal(Prestige.perform(), true, "회귀")
	_equal(Promotions.rank(W), 0, "회귀하면 승급 초기화")
	_close(Party.party_dps(false), 0.0, "동료도 없다")


func _test_save() -> void:
	_fresh_run()
	Promotions.ranks[0] = 2
	Promotions.ranks[2] = 1
	var data := Save.to_dict()
	_equal(data.has("promotions"), true, "저장 데이터에 승급이 들어간다")
	_fresh_run()
	_equal(Promotions.ranks, [0, 0, 0, 0], "초기화 확인")
	Save.from_dict(data)
	_equal(Promotions.ranks, [2, 0, 1, 0], "승급 단계 복원")
	_equal(Save.apply_json(JSON.stringify(data)), true, "JSON 적용")
	_equal(Promotions.ranks, [2, 0, 1, 0], "JSON을 거친 승급 단계")
	_equal(typeof(Promotions.ranks[0]), TYPE_INT, "단계는 int로 돌아온다")
	Save.from_dict({"save_version": 1})
	_equal(Promotions.ranks, [0, 0, 0, 0], "필드가 없으면 0단계")
	Save.from_dict({"save_version": 1, "promotions": {"ranks": [9, -1, 2]}})
	_equal(Promotions.ranks, [5, 0, 2, 0], "상한을 넘으면 잘라내고 모자란 동료는 0")
	Promotions.ranks[1] = 4
	Save.reset_data()
	_equal(Promotions.ranks, [0, 0, 0, 0], "데이터 초기화는 지운다")
