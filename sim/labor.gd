class_name SimLabor
extends RefCounted

## 노동력 배분 (GDD §4.4의 2번 — 물류를 대체하는 깊이의 두 번째 원천).
##
## **제로섬이다.** 대장장이를 늘리면 농부가 준다.
## 이 클래스는 그 제약을 강제하는 것이 아니라 *표현*한다 — 가구는 한 곳에만
## 있을 수 있으므로(SimFamily), 어디선가 빼오지 않으면 어디에도 넣을 수 없다.

var families: Array[SimFamily] = []


func total() -> int:
	return families.size()


func idle_count() -> int:
	var count := 0
	for family in families:
		if family.is_idle():
			count += 1
	return count


func assigned_to(slot_index: int) -> int:
	var count := 0
	for family in families:
		if family.workplace_slot == slot_index:
			count += 1
	return count


func add_family() -> void:
	families.append(SimFamily.new())


## 가구 하나를 내보낸다. 유휴 가구부터 나간다 — 굶주려 떠나는 마당에
## 생산 라인까지 먼저 무너지면 회복할 방법이 없다.
func remove_family() -> bool:
	if families.is_empty():
		return false

	for index in families.size():
		if families[index].is_idle():
			families.remove_at(index)
			return true

	families.remove_at(families.size() - 1)
	return true


## 해당 슬롯의 인원을 `desired`로 맞춘다.
##
## 늘릴 때는 유휴 가구에서만 데려온다. 다른 건물에서 자동으로 빼오지 않는다 —
## 플레이어가 어디를 비울지 직접 정해야 그 선택이 고민이 된다.
##
## 실제로 배정된 인원을 반환한다. 유휴 인력이 모자라면 요청보다 적을 수 있다.
func set_assignment(slot_index: int, desired: int, capacity: int) -> int:
	var target := clampi(desired, 0, capacity)
	var current := assigned_to(slot_index)

	if target < current:
		_release(slot_index, current - target)
	elif target > current:
		_recruit(slot_index, target - current)

	return assigned_to(slot_index)


## 건물이 사라졌을 때 그곳 인력을 유휴로 돌린다.
func release_all(slot_index: int) -> void:
	for family in families:
		if family.workplace_slot == slot_index:
			family.workplace_slot = -1


func _release(slot_index: int, count: int) -> void:
	var remaining := count
	for family in families:
		if remaining <= 0:
			return
		if family.workplace_slot == slot_index:
			family.workplace_slot = -1
			remaining -= 1


func _recruit(slot_index: int, count: int) -> void:
	var remaining := count
	for family in families:
		if remaining <= 0:
			return
		if family.is_idle():
			family.workplace_slot = slot_index
			remaining -= 1
