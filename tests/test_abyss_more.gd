extends "res://tests/test_abyss.gd"
## 심연 (GDD 7.13절) 2부: 저주 효과, 실패·회귀, 각인(폭풍 베기 둘 포함), 저장. 도우미(_open 등)는 1부에 있다


func run() -> void:
	_test_curses()
	_test_fail_and_reset()
	_test_marks()
	_test_save()
	Transcend.count = 0
	_fresh_run()


func _test_curses() -> void:
	_open()
	Party.hero_level = 100
	Party.companion_levels[0] = 50
	Party.companion_levels[1] = 50
	Party.companion_changed.emit(0, 50)
	Game.stage = 21
	Game._spawn_monster()
	var dps := Party.party_dps(false)
	var respawn := Game.respawn_delay()
	var ratio := Party.companion_dps(0, false) / Party.companion_dps(1, false)
	Abyss.runs = 1
	Abyss.enter()
	Abyss.curses = [Balance.Curse.CLICK_ONLY]
	_close(Abyss.companion_scale(), 0.0, "고립: 동료가 싸우지 않는다")
	_equal(Abyss.silences(0), true, "고립: 연출도 쉰다")
	Abyss.curses = [Balance.Curse.SEAL]
	Abyss.seal_target = 1
	_equal(Party.companion_dps(1, false), 0.0, "사슬: 묶인 동료 0")
	_equal(Party.party_dps(false) < dps, true, "사슬: 파티 DPS가 준다")
	_equal(Abyss.silences(0), false, "다른 동료는 싸운다")
	Abyss.curses = [Balance.Curse.SLOW]
	_close(Game.respawn_delay(), respawn * 2.0, "느린 숨: 재등장 ×2")
	Abyss.curses = [Balance.Curse.SILENCE]
	_equal(Skills.is_sealed(), true, "침묵: 스킬 봉인")
	Abyss.curses = [Balance.Curse.NO_CRIT]
	_equal(Abyss.blocks_crit(), true, "무딘 칼날")
	Abyss.curses = [Balance.Curse.TOUGH]
	_close(Abyss.monster_hp(), Balance.abyss_monster_hp(Abyss.base_damage, 1, 0, true, false), "단단한 껍질")
	Abyss.curses = [Balance.Curse.SHORT]
	_close(Abyss.time_limit(), Balance.ABYSS_TIME_LIMIT * 2.0 / 3.0, "조여드는 시간")
	Abyss.bond[0] = 1
	Abyss.curses = []
	_close(Party.companion_dps(0, false) / Party.companion_dps(1, false), 3.0 * ratio, "유대: 그 동료 ×3")
	Abyss.leave()
	_equal(Skills.is_sealed(), false, "밖에서는 저주가 없다")
	_close(Game.respawn_delay(), respawn, "밖에서는 재등장 그대로")
	_close(Party.party_dps(false), dps, "밖에서는 동료 그대로")


func _test_fail_and_reset() -> void:
	_open()
	Abyss.failed.connect(_on_failed)
	Game.stage = 31
	Game.highest_stage = 31
	Game._spawn_monster()
	Abyss.enter()
	Abyss.base_damage = 1e30  # 잡을 수 없는 몬스터
	Game._spawn_monster()
	_advance(Abyss.time_left + 0.5)
	_equal(_failed, [1], "시간이 다 되면 원정 끝")
	_equal(Game.in_tower, false, "본편으로")
	_equal(Game.stage, 31, "본편 스테이지 그대로")
	_close(Game.monster_max_hp, Balance.enemy_hp(31), "본편 몬스터")
	Abyss.failed.disconnect(_on_failed)
	Abyss.enter()
	Game.highest_stage = 150
	_equal(Prestige.perform(), true, "심연 안에서 회귀")
	_equal(Game.in_tower, false, "회귀하면 나온다")
	_equal(Abyss.active, false, "원정 끝")
	_equal(Abyss.runs, 0, "원정 둘을 다 썼다")


func _test_marks() -> void:
	_open()
	_equal(Abyss.buy(Balance.Mark.POWER), false, "심연석이 없으면 못 산다")
	Abyss.stones = 100.0
	_equal(Abyss.buy(Balance.Mark.POWER), true, "힘 1레벨")
	_close(Abyss.stones, 80.0, "20 냈다")
	Abyss.marks[Balance.Mark.TIME] = Balance.mark_max_level(Balance.Mark.TIME)
	_equal(Abyss.can_buy(Balance.Mark.TIME), false, "최대 레벨")
	# 폭풍 베기 각인 둘: 본편에도 듣는다 (방장 제안 2026-10-02)
	var storm := Balance.Skill.STORM_SLASH
	var cry := Balance.Skill.BATTLE_CRY
	var base_cooldown := Skills.cooldown(storm)
	var base_duration := Skills.duration(storm)
	Abyss.marks[Balance.Mark.STORM_COOLDOWN] = 10
	Abyss.marks[Balance.Mark.STORM_DURATION] = 10
	_close(Skills.cooldown(storm), base_cooldown * 0.5, "폭풍의 날 10레벨: 쿨타임 절반")
	_close(Skills.duration(storm), base_duration + 50.0, "폭풍의 숨 10레벨: 지속 +50초")
	_close(Skills.cooldown(cry), base_cooldown, "다른 스킬은 그대로")
	_close(Skills.duration(cry), base_duration, "다른 스킬 지속도 그대로")
	Party.hero_level = 100
	Skills.clock_override = 5000.0
	Skills.activate(storm)
	Skills.clock_override = 5000.0 + base_duration + 1.0
	_equal(Skills.is_active(storm), true, "늘어난 지속 동안 계속 돈다")
	Skills.clock_override = -1.0
	Abyss.marks[Balance.Mark.STORM_COOLDOWN] = 0
	Abyss.marks[Balance.Mark.STORM_DURATION] = 0


func _test_save() -> void:
	_open()
	Abyss.best_floor = 42
	Abyss.today_best = 30
	Abyss.runs = 1
	Abyss.stones = 123.0
	Abyss.marks[Balance.Mark.POWER] = 5
	var data := Save.to_dict()
	_equal(data.has("abyss"), true, "저장에 심연이 들어간다")
	Game.stage = 21
	Game._spawn_monster()
	Abyss.enter()
	_fresh_run()
	Transcend.count = 1
	Save.from_dict(data)
	_equal(Abyss.best_floor, 42, "최고 깊이 복원")
	_equal(Abyss.today_best, 30, "오늘의 최고 복원 (같은 날)")
	_equal(Abyss.runs, 1, "원정 복원")
	_close(Abyss.stones, 123.0, "심연석 복원")
	_equal(Abyss.level(Balance.Mark.POWER), 5, "각인 복원")
	_equal(Abyss.active or Game.in_tower, false, "불러오면 심연 밖")
	Save.from_dict({"save_version": 1})
	_equal(Abyss.best_floor, 0, "옛 저장은 0층")
	_equal(Abyss.runs, Balance.ABYSS_RUNS_PER_DAY, "옛 저장은 원정 가득")
	Save.from_dict({"save_version": 1, "abyss": {"best_floor": -3, "runs": 99, "stones": INF, "marks": [-1, 99, 3], "run_date": "2000-01-01", "today_best": 9}})
	_equal(Abyss.best_floor, 0, "음수 층은 0")
	_equal(Abyss.runs, Balance.ABYSS_RUNS_PER_DAY, "옛 날짜면 다시 채운다")
	_equal(Abyss.today_best, 0, "옛 날짜의 오늘 최고는 0")
	_close(Abyss.stones, Balance.MAX_NUMBER, "무한대 심연석은 상한으로")
	_equal(Abyss.level(Balance.Mark.POWER), 0, "음수 각인은 0")
	_equal(Abyss.level(Balance.Mark.TIME), Balance.mark_max_level(Balance.Mark.TIME), "최대를 넘는 각인은 최대로")
	_equal(Abyss.level(Balance.Mark.HARVEST), 3, "각인 레벨 복원")
