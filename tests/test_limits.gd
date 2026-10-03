extends "res://tests/test_case.gd"
## 수치 상한: 최종 스테이지(4000)와 돌파 상태, 골드·결정·피해의 MAX_NUMBER, 레벨 상한과 구매, 망가진(무한대) 저장 복구, 탑 꼭대기


func run() -> void:
	_test_balance()
	_test_purchase_cap()
	_test_load_clamps()
	_test_final_stage()
	_test_tower_top()
	_test_income_cap()
	_test_huge_multipliers()
	_fresh_run()


func _test_balance() -> void:
	_equal(Balance.FINAL_STAGE, 4000, "최종 스테이지 4000")
	_equal(Balance.is_demon_king_stage(Balance.FINAL_STAGE), true, "최종 스테이지는 마왕")
	_equal(is_finite(Balance.enemy_hp(Balance.FINAL_STAGE)), true, "최후의 마왕 체력은 유한")
	_equal(Balance.enemy_hp(Balance.FINAL_STAGE) < Balance.MAX_NUMBER, true, "최후의 마왕 체력은 피해 상한 아래")
	_equal(is_finite(Balance.hero_click_damage(Balance.MAX_LEVEL)), true, "최대 레벨의 용사 공격력은 유한")
	_equal(Balance.tower_max_floor(), 390, "탑 꼭대기 390층 (몬스터가 4000스테이지)")
	_equal(Balance.tower_stage(Balance.tower_max_floor()), Balance.FINAL_STAGE, "390층 몬스터 = 최종 스테이지")


func _test_purchase_cap() -> void:
	_fresh_run()
	Game.gold = Balance.MAX_NUMBER
	Party.hero_level = Balance.MAX_LEVEL - 3
	Party.set_buy_mode(Party.BuyMode.MAX)
	var purchase := Party.hero_purchase()
	_equal(purchase.count, 3, "최대 구매도 레벨 상한까지만")
	_equal(purchase.affordable, true, "살 수 있다")
	_equal(Party.buy_hero(), true, "구매")
	_equal(Party.hero_level, Balance.MAX_LEVEL, "최대 레벨")
	purchase = Party.hero_purchase()
	_equal(purchase.count, 0, "상한이면 0")
	_equal(purchase.affordable, false, "살 수 없다")
	_equal(Party.buy_hero(), false, "구매 실패")
	_equal(is_finite(Party.click_damage()), true, "최대 레벨의 클릭 피해는 유한")
	Party.set_buy_mode(Party.BuyMode.TEN)
	Party.companion_levels[Balance.Companion.WARRIOR] = Balance.MAX_LEVEL - 4
	_equal(Party.companion_purchase(Balance.Companion.WARRIOR).count, 4, "×10도 상한까지만")
	Party.set_buy_mode(Party.BuyMode.ONE)
	for i in Party.companion_levels.size():
		Party.companion_levels[i] = Balance.MAX_LEVEL
	Rebirth.fate_levels[Balance.Fate.DESTINY] = 1000  # ×3^1000은 무한대
	_close(Party.party_dps(false), Balance.MAX_NUMBER, "동료 DPS는 상한에서 잘린다")
	_close(Party.click_damage(), Balance.MAX_NUMBER, "클릭 피해도")
	Game.add_gold(Balance.MAX_NUMBER)
	_close(Game.gold, Balance.MAX_NUMBER, "골드도 상한")


func _test_load_clamps() -> void:
	_fresh_run()
	_equal(Save.apply_json('{"save_version":1,"game":{"gold":1e99999,"stage":5000,"highest_stage":6000},"party":{"hero_level":9.3e18,"companion_levels":[1e99999,5,0,0]},"prestige":{"crystals":1e99999}}'), true, "무한대가 든 저장도 읽는다")
	_close(Game.gold, Balance.MAX_NUMBER, "골드 무한대 → 상한")
	_equal(Game.stage, Balance.FINAL_STAGE, "스테이지는 최종까지")
	_equal(Game.highest_stage, Balance.FINAL_STAGE, "최고 스테이지도")
	_equal(Party.hero_level, Balance.MAX_LEVEL, "int 범위 밖의 용사 레벨 → 상한")
	_equal(Party.companion_levels[0], Balance.MAX_LEVEL, "무한대 동료 레벨 → 상한")
	_equal(Party.companion_levels[1], 5, "멀쩡한 값은 그대로")
	_close(Prestige.crystals, Balance.MAX_NUMBER, "결정도 상한")
	_equal(is_finite(Party.party_dps(false)), true, "DPS는 유한")


func _test_final_stage() -> void:
	_fresh_run()
	var finals := Achievements.value(Balance.Stat.FINAL)
	Game.stage = Balance.FINAL_STAGE
	Game.highest_stage = Balance.FINAL_STAGE
	Game.kills = 0
	Game._spawn_monster()
	_equal(Game.is_boss_stage(), true, "최후의 마왕")
	_close(Game.monster_max_hp, Balance.enemy_hp(Balance.FINAL_STAGE), "마왕 체력")
	Game._damage_monster(Game.monster_max_hp)
	_equal(Game.cleared, true, "잡으면 돌파 상태")
	_equal(Game.stage, Balance.FINAL_STAGE, "스테이지는 그대로")
	_close(Achievements.value(Balance.Stat.FINAL) - finals, 1.0, "최종 돌파 통계 +1")
	_equal(Achievements.value(Balance.Stat.DEMON_KING) >= 1.0, true, "마왕 처치도 센다")
	_advance(Game.respawn_delay() + 1.0)
	_equal(Game.is_monster_alive(), false, "몬스터가 더 나오지 않는다")
	_equal(Game.stage, Balance.FINAL_STAGE, "나아가지 않는다")
	_test_mode_after_final()
	_equal(Prestige.perform(), true, "회귀는 된다")
	_equal(Game.cleared, false, "새 판은 돌파 상태가 아니다")
	_equal(Game.is_monster_alive(), true, "몬스터가 다시 나온다")



## 돌파 뒤 탑에 다녀와도 본편에는 몬스터가 없다. 나온다는 알림은 몬스터를 정리한 뒤에 간다
## (먼저 가면 상단 바가 남은 탑 몬스터를 보스로 읽어 '보스 0초'를 띄우고, 화면에 탑 몬스터 그림이 남았다)
func _test_mode_after_final() -> void:
	Achievements.raise(Balance.Stat.STAGE, 100.0)
	_equal(Tower.enter(), true, "돌파 뒤에도 탑에 들어간다")
	_equal(Game.is_monster_alive(), true, "탑에는 몬스터가 있다")
	var alive_at_signal: Array[bool] = []
	var probe := func(_inside: bool) -> void: alive_at_signal.append(Game.is_monster_alive())
	Game.tower_changed.connect(probe)
	Tower.leave()
	Game.tower_changed.disconnect(probe)
	_equal(alive_at_signal, [false] as Array[bool], "나온다는 알림 때 이미 본편 상태 (몬스터 없음)")
	_equal(Game.cleared, true, "돌파 상태 그대로")


func _test_tower_top() -> void:
	_fresh_run()
	Achievements.raise(Balance.Stat.STAGE, 100.0)
	Tower.best_floor = Balance.tower_max_floor()
	_equal(Tower.can_enter(), false, "꼭대기를 돌파했으면 더 못 들어간다")
	Tower.best_floor = Balance.tower_max_floor() - 1
	_equal(Tower.enter(), true, "마지막 층에 들어간다")
	_equal(Tower.floor, Balance.tower_max_floor(), "꼭대기 층")
	Game._damage_monster(Balance.MAX_NUMBER)
	_equal(Game.in_tower, false, "꼭대기를 돌파하면 본편으로")
	_equal(Tower.best_floor, Balance.tower_max_floor(), "최고층 기록")
	_equal(Tower.can_enter(), false, "더 오를 곳이 없다")


## 수입·보상 글도 상한 안에서: 처치 골드 = 체력(1e291) ÷ 15 × 황금의 기억이 1.8e308을 넘어 금화 수입이 ∞로 보였다 (방장 2026-10-03)
func _test_income_cap() -> void:
	_close(Balance.cap(INF), Balance.MAX_NUMBER, "∞는 상한으로")
	_close(Balance.cap(0.0 * INF), 0.0, "0 × ∞(NaN)는 0으로")
	_fresh_run()
	Prestige.memory_levels[Balance.Memory.GOLD] = 600
	Rebirth.fate_levels[Balance.Fate.BOND] = 400
	Game.stage = Balance.FINAL_STAGE - 1
	Game.highest_stage = Balance.FINAL_STAGE - 1
	Game._spawn_monster()
	var reward := Game._award_kill()
	_equal(is_finite(reward) and reward <= Balance.MAX_NUMBER, true, "처치 골드는 상한 안")
	_close(Game.gold, Balance.MAX_NUMBER, "가진 골드는 상한")
	_equal(is_finite(Prestige.crystal_reward()), true, "회귀 보상 결정도 상한 안 (인연 2^400)")
	Party.companion_levels[Balance.Companion.WARRIOR] = 5000
	var before := Achievements.value(Balance.Stat.GOLD)
	Save.grant_offline(3600.0)
	_equal(is_finite(Achievements.value(Balance.Stat.GOLD) - before), true, "오프라인 보상도 상한 안")


## 배율이 무한대가 되지 않는다 (숙명 3^L은 646레벨, 인연 2^L은 1024레벨에서 ∞였다). ∞와 0을 곱하면 NaN이 나서
## 동료가 없는데도 DPS가 상한으로 읽히고, 운명의 상점에 '지금 ×∞'가 떴다 (방장 2026-10-03 무한대 점검)
func _test_huge_multipliers() -> void:
	_fresh_run()
	for value: float in [Balance.destiny_multiplier(5000), Balance.bond_multiplier(5000), Balance.sword_multiplier(5000),
			Balance.gold_memory_multiplier(5000), Balance.blessing_multiplier(500), Balance.memory_cost(5000)]:
		_equal(is_inf(value) or is_nan(value), false, "큰 레벨의 배율도 유한하다")
		_close(value, Balance.MAX_NUMBER, "상한에서 멈춘다")
	Rebirth.fate_levels[Balance.Fate.DESTINY] = 5000
	Transcend.star_levels[Balance.Star.BLESSING] = 500
	_equal(is_inf(Rebirth.damage_multiplier()), false, "숙명 × 별의 축복도 유한하다")
	_close(Party.party_dps(false), 0.0, "동료가 없으면 배율이 커도 DPS 0")
	_close(Party.companion_dps(Balance.Companion.WARRIOR, false), 0.0, "안 고용한 동료는 0")
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	_close(Party.party_dps(false), Balance.MAX_NUMBER, "고용하면 상한까지")
	_equal(Num.format(Balance.destiny_multiplier(5000)).contains("∞"), false, "표시에 ∞가 없다")
	Transcend.reset()
