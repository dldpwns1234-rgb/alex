extends "res://tests/test_case.gd"
## 운명 자동 구매 (운명의 상점 '자동 회귀'가 자동 회귀·결정 자동 구매와 함께 연다): 운명의 실로 운명을 싼 것부터 산다.
## 잠김·끔에는 안 사고, 같은 값이면 앞의 운명, 다 찬 운명은 건너뛰고, 실이 모자라면 멈춘다

const FRAME: float = 1.0 / 60.0


func run() -> void:
	_test_auto_fates()
	_fresh_run()


func _test_auto_fates() -> void:
	_fresh_run()
	var F: int = Balance.Auto.FATES
	Rebirth.threads = 5.0
	Automation._process(FRAME)
	_close(Rebirth.threads, 5.0, "운명을 사기 전엔 안 산다")
	_equal(Automation.is_unlocked(F), false, "잠김")
	_equal(Rebirth.buy(Balance.Fate.AUTO_PRESTIGE), true, "자동 회귀 해금 (실 1)")
	_equal(Automation.is_unlocked(F), true, "운명 자동 구매도 같은 운명이 연다")
	_equal(Automation.is_enabled(F), true, "기본은 켬")
	Automation.set_enabled(F, false)
	Automation._process(FRAME)
	_close(Rebirth.threads, 4.0, "끄면 안 산다")
	Automation.set_enabled(F, true)

	# 실 4: 0레벨 운명이 모두 1실이라 앞에서부터 숙명·인연·예지·자동 스킬 (자동 회귀는 다 차서 건너뛴다)
	Automation._process(FRAME)
	_close(Rebirth.threads, 0.0, "실을 다 쓴다")
	_equal(Rebirth.level(Balance.Fate.DESTINY), 1, "숙명 1")
	_equal(Rebirth.level(Balance.Fate.BOND), 1, "인연 1")
	_equal(Rebirth.level(Balance.Fate.FORESIGHT), 1, "예지 1")
	_equal(Rebirth.level(Balance.Fate.AUTO_SKILLS), 1, "자동 스킬 1")
	_equal(Rebirth.level(Balance.Fate.AUTO_PRESTIGE), 1, "다 찬 자동 회귀는 그대로")
	_equal(Rebirth.level(Balance.Fate.COMPANION_MEMORY), 0, "실이 모자라 동료 기억은 다음에")

	# 실 1: 남은 1실짜리(동료 기억)가 2실짜리 숙명보다 먼저
	Rebirth.add_threads(1.0)
	Automation._process(FRAME)
	_equal(Rebirth.level(Balance.Fate.COMPANION_MEMORY), 1, "가장 싼 것부터")
	_equal(Rebirth.level(Balance.Fate.DESTINY), 1, "비싼 숙명은 아직")

	# 넉넉하면 다 찬 해금형은 건너뛰고 무한 운명은 계속 산다
	Rebirth.add_threads(1000.0)
	var levels_before := _total_levels()
	Automation._process(FRAME)
	_equal(_total_levels() - levels_before, Balance.AUTO_UPGRADE_BUYS_PER_FRAME, "한 프레임에 %d번까지 (실이 아주 많아도 멈추지 않게)" % Balance.AUTO_UPGRADE_BUYS_PER_FRAME)
	for _i in 200:
		Automation._process(FRAME)
	for i in Balance.FATES.size():
		_equal(Rebirth.can_buy(i), false, "%s: 살 수 있는 게 남지 않는다" % Balance.fate_name(i))
	_equal(Rebirth.level(Balance.Fate.AUTO_UPGRADE), 1, "자동 강화는 1/1에서 멈춘다")
	_equal(Rebirth.level(Balance.Fate.DESTINY) > 10, true, "숙명은 계속 오른다")

	# 저장: 토글이 여섯뿐이던 저장은 일곱째가 켬
	Automation.from_dict({"enabled": [true, true, true, true, true, false]})
	_equal(Automation.is_enabled(F), true, "옛 저장은 운명 자동 구매가 켬")
	_equal(Automation.is_enabled(Balance.Auto.TRAINING), false, "있는 값은 그대로")
	Automation.reset()


func _total_levels() -> int:
	var total := 0
	for level in Rebirth.fate_levels:
		total += level
	return total
