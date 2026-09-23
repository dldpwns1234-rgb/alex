extends "res://tests/test_case.gd"
## 보스 스테이지: 타이머, 실패 시 파밍, 보스 도전, 마법사 ×3


func run() -> void:
	_test_boss_fight()
	_test_mage_versus_boss()
	_test_auto_retry()
	_test_auto_retry_by_tapping()


func _test_boss_fight() -> void:
	_fresh_run()
	# 4스테이지에서 10마리를 잡으면 5스테이지 보스가 나온다
	Game.stage = 4
	Game.highest_stage = 4
	Game._spawn_monster()
	for i in 9:
		Game._damage_monster(Game.monster_max_hp)
		_advance(1.0)
	Game._damage_monster(Game.monster_max_hp)
	_advance(0.5)  # 재등장 0.3초만 지나고 보스 타이머는 아직 흐르지 않은 시점
	_equal(Game.stage, 5, "5스테이지")
	_equal(Game.is_boss_stage(), true, "보스 스테이지")
	_close(Game.monster_max_hp, Balance.boss_hp(5), "보스 체력")
	_close(Game.boss_time_left, 30.0, "타이머 30초에서 시작")

	# 동료가 없으니 피해가 없고 시간만 간다
	_advance(10.0)
	_close(Game.boss_time_left, 20.0, "10초 뒤 20초")
	_equal(Game.farming, false, "아직 실패 아님")
	_advance(19.9)
	_equal(Game.farming, false, "0.1초 남음")
	_advance(0.25)
	_equal(Game.farming, true, "시간 초과 → 파밍 모드")
	_equal(Game.stage, 4, "직전 스테이지로 돌아간다")
	_equal(Game.highest_stage, 5, "최고 스테이지는 유지")
	_close(Game.boss_time_left, 0.0, "타이머 정지")
	_equal(Game.is_monster_alive(), false, "보스가 사라진다")
	_advance(0.5)
	_equal(Game.is_monster_alive(), true, "일반 몬스터가 다시 나온다")
	_close(Game.monster_max_hp, Balance.monster_hp(4), "4스테이지 몬스터 체력")

	# 파밍 중에는 10마리를 잡아도 진행하지 않는다
	var gold_before := Game.gold
	for i in 10:
		Game._damage_monster(Game.monster_max_hp)
		_advance(1.0)
	_equal(Game.stage, 4, "파밍 중에는 스테이지 유지")
	_equal(Game.kills, 0, "처치 수는 10에서 다시 0")
	_close(Game.gold, gold_before + 10.0 * Balance.kill_gold(Balance.monster_hp(4)), "파밍 골드")

	# 보스 도전: 지금 몬스터를 잡은 뒤 보스가 나온다. 다시 누르면 취소
	Game._damage_monster(1.0)
	Game.challenge_boss()
	_equal(Game.boss_queued, true, "도전 예약")
	_equal(Game.farming, true, "아직 파밍 중")
	_equal(Game.stage, 4, "아직 4스테이지")
	_close(Game.monster_hp, Balance.monster_hp(4) - 1.0, "지금 몬스터의 피해는 그대로")
	Game.challenge_boss()
	_equal(Game.boss_queued, false, "다시 누르면 취소")
	Game.challenge_boss()
	Game._damage_monster(Game.monster_max_hp)
	_equal(Game.farming, false, "잡으면 파밍 종료")
	_equal(Game.boss_queued, false, "예약 해제")
	_equal(Game.stage, 5, "5스테이지로")
	_equal(Game.is_monster_alive(), false, "재등장 대기")
	_advance(0.5)
	_equal(Game.is_monster_alive(), true, "보스 등장")
	_close(Game.monster_max_hp, Balance.boss_hp(5), "보스 체력")
	_close(Game.boss_time_left, 30.0, "타이머 30초")
	Game.challenge_boss()
	_equal(Game.stage, 5, "파밍 중이 아니면 아무 일도 없다")

	# 다시 실패한 뒤, 재등장을 기다리는 중에 누르면 잃을 피해가 없으니 바로 간다
	_advance(30.25)
	_equal(Game.farming, true, "다시 파밍")
	_advance(0.5)
	Game._damage_monster(Game.monster_max_hp)
	_equal(Game.is_monster_alive(), false, "재등장 대기 중")
	Game.challenge_boss()
	_equal(Game.farming, false, "바로 파밍 종료")
	_equal(Game.stage, 5, "바로 5스테이지")
	_advance(0.5)
	_close(Game.monster_max_hp, Balance.boss_hp(5), "보스가 나온다")

	# 보스를 잡으면 골드 = 체력 ÷ 15, 다음 스테이지
	gold_before = Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, gold_before + Balance.kill_gold(Balance.boss_hp(5)), "보스 골드")
	_close(Game.boss_time_left, 0.0, "타이머 정지")
	_advance(0.5)
	_equal(Game.stage, 6, "보스 처치 후 6스테이지")
	_equal(Game.is_boss_stage(), false, "일반 스테이지")
	_close(Game.monster_max_hp, Balance.monster_hp(6), "6스테이지 몬스터")


func _test_mage_versus_boss() -> void:
	_fresh_run()
	var M: int = Balance.Companion.MAGE
	Party.companion_levels[M] = 1
	_close(Party.party_dps(false), 110.0, "마법사 일반 DPS")
	_close(Party.party_dps(true), 330.0, "마법사 보스 DPS ×3")
	_close(Party.companion_dps(M, true), 330.0, "연출용 DPS도 ×3")

	Game.stage = 10
	Game.highest_stage = 10
	Game._spawn_monster()
	var before := Game.monster_hp
	_advance(0.25)
	_close(Game.monster_hp, before - 330.0 * 0.25, "보스에게는 ×3 피해가 들어간다")


## 5스테이지 보스에 실패해 4스테이지를 파밍하는 상태로 만든다
func _farm_after_boss_fail() -> void:
	_fresh_run()
	Game.stage = 5
	Game.highest_stage = 5
	Game._spawn_monster()
	_advance(31.0)
	_equal(Game.farming, true, "보스 실패 → 파밍")


## 자동 재도전: 잡을 수 있을 것 같을 때만, 실패 직후 잠깐 쉬고, 취소하면 미루고, 끄면 안 한다.
## 예약은 몬스터가 죽는 순간 보스전으로 바뀌므로 대부분 "파밍이 끝났는가"로 확인한다
func _test_auto_retry() -> void:
	_farm_after_boss_fail()
	_equal(Game.auto_retry, true, "기본은 켜짐")
	_advance(200.0)
	_equal(Game.boss_queued, false, "DPS가 없으면 아무리 기다려도 도전하지 않는다")
	_equal(Game.farming, true, "계속 파밍")

	Party.companion_levels[Balance.Companion.WARRIOR] = 10  # 초당 60: 5스테이지 보스(체력 187)를 3초에 잡는다
	_equal(Game.boss_looks_beatable(), true, "잡을 수 있어 보인다")
	_advance(Balance.MAX_DELTA)
	_equal(Game.boss_queued, true, "잡을 수 있으면 스스로 예약")
	Game.challenge_boss()  # 손으로 취소
	_equal(Game.boss_queued, false, "취소")
	_advance(Balance.AUTO_RETRY_INTERVAL * 0.5)
	_equal(Game.farming and not Game.boss_queued, true, "취소하면 한동안 미룬다")
	_advance(Balance.AUTO_RETRY_INTERVAL * 0.5 + Balance.AUTO_RETRY_REST + 5.0)
	_equal(Game.farming, false, "미룬 뒤 다시 도전해 파밍을 끝낸다")
	_equal(Game.stage >= 5, true, "보스 스테이지 이상으로 진행")

	# 실패 직후에는 최소 파밍 시간 동안 쉰다
	Party.companion_levels[Balance.Companion.WARRIOR] = 0
	Game.stage = 5
	Game._spawn_monster()
	_advance(31.0)
	_equal(Game.farming, true, "다시 실패")
	Party.companion_levels[Balance.Companion.WARRIOR] = 10
	_advance(Balance.AUTO_RETRY_REST * 0.5)
	_equal(Game.farming and not Game.boss_queued, true, "실패 직후에는 쉰다")
	_advance(Balance.AUTO_RETRY_REST * 0.5 + 5.0)
	_equal(Game.farming, false, "쉰 뒤에 도전한다")

	# 끄면 도전하지 않는다
	Party.companion_levels[Balance.Companion.WARRIOR] = 0
	Game.stage = 5
	Game._spawn_monster()
	_advance(31.0)
	_equal(Game.farming, true, "또 실패")
	Game.set_auto_retry(false)
	Party.companion_levels[Balance.Companion.WARRIOR] = 10
	_advance(Balance.AUTO_RETRY_INTERVAL + Balance.AUTO_RETRY_REST + 5.0)
	_equal(Game.farming and not Game.boss_queued, true, "끄면 도전하지 않는다")
	Game.set_auto_retry(true)
	_fresh_run()


## 탭하는 중이면 예상과 무관하게 한참마다 한 번 더 해 본다
func _test_auto_retry_by_tapping() -> void:
	_farm_after_boss_fail()
	_equal(Game.boss_looks_beatable(), false, "클릭 피해 1로는 잡을 수 없어 보인다")
	var seconds := 0.0
	while seconds < Balance.AUTO_RETRY_INTERVAL * 0.9:
		Game.tap_attack()
		Game._process(Balance.MAX_DELTA)
		seconds += Balance.MAX_DELTA
	_equal(Game.tap_rate > 0.0, true, "탭 빈도가 잡힌다")
	_equal(Game.farming and not Game.boss_queued, true, "간격 전에는 도전하지 않는다")
	while seconds < Balance.AUTO_RETRY_INTERVAL + 5.0:
		Game.tap_attack()
		Game._process(Balance.MAX_DELTA)
		seconds += Balance.MAX_DELTA
	_equal(Game.boss_queued or not Game.farming, true, "탭하는 중이면 간격마다 도전")
	_fresh_run()
