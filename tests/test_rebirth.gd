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
	_equal(Prestige.perform(), true, "회귀")
	_equal(Game.stage, 101, "회귀 후 101스테이지에서 시작")
	_equal(Game.highest_stage, 101, "이번 판 최고도 101")
	_equal(Party.is_companion_unlocked(Balance.Companion.CLERIC), true, "성직자가 바로 합류한다")
	_close(Game.monster_max_hp, Balance.monster_hp(101), "101스테이지 몬스터가 나온다")


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
	_equal(Rebirth.fate_levels, [1, 0, 2], "운명의 상점 복원")
	_equal(Rebirth.rebirth_count, 2, "환생 횟수 복원")
	_equal(Save.apply_json(JSON.stringify(data)), true, "JSON 적용")
	_equal(Rebirth.fate_levels, [1, 0, 2], "JSON을 거친 상점 레벨")
	_equal(typeof(Rebirth.fate_levels[0]), TYPE_INT, "레벨은 int로 돌아온다")
	Save.from_dict({"save_version": 1})
	_close(Rebirth.threads, 0.0, "필드가 없으면 실 0")
	_equal(Rebirth.fate_levels, [0, 0, 0], "필드가 없으면 0레벨")
	Save.from_dict({"save_version": 1, "rebirth": {"fate_levels": [3, 1, 99], "threads": -2, "rebirth_count": -1}})
	_equal(Rebirth.fate_levels, [3, 1, 4], "상한을 넘는 예지는 잘라낸다")
	_close(Rebirth.threads, 0.0, "음수 실은 0")
	_equal(Rebirth.rebirth_count, 0, "음수 횟수는 0")
	Rebirth.threads = 9.0
	Save.reset_data()
	_close(Rebirth.threads, 0.0, "데이터 초기화는 지운다")
	_equal(Game.stage, 1, "초기화하면 1스테이지")
