extends "res://tests/test_case.gd"
## 용기사 (GDD 6절): 600에 합류, 마왕에게 피해 ×10, 단련 5종. 고용은 최대로 산다 (늦게 합류해 1레벨의 효율이 0에 가깝다)

const FRAME: float = 0.1


func run() -> void:
	var K: int = Balance.Companion.DRAGON_KNIGHT
	_fresh_run()
	_equal(Balance.companion_name(K), "용기사", "이름")
	_equal(Balance.companion_unlock_stage(K), 600, "600에 합류")
	_equal(Party.is_companion_unlocked(K), false, "처음엔 잠김")
	_close(Balance.companion_dps(K, 1, false), 50000.0 * Balance.attack(1.0, 1), "1레벨 DPS = 기본 공격력 5만")
	_close(Balance.companion_dps(K, 100, true, {"demon_king": true}) / Balance.companion_dps(K, 100, true),
		Balance.DRAGON_KNIGHT_KING_MULTIPLIER, "마왕에게 ×10")
	_equal(Balance.companion_note(K), "마왕에게 피해 ×10", "특수 효과 설명")
	var owned := 0
	for i in Balance.TRAININGS.size():
		if Balance.training_owner(i) == K:
			owned += 1
	_equal(owned, 5, "용기사 단련 5종")

	# 마왕 스테이지에서만 Party가 ×10을 건다
	Game.highest_stage = 999
	Game.stage = 999
	Party.companion_levels[K] = 100
	var normal := Party.companion_dps(K, true)
	Game.stage = 1000
	_close(Party.companion_dps(K, true) / normal, Balance.DRAGON_KNIGHT_KING_MULTIPLIER, "마왕 스테이지에서 ×10")
	Party.companion_levels[K] = 0
	Game.stage = 650

	# 고용: 늘 최대로. 다른 동료가 수천 레벨이면 1레벨의 효율은 0에 가깝다
	for i in Balance.Companion.DRAGON_KNIGHT:
		Party.companion_levels[i] = 1500
	Game.gold = 1e30
	var max_purchase := Party.companion_purchase(K, Party.BuyMode.MAX)
	_equal(max_purchase.count > 500, true, "최대로 사면 수백 레벨")
	_equal(Party.buy_companion(K, Party.BuyMode.MAX), true, "최대로 고용")
	_equal(Party.companion_levels[K], max_purchase.count, "산 만큼 레벨")

	# 자동 강화는 합류한 미고용 동료를 먼저 최대로 고용한다
	Party.companion_levels[K] = 0
	Game.gold = 1e30
	Rebirth.threads = 1.0
	Rebirth.buy(Balance.Fate.AUTO_UPGRADE)
	Automation._process(FRAME)
	_equal(Party.companion_levels[K] > 500, true, "자동 강화가 용기사를 최대로 고용")
	_fresh_run()
