class_name SimAssignWorkersCommand
extends SimCommand

## 건물에 배정된 가구 수를 바꾼다 (GDD §4.6 — 모든 건물 화면의 공통 컨트롤).
##
## 늘릴 때는 **유휴 가구에서만** 데려온다. 다른 건물에서 자동으로 빼오지 않는다.
## 자동으로 빼주면 플레이어는 무엇을 포기했는지 모르고 넘어간다.
## 어디를 비울지 직접 고르게 만드는 것이 §4.4의 2번(노동력 배분)의 핵심이다.

const ERR_NO_BUILDING := "no_building"
const ERR_NOT_COMPLETE := "not_complete"
const ERR_NO_WORKER_SLOTS := "no_worker_slots"

var slot_index: int
var desired_workers: int


func _init(target_slot: int, workers: int) -> void:
	slot_index = target_slot
	desired_workers = workers


func execute(world: SimWorld) -> String:
	var village := world.village
	var building := village.building_at(slot_index)

	if building == null:
		return ERR_NO_BUILDING
	if not building.is_complete():
		return ERR_NOT_COMPLETE

	var capacity := village.worker_capacity(slot_index)
	if capacity <= 0:
		return ERR_NO_WORKER_SLOTS

	village.labor.set_assignment(slot_index, desired_workers, capacity)

	# 인력이 0이 되면 다음 틱을 기다리지 않고 바로 경고를 띄운다.
	if village.labor.assigned_to(slot_index) <= 0:
		building.halt_reason = SimBuilding.HALT_NO_WORKERS
	elif building.halt_reason == SimBuilding.HALT_NO_WORKERS:
		building.halt_reason = SimBuilding.HALT_NONE

	return OK
