extends "res://tests/test_case.gd"
## 동료 골드 효율 (동료 탭 표시): 지금 구매로 파티 DPS가 골드당 얼마나 느는지. 합류 전·홀로 서기 중엔 0, 뒤처진 성직자가 1등


func run() -> void:
	_test_gain_per_gold()
	_fresh_run()


func _test_gain_per_gold() -> void:
	_fresh_run()
	Game.highest_stage = 100
	Game.gold = 1e12
	var levels: Array[int] = [181, 161, 128, 106, 0]  # 시뮬레이션 첫 판 100스테이지의 레벨 (용기사는 600 합류)
	for i in levels.size():
		Party.companion_levels[i] = levels[i]
	var gains: Array[float] = []
	for i in levels.size():
		gains.append(Party.companion_gain_per_gold(i))
	_equal(gains[Balance.Companion.CLERIC] > gains[Balance.Companion.MAGE], true, "뒤처진 성직자가 마법사보다 골드 효율이 좋다")
	_equal(gains[Balance.Companion.MAGE] > gains[Balance.Companion.ARCHER], true, "마법사가 궁수보다")
	_equal(gains[Balance.Companion.ARCHER] > gains[Balance.Companion.WARRIOR], true, "궁수가 전사보다")
	_equal(Party.companion_levels, levels, "재는 동안 레벨을 바꾸지 않는다")
	var purchase := Party.companion_purchase(Balance.Companion.WARRIOR)
	var before := Party.party_dps(false)
	Party.companion_levels[Balance.Companion.WARRIOR] += purchase.count
	var expected := (Party.party_dps(false) - before) / purchase.cost
	Party.companion_levels[Balance.Companion.WARRIOR] -= purchase.count
	_close(gains[Balance.Companion.WARRIOR], expected, "전사: 구매 뒤 파티 DPS 증가 ÷ 비용")
	Party.set_buy_mode(Party.BuyMode.MAX)
	_equal(Party.companion_gain_per_gold(Balance.Companion.WARRIOR) > 0.0, true, "최대 구매로도 잰다")
	Party.set_buy_mode(Party.BuyMode.ONE)
	Game.highest_stage = 30
	Party.companion_levels[Balance.Companion.CLERIC] = 0
	_close(Party.companion_gain_per_gold(Balance.Companion.CLERIC), 0.0, "합류 전(50)이면 0")
	Party.companion_memory[Balance.Companion.CLERIC] = 5
	_equal(Party.companion_gain_per_gold(Balance.Companion.CLERIC) > 0.0, true, "기억 레벨로 고용 상태면 잰다")
	Rebirth.rebirth_count = 1
	Game.highest_stage = 150
	Challenges.start(0)
	_close(Party.companion_gain_per_gold(Balance.Companion.WARRIOR), 0.0, "홀로 서기 중에는 0")
	Challenges.give_up()
