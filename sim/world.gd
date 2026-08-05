class_name SimWorld
extends RefCounted

## 시뮬레이션 최상위 상태.
##
## M1 기준으로 달력과 마을(자원 · 슬롯 · 건물)을 들고 있다.
## 이후 마일스톤에서 가구 · 생산 · 병력이 여기에 붙는다.
##
## 순수 로직 규칙 (ARCHITECTURE §2):
##   - Node를 상속하지 않는다. RefCounted와 signal까지만 엔진 기능을 쓴다
##   - 실시간(delta)을 모른다. 외부에서 tick()을 불러줄 뿐이다
##   - game 계층을 역참조하지 않는다

signal day_advanced(elapsed_days: int)
signal season_changed(season: SimCalendar.Season)
signal year_changed(year: int)
signal building_completed(building: SimBuilding)
signal slots_unlocked(total: int)
## 먹이거나 데우지 못한 날. 계속되면 가구가 떠난다.
## shortage는 "food" · "firewood" · "both" 중 하나다.
signal shortage_occurred(shortage: String, hardship: int)
## "family_arrived" 또는 "family_left" — 한글 문구는 game 계층의 몫이다.
signal population_changed(event: String, total_families: int)
## 마을 상태가 바뀌었다. UI가 다시 그릴 신호다.
signal village_changed()
## 게임이 끝났다. "victory" 또는 "defeat" — 한글 문구는 game 계층의 몫이다.
signal game_ended(outcome: String)

var calendar := SimCalendar.new()
var village: SimVillage

## "" · "victory" · "defeat". 한 번 정해지면 바뀌지 않는다.
var outcome: String = ""


static func create_default() -> SimWorld:
	var world := SimWorld.new()
	world.village = SimVillage.load_default()
	return world


## 플레이어 입력이 들어오는 유일한 문 (ARCHITECTURE §2 규칙 4).
## 성공하면 SimCommand.OK, 실패하면 오류 코드를 반환한다.
func execute(command: SimCommand) -> String:
	var error := command.execute(self)
	if error == SimCommand.OK:
		village_changed.emit()
	return error


## 하루 진행. 경영 시계의 1틱이다 (ARCHITECTURE §3.1).
##
## 호출자는 실시간 경과를 누적해 하루치가 찼을 때 이 함수를 부른다.
## 시뮬레이션 자체는 실시간을 알지 못한다.
## 하루의 순서. 이 순서 자체가 게임 규칙이다:
##
##   건설 → 생산 → 소비 → 인구 → 슬롯 해금
##
## 생산이 소비보다 먼저인 이유는 그날 거둔 것을 그날 먹을 수 있어야
## "지금 인력을 농장으로 돌리면 살 수 있나"라는 판단이 성립하기 때문이다.
func tick() -> void:
	var previous_season := calendar.season()
	var previous_year := calendar.year()

	if is_over():
		return

	calendar.advance_day()
	village.season = calendar.season()

	var completed := village.advance_construction()
	village.produce()
	var provided_for := village.consume()
	var population_event := village.update_population(provided_for)
	var newly_unlocked := village.refresh_slot_unlocks(calendar.year())

	day_advanced.emit(calendar.elapsed_days)

	for building in completed:
		building_completed.emit(building)
	if newly_unlocked > 0:
		slots_unlocked.emit(village.unlocked_slot_count)
	if not provided_for:
		shortage_occurred.emit(village.last_shortage, village.hardship)
	if population_event != "":
		population_changed.emit(population_event, village.labor.total())

	# 자원과 생산 상태는 매일 바뀐다. UI는 항상 다시 그린다.
	village_changed.emit()

	if calendar.season() != previous_season:
		season_changed.emit(calendar.season())
	if calendar.year() != previous_year:
		year_changed.emit(calendar.year())

	_check_outcome()


func is_over() -> bool:
	return outcome != ""


## 승패 판정 (ROADMAP M3).
##
## 패배가 먼저다. 마지막 가구가 떠난 날이 마침 승리 연차의 첫날이라면
## 그것은 이긴 것이 아니다.
func _check_outcome() -> void:
	if is_over():
		return

	if village.labor.total() <= 0:
		outcome = "defeat"
	elif calendar.year() > village.rules.years_to_survive:
		outcome = "victory"
	else:
		return

	game_ended.emit(outcome)
