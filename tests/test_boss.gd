extends "res://tests/test_case.gd"
## 보스 스테이지: 타이머, 실패 시 파밍, 보스 도전, 마법사 ×3


func run() -> void:
	_test_boss_fight()
	_test_mage_versus_boss()


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

	# 보스 도전: 지금 몬스터를 버리고 보스가 바로 나온다
	Game.challenge_boss()
	_equal(Game.farming, false, "파밍 종료")
	_equal(Game.stage, 5, "다시 5스테이지")
	_equal(Game.is_monster_alive(), true, "보스가 바로 나온다")
	_close(Game.monster_max_hp, Balance.boss_hp(5), "보스 체력")
	_close(Game.boss_time_left, 30.0, "타이머 다시 30초")
	Game.challenge_boss()
	_equal(Game.stage, 5, "파밍 중이 아니면 아무 일도 없다")

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
