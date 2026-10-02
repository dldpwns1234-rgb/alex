extends "res://tests/test_case.gd"
## 별자리 시련 (GDD 7.12절): 해금, 제한 둘이 함께 걸림, 단계 목표, 달성과 보상, 도전 판과 겹치지 않음, 저장


func run() -> void:
	_fresh_run()
	Transcend.reset()
	Trials.reset()
	_test_table()
	_test_unlock_and_start()
	_test_complete_and_rewards()
	_test_save()
	_fresh_run()
	Trials.reset()
	Transcend.reset()


func _test_table() -> void:
	_equal(Balance.TRIALS.size(), 5, "시련 5개")
	for i in Balance.TRIALS.size():
		_equal(Balance.trial_restrictions(i).size(), 2, "%d번 시련은 제한 둘" % i)
		_equal(Balance.trial_goal(i, 4) > Balance.trial_goal(i, 0), true, "%d번 시련은 단계마다 목표가 오른다" % i)
		_equal(Balance.trial_goal(i, 4) < Balance.FINAL_STAGE, true, "%d번 시련 5단계도 최종 스테이지 안" % i)
	_equal(Balance.trial_goal(0, 0), 1500, "침묵의 시간 1단계 1500")
	_equal(Balance.trial_goal(0, 4), 3750, "5단계는 ×2.5")


func _test_unlock_and_start() -> void:
	_equal(Trials.can_start(0), false, "초월 전에는 시작할 수 없다")
	Transcend.count = 1
	_equal(Trials.can_start(0), true, "초월 1회부터")
	_equal(Trials.start(0), true, "침묵의 시간 시작")
	_equal(Challenges.blocks_skills(), true, "스킬 봉인")
	_close(Challenges.boss_time_scale(), Balance.CHALLENGE_BOSS_TIME_SCALE, "보스 시간 절반도 함께")
	_equal(Challenges.blocks_companions(), false, "다른 제한은 없다")
	_equal(Challenges.any_active(), true, "자동 회귀가 쉰다")
	_equal(Trials.can_start(1), false, "한 번에 하나만")
	Rebirth.rebirth_count = 1
	_equal(Challenges.can_start(0), false, "시련 중에는 도전 판도 못 한다")
	Trials.give_up()
	_equal(Challenges.blocks_skills(), false, "포기하면 제한이 풀린다")
	_equal(Trials.tiers[0], 0, "포기는 단계가 아니다")


func _test_complete_and_rewards() -> void:
	Trials.start(1)  # 고독한 맨손: 목표 450
	_equal(Challenges.blocks_companions() and Challenges.blocks_equipment(), true, "동료·장비 제한")
	var before := Challenges.click_multiplier()
	Game.highest_stage = 449
	Game.stage_changed.emit(449)
	_equal(Trials.tiers[1], 0, "목표 전에는 그대로")
	Game.highest_stage = 450
	Game.stage_changed.emit(450)
	_equal(Trials.tiers[1], 1, "목표에 닿으면 1단계")
	_equal(Trials.active, -1, "제한이 풀린다")
	_close(Challenges.click_multiplier(), before * 2.0, "보상: 클릭 피해 ×2")
	_equal(Trials.goal(1), 585, "2단계 목표 585")
	Trials.tiers[4] = 2
	_close(Trials.star_bonus(), 2.0, "홀로 잊힌 자 2단계: 파편 +2")
	Transcend.cycle_seconds = 21600.0
	_close(Transcend.star_reward(), 5.0, "초월 파편 3 + 2")
	Trials.tiers[0] = 2
	_close(Trials.boss_time_bonus(), 6.0, "침묵의 시간 2단계: 보스 +6초")
	Trials.tiers[2] = 3
	_close(Trials.crystal_multiplier(), 8.0, "망각의 침묵 3단계: 결정 ×8")
	Trials.tiers[3] = 2
	_close(Trials.stone_multiplier(), 2.0, "맨손의 질주 2단계: 강화석 ×2")
	Trials.tiers[2] = 5
	_equal(Trials.can_start(2), false, "5단계를 다 깨면 끝")


func _test_save() -> void:
	var data := Save.to_dict()
	_equal(data.has("trials"), true, "저장 데이터에 시련이 들어간다")
	var tiers := Trials.tiers.duplicate()
	Trials.reset()
	Save.from_dict(data)
	_equal(Trials.tiers, tiers, "단계 복원")
	var old := data.duplicate(true)
	old.erase("trials")
	Save.from_dict(old)
	_equal(Trials.tiers, [0, 0, 0, 0, 0], "시련이 없던 옛 저장은 0단계")
	_equal(Trials.active, -1, "진행 중인 시련 없음")
