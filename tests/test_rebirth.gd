extends "res://tests/test_case.gd"
## 환생: 조건과 운명의 실, 실행(내려놓는 것과 남는 것), 운명의 상점과 효과, 회귀 후 시작 스테이지, 저장


func run() -> void:
	_test_balance()
	_test_perform()
	_test_shop_and_effects()
	_test_save()
	_fresh_run()


func _test_balance() -> void:
	_equal(Balance.can_rebirth(499), false, "499는 환생 불가")
	_equal(Balance.can_rebirth(500), true, "500부터 환생")
	_close(Balance.thread_reward(499), 0.0, "조건 미달이면 실 0")
	_close(Balance.thread_reward(500), 5.0, "500에서 실 5")
	_close(Balance.thread_reward(515), 6.0, "515에서 실 6 (10마다 1)")
	_close(Balance.thread_reward(600), 15.0, "600에서 실 15")
	_close(Balance.fate_cost(0), 1.0, "첫 레벨 비용 1")
	_close(Balance.fate_cost(3), 4.0, "4번째 레벨 비용 4")
	_close(Balance.destiny_multiplier(2), 9.0, "숙명 2레벨 ×9")
	_close(Balance.bond_multiplier(3), 8.0, "인연 3레벨 ×8")
	_equal(Balance.start_stage(0), 1, "예지 없으면 1스테이지")
	_equal(Balance.start_stage(2), 51, "예지 2레벨: 51스테이지")
	_equal(Balance.fate_max_level(Balance.Fate.FORESIGHT), 4, "예지 상한 4")
	_equal(Balance.fate_max_level(Balance.Fate.DESTINY), 0, "숙명은 상한 없음")
	_equal(Balance.fate_max_level(Balance.Fate.AUTO_PRESTIGE), 1, "자동 회귀는 해금 한 번")
	_equal(Balance.fate_max_level(Balance.Fate.COMPANION_MEMORY), 5, "동료 기억 상한 5")
	_close(Balance.inheritance_gold(1, 1.0), 0.0, "1스테이지 시작이면 유산 없음")
	_close(Balance.inheritance_gold(2, 1.0), 10.0 * Balance.kill_gold(Balance.monster_hp(1)), "2스테이지 시작: 1스테이지 10마리 몫")
	_close(Balance.inheritance_gold(3, 2.0), 20.0 * (Balance.kill_gold(Balance.monster_hp(1)) + Balance.kill_gold(Balance.monster_hp(2))), "골드 배율이 곱해진다")
	_close(Balance.companion_memory_ratio(3), 0.3, "동료 기억 3레벨: 30%")
	_equal(Balance.remembered_level(250, 0.3), 75, "250레벨의 30%는 75")
	_equal(Balance.remembered_level(7, 0.0), 0, "기억이 없으면 0")


func _test_perform() -> void:
	_fresh_run()
	var W: int = Balance.Slot.WEAPON
	Prestige.crystals = 50.0
	Prestige.memory_levels[Balance.Memory.SWORD] = 3
	Prestige.best_stage = 480
	Prestige.prestige_count = 7
	Game.highest_stage = 300
	_equal(Rebirth.can_rebirth(), false, "역대 480은 아직")
	_equal(Rebirth.perform(), false, "조건 미달이면 아무 일도 없다")
	Game.highest_stage = 520
	_equal(Rebirth.best_stage(), 520, "이번 판 최고도 역대 기록으로 친다")
	_equal(Rebirth.can_rebirth(), true, "520이면 환생 가능")
	_close(Rebirth.thread_reward(), 7.0, "받을 실 7")
	Equipment.drop(W, Balance.Grade.COMMON, 100)
	Achievements.add(Balance.Stat.KILLS, 5.0)
	Party.hero_level = 30
	Game.gold = 999.0
	_equal(Rebirth.perform(), true, "환생")
	_close(Rebirth.threads, 7.0, "실을 받았다")
	_equal(Rebirth.rebirth_count, 1, "환생 1회")
	_close(Prestige.crystals, 0.0, "결정을 내려놓는다")
	_equal(Prestige.level(Balance.Memory.SWORD), 0, "기억의 상점도")
	_equal(Prestige.best_stage, 1, "역대 최고 스테이지도")
	_equal(Prestige.prestige_count, 0, "회귀 횟수도")
	_equal(Game.stage, 1, "1스테이지부터")
	_equal(Party.hero_level, 1, "용사 1레벨")
	_close(Game.gold, 0.0, "골드 0")
	_equal(Equipment.has_item(W), true, "장비는 남는다")
	_close(Achievements.value(Balance.Stat.KILLS), 5.0, "통계는 남는다")
	_close(Achievements.value(Balance.Stat.REBIRTHS), 1.0, "환생 횟수 통계")
	_equal(Rebirth.can_rebirth(), false, "환생 직후엔 다시 불가")


func _test_shop_and_effects() -> void:
	_fresh_run()
	var D: int = Balance.Fate.DESTINY
	var B: int = Balance.Fate.BOND
	var F: int = Balance.Fate.FORESIGHT
	_equal(Rebirth.buy(D), false, "실이 없으면 못 산다")
	Rebirth.threads = 3.0
	_close(Rebirth.fate_cost(D), 1.0, "첫 비용 1")
	_equal(Rebirth.buy(D), true, "숙명 구매")
	_close(Rebirth.threads, 2.0, "실 2")
	_equal(Rebirth.buy(D), true, "숙명 2레벨 (비용 2)")
	_close(Rebirth.threads, 0.0, "실 0")
	_equal(Rebirth.buy(D), false, "비용 3은 못 낸다")
	_close(Rebirth.damage_multiplier(), 9.0, "숙명 2레벨: 모든 피해 ×9")
	Party.hero_level = 10
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	_close(Party.click_damage(), 180.0, "클릭 피해에 숙명")
	_close(Party.party_dps(false), 27.0, "동료 DPS에 숙명")

	Rebirth.threads = 1.0
	_equal(Rebirth.buy(B), true, "인연 구매")
	_close(Rebirth.crystal_multiplier(), 2.0, "인연 1레벨: 결정 ×2")
	Game.highest_stage = 140
	_close(Prestige.crystal_reward(), 134.0, "140스테이지 결정 67 × 2")

	Rebirth.threads = 20.0
	for i in 4:
		_equal(Rebirth.buy(F), true, "예지 %d레벨" % (i + 1))
	_equal(Rebirth.is_maxed(F), true, "예지 4레벨이면 최대")
	_equal(Rebirth.buy(F), false, "최대는 못 산다")
	_close(Rebirth.threads, 10.0, "비용 1+2+3+4 = 10")
	_equal(Rebirth.start_stage(), 101, "예지 4레벨: 시작 101스테이지")
	var gold_multiplier := Game.gold_multiplier()  # 유산은 회귀 업적이 열리기 전(Game.reset 시점)의 배율로 센다
	_equal(Prestige.perform(), true, "회귀")
	_equal(Game.stage, 101, "회귀 후 101스테이지에서 시작")
	_equal(Game.highest_stage, 101, "이번 판 최고도 101")
	_equal(Party.is_companion_unlocked(Balance.Companion.CLERIC), true, "성직자가 바로 합류한다")
	_close(Game.monster_max_hp, Balance.monster_hp(101), "101스테이지 몬스터가 나온다")
	_close(Game.gold, Balance.inheritance_gold(101, gold_multiplier), "건너뛴 100스테이지의 골드를 유산으로 받는다")
	_equal(Game.gold > Balance.kill_gold(Balance.monster_hp(101)) * gold_multiplier * 50.0, true, "유산은 시작 스테이지 몬스터 50마리 몫보다 크다 (등비 합 ≈ 59마리)")
	Rebirth.threads = 3.0
	_equal(Rebirth.buy(Balance.Fate.COMPANION_MEMORY), true, "동료 기억 구매")
	_equal(Rebirth.buy(Balance.Fate.COMPANION_MEMORY), true, "동료 기억 2레벨")
	Party.companion_levels[Balance.Companion.WARRIOR] = 250
	Party.companion_levels[Balance.Companion.CLERIC] = 7
	Game.highest_stage = 130
	_equal(Prestige.perform(), true, "회귀")
	_equal(Party.companion_level(Balance.Companion.WARRIOR), 50, "전사는 250의 20%인 50레벨로 시작")
	_equal(Party.companion_levels[Balance.Companion.WARRIOR], 0, "산 레벨은 0이라 레벨업 비용이 처음부터다")
	_equal(Party.companion_memory[Balance.Companion.WARRIOR], 50, "기억 레벨 50")
	_close(Party.companion_purchase(Balance.Companion.WARRIOR).cost, Balance.companion_base_cost(Balance.Companion.WARRIOR), "다음 레벨 비용은 기본 비용")
	_equal(Party.companion_level(Balance.Companion.CLERIC), 1, "성직자는 7의 20%를 내림한 1레벨")
	_equal(Party.companion_level(Balance.Companion.ARCHER), 0, "없던 동료는 그대로 0")
	_equal(Party.hero_level, 1, "용사는 기억하지 않는다")
	_equal(Promotions.is_unlocked(Balance.Companion.WARRIOR), true, "기억 레벨 50으로 승급 1단계가 열린다")
	_close(Party.party_dps(false), Balance.party_dps([50, 0, 0, 1], false, Party._mods()) * Party._party_bonus(false), "DPS는 기억 레벨로 센다")
	Rebirth.fate_levels[Balance.Fate.FORESIGHT] = 0
	Game.reset()
	_equal(Party.is_companion_unlocked(Balance.Companion.CLERIC), true, "기억으로 레벨이 있는 동료는 합류 제한이 없다")
	_equal(Party.is_companion_unlocked(Balance.Companion.ARCHER), false, "레벨 없는 동료는 합류 스테이지를 기다린다")
	_equal(Rebirth.perform(), false, "환생 조건 미달")
	Game.highest_stage = 500
	_equal(Rebirth.perform(), true, "환생")
	_equal(Party.companion_level(Balance.Companion.WARRIOR), 10, "환생 뒤에도 동료 기억 (50의 20%)")
	var data := Save.to_dict()
	Party.reset()
	_equal(data["party"].has("companion_memory"), true, "기억 레벨이 저장된다")
	Save.from_dict(data)
	_equal(Party.companion_memory[Balance.Companion.WARRIOR], 10, "기억 레벨 복원")
	Save.from_dict({"save_version": 1, "party": {"companion_levels": [3, 0, 0, 0]}})
	_equal(Party.companion_level(Balance.Companion.WARRIOR), 3, "옛 저장은 기억 레벨 0")


func _test_save() -> void:
	_fresh_run()
	Rebirth.threads = 5.0
	Rebirth.fate_levels[0] = 1
	Rebirth.fate_levels[2] = 2
	Rebirth.rebirth_count = 2
	var data := Save.to_dict()
	_equal(data.has("rebirth"), true, "저장 데이터에 환생이 들어간다")
	_fresh_run()
	_close(Rebirth.threads, 0.0, "초기화 확인")
	Save.from_dict(data)
	_close(Rebirth.threads, 5.0, "실 복원")
	_equal(Rebirth.fate_levels, [1, 0, 2, 0, 0, 0], "운명의 상점 복원")
	_equal(Rebirth.rebirth_count, 2, "환생 횟수 복원")
	_equal(Save.apply_json(JSON.stringify(data)), true, "JSON 적용")
	_equal(Rebirth.fate_levels, [1, 0, 2, 0, 0, 0], "JSON을 거친 상점 레벨")
	_equal(typeof(Rebirth.fate_levels[0]), TYPE_INT, "레벨은 int로 돌아온다")
	Save.from_dict({"save_version": 1})
	_close(Rebirth.threads, 0.0, "필드가 없으면 실 0")
	_equal(Rebirth.fate_levels, [0, 0, 0, 0, 0, 0], "필드가 없으면 0레벨")
	Save.from_dict({"save_version": 1, "rebirth": {"fate_levels": [3, 1, 99], "threads": -2, "rebirth_count": -1}})
	_equal(Rebirth.fate_levels, [3, 1, 4, 0, 0, 0], "상한을 넘는 예지는 잘라내고 옛 저장의 새 운명은 0")
	_close(Rebirth.threads, 0.0, "음수 실은 0")
	_equal(Rebirth.rebirth_count, 0, "음수 횟수는 0")
	Rebirth.threads = 9.0
	Save.reset_data()
	_close(Rebirth.threads, 0.0, "데이터 초기화는 지운다")
	_equal(Game.stage, 1, "초기화하면 1스테이지")
