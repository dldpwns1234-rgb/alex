class_name SimWorld
extends RefCounted

## 시뮬레이션 최상위 상태.
##
## M0에서는 달력만 들고 있다. 이후 마일스톤에서 자원 · 가구 · 건물 · 병력이
## 여기에 붙는다.
##
## 순수 로직 규칙 (ARCHITECTURE §2):
##   - Node를 상속하지 않는다. RefCounted와 signal까지만 엔진 기능을 쓴다
##   - 실시간(delta)을 모른다. 외부에서 tick()을 불러줄 뿐이다
##   - game 계층을 역참조하지 않는다

signal day_advanced(elapsed_days: int)
signal season_changed(season: SimCalendar.Season)
signal year_changed(year: int)

var calendar := SimCalendar.new()


## 하루 진행. 경영 시계의 1틱이다 (ARCHITECTURE §3.1).
##
## 호출자는 실시간 경과를 누적해 하루치가 찼을 때 이 함수를 부른다.
## 시뮬레이션 자체는 실시간을 알지 못한다.
func tick() -> void:
	var previous_season := calendar.season()
	var previous_year := calendar.year()

	calendar.advance_day()

	# 앞으로 여기에 생산 · 소비 · 건설 진행이 순서대로 붙는다.

	day_advanced.emit(calendar.elapsed_days)

	if calendar.season() != previous_season:
		season_changed.emit(calendar.season())
	if calendar.year() != previous_year:
		year_changed.emit(calendar.year())
