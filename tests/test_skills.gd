extends "res://tests/test_case.gd"
## 스킬: 해금, 실제 시간 기준 지속·쿨타임, 효과, 저장


func run() -> void:
	_test_balance()
	_test_state()
	_test_effects()
	_test_storm_slash()


func _test_balance() -> void:
	_equal(Balance.skill_unlock_level(Balance.Skill.STORM_SLASH), 10, "폭풍 베기 10레벨")
	_equal(Balance.skill_unlock_level(Balance.Skill.BATTLE_CRY), 25, "전투의 함성 25레벨")
	_equal(Balance.skill_unlock_level(Balance.Skill.GOLDEN_TOUCH), 50, "황금 손길 50레벨")
	_close(Balance.skill_cooldown(0), 300.0, "쿨타임 5분")
	_close(Balance.skill_cooldown(2), 240.0, "명상 2레벨이면 −20%")
	_equal(Num.format_clock(272.0), "4:32", "쿨타임 표기")
	_equal(Num.format_clock(0.0), "0:00", "0초")


func _test_state() -> void:
	_fresh_run()
	var S: int = Balance.Skill.STORM_SLASH
	_equal(Skills.is_unlocked(S), false, "1레벨은 잠김")
	_equal(Skills.activate(S), false, "잠긴 스킬은 못 쓴다")
	Party.hero_level = 10
	_equal(Skills.is_unlocked(S), true, "10레벨에 해금")
	_equal(Skills.is_ready(S), true, "처음엔 바로 쓸 수 있다")
	_equal(Skills.activate(S), true, "발동")
	_equal(Skills.is_active(S), true, "발동 직후 활성")
	_equal(absf(Skills.active_left(S) - 30.0) < 1.0, true, "남은 지속 시간 약 30초")
	_equal(Skills.is_ready(S), false, "쿨타임 중")
	_equal(absf(Skills.cooldown_left(S) - 300.0) < 1.0, true, "남은 쿨타임 약 5분")
	_equal(Skills.activate(S), false, "쿨타임 중엔 못 쓴다")

	# 실제 시간 기준: 발동 시각을 과거로 돌리면 그만큼 흐른 것과 같다
	var now := Time.get_unix_time_from_system()
	Skills.activated_at[S] = now - 31.0
	_equal(Skills.is_active(S), false, "31초 뒤엔 끝난다")
	_equal(Skills.is_ready(S), false, "아직 쿨타임")
	Skills.activated_at[S] = now - 301.0
	_equal(Skills.is_ready(S), true, "5분 뒤엔 다시 준비")

	# 저장 왕복: 쿨타임이 이어진다
	Skills.activated_at[S] = now - 100.0
	var data := Skills.to_dict()
	Skills.reset()
	_equal(Skills.is_ready(S), true, "초기화하면 쿨타임도 지워진다")
	Skills.from_dict(data)
	_equal(absf(Skills.cooldown_left(S) - 200.0) < 1.0, true, "불러오면 남은 쿨타임 약 200초")
	Skills.from_dict({})
	_equal(Skills.activated_at, [0.0, 0.0, 0.0], "필드가 없으면 0")

	Skills.activated_at[S] = now - 100.0
	var whole := Save.to_dict()
	_equal(whole.has("skills"), true, "저장 데이터에 스킬이 들어간다")
	Skills.reset()
	Save.from_dict(whole)
	_equal(absf(Skills.cooldown_left(S) - 200.0) < 1.0, true, "Save로 복원")


func _test_effects() -> void:
	_fresh_run()
	Party.hero_level = 50
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	_close(Party.party_dps(false), 3.0, "함성 전 DPS 3")
	_equal(Skills.activate(Balance.Skill.BATTLE_CRY), true, "전투의 함성 발동")
	_close(Party.party_dps(false), 6.0, "전투의 함성: 동료 공격력 ×2")
	_close(Party.companion_dps(Balance.Companion.WARRIOR, false), 6.0, "연출용 DPS도 ×2")
	_close(Party.click_damage(), Balance.hero_click_damage(50), "클릭 피해는 그대로")
	Skills.reset()
	_close(Party.party_dps(false), 3.0, "끝나면 원래대로")

	var before := Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(10.0), "평소 처치 골드")
	_advance(0.5)
	_equal(Skills.activate(Balance.Skill.GOLDEN_TOUCH), true, "황금 손길 발동")
	before = Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(10.0) * 2.0, "황금 손길: 처치 골드 ×2")
	Skills.reset()


func _test_storm_slash() -> void:
	_fresh_run()
	Party.hero_level = 10  # 클릭 피해 20
	Game.stage = 30
	Game.highest_stage = 30
	Game._spawn_monster()
	var start := Game.monster_hp
	for i in 4:
		Skills._process(0.25)
	_close(Game.monster_hp, start, "발동 전엔 자동 클릭이 없다")
	_equal(Skills.activate(Balance.Skill.STORM_SLASH), true, "폭풍 베기 발동")
	for i in 4:
		Skills._process(0.25)
	_close(Game.monster_hp, start - 10.0 * Balance.hero_click_damage(10), "1초에 10회 자동 클릭")
