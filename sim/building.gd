class_name SimBuilding
extends RefCounted

## 슬롯에 실제로 놓인 건물 한 채.
##
## SimBuildingType이 "화덕이란 무엇인가"라면, 이쪽은 "3번 슬롯의 저 화덕"이다.

enum State {
	## 건설 중. 자원은 이미 지불되었고 날짜만 남았다.
	UNDER_CONSTRUCTION,
	## 완공. M2부터 여기서 생산이 일어난다.
	ACTIVE,
}

var type_id: String = ""
var slot_index: int = -1
var state: State = State.UNDER_CONSTRUCTION
## 완공까지 남은 일수. 0이면 다음 틱에 완공된다.
var days_remaining: int = 0
## 진행률 표시에 쓴다.
var total_build_days: int = 0


static func start_construction(type: SimBuildingType, slot: int) -> SimBuilding:
	var building := SimBuilding.new()
	building.type_id = type.id
	building.slot_index = slot
	building.total_build_days = type.build_days
	building.days_remaining = type.build_days
	building.state = State.ACTIVE if type.build_days <= 0 else State.UNDER_CONSTRUCTION
	return building


func is_complete() -> bool:
	return state == State.ACTIVE


## 하루 진행. 완공된 순간에만 true를 반환한다.
func advance_construction() -> bool:
	if is_complete():
		return false

	days_remaining -= 1
	if days_remaining > 0:
		return false

	days_remaining = 0
	state = State.ACTIVE
	return true


## 0.0 ~ 1.0. 건설 진행률.
func construction_progress() -> float:
	if total_build_days <= 0:
		return 1.0
	return float(total_build_days - days_remaining) / float(total_build_days)
