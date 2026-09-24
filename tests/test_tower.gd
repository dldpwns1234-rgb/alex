extends "res://tests/test_case.gd"
## 시련의 탑 (GDD 7.10절): 공식, 해금, 입장권과 날짜, 입장·층 돌파·보상·실패·나가기, 보스전 중 입장 불가, 자동 회귀 예외, 회귀하면 퇴장, 저장

var _cleared: Array = []
var _failed: Array[int] = []


func run() -> void:
	_test_balance()
	_test_unlock_and_tickets()
	await _test_climb()
	_test_fail_and_leave()
	_test_save()
	_fresh_run()


func _on_cleared(floor: int, stones: float, threads: float) -> void:
	_cleared.append([floor, stones, threads])


func _on_failed(floor: int) -> void:
	_failed.append(floor)


## 역대 100을 만들어 탑을 연다
func _open() -> void:
	_fresh_run()
	Achievements.raise(Balance.Stat.STAGE, Balance.TOWER_UNLOCK_STAGE)
	_cleared.clear()
	_failed.clear()


func _test_balance() -> void:
	_equal(Balance.tower_stage(1), 110, "1층은 스테이지 110")
	_equal(Balance.tower_stage(50), 600, "50층은 스테이지 600")
	_close(Balance.tower_monster_hp(3), Balance.monster_hp(130), "층 몬스터 체력")
	_close(Balance.tower_stones(7), 7.0, "7층 강화석 7")
	_close(Balance.tower_threads(9), 0.0, "9층은 실 없음")
	_close(Balance.tower_threads(10), 1.0, "10층 실 1")
	_close(Balance.tower_threads(30), 3.0, "30층 실 3")
	_close(Balance.tower_threads(25), 0.0, "25층은 실 없음")


func _test_unlock_and_tickets() -> void:
	_fresh_run()
	_equal(Tower.is_unlocked(), false, "역대 100 전에는 잠김")
	_equal(Tower.enter(), false, "잠겨 있으면 못 들어간다")
	_open()
	_equal(Tower.is_unlocked(), true, "역대 100부터")
	_equal(Tower.tickets, Balance.TOWER_TICKETS_PER_DAY, "입장권 3장")
	Tower.tickets = 0
	_equal(Tower.can_enter(), false, "입장권이 없으면 못 들어간다")
	Tower.ticket_date = "2000-01-01"
	Tower.refill_if_new_day()
	_equal(Tower.tickets, Balance.TOWER_TICKETS_PER_DAY, "날이 바뀌면 다시 채운다")
	_equal(Tower.ticket_date, Time.get_date_string_from_system(), "채운 날짜")
	Tower.tickets = 1
	Tower.refill_if_new_day()
	_equal(Tower.tickets, 1, "같은 날은 채우지 않는다")
	Game.stage = 5
	Game.highest_stage = 5
	Game._spawn_monster()
	_equal(Tower.can_enter(), false, "보스와 싸우는 중에는 못 들어간다")
	Game.monster_hp = 0.0
	_equal(Tower.can_enter(), true, "보스가 없으면 들어간다")


func _test_climb() -> void:
	_open()
	Tower.floor_cleared.connect(_on_cleared)
	Game.stage = 21  # 20은 보스 스테이지라 못 들어간다
	Game.highest_stage = 21
	Game._spawn_monster()
	var main_hp := Game.monster_max_hp
	Tower.best_floor = 9
	Party.hero_level = 5000  # 한 방
	_equal(Tower.enter(), true, "입장")
	_equal(Tower.tickets, Balance.TOWER_TICKETS_PER_DAY - 1, "입장권 한 장 소모")
	_equal(Game.in_tower, true, "탑 안")
	_equal(Tower.floor, 10, "최고층 다음 층부터")
	_close(Game.monster_max_hp, Balance.tower_monster_hp(10), "탑 몬스터가 나온다")
	_equal(Game.visual_stage(), Balance.tower_stage(10), "그림은 층에 해당하는 스테이지")
	_equal(Game.is_boss_stage(), false, "탑에는 보스가 없다")
	_close(Tower.time_left, Balance.TOWER_TIME_LIMIT, "제한 시간 60초")
	var gold := Game.gold
	var stones := Equipment.stones
	var threads := Rebirth.threads
	for i in Balance.MONSTERS_PER_STAGE:
		Game.tap_attack()
		_advance(Game.respawn_delay() + 0.01)
	_close(Game.gold, gold, "탑에서는 골드가 없다")
	_equal(_cleared, [[10, 10.0, 1.0]], "10층 돌파: 강화석 10, 실 1")
	_close(Equipment.stones, stones + 10.0, "강화석을 받았다")
	_close(Rebirth.threads, threads + 1.0, "실을 받았다")
	_equal(Tower.best_floor, 10, "최고층 10")
	_equal(Tower.floor, 11, "바로 다음 층")
	_equal(Tower.time_left > Balance.TOWER_TIME_LIMIT - 1.0, true, "제한 시간이 새로 시작 (바로 흐른다)")
	_close(Game.monster_max_hp, Balance.tower_monster_hp(11), "11층 몬스터")
	_equal(Game.stage, 21, "본편 스테이지는 그대로")
	Tower.leave()
	_equal(Game.in_tower, false, "나왔다")
	_equal(Tower.floor, 0, "층은 0")
	_close(Game.monster_max_hp, main_hp, "본편 몬스터가 다시 나온다")
	# 이미 돌파한 층을 다시 오르면 보상이 없다
	Tower.best_floor = 12
	Tower.enter()
	Tower.floor = 11
	Game._spawn_monster()
	_cleared.clear()
	for i in Balance.MONSTERS_PER_STAGE:
		Game.tap_attack()
		_advance(Game.respawn_delay() + 0.01)
	_equal(_cleared, [[11, 0.0, 0.0]], "다시 오른 층은 보상이 없다")
	Tower.leave()
	Tower.floor_cleared.disconnect(_on_cleared)
	await get_tree().process_frame


func _test_fail_and_leave() -> void:
	_open()
	Tower.failed.connect(_on_failed)
	Game.stage = 31
	Game.highest_stage = 31
	Game._spawn_monster()
	Party.hero_level = 1
	Tower.enter()
	_advance(Balance.TOWER_TIME_LIMIT - 1.0)
	_equal(Game.in_tower, true, "시간이 남았으면 탑 안")
	_advance(2.0)
	_equal(_failed, [1], "시간이 다 되면 실패")
	_equal(Game.in_tower, false, "본편으로 돌아온다")
	_equal(Game.stage, 31, "본편 스테이지 그대로")
	_close(Game.monster_max_hp, Balance.enemy_hp(31), "본편 몬스터")
	_equal(Tower.best_floor, 0, "돌파는 없다")
	Tower.failed.disconnect(_on_failed)
	# 자동 회귀는 탑 안에서 쉰다
	Rebirth.threads = 1.0
	Rebirth.buy(Balance.Fate.AUTO_PRESTIGE)
	Game.highest_stage = 150
	Tower.enter()
	var count := Prestige.prestige_count
	var left := Balance.AUTO_PRESTIGE_STALL + 2.0
	while left > 0.0:
		Automation._process(Balance.MAX_DELTA)
		left -= Balance.MAX_DELTA
	_equal(Prestige.prestige_count, count, "탑 안에서는 자동 회귀하지 않는다")
	_equal(Prestige.perform(), true, "탑 안에서 회귀")
	_equal(Game.in_tower, false, "회귀하면 탑에서 나온다")
	_equal(Tower.floor, 0, "층 0")


func _test_save() -> void:
	_open()
	Tower.best_floor = 7
	Tower.tickets = 1
	var data := Save.to_dict()
	_equal(data.has("tower"), true, "저장 데이터에 탑이 들어간다")
	Tower.enter()
	var saved := Save.to_dict()
	_equal(int(saved["game"]["kills"]), 0, "탑 안에서 저장해도 본편 처치 수는 0")
	_fresh_run()
	Save.from_dict(data)
	_equal(Tower.best_floor, 7, "최고층 복원")
	_equal(Tower.tickets, 1, "입장권 복원 (같은 날)")
	_equal(Game.in_tower, false, "불러오면 탑 밖")
	Save.from_dict({"save_version": 1})
	_equal(Tower.best_floor, 0, "옛 저장은 0층")
	_equal(Tower.tickets, Balance.TOWER_TICKETS_PER_DAY, "옛 저장은 입장권 가득")
	Save.from_dict({"save_version": 1, "tower": {"best_floor": -3, "tickets": 99, "ticket_date": "2000-01-01"}})
	_equal(Tower.best_floor, 0, "음수 층은 0")
	_equal(Tower.tickets, Balance.TOWER_TICKETS_PER_DAY, "옛 날짜면 다시 채운다")
