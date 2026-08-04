class_name SimCalendar
extends RefCounted

## 게임 내 달력 — 날짜 · 계절 · 연차.
##
## 순수 로직이다. 렌더링도, 실시간(delta)도, 표시 문자열도 모르며
## 오직 "며칠이 지났는가"만 안다. (ARCHITECTURE §2, §3.1)
##
## 계절 이름 같은 표시용 문자열은 game 계층이 담당한다.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const DAYS_PER_SEASON := 30
const SEASONS_PER_YEAR := 4
const DAYS_PER_YEAR := DAYS_PER_SEASON * SEASONS_PER_YEAR

## 게임 시작 이후 경과한 일수. 0 = 1년차 봄 1일.
var elapsed_days: int = 0


## 하루 진행. 이것이 경영 시계의 유일한 진행 수단이다.
func advance_day() -> void:
	elapsed_days += 1


## 1부터 시작하는 연차.
func year() -> int:
	@warning_ignore("integer_division")
	return elapsed_days / DAYS_PER_YEAR + 1


func season() -> Season:
	@warning_ignore("integer_division")
	var seasons_elapsed := elapsed_days / DAYS_PER_SEASON
	return (seasons_elapsed % SEASONS_PER_YEAR) as Season


## 해당 계절에서 몇 번째 날인지. 1..DAYS_PER_SEASON
func day_of_season() -> int:
	return elapsed_days % DAYS_PER_SEASON + 1


## 해당 연도에서 몇 번째 날인지. 1..DAYS_PER_YEAR
func day_of_year() -> int:
	return elapsed_days % DAYS_PER_YEAR + 1


## 겨울은 이 게임의 보스전이다 (GDD §3.2).
## 생산 배율 · 소비량 · 습격 규모가 전부 이 판정에 걸린다.
func is_winter() -> bool:
	return season() == Season.WINTER
