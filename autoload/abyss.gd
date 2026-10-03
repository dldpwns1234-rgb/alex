extends "res://autoload/abyss/marks.gd"
## 심연 (GDD 7.13절): 첫 초월 뒤에 여는 끝없는 층. 하루 원정 2회, 원정은 늘 1층부터 60초 안에 10마리씩(10층마다 두목 1마리) 내려간다.
## 몬스터 체력은 들어갈 때 잰 플레이어 피해량에 비례하고 층마다 ×1.1이라 숫자 한계 안에서 끝이 없다. 층마다 오늘 날짜를 시드로 저주가 붙고,
## 10층마다 축복 셋 중 하나를 고른다. 층마다 심연석, 처음 닿은 10층마다 별의 파편. 심연석으로 심연 안에서만 듣는 각인을 산다.
## 실패하거나 나가면 본편으로 돌아온다. 전투는 Game이 별도 모드(in_tower, dungeon = Abyss)로 돌린다. 상태 변경은 이 오토로드의 함수로만 한다.

signal abyss_changed()                                     # 입장·퇴장, 남은 원정, 기록, 층
signal floor_cleared(floor: int, stones: float, stars: float)
signal failed(floor: int)                                  # 시간이 다 되어 원정이 끝났다

const REFILL_CHECK_INTERVAL: float = 60.0  # 초. 열어 둔 채 날이 바뀌어도 원정이 차도록 이만큼마다 날짜를 본다

var runs: int = 0              # 오늘 남은 원정
var run_date: String = ""      # 원정을 채운 날짜 (기기 시간). 날짜가 앞으로 갈 때만 다시 채운다
var best_floor: int = 0        # 개인 최고 깊이 (돌파한 층)
var today_best: int = 0        # 오늘의 최고 깊이. 원정을 채울 때 0으로
var _check_left: float = REFILL_CHECK_INTERVAL


func _ready() -> void:
	reset()
	Prestige.prestiged.connect(_on_run_reset)
	Game.run_started.connect(leave.unbind(1))  # 도전·별자리 시련 시작처럼 회귀 없이 새 판이 되어도 나온다 (버그 점검 2026-10-03)
	Rebirth.reborn.connect(_on_run_reset)
	Transcend.transcended.connect(_on_run_reset)


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = REFILL_CHECK_INTERVAL
		refill_if_new_day()


## 데이터 초기화에서만 부른다
func reset() -> void:
	_clear_run()
	best_floor = 0
	today_best = 0
	stones = 0.0
	marks.clear()
	marks.resize(Balance.MARKS.size())
	marks.fill(0)
	_refill()
	stones_changed.emit(stones)
	for i in marks.size():
		mark_changed.emit(i, 0)
	abyss_changed.emit()


func to_dict() -> Dictionary:
	return {"runs": runs, "run_date": run_date, "best_floor": best_floor, "today_best": today_best,
		"stones": stones, "marks": marks.duplicate()}


## 없는 필드는 기본값으로 (심연이 없던 옛 저장은 원정 2회, 기록 0). 불러오면 심연 밖이다
func from_dict(data: Dictionary) -> void:
	reset()
	runs = clampi(int(data.get("runs", Balance.ABYSS_RUNS_PER_DAY)), 0, Balance.ABYSS_RUNS_PER_DAY)
	run_date = str(data.get("run_date", run_date))
	best_floor = maxi(int(clampf(float(data.get("best_floor", 0)), 0.0, 1e9)), 0)
	today_best = clampi(int(clampf(float(data.get("today_best", 0)), 0.0, 1e9)), 0, best_floor)
	stones = clampf(float(data.get("stones", 0.0)), 0.0, Balance.MAX_NUMBER)
	var saved: Variant = data.get("marks", [])
	if saved is Array:
		for i in mini(saved.size(), marks.size()):
			marks[i] = int(clampf(float(saved[i]), 0.0, float(_cap(i))))
	refill_if_new_day()
	stones_changed.emit(stones)
	for i in marks.size():
		mark_changed.emit(i, marks[i])
	abyss_changed.emit()


## 날짜가 앞으로 갔을 때만 채운다 ("YYYY-MM-DD"는 문자열 순서가 곧 날짜 순서). 기기 날짜를 되돌려 원정을 더 얻지 못하게
func refill_if_new_day() -> void:
	if Time.get_date_string_from_system() > run_date:
		_refill()
		abyss_changed.emit()


func _refill() -> void:
	runs = Balance.ABYSS_RUNS_PER_DAY
	run_date = Time.get_date_string_from_system()
	today_best = 0


## 첫 초월 뒤에 연다 (방장 결정 2026-10-02)
func is_unlocked() -> bool:
	return Transcend.count >= 1


## 원정이 남았고 별도 모드 밖이며 보스와 싸우는 중이 아닐 때
func can_enter() -> bool:
	if not is_unlocked() or runs <= 0 or Game.in_tower:
		return false
	return not (Game.is_boss_stage() and Game.is_monster_alive())


## 원정 하나를 쓰고 1층부터. 기준 피해량은 본편에서 잰다
func enter() -> bool:
	refill_if_new_day()
	if not can_enter():
		return false
	runs -= 1
	_clear_run()
	active = true
	seed_date = Time.get_date_string_from_system()
	base_damage = measure_damage()
	floor = 1
	_begin_floor()  # 저주(단단한 껍질)가 첫 몬스터의 체력에 들도록 들어가기 전에
	Game.enter_tower(self)
	abyss_changed.emit()
	Save.save_game()
	return true


## 본편으로 돌아온다. 기록·심연석은 남고 원정은 돌려주지 않는다
func leave() -> void:
	if not active:
		return
	var inside := Game.in_tower and Game.dungeon == self
	_clear_run()
	if inside:
		Game.exit_tower()  # 회귀·환생·초월은 Game.reset()이 먼저 빠져나온 뒤라 원정만 지운다
	abyss_changed.emit()
	Save.save_game()


func fail() -> void:
	var lost := floor
	leave()
	failed.emit(lost)


## 층 돌파 (Game이 부른다): 심연석, 처음 닿은 10층마다 별의 파편, 기록. 두목 층이었으면 축복을 고르는 동안 멈춘다
func clear_floor() -> void:
	var got := Balance.abyss_floor_stones(floor, Balance.abyss_curse_weight(curses), level(Balance.Mark.HARVEST))
	var stars := Balance.abyss_floor_stars(floor) if floor > best_floor else 0.0
	best_floor = maxi(best_floor, floor)
	today_best = maxi(today_best, floor)
	stones = minf(stones + got, Balance.MAX_NUMBER)
	Transcend.add_stars(stars)
	stones_changed.emit(stones)
	floor_cleared.emit(floor, got, stars)
	var boss := Balance.abyss_is_boss_floor(floor)
	floor += 1
	base_damage = maxf(base_damage, measure_damage())
	if boss:
		_roll_offers()
	_begin_floor()
	abyss_changed.emit()


## 축복을 고른다 (축복 고르기 창이 부른다). 다음 층의 저주와 제한 시간을 다시 정한다
func choose_blessing(index: int) -> bool:
	if index < 0 or index >= offers.size():
		return false
	_apply_blessing(offers[index])
	offers.clear()
	_begin_floor()
	abyss_changed.emit()
	return true


## 이 층의 저주(오늘의 시드)와 사슬이 묶을 동료, 제한 시간
func _begin_floor() -> void:
	curses = Balance.abyss_floor_curses(seed_date, floor, removed)
	seal_target = _pick(_hired(), "seal") if curses.has(Balance.Curse.SEAL) else -1
	time_left = time_limit()
	floor_started.emit(floor)
	timer_changed.emit(time_left)


func _on_run_reset(_reward: float) -> void:
	leave()
