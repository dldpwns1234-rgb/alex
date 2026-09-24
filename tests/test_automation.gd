extends "res://tests/test_case.gd"
## 자동화: 운명의 상점 해금과 토글, 정체 30초 자동 회귀(보스와 싸우는 중은 제외), 결정 자동 구매, 스킬 자동 사용, 저장


func run() -> void:
	_test_unlock_and_toggle()
	_test_auto_prestige()
	_test_auto_memories()
	_test_auto_skills()
	_test_save()
	_fresh_run()


func _test_unlock_and_toggle() -> void:
	_fresh_run()
	var P: int = Balance.Auto.PRESTIGE
	var S: int = Balance.Auto.SKILLS
	_equal(Automation.is_enabled(P), true, "기본은 켬")
	_equal(Automation.is_unlocked(P), false, "운명을 사기 전엔 잠김")
	_equal(Automation.is_active(P), false, "잠겨 있으면 동작하지 않는다")
	Rebirth.threads = 2.0
	_equal(Rebirth.buy(Balance.Fate.AUTO_PRESTIGE), true, "자동 회귀 해금")
	_equal(Rebirth.buy(Balance.Fate.AUTO_PRESTIGE), false, "해금은 한 번뿐")
	_equal(Automation.is_unlocked(P), true, "자동 회귀 열림")
	_equal(Automation.is_unlocked(Balance.Auto.MEMORIES), true, "결정 자동 구매도 같은 운명이 연다")
	_equal(Automation.is_unlocked(S), false, "자동 스킬은 따로 산다")
	_equal(Automation.is_active(P), true, "열리고 켜져 있으면 동작")
	Automation.set_enabled(P, false)
	_equal(Automation.is_active(P), false, "끄면 동작하지 않는다")
	Automation.set_enabled(P, true)


func _test_auto_prestige() -> void:
	_fresh_run()
	Rebirth.threads = 1.0
	Rebirth.buy(Balance.Fate.AUTO_PRESTIGE)
	Game.highest_stage = 150
	Game.stage = 150
	Party.hero_level = 100
	_tick(Balance.AUTO_PRESTIGE_STALL - 1.0)
	_equal(Prestige.prestige_count, 0, "정체 기준 전에는 회귀하지 않는다")
	_tick(2.0)
	_equal(Prestige.prestige_count, 1, "정체 30초면 스스로 회귀한다")
	_equal(Game.stage, 1, "회귀해서 1스테이지")
	_tick(Balance.AUTO_PRESTIGE_STALL + 1.0)
	_equal(Prestige.prestige_count, 1, "회귀 조건(120)이 안 되면 정체해도 회귀하지 않는다")
	# 새 스테이지에 닿으면 정체 시계가 되돌아간다
	Game.highest_stage = 150
	Game.stage = 150
	_tick(Balance.AUTO_PRESTIGE_STALL - 1.0)
	Game.stage = 151
	Game.highest_stage = 151
	Game.stage_changed.emit(151)
	_tick(2.0)
	_equal(Prestige.prestige_count, 1, "진행 중이면 회귀하지 않는다")
	# 보스와 싸우는 중에는 회귀하지 않고, 보스가 죽거나 시간이 끝나면 회귀한다
	Game.stage = 155
	Game.highest_stage = 155
	Game.stage_changed.emit(155)
	Game._spawn_monster()
	_equal(Game.is_boss_stage() and Game.is_monster_alive(), true, "보스 살아 있음")
	_tick(Balance.AUTO_PRESTIGE_STALL + 1.0)
	_equal(Prestige.prestige_count, 1, "보스와 싸우는 중에는 회귀하지 않는다")
	Game.monster_hp = 0.0
	_tick(1.0)
	_equal(Prestige.prestige_count, 2, "보스가 사라지면 회귀한다")
	Automation.set_enabled(Balance.Auto.PRESTIGE, false)
	Game.highest_stage = 150
	_tick(Balance.AUTO_PRESTIGE_STALL + 1.0)
	_equal(Prestige.prestige_count, 2, "꺼 두면 회귀하지 않는다")


func _test_auto_memories() -> void:
	_fresh_run()
	var SWORD: int = Balance.Memory.SWORD
	Rebirth.threads = 1.0
	Rebirth.buy(Balance.Fate.AUTO_PRESTIGE)
	Game.highest_stage = 120  # 회귀 보상 10개: 일곱 개를 1개씩 사고, 남은 3개로 검술 2레벨(2개), 1개는 남는다
	_equal(Prestige.perform(), true, "회귀")
	_close(Prestige.crystals, 1.0, "회귀하면 받은 결정을 싼 것부터 산다")
	_equal(Prestige.level(SWORD), 2, "같은 값이면 앞의 것(검술)부터")
	for i in range(1, Balance.MEMORIES.size()):
		_equal(Prestige.level(i), 1, "%s 1레벨" % Balance.memory_name(i))
	Game.highest_stage = 120
	Automation.set_enabled(Balance.Auto.MEMORIES, false)
	_equal(Prestige.perform(), true, "회귀")
	_equal(Prestige.level(SWORD), 2, "꺼 두면 사지 않는다")
	_close(Prestige.crystals, 11.0, "결정이 남아 있다")


func _test_auto_skills() -> void:
	_fresh_run()
	Skills.clock_override = 1000.0
	Party.hero_level = 100
	_tick(0.25)
	_equal(Skills.is_active(Balance.Skill.STORM_SLASH), false, "해금 전에는 스킬을 쓰지 않는다")
	Rebirth.threads = 1.0
	Rebirth.buy(Balance.Fate.AUTO_SKILLS)
	_tick(0.25)
	for i in Balance.SKILLS.size():
		_equal(Skills.is_active(i), true, "%s를 바로 쓴다" % Balance.skill_name(i))
	Skills.clock_override = 1000.0 + Skills.cooldown() + 1.0
	Skills.activated_at[0] = 500.0  # 폭풍 베기만 쿨타임이 끝난 상태로
	_tick(0.25)
	_close(Skills.activated_at[0], Skills.clock_override, "쿨타임이 끝나면 다시 쓴다")
	Skills.clock_override = -1.0


func _test_save() -> void:
	_fresh_run()
	Automation.set_enabled(Balance.Auto.MEMORIES, false)
	var data := Save.to_dict()
	_equal(data.has("automation"), true, "저장 데이터에 자동화가 들어간다")
	_fresh_run()
	_equal(Automation.is_enabled(Balance.Auto.MEMORIES), true, "초기화하면 켬")
	Save.from_dict(data)
	_equal(Automation.is_enabled(Balance.Auto.MEMORIES), false, "설정 복원")
	_equal(Automation.is_enabled(Balance.Auto.PRESTIGE), true, "다른 설정은 켬")
	Save.from_dict({"save_version": 1})
	_equal(Automation.enabled, [true, true, true], "옛 저장은 전부 켬")
	Save.from_dict({"save_version": 1, "automation": {"enabled": [false]}})
	_equal(Automation.enabled, [false, true, true], "짧은 배열은 앞만 적용")


## Automation과 Game의 프레임을 함께 돌린다
func _tick(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(left, Balance.MAX_DELTA)
		Game._process(dt)
		Automation._process(dt)
		left -= dt
