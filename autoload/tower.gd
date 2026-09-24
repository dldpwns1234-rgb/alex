extends Node
## 시련의 탑 (GDD 7.10절): 별도 모드. 입장권(하루 3장)을 내고 최고층 다음 층부터 60초 안에 10마리씩 잡아 오른다.
## 층을 처음 돌파하면 강화석(층 수만큼)과 10층마다 운명의 실을 받는다. 실패하거나 나가면 본편으로 돌아온다 (입장권은 소모).
## 전투는 Game이 그대로 돌리고(탑 안이면 Tower.monster_hp()의 몬스터), 제한 시간은 여기서 잰다. 회귀·환생하면 탑에서 나온다.
## 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal tower_changed()
signal timer_changed(seconds_left: float)
signal floor_cleared(floor: int, stones: float, threads: float)
signal failed(floor: int)

const REFILL_CHECK_INTERVAL: float = 60.0  # 초. 열어 둔 채 날이 바뀌어도 입장권이 차도록 이만큼마다 날짜를 본다

var best_floor: int = 0
var tickets: int = 0
var ticket_date: String = ""   # 입장권을 채운 날짜 (기기 시간). 날이 바뀌면 다시 채운다
var floor: int = 0             # 도전 중인 층. 탑 밖에서는 0
var time_left: float = 0.0
var _check_left: float = REFILL_CHECK_INTERVAL


func _ready() -> void:
	reset()
	Prestige.prestiged.connect(_on_run_reset)
	Rebirth.reborn.connect(_on_run_reset)


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = REFILL_CHECK_INTERVAL
		refill_if_new_day()


## 데이터 초기화에서만 부른다
func reset() -> void:
	best_floor = 0
	floor = 0
	time_left = 0.0
	_refill()
	tower_changed.emit()


func to_dict() -> Dictionary:
	return {"best_floor": best_floor, "tickets": tickets, "ticket_date": ticket_date}


## 없는 필드는 기본값으로. 불러오면 탑 밖이고, 날이 바뀌었으면 입장권을 채운다
func from_dict(data: Dictionary) -> void:
	reset()
	best_floor = maxi(int(data.get("best_floor", 0)), 0)
	tickets = clampi(int(data.get("tickets", Balance.TOWER_TICKETS_PER_DAY)), 0, Balance.TOWER_TICKETS_PER_DAY)
	ticket_date = str(data.get("ticket_date", ticket_date))
	refill_if_new_day()
	tower_changed.emit()


func refill_if_new_day() -> void:
	if Time.get_date_string_from_system() != ticket_date:
		_refill()
		tower_changed.emit()


func _refill() -> void:
	tickets = Balance.TOWER_TICKETS_PER_DAY
	ticket_date = Time.get_date_string_from_system()


## 역대 최고 스테이지 100부터 연다
func is_unlocked() -> bool:
	return Achievements.value(Balance.Stat.STAGE) >= Balance.TOWER_UNLOCK_STAGE


## 입장권이 있고 탑 밖이며 보스와 싸우는 중이 아닐 때
func can_enter() -> bool:
	if not is_unlocked() or tickets <= 0 or Game.in_tower:
		return false
	return not (Game.is_boss_stage() and Game.is_monster_alive())


## 입장권 한 장을 쓰고 최고층 다음 층부터 시작한다
func enter() -> bool:
	refill_if_new_day()
	if not can_enter():
		return false
	tickets -= 1
	floor = best_floor + 1
	time_left = Balance.TOWER_TIME_LIMIT
	Game.enter_tower()
	tower_changed.emit()
	timer_changed.emit(time_left)
	Save.save_game()
	return true


## 본편으로 돌아온다. 돌파한 층은 남고 입장권은 돌려주지 않는다
func leave() -> void:
	if floor <= 0:
		return
	floor = 0
	time_left = 0.0
	if Game.in_tower:
		Game.exit_tower()  # 회귀·환생은 Game.reset()이 먼저 탑을 빠져나온 뒤라 층만 지운다
	tower_changed.emit()
	Save.save_game()


## 제한 시간. Game이 탑 안에서 매 프레임 부른다
func tick(dt: float) -> void:
	time_left -= dt
	timer_changed.emit(maxf(time_left, 0.0))
	if time_left <= 0.0:
		fail()


func fail() -> void:
	var lost := floor
	leave()
	failed.emit(lost)


## 10마리를 다 잡았다 (Game이 부른다): 첫 돌파면 보상을 주고 다음 층으로. 제한 시간은 층마다 새로 잰다
func clear_floor() -> void:
	var stones := Balance.tower_stones(floor) if floor > best_floor else 0.0
	var threads := Balance.tower_threads(floor) if floor > best_floor else 0.0
	best_floor = maxi(best_floor, floor)
	Equipment.add_stones(stones)
	Rebirth.add_threads(threads)
	floor_cleared.emit(floor, stones, threads)
	floor += 1
	time_left = Balance.TOWER_TIME_LIMIT
	tower_changed.emit()
	timer_changed.emit(time_left)


func monster_hp() -> float:
	return Balance.tower_monster_hp(floor)


func _on_run_reset(_reward: float) -> void:
	leave()
