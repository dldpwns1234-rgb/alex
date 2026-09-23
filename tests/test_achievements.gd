extends "res://tests/test_case.gd"
## 업적: 정의 표, 통계 수집, 달성과 보너스, 본 것 표시, 저장과 옛 저장 호환, 회귀 유지와 초기화

var _got: Array[int] = []  # unlocked 시그널로 받은 업적 번호


func run() -> void:
	_test_table()
	_test_stats()
	_test_unlock_and_bonus()
	_test_seen()
	_test_save()
	_test_prestige_and_reset()
	_fresh_run()


func _test_table() -> void:
	var names := {}
	var last_goal := {}
	for i in Balance.ACHIEVEMENTS.size():
		names[Balance.achievement_name(i)] = true
		var stat := Balance.achievement_stat(i)
		_equal(Balance.achievement_goal(i) > float(last_goal.get(stat, 0.0)), true, "%d번 업적의 목표는 같은 통계 안에서 오른다" % i)
		last_goal[stat] = Balance.achievement_goal(i)
		_equal(Balance.achievement_amount(i) > 0.0, true, "%d번 업적의 보너스는 양수" % i)
	_equal(names.size(), Balance.ACHIEVEMENTS.size(), "업적 이름은 겹치지 않는다")
	_equal(Balance.achievement_goal_text(0, "10"), "스테이지 10 도달", "목표 설명")
	_equal(Balance.achievement_reward_note(0), "모든 피해 +1%", "보너스 설명")
	var none: Array[bool] = []
	none.resize(Balance.ACHIEVEMENTS.size())
	none.fill(false)
	_close(Balance.achievement_multiplier(Balance.Reward.DAMAGE, none), 1.0, "달성이 없으면 ×1")
	var all: Array[bool] = none.duplicate()
	all.fill(true)
	var damage := 0.0
	var gold := 0.0
	for i in Balance.ACHIEVEMENTS.size():
		if Balance.achievement_reward(i) == Balance.Reward.DAMAGE:
			damage += Balance.achievement_amount(i)
		else:
			gold += Balance.achievement_amount(i)
	_close(Balance.achievement_multiplier(Balance.Reward.DAMAGE, all), 1.0 + damage, "전부 달성하면 피해 보너스의 합")
	_close(Balance.achievement_multiplier(Balance.Reward.GOLD, all), 1.0 + gold, "전부 달성하면 골드 보너스의 합")


func _test_stats() -> void:
	_fresh_run()
	var S := Balance.Stat
	_close(Achievements.value(S.TAPS), 0.0, "시작 탭 수 0")
	Game.tap_attack()
	Game.tap_attack(true)
	_close(Achievements.value(S.TAPS), 1.0, "폭풍 베기의 자동 클릭은 탭 수에 안 들어간다")
	Game._damage_monster(Game.monster_max_hp)
	_close(Achievements.value(S.KILLS), 1.0, "처치 1")
	_close(Achievements.value(S.BOSS_KILLS), 0.0, "일반 몬스터는 보스 처치가 아니다")
	_close(Achievements.value(S.GOLD), Balance.kill_gold(10.0), "처치 골드가 누적된다")
	Game.stage = 5
	Game.highest_stage = 5
	Game._spawn_monster()
	Game._damage_monster(Game.monster_max_hp)
	_close(Achievements.value(S.BOSS_KILLS), 1.0, "보스 처치 1")
	_close(Achievements.value(S.KILLS), 2.0, "보스도 처치 수에 든다")
	_close(Achievements.value(S.STAGE), 6.0, "보스를 잡고 6스테이지: 역대 최고 갱신")
	Game.gold = 200.0
	Party.buy_hero()
	_close(Achievements.value(S.HERO_LEVEL), 2.0, "용사 레벨업이 잡힌다")
	Party.buy_companion(Balance.Companion.WARRIOR)
	_close(Achievements.value(S.PARTY), 1.0, "고용한 동료 수")
	Party.hero_level = 10
	Skills.activate(Balance.Skill.STORM_SLASH)
	_close(Achievements.value(S.SKILLS), 1.0, "스킬 사용이 잡힌다")
	Skills.reset()
	var before := Game.gold
	var earned := Achievements.value(S.GOLD)
	Save.grant_offline(100.0)
	_close(Achievements.value(S.GOLD), earned + (Game.gold - before), "오프라인 보상도 획득 골드에 든다")
	Game.highest_stage = 120
	_equal(Prestige.perform(), true, "회귀")
	_close(Achievements.value(S.PRESTIGES), 1.0, "회귀 횟수가 잡힌다")
	_close(Achievements.value(S.KILLS), 2.0, "회귀해도 통계는 남는다")
	_close(Achievements.value(S.STAGE), 120.0, "역대 최고 스테이지도 남는다")


func _test_unlock_and_bonus() -> void:
	_fresh_run()
	Achievements.unlocked.connect(_on_unlocked)
	_got.clear()
	_equal(Achievements.is_unlocked(0), false, "처음엔 미달성")
	_close(Achievements.damage_multiplier(), 1.0, "보너스 없음")
	Achievements.raise(Balance.Stat.STAGE, 9.0)
	_close(Achievements.progress(0), 0.9, "진행 90%")
	_equal(_got, [], "아직 달성 없음")
	Achievements.raise(Balance.Stat.STAGE, 10.0)
	_equal(_got, [0], "스테이지 10에 첫 업적")
	_equal(Achievements.is_unlocked(0), true, "달성됨")
	_close(Achievements.progress(0), 1.0, "진행 100%")
	_close(Achievements.damage_multiplier(), 1.01, "모든 피해 +1%")
	Achievements.raise(Balance.Stat.STAGE, 9.0)
	Achievements.raise(Balance.Stat.STAGE, 11.0)
	_equal(_got, [0], "낮은 값은 무시하고, 다시 달성하지 않는다")
	Party.hero_level = 10
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	_close(Party.click_damage(), 20.0 * 1.01, "클릭 피해에 업적 배율")
	_close(Party.party_dps(false), 3.0 * 1.01, "동료 DPS에 업적 배율")
	_close(Party.companion_dps(Balance.Companion.WARRIOR, false), 3.0 * 1.01, "연출용 DPS도")

	Achievements.add(Balance.Stat.GOLD, 10000.0)
	_close(Achievements.gold_multiplier(), 1.01, "골드 1만 획득: 처치 골드 +1%")
	var before := Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(10.0) * 1.01, "처치 골드에 업적 배율")
	before = Game.gold
	Save.grant_offline(100.0)
	var per_second := Balance.offline_gold_per_second(1, 3.0 * 1.01) * 1.01
	_close(Game.gold, before + per_second * 100.0 * 0.5, "오프라인 보상에도 업적 배율 (피해와 골드 둘 다)")

	_got.clear()
	Achievements.raise(Balance.Stat.STAGE, 100.0)
	_equal(_got, [1, 2, 3], "한 번에 여러 목표를 넘으면 차례로 달성")
	_close(Achievements.damage_multiplier(), 1.0 + 0.01 + 0.01 + 0.02 + 0.02, "피해 보너스는 더한다")
	_equal(Achievements.unlocked_count(), 5, "달성 5개 (스테이지 4, 골드 1)")
	Achievements.unlocked.disconnect(_on_unlocked)


func _test_seen() -> void:
	_fresh_run()
	_equal(Achievements.has_unseen(), false, "처음엔 볼 것 없음")
	Achievements.raise(Balance.Stat.STAGE, 10.0)
	_equal(Achievements.has_unseen(), true, "달성하면 안 본 것이 생긴다")
	Achievements.mark_seen()
	_equal(Achievements.has_unseen(), false, "탭을 열면 본 것으로")
	_equal(Achievements.seen_count, 1, "본 달성 수 1")
	Achievements.raise(Balance.Stat.STAGE, 25.0)
	_equal(Achievements.has_unseen(), true, "새로 달성하면 다시 점")


func _test_save() -> void:
	_fresh_run()
	Achievements.raise(Balance.Stat.STAGE, 25.0)
	Achievements.add(Balance.Stat.KILLS, 150.0)
	Achievements.mark_seen()
	var data := Save.to_dict()
	_equal(data.has("achievements"), true, "저장 데이터에 업적이 들어간다")
	_fresh_run()
	_close(Achievements.value(Balance.Stat.KILLS), 0.0, "초기화 확인")
	Save.from_dict(data)
	_close(Achievements.value(Balance.Stat.STAGE), 25.0, "스테이지 통계 복원")
	_close(Achievements.value(Balance.Stat.KILLS), 150.0, "처치 통계 복원")
	_equal(Achievements.unlocked_count(), 3, "달성이 통계에서 다시 계산된다")
	_equal(Achievements.seen_count, 3, "본 달성 수 복원")
	_close(Achievements.damage_multiplier(), 1.03, "보너스 복원")
	_equal(Save.apply_json(JSON.stringify(data)), true, "JSON을 거쳐도 같다")
	_close(Achievements.value(Balance.Stat.KILLS), 150.0, "JSON을 거친 처치 통계")

	# 업적이 없던 옛 저장: 회귀 기록과 이번 판 최고 스테이지에서 시작한다
	Save.from_dict({"save_version": 1, "prestige": {"best_stage": 130, "prestige_count": 2},
		"game": {"stage": 60, "highest_stage": 80}})
	_close(Achievements.value(Balance.Stat.STAGE), 130.0, "역대 최고 스테이지를 이어받는다")
	_close(Achievements.value(Balance.Stat.PRESTIGES), 2.0, "회귀 횟수를 이어받는다")
	_close(Achievements.value(Balance.Stat.KILLS), 0.0, "모르는 통계는 0")
	_equal(Achievements.seen_count, 0, "본 것 없음")
	_equal(Achievements.has_unseen(), true, "이어받은 달성은 점으로 알린다")
	Save.from_dict({"save_version": 1, "game": {"stage": 60, "highest_stage": 80}})
	_close(Achievements.value(Balance.Stat.STAGE), 80.0, "회귀 기록이 없으면 이번 판 최고 스테이지")
	Save.from_dict({"save_version": 1, "achievements": {"stats": [-5, 7], "seen_count": 99}})
	_close(Achievements.value(Balance.Stat.STAGE), 1.0, "음수 통계는 0 (회귀 기록 1로 채워진다)")
	_close(Achievements.value(Balance.Stat.KILLS), 7.0, "있는 값은 그대로")
	_close(Achievements.value(Balance.Stat.TAPS), 0.0, "모자란 항목은 0")
	_equal(Achievements.seen_count, 0, "본 달성 수는 달성 수를 넘지 않는다")


func _test_prestige_and_reset() -> void:
	_fresh_run()
	Achievements.raise(Balance.Stat.STAGE, 10.0)
	Game.highest_stage = 120
	_equal(Prestige.perform(), true, "회귀")
	_equal(Achievements.is_unlocked(0), true, "회귀해도 달성은 남는다")
	_close(Achievements.value(Balance.Stat.STAGE), 120.0, "회귀 기록이 역대 최고 스테이지가 된다")
	_close(Achievements.damage_multiplier(), 1.06, "회귀해도 보너스는 남고, 스테이지 25·50·100 업적이 더 열린다")
	Save.reset_data()
	_equal(Achievements.is_unlocked(0), false, "데이터 초기화는 지운다")
	_close(Achievements.value(Balance.Stat.STAGE), 1.0, "통계는 시작 스테이지 1")
	_close(Achievements.damage_multiplier(), 1.0, "보너스도 사라진다")


func _on_unlocked(index: int) -> void:
	_got.append(index)
