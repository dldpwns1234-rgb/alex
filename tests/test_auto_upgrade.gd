extends "res://tests/test_case.gd"
## 동료 자동 강화 (운명의 상점 '자동 강화'): 골드 효율이 가장 좋은 레벨업이나 승급을 살 수 있는 대로 산다.
## 잠김·끔·홀로 서기 중에는 안 사고, 한 프레임에 상한까지만 산다

const FRAME: float = 1.0 / 60.0
const LEVELS: Array[int] = [181, 161, 128, 106]  # 시뮬레이션 첫 판 100스테이지의 레벨 (성직자가 골드 효율 최고)


func run() -> void:
	_test_promotion_value()
	_test_auto_upgrade()
	_fresh_run()


func _test_promotion_value() -> void:
	_fresh_run()
	var W: int = Balance.Companion.WARRIOR
	Game.highest_stage = 100
	Party.companion_levels[W] = 74
	Party.companion_levels[Balance.Companion.CLERIC] = 106
	Game.gold = 1e9
	var cost := Promotions.cost(W)
	var before := Party.party_dps(false)
	Promotions.ranks[W] = 1
	var expected := (Party.party_dps(false) - before) / cost
	Promotions.ranks[W] = 0
	_close(Party.promotion_gain_per_gold(W), expected, "승급: 파티 DPS 증가 ÷ 승급 비용")
	_equal(Promotions.ranks[W], 0, "재는 동안 단계를 바꾸지 않는다")
	Party.companion_levels[W] = 10
	_close(Party.promotion_gain_per_gold(W), 0.0, "레벨이 모자라면 0")
	Party.companion_levels[W] = 300
	Promotions.ranks[W] = Balance.PROMOTION_MAX_RANK
	_close(Party.promotion_gain_per_gold(W), 0.0, "최고 단계면 0")
	Promotions.ranks[W] = 0


func _test_auto_upgrade() -> void:
	_fresh_run()
	var W: int = Balance.Companion.WARRIOR
	var C: int = Balance.Companion.CLERIC
	var U: int = Balance.Auto.UPGRADE
	Game.highest_stage = 100
	for i in LEVELS.size():
		Party.companion_levels[i] = LEVELS[i]
		Promotions.ranks[i] = Balance.PROMOTION_MAX_RANK  # 승급은 뒤에서 따로 본다 (이 레벨이면 안 산 승급이 레벨업보다 효율이 좋다)
	Game.gold = Party.companion_purchase(C).cost + 1.0
	Automation._process(FRAME)
	_equal(Party.companion_levels[C], 106, "운명을 사기 전엔 안 산다")
	Rebirth.threads = 1.0
	_equal(Rebirth.buy(Balance.Fate.AUTO_UPGRADE), true, "자동 강화 해금")
	_equal(Automation.is_unlocked(U), true, "동료 자동 강화 열림")
	_equal(Automation.is_enabled(U), true, "기본은 켬")
	Automation.set_enabled(U, false)
	Automation._process(FRAME)
	_equal(Party.companion_levels[C], 106, "끄면 안 산다")
	Automation.set_enabled(U, true)
	Automation._process(FRAME)
	_equal(Party.companion_levels[C], 107, "골드 효율 최고인 성직자를 한 레벨 (남은 골드로는 아무것도 못 산다)")
	_equal(Party.companion_level_list(), [181, 161, 128, 107, 0], "다른 동료는 그대로")
	_close(Game.gold, 1.0, "비용만큼 썼다")

	# 승급이 레벨업보다 골드 효율이 좋으면 승급을 산다 (전사 70레벨: 승급 1단계가 DPS의 절반을 더해 주고, 75의 마일스톤은 아직 멀다)
	Party.companion_levels[W] = 70
	Promotions.ranks[W] = 0
	Game.gold = Promotions.cost(W) + 1.0
	_equal(Promotions.can_promote(W), true, "전사 승급 가능")
	Automation._process(FRAME)
	_equal(Promotions.rank(W), 1, "전사 승급을 샀다")
	_equal(Party.companion_levels[W], 70, "레벨업 대신")
	_close(Game.gold, 1.0, "승급 비용만큼 썼다")
	# 승급은 못 사고 레벨업만 살 수 있으면 레벨업
	Game.gold = Party.companion_purchase(W).cost * 1.5
	Automation._process(FRAME)
	_equal(Party.companion_levels[W], 71, "살 수 있는 것 중에서 고른다 (전사 레벨업)")
	_equal(Promotions.rank(W), 1, "승급은 그대로")

	# 한 프레임에 상한까지만
	Game.gold = 1e30
	var before := Promotions.ranks.duplicate()
	var total_before := _total(Party.companion_level_list(), before)
	Automation._process(FRAME)
	_equal(_total(Party.companion_level_list(), Promotions.ranks) - total_before, Balance.AUTO_UPGRADE_BUYS_PER_FRAME,
		"한 프레임에 %d번까지" % Balance.AUTO_UPGRADE_BUYS_PER_FRAME)

	# 홀로 서기 도전 중에는 동료를 사지 않는다
	Rebirth.rebirth_count = 1
	Game.highest_stage = 150
	Challenges.start(0)
	Game.gold = 1e9
	Automation._process(FRAME)
	_equal(Party.companion_level_list(), [0, 0, 0, 0, 0], "홀로 서기 중에는 고용도 레벨업도 안 한다")
	Challenges.give_up()

	# 저장: 토글이 셋뿐이던 저장은 넷째가 켬
	Automation.from_dict({"enabled": [true, true, false]})
	_equal(Automation.is_enabled(U), true, "옛 저장은 동료 자동 강화가 켬")
	_equal(Automation.is_enabled(Balance.Auto.SKILLS), false, "있는 값은 그대로")


func _total(levels: Array[int], ranks: Array[int]) -> int:
	var total := 0
	for level in levels:
		total += level
	for rank in ranks:
		total += rank
	return total
