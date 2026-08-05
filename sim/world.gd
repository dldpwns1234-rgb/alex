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
## 마을 상태가 바뀌었다. UI가 다시 그릴 신호다.
signal village_changed()

var calendar := SimCalendar.new()
var village: SimVillage


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
func tick() -> void:
	var previous_season := calendar.season()
	var previous_year := calendar.year()

	calendar.advance_day()

	# 앞으로 여기에 생산 · 소비가 순서대로 붙는다.
	var completed := village.advance_construction()
	var newly_unlocked := village.refresh_slot_unlocks(calendar.year())

	day_advanced.emit(calendar.elapsed_days)

	for building in completed:
		building_completed.emit(building)
	if newly_unlocked > 0:
		slots_unlocked.emit(village.unlocked_slot_count)
	if not completed.is_empty() or newly_unlocked > 0:
		village_changed.emit()

	if calendar.season() != previous_season:
		season_changed.emit(calendar.season())
	if calendar.year() != previous_year:
		year_changed.emit(calendar.year())
