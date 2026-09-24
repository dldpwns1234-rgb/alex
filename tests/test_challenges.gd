extends "res://tests/test_case.gd"
## 도전 판 (GDD 7.9절): 해금, 시작(회귀로 끝내기), 제한 5종, 달성과 영구 보너스, 포기와 회귀로 풀림, 자동 회귀 예외, 저장

var _completed: Array[int] = []


func run() -> void:
	_test_balance()
	_test_unlock_and_start()
	_test_no_companions()
	_test_no_skills()
	_test_half_boss_time()
	_test_no_equipment()
	_test_no_memories()
	_test_cancel_and_automation()
	_test_save()
	_fresh_run()


func _on_completed(index: int) -> void:
	_completed.append(index)


## 환생 1회를 만들고 새 판에서 시작한다
func _unlock() -> void:
	_fresh_run()
	Rebirth.rebirth_count = 1
	_completed.clear()


func _test_balance() -> void:
	var names: Array[String] = []
	for i in Balance.CHALLENGES.size():
		_equal(names.has(Balance.challenge_name(i)), false, "도전 이름은 겹치지 않는다")
		names.append(Balance.challenge_name(i))
		_equal(Balance.challenge_goal(i) > Balance.start_stage(Balance.fate_max_level(Balance.Fate.FORESIGHT)), true, "목표는 예지 최대의 시작 스테이지보다 높다")
		_equal(Balance.restriction_note(Balance.challenge_restriction(i)).is_empty(), false, "제한 설명")
		_equal(Balance.perk_note(Balance.challenge_perk(i)).is_empty(), false, "보상 설명")


func _test_unlock_and_start() -> void:
	_fresh_run()
	_equal(Challenges.is_unlocked(), false, "환생 전에는 잠김")
	_equal(Challenges.start(0), false, "잠겨 있으면 시작 못 한다")
	Rebirth.rebirth_count = 1
	_equal(Challenges.is_unlocked(), true, "환생 1회부터")
	Game.highest_stage = 150
	Party.hero_level = 40
	_equal(Challenges.start(0), true, "도전 시작")
	_equal(Prestige.prestige_count, 1, "120 이상이면 회귀로 판을 끝내 결정을 받는다")
	_equal(Prestige.crystals > 0.0, true, "결정을 받았다")
	_equal(Party.hero_level, 1, "새 판")
	_equal(Challenges.active, 0, "홀로 서기 진행 중")
	_equal(Challenges.can_start(1), false, "한 번에 하나만")
	Challenges.give_up()
	_equal(Challenges.active, -1, "포기하면 풀린다")
	Game.highest_stage = 50
	Party.hero_level = 20
	_equal(Challenges.start(1), true, "120 전에도 시작할 수 있다")
	_equal(Prestige.prestige_count, 1, "회귀 보상 없이 판만 끝낸다")
	_equal(Party.hero_level, 1, "새 판")
	Challenges.give_up()


func _test_no_companions() -> void:
	_unlock()
	Challenges.completed.connect(_on_completed)
	Party.companion_levels[Balance.Companion.WARRIOR] = 5
	Game.highest_stage = 10
	_equal(Party.party_dps(false) > 0.0, true, "평소엔 동료가 싸운다")
	Challenges.start(0)
	Party.companion_levels[Balance.Companion.WARRIOR] = 5
	_close(Party.party_dps(false), 0.0, "홀로 서기: 동료 DPS 0")
	_close(Party.companion_dps(Balance.Companion.WARRIOR, false), 0.0, "동료 하나의 DPS도 0")
	Game.gold = 1e9
	_equal(Party.buy_companion(Balance.Companion.WARRIOR), false, "동료를 못 산다")
	var click := Party.click_damage() / Achievements.damage_multiplier()  # 목표에 닿으며 열리는 스테이지 업적은 빼고 본다
	Game.highest_stage = Balance.challenge_goal(0) - 1
	Game.stage_changed.emit(Game.highest_stage)
	_equal(Challenges.is_done(0), false, "목표 전에는 미달성")
	Game.highest_stage = Balance.challenge_goal(0)
	Game.stage_changed.emit(Game.highest_stage)
	_equal(Challenges.is_done(0), true, "목표에 닿으면 달성")
	_equal(Challenges.active, -1, "달성하면 제한이 풀린다")
	_equal(_completed, [0], "달성 시그널")
	_equal(Party.party_dps(false) > 0.0, true, "동료가 다시 싸운다")
	_close(Party.click_damage() / Achievements.damage_multiplier(), click * (1.0 + Balance.PERK_CLICK_BONUS), "클릭 피해 +25% (영구)")
	_equal(Challenges.can_start(0), false, "달성한 도전은 다시 못 한다")
	Challenges.completed.disconnect(_on_completed)


func _test_no_skills() -> void:
	_unlock()
	Party.hero_level = 100
	var base := Skills.cooldown()
	Challenges.start(1)
	Party.hero_level = 100
	_equal(Skills.is_sealed(), true, "침묵의 검: 봉인")
	_equal(Skills.can_activate(0), false, "스킬을 못 쓴다")
	_equal(Skills.activate(0), false, "발동도 안 된다")
	Game.highest_stage = Balance.challenge_goal(1)
	Game.stage_changed.emit(Game.highest_stage)
	_equal(Challenges.is_done(1), true, "달성")
	_equal(Skills.is_sealed(), false, "봉인이 풀린다")
	_close(Skills.cooldown(), base * (1.0 - Balance.PERK_COOLDOWN_CUT), "쿨타임 −10% (영구)")


func _test_half_boss_time() -> void:
	_unlock()
	var base := Game.boss_limit(5)
	Challenges.start(2)
	_close(Game.boss_limit(5), base * Balance.CHALLENGE_BOSS_TIME_SCALE, "시간의 채찍: 보스 시간 절반")
	Game.highest_stage = Balance.challenge_goal(2)
	Game.stage_changed.emit(Game.highest_stage)
	_close(Game.boss_limit(5), base + Balance.PERK_BOSS_TIME_SECONDS, "달성하면 +5초 (영구)")


func _test_no_equipment() -> void:
	_unlock()
	var W: int = Balance.Slot.WEAPON
	Equipment.drop(W, Balance.Grade.LEGENDARY, 300)
	_equal(Equipment.click_multiplier() > 1.0, true, "평소엔 무기 효과")
	Challenges.start(3)
	_close(Equipment.click_multiplier(), 1.0, "빈손: 무기 효과 없음")
	_close(Equipment.party_multiplier(), 1.0, "깃발 효과 없음")
	_close(Equipment.gold_multiplier(), 1.0, "장신구 효과 없음")
	Game.highest_stage = Balance.challenge_goal(3)
	Game.stage_changed.emit(Game.highest_stage)
	_equal(Equipment.click_multiplier() > 1.0, true, "달성하면 효과가 돌아온다")
	var stones := Equipment.stones
	Equipment.drop(W, Balance.Grade.COMMON, 1)  # 나쁜 장비라 분해
	_close(Equipment.stones, stones + Balance.dismantle_stones(Balance.Grade.COMMON) * Balance.PERK_STONE_MULTIPLIER, "분해 강화석 ×2 (영구)")


func _test_no_memories() -> void:
	_unlock()
	Prestige.memory_levels[Balance.Memory.SWORD] = 3
	Prestige.memory_levels[Balance.Memory.SAND] = 2
	_equal(Prestige.sword_multiplier() > 1.0, true, "평소엔 검술의 기억")
	Challenges.start(4)
	_close(Prestige.sword_multiplier(), 1.0, "맨몸의 회귀: 검술 효과 없음")
	_equal(Prestige.level(Balance.Memory.SWORD), 3, "상점 표시 레벨은 그대로")
	_close(Game.boss_limit(5), Balance.BOSS_TIME_LIMIT, "시간의 모래도 없음")
	Game.highest_stage = 140
	var reward := Prestige.crystal_reward()
	Game.highest_stage = Balance.challenge_goal(4)
	Game.stage_changed.emit(Game.highest_stage)
	_equal(Prestige.sword_multiplier() > 1.0, true, "달성하면 효과가 돌아온다")
	Game.highest_stage = 140
	_close(Prestige.crystal_reward(), reward * (1.0 + Balance.PERK_CRYSTAL_BONUS), "기억의 결정 +10% (영구)")


func _test_cancel_and_automation() -> void:
	_unlock()
	Challenges.start(0)
	Game.highest_stage = 150
	_equal(Prestige.perform(), true, "도전 중 회귀")
	_equal(Challenges.active, -1, "회귀하면 도전이 풀린다")
	_equal(Challenges.is_done(0), false, "달성은 아니다")
	Challenges.start(0)
	Rebirth.threads = 1.0
	Rebirth.buy(Balance.Fate.AUTO_PRESTIGE)
	Game.highest_stage = 150
	var count := Prestige.prestige_count
	var left := Balance.AUTO_PRESTIGE_STALL + 2.0
	while left > 0.0:
		Automation._process(Balance.MAX_DELTA)
		left -= Balance.MAX_DELTA
	_equal(Prestige.prestige_count, count, "도전 중에는 자동 회귀하지 않는다")
	Game.highest_stage = 520
	_equal(Rebirth.perform(), true, "도전 중 환생")
	_equal(Challenges.active, -1, "환생해도 도전이 풀린다")


func _test_save() -> void:
	_unlock()
	Challenges.done[2] = true
	Challenges.start(1)
	var data := Save.to_dict()
	_equal(data.has("challenges"), true, "저장 데이터에 도전이 들어간다")
	_fresh_run()
	Save.from_dict(data)
	_equal(Challenges.active, 1, "진행 중인 도전 복원")
	_equal(Challenges.done, [false, false, true, false, false], "달성 복원")
	Save.from_dict({"save_version": 1})
	_equal(Challenges.active, -1, "옛 저장은 도전 없음")
	_equal(Challenges.done, [false, false, false, false, false], "옛 저장은 미달성")
	Save.from_dict({"save_version": 1, "challenges": {"active": 99, "done": [true]}})
	_equal(Challenges.active, 4, "범위를 넘는 색인은 잘라낸다")
	_equal(Challenges.done[0], true, "짧은 배열은 앞만 적용")
