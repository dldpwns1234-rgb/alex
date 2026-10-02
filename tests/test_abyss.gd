extends "res://tests/test_case.gd"
## 심연 (GDD 7.13절): 공식(체력·저주·축복·보상·각인), 끝이 없는 체력, 해금과 하루 원정, 입장·층·두목·축복 고르기, 저주 효과, 실패·회귀, 저장

var _cleared: Array = []
var _failed: Array[int] = []


func run() -> void:
	_test_balance()
	_test_endless()
	_test_unlock_and_runs()
	_test_climb()
	_test_curses()
	_test_fail_and_reset()
	_test_marks()
	_test_save()
	Transcend.count = 0
	_fresh_run()


func _on_cleared(floor: int, stones: float, stars: float) -> void:
	_cleared.append([floor, stones, stars])


func _on_failed(floor: int) -> void:
	_failed.append(floor)


func _open() -> void:
	_fresh_run()
	Transcend.count = 1
	_cleared.clear()
	_failed.clear()


## 한 층의 몬스터를 하나씩 잡는다 (넘친 피해로 연쇄하지 않게 체력만큼)
func _clear_current_floor() -> void:
	for i in Abyss.kills_needed():
		Game._damage_monster(Game.monster_hp)
		_advance(Game.respawn_delay() + 0.01)


func _test_balance() -> void:
	_close(Balance.abyss_monster_hp(100.0, 0, 0, false, false), 50.0, "0층은 기준 피해량 0.5초 몫")
	_close(Balance.abyss_monster_hp(100.0, 2, 0, false, false), 50.0 * 1.21, "층마다 ×1.1")
	_close(Balance.abyss_monster_hp(100.0, 12, 2, false, false), Balance.abyss_monster_hp(100.0, 10, 0, false, false), "심연의 힘 1레벨 = 1층")
	_close(Balance.abyss_monster_hp(100.0, 3, 0, true, true), Balance.abyss_monster_hp(100.0, 3, 0, false, false) * 1.5 * 12.0, "껍질 ×1.5, 두목 ×12")
	_equal(Balance.abyss_curse_count(1), 1, "1층 저주 1개")
	_equal(Balance.abyss_curse_count(20), 2, "20층부터 2개")
	_equal(Balance.abyss_curse_count(50), 3, "50층부터 3개")
	_equal(Balance.abyss_is_boss_floor(10), true, "10층은 두목")
	_equal(Balance.abyss_is_boss_floor(11), false, "11층은 아니다")
	var none: Array[int] = []
	_equal(Balance.abyss_floor_curses("2026-10-02", 7, none), Balance.abyss_floor_curses("2026-10-02", 7, none), "같은 날 같은 층은 같은 저주")
	var differs := false
	for f in range(1, 30):
		if Balance.abyss_floor_curses("2026-10-02", f, none) != Balance.abyss_floor_curses("2026-10-03", f, none):
			differs = true
	_equal(differs, true, "날이 바뀌면 저주 순서가 바뀐다")
	var three := Balance.abyss_floor_curses("2026-10-02", 60, none)
	_equal(three.size(), 3, "60층 저주 3개")
	var removed: Array[int] = [three[0]]
	var left := Balance.abyss_floor_curses("2026-10-02", 60, removed)
	_equal(left.size(), 2, "정화한 저주는 빠진다 (다른 것으로 채우지 않는다)")
	_equal(left.has(three[0]), false, "지운 저주가 없다")
	var offers := Balance.abyss_blessing_offers("2026-10-02", 10)
	_equal(offers.size(), 3, "축복 셋")
	_equal(offers[0] != offers[1] and offers[1] != offers[2] and offers[0] != offers[2], true, "서로 다른 축복")
	_close(Balance.abyss_time_limit(0, 0, false), 60.0, "제한 시간 60초")
	_close(Balance.abyss_time_limit(2, 1, true), (60.0 + 6.0 + 15.0) * 2.0 / 3.0, "시간 각인·유예·조여드는 시간")
	_close(Balance.abyss_floor_stones(1, 0.0, 0), 1.0, "1층 심연석 1")
	_close(Balance.abyss_floor_stones(30, 2.0, 0), floor(4.0 * 1.5), "30층·저주 무게 2")
	_close(Balance.abyss_floor_stones(30, 2.0, 5), floor(4.0 * 1.5 * 2.0), "수확 5레벨 ×2")
	_close(Balance.abyss_floor_stars(9), 0.0, "9층 파편 없음")
	_close(Balance.abyss_floor_stars(10), 1.0, "10층 파편 1")
	_close(Balance.abyss_floor_stars(100), 10.0, "100층 파편 10")
	_close(Balance.mark_cost(Balance.Mark.POWER, 0), 20.0, "힘 첫 레벨 20")
	_close(Balance.mark_cost(Balance.Mark.TIME, 2), 90.0, "시간 3레벨 90")
	_equal(Balance.abyss_visual_stage(41) % 1000 != 0, true, "그림이 마왕 스테이지에 걸리지 않는다")


## 숫자 한계 안에서 끝이 없다: 아주 깊은 층도, 상한에 닿은 피해량도 유한하다
func _test_endless() -> void:
	var deep := Balance.abyss_monster_hp(1e20, 100000, 99970, false, true)
	_equal(is_finite(deep) and deep > 1e20, true, "10만 층도 유한하고 벽이 남는다")
	var capped := Balance.abyss_monster_hp(Balance.MAX_NUMBER, 40, 0, true, true)
	_equal(is_finite(capped), true, "상한 피해량의 두목도 유한")
	_equal(capped > Balance.MAX_NUMBER, true, "상한 피해량으로도 한 방은 아니다")
	_equal(is_finite(Balance.mark_cost(Balance.Mark.POWER, 100000)), true, "각인 비용도 유한")


func _test_unlock_and_runs() -> void:
	_fresh_run()
	Transcend.count = 0
	_equal(Abyss.is_unlocked(), false, "첫 초월 전에는 잠김")
	_equal(Abyss.enter(), false, "잠겨 있으면 못 들어간다")
	_open()
	_equal(Abyss.is_unlocked(), true, "첫 초월 뒤 열림")
	_equal(Abyss.runs, Balance.ABYSS_RUNS_PER_DAY, "하루 원정 2회")
	Abyss.runs = 0
	_equal(Abyss.can_enter(), false, "원정이 없으면 못 들어간다")
	Abyss.today_best = 7
	Abyss.run_date = "2999-01-01"  # 시계를 앞으로 돌려 채운 뒤 되돌린 상태
	Abyss.refill_if_new_day()
	_equal(Abyss.runs, 0, "날짜를 되돌려도 차지 않는다")
	Abyss.run_date = "2000-01-01"
	Abyss.refill_if_new_day()
	_equal(Abyss.runs, Balance.ABYSS_RUNS_PER_DAY, "날짜가 앞으로 가면 찬다")
	_equal(Abyss.today_best, 0, "오늘의 최고는 새 날에 0")
	Tower.best_floor = 0
	Achievements.raise(Balance.Stat.STAGE, Balance.TOWER_UNLOCK_STAGE)
	Game.stage = 21
	Game.highest_stage = 21
	Game._spawn_monster()
	Tower.enter()
	_equal(Abyss.can_enter(), false, "탑 안에서는 못 들어간다")
	Tower.leave()


func _test_climb() -> void:
	_open()
	Abyss.floor_cleared.connect(_on_cleared)
	Game.stage = 21
	Game.highest_stage = 21
	Game._spawn_monster()
	var main_hp := Game.monster_max_hp
	var stars := Transcend.stars
	var expected_base := Abyss.measure_damage()
	_equal(Abyss.enter(), true, "입장")
	_equal(Abyss.runs, Balance.ABYSS_RUNS_PER_DAY - 1, "원정 하나 소모")
	_equal(Game.in_tower and Game.dungeon == Abyss, true, "심연 안")
	_equal(Tower.can_enter(), false, "심연 안에서는 탑에 못 들어간다")
	_equal(Abyss.floor, 1, "1층부터")
	_equal(Abyss.seed_date, Time.get_date_string_from_system(), "오늘의 시드")
	_close(Abyss.base_damage, expected_base, "기준 피해량은 들어갈 때 잰 값")
	_close(Game.monster_max_hp, Abyss.monster_hp(), "심연 몬스터가 나온다")
	_equal(Abyss.curses.size(), 1, "1층 저주 하나")
	_clear_current_floor()
	_equal(_cleared.size(), 1, "1층 돌파")
	_equal(Abyss.floor, 2, "다음 층")
	_equal(Abyss.best_floor, 1, "최고 깊이 1")
	_equal(Abyss.today_best, 1, "오늘의 최고 1")
	_equal(Abyss.stones >= 1.0, true, "심연석을 받았다")
	while Abyss.floor < 10:
		_clear_current_floor()
	_equal(Abyss.kills_needed(), 1, "10층은 두목 하나")
	_equal(Abyss.is_boss_floor(), true, "두목 층")
	_clear_current_floor()
	_close(Transcend.stars, stars + 1.0, "처음 닿은 10층: 별의 파편 +1")
	_equal(Abyss.offers.size(), 3, "축복 셋이 뜬다")
	_equal(Abyss.paused(), true, "고르는 동안 멈춘다")
	var before := Abyss.time_left
	_advance(5.0)
	_close(Abyss.time_left, before, "고르는 동안 시간이 흐르지 않는다")
	var pick := 0
	for i in Abyss.offers.size():
		if int(Abyss.offers[i]["type"]) == Balance.Blessing.FURY:
			pick = i
	var type := int(Abyss.offers[pick]["type"])
	var click := Party.click_damage()
	_equal(Abyss.choose_blessing(pick), true, "축복을 골랐다")
	_equal(Abyss.paused(), false, "다시 흐른다")
	if type == Balance.Blessing.FURY:
		_close(Party.click_damage(), click * Balance.ABYSS_FURY_MULTIPLIER, "분노: 클릭 ×1.5")
	_equal(Abyss.floor, 11, "11층")
	# 이미 닿은 깊이를 다시 오르면 파편은 없다 (심연석은 받는다)
	Abyss.leave()
	_equal(Game.in_tower, false, "나왔다")
	_close(Game.monster_max_hp, main_hp, "본편 몬스터")
	_equal(Game.stage, 21, "본편 스테이지 그대로")
	Abyss.runs = 1
	Abyss.enter()
	_cleared.clear()
	while Abyss.floor < 11:
		_clear_current_floor()
		if Abyss.paused():
			Abyss.choose_blessing(0)
	_equal(_cleared[9][2], 0.0, "다시 닿은 10층은 파편 없음")
	_equal(float(_cleared[9][1]) > 0.0, true, "심연석은 받는다")
	Abyss.leave()
	Abyss.floor_cleared.disconnect(_on_cleared)


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
