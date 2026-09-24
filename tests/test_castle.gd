extends "res://tests/test_case.gd"
## 마왕성 (GDD 7.8절): 마왕 스테이지와 체력·제한 시간, 마왕 처치 시그널과 통계·업적, 무한 모드로 이어짐, 자동 재도전의 마왕 판단

var _defeats: int = 0


func run() -> void:
	_test_balance()
	_test_defeat()
	_test_auto_retry()
	_fresh_run()


func _test_balance() -> void:
	_equal(Balance.is_castle_stage(599), false, "599는 마왕성 밖")
	_equal(Balance.is_castle_stage(600), true, "600부터 마왕성")
	_equal(Balance.is_demon_king_stage(1000), true, "1000은 마왕")
	_equal(Balance.is_demon_king_stage(3000), true, "3000도 마왕")
	_equal(Balance.is_demon_king_stage(995), false, "995는 보통 보스")
	_equal(Balance.is_demon_king_stage(0), false, "0은 아니다")
	_close(Balance.enemy_hp(1000), Balance.boss_hp(1000) * 3.0, "마왕 체력은 보스의 3배")
	_close(Balance.enemy_hp(995), Balance.boss_hp(995), "보통 보스 체력")
	_close(Balance.boss_time_limit(0, 1000), Balance.BOSS_TIME_LIMIT + 30.0, "마왕전 제한 시간 +30초")
	_close(Balance.boss_time_limit(2, 995), Balance.BOSS_TIME_LIMIT + 6.0, "보통 보스는 시간의 모래만")
	_close(Balance.boss_time_limit(2), Balance.BOSS_TIME_LIMIT + 6.0, "스테이지를 안 주면 보통 보스")


func _on_defeated() -> void:
	_defeats += 1


func _test_defeat() -> void:
	_fresh_run()
	_defeats = 0
	Game.demon_king_defeated.connect(_on_defeated)
	Game.stage = 1000
	Game.highest_stage = 1000
	Game._spawn_monster()
	_equal(Game.is_boss_stage(), true, "1000은 보스 스테이지")
	_close(Game.monster_max_hp, Balance.enemy_hp(1000), "마왕 체력으로 나온다")
	_close(Game.boss_time_left, Game.boss_limit(1000), "마왕전 제한 시간")
	_equal(Game.boss_time_left > Balance.BOSS_TIME_LIMIT, true, "보통 보스보다 길다")
	Game._damage_monster(Game.monster_max_hp)
	_equal(_defeats, 1, "마왕 처치 시그널")
	_equal(Game.stage, 1001, "무한 모드: 1001로 이어진다")
	_close(Achievements.value(Balance.Stat.DEMON_KING), 1.0, "마왕 처치 통계")
	var index := -1
	for i in Balance.ACHIEVEMENTS.size():
		if Balance.achievement_name(i) == "마왕 토벌":
			index = i
	_equal(index >= 0, true, "마왕 토벌 업적이 있다")
	_equal(Achievements.is_unlocked(index), true, "마왕을 잡으면 열린다")
	# 스테이지 업적 8개(1001 도달, 합 +18%)와 마왕 토벌(+5%)이 더해진다
	_close(Achievements.damage_multiplier(), 1.0 + 0.18 + 0.05, "스테이지 업적과 마왕 토벌이 더해진다")
	Game.stage = 1005
	Game._spawn_monster()
	Game._damage_monster(Game.monster_max_hp)
	_equal(_defeats, 1, "1005의 두목은 마왕이 아니다")
	Game.demon_king_defeated.disconnect(_on_defeated)


func _test_auto_retry() -> void:
	_fresh_run()
	Game.stage = 999
	Game.highest_stage = 1000
	Game.farming = true
	Party.hero_level = 1
	_equal(Game.boss_looks_beatable(), false, "약하면 마왕에 도전하지 않는다")
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	Promotions.ranks[Balance.Companion.WARRIOR] = 0
	# 마왕 체력을 제한 시간의 90% 안에 잡을 DPS가 필요하다. 공식으로 필요한 DPS를 만들어 넣는다
	var needed := Balance.enemy_hp(1000) / (Game.boss_limit(1000) * Balance.AUTO_RETRY_MARGIN)
	Game.tap_rate = needed / Party.click_damage() + 1.0
	_equal(Game.boss_looks_beatable(), true, "마왕 체력과 마왕전 시간으로 판단한다")
	Game.tap_rate = 0.0
