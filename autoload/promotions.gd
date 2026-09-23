extends Node
## 동료 승급 (GDD 6.6절). 동료 레벨이 50, 100, 150, 200, 250에 닿으면 골드를 내고 한 단계씩 승급한다.
## 단계마다 그 동료의 DPS가 1.5배가 된다. 단련처럼 한 판 안의 강화라 회귀하면 초기화된다.
## 배율은 Party가 동료 공식에 넘긴다. 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal promotion_changed(index: int, rank: int)  # 상태 갱신용 (초기화와 불러오기 포함)
signal promoted(index: int, rank: int)           # 실제로 승급한 순간. 연출과 알림용

var ranks: Array[int] = []  # 동료별 승급 단계. Balance.Companion 순서, 0 = 승급 없음


func _ready() -> void:
	reset()


## 새 판 시작 상태. 회귀와 데이터 초기화에서 부른다
func reset() -> void:
	ranks.clear()
	ranks.resize(Balance.COMPANIONS.size())
	ranks.fill(0)
	for i in ranks.size():
		promotion_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {"ranks": ranks.duplicate()}


## 없는 필드는 0으로, 상한을 넘는 값은 잘라낸다. 동료가 늘어나면 새 동료는 0단계
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("ranks", [])
	if saved is Array:
		for i in mini(saved.size(), ranks.size()):
			ranks[i] = clampi(int(saved[i]), 0, Balance.PROMOTION_MAX_RANK)
	for i in ranks.size():
		promotion_changed.emit(i, ranks[i])


func rank(index: int) -> int:
	return ranks[index]


func is_maxed(index: int) -> bool:
	return ranks[index] >= Balance.PROMOTION_MAX_RANK


## 다음 승급에 필요한 동료 레벨
func next_level(index: int) -> int:
	return Balance.promotion_level(ranks[index] + 1)


## 동료 레벨이 다음 승급 레벨에 닿았는지 (최고 단계면 false)
func is_unlocked(index: int) -> bool:
	return not is_maxed(index) and Party.companion_levels[index] >= next_level(index)


## 다음 승급 비용
func cost(index: int) -> float:
	return Balance.promotion_cost(index, ranks[index] + 1)


func can_promote(index: int) -> bool:
	return is_unlocked(index) and Game.gold >= cost(index)


## 승급. 레벨이 모자라거나 최고 단계이거나 골드가 모자라면 false
func promote(index: int) -> bool:
	if not is_unlocked(index) or not Game.spend(cost(index)):
		return false
	ranks[index] += 1
	promotion_changed.emit(index, ranks[index])
	promoted.emit(index, ranks[index])
	return true


## 승급할 수 있는 동료가 하나라도 있는지 (동료 탭 점)
func any_affordable() -> bool:
	for i in ranks.size():
		if can_promote(i):
			return true
	return false


## 이 동료의 DPS 배율
func multiplier(index: int) -> float:
	return Balance.promotion_multiplier(ranks[index])
