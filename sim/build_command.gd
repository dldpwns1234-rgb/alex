class_name SimBuildCommand
extends SimCommand

## 슬롯에 건물을 짓는다.
##
## 검사 순서가 곧 UI가 보여줄 거절 사유의 우선순위다.
## 자원 부족보다 슬롯 잠김이 먼저 걸린다 — 잠긴 슬롯 앞에서
## "목재가 부족합니다"라고 말하면 플레이어를 헤매게 만든다.

const ERR_SLOT_OUT_OF_RANGE := "slot_out_of_range"
const ERR_SLOT_LOCKED := "slot_locked"
const ERR_SLOT_OCCUPIED := "slot_occupied"
const ERR_UNKNOWN_TYPE := "unknown_type"
const ERR_TYPE_LOCKED := "type_locked"
const ERR_CANNOT_AFFORD := "cannot_afford"

var slot_index: int
var type_id: String


func _init(target_slot: int, building_type_id: String) -> void:
	slot_index = target_slot
	type_id = building_type_id


func execute(world: SimWorld) -> String:
	var village := world.village

	if slot_index < 0 or slot_index >= village.slot_count():
		return ERR_SLOT_OUT_OF_RANGE
	if not village.is_slot_unlocked(slot_index):
		return ERR_SLOT_LOCKED
	if not village.is_slot_empty(slot_index):
		return ERR_SLOT_OCCUPIED

	var type := village.catalog.get_type(type_id)
	if type == null:
		return ERR_UNKNOWN_TYPE
	if not village.is_type_unlocked(type_id):
		return ERR_TYPE_LOCKED
	if not village.resources.can_afford(type.cost):
		return ERR_CANNOT_AFFORD

	# 자원은 착공 시점에 전부 빠져나간다. 건설 중 취소·환불은 없다.
	# TODO(M8): 철거와 부분 환불.
	village.resources.spend(type.cost)
	village.buildings[slot_index] = SimBuilding.start_construction(type, slot_index)

	return OK
