class_name SimResourcePool
extends RefCounted

## 마을 자원 창고 (GDD §4.3).
##
## 자원 종류를 코드에 열거하지 않는다. 데이터 파일이 "wood"라고 쓰면 그것이 자원이다.
## 새 자원을 추가할 때 이 파일은 건드릴 필요가 없다 (ARCHITECTURE §5).
##
## 비용 딕셔너리는 어디서나 `{ "wood": 15, "stone": 10 }` 형태다.

## 자원 id → 보유량. 없는 키는 0으로 취급한다.
var _amounts: Dictionary = {}


static func from_dict(initial: Dictionary) -> SimResourcePool:
	var pool := SimResourcePool.new()
	for id in initial:
		pool.add(String(id), int(initial[id]))
	return pool


func amount_of(id: String) -> int:
	return int(_amounts.get(id, 0))


## 음수를 넘기면 차감이다. 보유량은 0 아래로 내려가지 않는다.
func add(id: String, delta: int) -> void:
	_amounts[id] = maxi(0, amount_of(id) + delta)


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if amount_of(String(id)) < int(cost[id]):
			return false
	return true


## 전부 지불할 수 있을 때만 지불한다. 일부만 빠져나가는 일은 없다.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for id in cost:
		add(String(id), -int(cost[id]))
	return true


## 보유량이 0인 것까지 포함해, 한 번이라도 등장한 자원 id 전부.
## UI가 자원 바를 그릴 때 쓴다.
func tracked_ids() -> Array:
	var ids := _amounts.keys()
	ids.sort()
	return ids


func to_dict() -> Dictionary:
	return _amounts.duplicate()
