extends "res://tests/test_case.gd"
## Game 진행과 Party 구매 검사. 오토로드 싱글턴을 새 판으로 되돌린 뒤 직접 검사한다


func run() -> void:
	_test_game()
	_test_party()
	_test_buy_modes()


func _test_game() -> void:
	_fresh_run()
	_equal(Game.stage, 1, "시작 스테이지")
	_close(Game.gold, 0.0, "시작 골드")
	_close(Game.monster_hp, 10.0, "첫 몬스터 체력")
	_equal(Game.is_monster_alive(), true, "몬스터 살아 있음")

	Game.tap_attack()
	_close(Game.monster_hp, 9.0, "탭 1회에 클릭 피해 1")

	for i in 9:
		Game.tap_attack()
	_close(Game.monster_hp, 0.0, "10회 탭에 처치")
	_close(Game.gold, 10.0 / 15.0, "처치 골드 = 체력 ÷ 15")
	_equal(Game.kills, 1, "처치 수")
	_equal(Game.is_monster_alive(), false, "재등장 대기 중")

	Game.tap_attack()
	_close(Game.gold, 10.0 / 15.0, "대기 중에는 피해도 골드도 없음")

	_advance(0.1)
	_equal(Game.is_monster_alive(), false, "0.1초 뒤에도 아직 대기")
	_advance(0.25)
	_equal(Game.is_monster_alive(), true, "0.3초가 지나면 재등장")
	_close(Game.monster_hp, 10.0, "재등장 몬스터 체력")

	_equal(Game.spend(1.0), false, "골드가 모자라면 못 치른다")
	Game.gold = 6.0
	_equal(Game.spend(5.0), true, "있으면 치른다")
	_close(Game.gold, 1.0, "치른 만큼 준다")

	# 9마리를 더 잡으면 2스테이지. 재등장은 delta 상한 때문에 여러 프레임이 걸린다
	for i in 9:
		Game._damage_monster(Game.monster_max_hp)
		_advance(1.0)
	_equal(Game.stage, 2, "10마리 처치 후 2스테이지")
	_equal(Game.highest_stage, 2, "최고 스테이지 갱신")
	_equal(Game.kills, 0, "처치 수 초기화")
	_close(Game.monster_max_hp, 11.5, "2스테이지 몬스터 체력")


func _test_party() -> void:
	_fresh_run()
	var W: int = Balance.Companion.WARRIOR
	var A: int = Balance.Companion.ARCHER
	_equal(Party.hero_level, 1, "용사 1레벨 시작")
	_equal(Party.companion_levels, [0, 0, 0, 0], "동료는 모두 미고용")
	_close(Party.party_dps(false), 0.0, "동료 없으면 DPS 0")

	_equal(Party.buy_hero(), false, "골드가 모자라면 못 산다")
	Game.gold = 6.0
	_equal(Party.buy_hero(), true, "비용(5.35)보다 많으면 산다")
	_equal(Party.hero_level, 2, "용사 2레벨")
	_close(Game.gold, 6.0 - 5.0 * 1.07, "비용을 뺀다")
	_close(Party.click_damage(), 2.0, "2레벨 클릭 피해")

	_equal(Party.is_companion_unlocked(W), true, "전사는 처음부터 합류")
	_equal(Party.is_companion_unlocked(A), false, "궁수는 아직 잠김")
	Game.gold = 200.0
	_equal(Party.buy_companion(A), false, "잠긴 동료는 못 산다")
	_equal(Party.buy_companion(W), true, "전사 고용")
	_equal(Party.companion_levels[W], 1, "전사 1레벨")
	_close(Game.gold, 190.0, "고용 비용 10")
	_close(Party.party_dps(false), 3.0, "전사 DPS 3")
	_close(Party.companion_dps(W, false), 3.0, "전사 한 명의 DPS")

	Game.highest_stage = 10
	_equal(Party.is_companion_unlocked(A), true, "10스테이지에 도달하면 궁수 합류")
	_equal(Party.buy_companion(A), true, "궁수 고용")
	_close(Game.gold, 90.0, "고용 비용 100")
	_close(Party.party_dps(false), 3.0 + 16.0 * 1.4, "전사 + 궁수 DPS")

	# 동료 피해는 매 프레임 DPS × delta
	var before := Game.monster_hp
	_advance(0.25)
	_close(Game.monster_hp, before - (3.0 + 22.4) * 0.25, "0.25초 동안 DPS × delta")


func _test_buy_modes() -> void:
	_fresh_run()
	Party.set_buy_mode(Party.BuyMode.TEN)
	var ten := Party.hero_purchase()
	_equal(ten.count, 10, "×10 모드는 10레벨")
	_close(ten.cost, Balance.bulk_cost(5.0, 1, 10), "×10 비용")
	_equal(ten.affordable, false, "골드 0이면 못 산다")
	_equal(Party.buy_hero(), false, "못 사면 false")

	Game.gold = ten.cost + 1.0
	_equal(Party.buy_hero(), true, "×10 구매")
	_equal(Party.hero_level, 11, "1 + 10 = 11레벨")
	_close(Game.gold, 1.0, "비용을 뺀다")

	Party.set_buy_mode(Party.BuyMode.MAX)
	var none := Party.hero_purchase()
	_equal(none.count, 1, "최대 모드에서 못 사면 1레벨 비용을 보여준다")
	_equal(none.affordable, false, "그리고 못 산다")
	Game.gold = Balance.bulk_cost(5.0, 11, 7) + 0.5
	var seven := Party.hero_purchase()
	_equal(seven.count, 7, "최대 모드는 살 수 있는 만큼")
	_equal(Party.buy_hero(), true, "최대 구매")
	_equal(Party.hero_level, 18, "11 + 7 = 18레벨")
	_close(Game.gold, 0.5, "남는 골드")

	Party.set_buy_mode(Party.BuyMode.ONE)
	_equal(Party.hero_purchase().count, 1, "×1 모드")
	Game.gold = 100.0
	_equal(Party.buy_companion(Balance.Companion.WARRIOR), true, "동료도 같은 배수로 산다")
	_equal(Party.companion_levels[Balance.Companion.WARRIOR], 1, "전사 1레벨")
