extends "res://tests/test_case.gd"
## 회귀와 기억의 상점: 조건, 결정 수, 초기화와 유지, 상점 구매, 효과, 저장


func run() -> void:
	_test_balance()
	_test_prestige()
	_test_shop()
	_test_effects()
	_test_save()


func _test_balance() -> void:
	_equal(Balance.can_prestige(119), false, "119스테이지는 회귀 불가")
	_equal(Balance.can_prestige(120), true, "120스테이지부터 회귀")
	_close(Balance.crystal_reward(119), 0.0, "조건 미달이면 결정 0")
	_close(Balance.crystal_reward(120), 10.0, "120스테이지 결정 10")
	_close(Balance.crystal_reward(140), floor(10.0 * pow(1.1, 20)), "140스테이지 결정 67")
	_close(Balance.memory_cost(0), 1.0, "첫 레벨 비용 1")
	_close(Balance.memory_cost(3), 8.0, "4번째 레벨 비용 8")
	_close(Balance.sword_multiplier(2), 2.25, "검술 2레벨 ×2.25")
	_close(Balance.gold_memory_multiplier(1), 1.25, "황금 1레벨 ×1.25")
	_close(Balance.awakening_share(3), 0.03, "각성 3레벨 3%")
	_equal(Balance.memory_max_level(Balance.Memory.SWORD), 0, "검술은 상한 없음")
	_equal(Balance.memory_max_level(Balance.Memory.SAND), 10, "시간의 모래 상한 10")
	_equal(Balance.memory_max_level(Balance.Memory.WIND), 5, "바람의 걸음 상한 5")
	_close(Balance.wind_respawn_cut(5), 0.15, "바람의 걸음 5레벨: −0.15초")
	_equal(Balance.memory_note(Balance.Memory.WIND), "재등장 대기 −0.03초", "바람의 걸음 설명")


func _test_prestige() -> void:
	_fresh_run()
	Game.gold = 999.0
	Party.hero_level = 40
	Party.companion_levels[Balance.Companion.WARRIOR] = 7
	Skills.activated_at[Balance.Skill.STORM_SLASH] = Time.get_unix_time_from_system()
	_equal(Prestige.can_prestige(), false, "1스테이지에서는 회귀 불가")
	_equal(Prestige.perform(), false, "조건 미달이면 아무 일도 없다")
	_close(Prestige.crystals, 0.0, "결정 그대로")

	Game.highest_stage = 140
	Game.stage = 138
	_equal(Prestige.can_prestige(), true, "140스테이지면 회귀 가능")
	_close(Prestige.crystal_reward(), 67.0, "받을 결정 67")
	_equal(Prestige.perform(), true, "회귀")
	_close(Prestige.crystals, 67.0, "결정을 받았다")
	_equal(Prestige.best_stage, 140, "역대 최고 스테이지")
	_equal(Prestige.prestige_count, 1, "회귀 1회")
	_equal(Game.stage, 1, "스테이지 1로")
	_equal(Game.highest_stage, 1, "이번 판 최고 스테이지도 1로")
	_close(Game.gold, 0.0, "골드 0으로")
	_equal(Party.hero_level, 1, "용사 1레벨로")
	_equal(Party.companion_levels, [0, 0, 0, 0], "동료 미고용으로")
	_equal(Skills.is_ready(Balance.Skill.STORM_SLASH), true, "스킬 쿨타임 초기화")
	_equal(Prestige.can_prestige(), false, "회귀 직후엔 다시 불가")


func _test_shop() -> void:
	_fresh_run()
	var S: int = Balance.Memory.SWORD
	var SAND: int = Balance.Memory.SAND
	_equal(Prestige.buy(S), false, "결정이 없으면 못 산다")
	Prestige.crystals = 10.0
	_close(Prestige.memory_cost(S), 1.0, "첫 비용 1")
	_equal(Prestige.buy(S), true, "검술 구매")
	_equal(Prestige.level(S), 1, "검술 1레벨")
	_close(Prestige.crystals, 9.0, "결정 9")
	_close(Prestige.memory_cost(S), 2.0, "다음 비용 2")
	_equal(Prestige.buy(S), true, "검술 2레벨")
	_close(Prestige.crystals, 7.0, "결정 7")

	Prestige.crystals = 2000.0
	for i in 10:
		_equal(Prestige.buy(SAND), true, "시간의 모래 %d레벨" % (i + 1))
	_equal(Prestige.is_maxed(SAND), true, "10레벨이면 최대")
	_equal(Prestige.buy(SAND), false, "최대 레벨은 못 산다")
	_close(Prestige.crystals, 2000.0 - 1023.0, "10레벨까지 비용 합 1023")


func _test_effects() -> void:
	_fresh_run()
	Party.hero_level = 10
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	_close(Party.click_damage(), 20.0, "기본 클릭 피해 20")
	_close(Party.party_dps(false), 3.0, "기본 동료 DPS 3")
	Prestige.memory_levels[Balance.Memory.SWORD] = 1
	_close(Party.click_damage(), 30.0, "검술 1레벨: 클릭 ×1.5")
	_close(Party.party_dps(false), 4.5, "검술 1레벨: 동료 ×1.5")
	_close(Party.companion_dps(Balance.Companion.WARRIOR, false), 4.5, "연출용 DPS도 ×1.5")
	Prestige.memory_levels[Balance.Memory.AWAKENING] = 2
	_close(Party.click_damage(), 30.0 + 4.5 * 0.02, "각성 2레벨: 동료 DPS의 2% 추가")

	Prestige.memory_levels[Balance.Memory.GOLD] = 1
	var before := Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(10.0) * 1.25, "황금 1레벨: 처치 골드 ×1.25")

	Prestige.memory_levels[Balance.Memory.SAND] = 2
	Game.stage = 5
	Game.highest_stage = 5
	Game._spawn_monster()
	_close(Game.boss_time_left, 36.0, "시간의 모래 2레벨: 보스 36초")

	Prestige.memory_levels[Balance.Memory.MEDITATION] = 1
	Skills.activated_at[Balance.Skill.STORM_SLASH] = Time.get_unix_time_from_system()
	_equal(absf(Skills.cooldown_left(Balance.Skill.STORM_SLASH) - 270.0) < 1.0, true, "명상 1레벨: 쿨타임 4분 30초")

	Prestige.memory_levels[Balance.Memory.NAP] = 1
	Game.stage = 1
	Game._spawn_monster()
	before = Game.gold
	Save.grant_offline(100.0)
	var per_second := Balance.offline_gold_per_second(1, 4.5) * 1.25
	_close(Game.gold, before + per_second * 100.0 * 0.6, "단잠 1레벨: 오프라인 0.6배, 검술·황금 반영")

	Prestige.memory_levels[Balance.Memory.WIND] = 5
	_close(Game.respawn_delay(), 0.15, "바람의 걸음 5레벨: 재등장 0.15초")
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.respawn_left, 0.15, "처치 뒤 대기 0.15초")
	_advance(0.16)
	_equal(Game.is_monster_alive(), true, "0.16초 뒤 재등장")
	Training.levels[6] = 5  # 도발 5레벨 (−0.1초)
	_close(Game.respawn_delay(), 0.05, "도발과 함께 0.05초")
	Prestige.memory_levels[Balance.Memory.WIND] = 20
	_close(Game.respawn_delay(), 0.05, "최소 0.05초 아래로는 안 내려간다")
	Prestige.memory_levels[Balance.Memory.WIND] = 5
	Training.levels[6] = 0
	before = Game.gold
	Save.grant_offline(100.0)
	per_second = Balance.offline_gold_per_second(1, 4.5, 0.15) * 1.25
	_close(Game.gold, before + per_second * 100.0 * 0.6, "오프라인 보상에도 줄어든 재등장 대기")


func _test_save() -> void:
	_fresh_run()
	Prestige.crystals = 12.0
	Prestige.memory_levels[Balance.Memory.SWORD] = 3
	Prestige.best_stage = 130
	Prestige.prestige_count = 2
	var data := Save.to_dict()
	_equal(data.has("prestige"), true, "저장 데이터에 회귀가 들어간다")
	Game.reset()
	_close(Prestige.crystals, 12.0, "새 판을 시작해도 결정은 남는다")
	Prestige.reset()
	_close(Prestige.crystals, 0.0, "데이터 초기화는 지운다")
	Save.from_dict(data)
	_close(Prestige.crystals, 12.0, "결정 복원")
	_equal(Prestige.level(Balance.Memory.SWORD), 3, "상점 레벨 복원")
	_equal(Prestige.best_stage, 130, "역대 최고 복원")
	_equal(Prestige.prestige_count, 2, "회귀 횟수 복원")
	Save.from_dict({"save_version": 1, "prestige": {"memory_levels": [1, 1, 99]}})
	_equal(Prestige.level(Balance.Memory.SAND), 10, "상한을 넘는 저장값은 잘라낸다")
	_equal(Prestige.level(Balance.Memory.NAP), 0, "모자란 항목은 0")
	_fresh_run()
